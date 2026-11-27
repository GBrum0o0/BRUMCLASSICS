"""Generate and validate the official BRUMCLASSICS iOS SideStore source JSON."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import plistlib
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

OFFICIAL_SOURCE_URL = "https://raw.githubusercontent.com/GBrum0o0/BRUMCLASSICS/sidestore-source/sidestore-source.json"
OFFICIAL_ICON_URL = "https://raw.githubusercontent.com/GBrum0o0/BRUMCLASSICS/main/ios/BRUMCLASSICSMobile/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
OFFICIAL_WEBSITE = "https://github.com/GBrum0o0/BRUMCLASSICS"
OFFICIAL_BUNDLE_ID = "com.brumclassics.mobile.ios"
OFFICIAL_SOURCE_ID = "com.brumclassics.sidestore.source"
OFFICIAL_SOURCE_NAME = "BRUMCLASSICS Oficial (iOS)"
OFFICIAL_APP_NAME = "BRUMCLASSICS"
OFFICIAL_DEVELOPER = "BRUMCLASSICS"
OFFICIAL_TINT = "#10B981"

SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
HEX_COLOR_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})?)?$")
ALLOWED_DOWNLOAD_RE = re.compile(
    r"^https://github\.com/GBrum0o0/BRUMCLASSICS/releases/download/"
    r"ios-v(\d+\.\d+\.\d+)/BRUMCLASSICS-MOVEL-IOS-\1\.ipa$"
)
MAX_REMOTE_IPA_BYTES = 512 * 1024 * 1024


class _StrictGitHubRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlsplit(newurl)
        host = (parsed.hostname or "").lower()
        if parsed.scheme != "https" or (host != "github.com" and not host.endswith(".githubusercontent.com")):
            raise ValueError(f"Redirect para host não autorizado recusado: {newurl}")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _urlopen_strict(url: str, timeout: int = 30):
    parsed = urllib.parse.urlsplit(url)
    host = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or (
        host != "github.com" and host != "api.github.com" and not host.endswith(".githubusercontent.com")
    ):
        raise ValueError(f"URL externa não permitida: {url}")
    opener = urllib.request.build_opener(_StrictGitHubRedirectHandler())
    req = urllib.request.Request(url, headers={"User-Agent": "BRUMCLASSICS-SideStore-Generator/1.0"})
    return opener.open(req, timeout=timeout)


def _version_sort_key(entry: dict) -> tuple[tuple[int, ...], int, str]:
    parts = tuple(int(part) for part in str(entry.get("version", "0.0.0")).split("."))
    try:
        build = int(str(entry.get("buildVersion", "0")).strip())
    except ValueError:
        build = 0
    return (parts, build, str(entry.get("date", "")))


def inspect_ipa_bytes_or_file(source: Path | bytes) -> dict:
    raw = source.read_bytes() if isinstance(source, Path) else source
    size = len(raw)
    sha256 = hashlib.sha256(raw).hexdigest().lower()
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        plist_names = [
            name for name in archive.namelist()
            if name.startswith("Payload/") and name.endswith(".app/Info.plist") and name.count("/") == 2
        ]
        if not plist_names:
            raise ValueError("Info.plist não encontrado dentro do pacote .ipa.")
        info = plistlib.loads(archive.read(plist_names[0]))
        if archive.testzip() is not None:
            raise ValueError("Verificação CRC do arquivo .ipa falhou.")

    bundle_id = str(info.get("CFBundleIdentifier") or "").strip()
    if bundle_id != OFFICIAL_BUNDLE_ID:
        raise ValueError(f"Bundle identifier inesperado no .ipa: {bundle_id!r}")
    if info.get("BRUMExperimentalBackends") is True:
        raise ValueError("Pacotes experimentais (-BACKENDS-TESTE) não podem entrar na fonte oficial.")

    version = str(info.get("CFBundleShortVersionString") or "").strip()
    build_version = str(info.get("CFBundleVersion") or "").strip()
    min_os = str(info.get("MinimumOSVersion") or "16.0").strip()
    if not SEMVER_RE.match(version):
        raise ValueError(f"CFBundleShortVersionString inválido: {version!r}")
    if not build_version.isdigit() or int(build_version) <= 0:
        raise ValueError(f"CFBundleVersion inválido: {build_version!r}")

    return {
        "bundleIdentifier": bundle_id,
        "version": version,
        "buildVersion": build_version,
        "minOSVersion": min_os,
        "size": size,
        "sha256": sha256,
    }


def validate_version_entry(entry: dict) -> None:
    version = str(entry.get("version") or "").strip()
    if not SEMVER_RE.match(version):
        raise ValueError(f"Versão inválida na fonte SideStore: {version!r}")
    build_version = str(entry.get("buildVersion") or "").strip()
    if not build_version.isdigit() or int(build_version) <= 0:
        raise ValueError(f"buildVersion inválido na fonte SideStore: {build_version!r}")
    date = str(entry.get("date") or "").strip()
    if not ISO_DATE_RE.match(date):
        raise ValueError(f"Data ISO inválida na fonte SideStore: {date!r}")
    download_url = str(entry.get("downloadURL") or "").strip()
    if "/releases/latest" in download_url.lower():
        raise ValueError("downloadURL não pode apontar para /releases/latest.")
    match = ALLOWED_DOWNLOAD_RE.match(download_url)
    if not match or match.group(1) != version:
        raise ValueError(f"downloadURL não corresponde a uma release oficial iOS {version}: {download_url!r}")
    size = entry.get("size")
    if not isinstance(size, int) or isinstance(size, bool) or size <= 0:
        raise ValueError(f"Tamanho inválido para {version}: {size!r}")
    sha256 = str(entry.get("sha256") or "").strip().lower()
    if not SHA256_RE.match(sha256):
        raise ValueError(f"SHA-256 inválido para {version}: {sha256!r}")
    min_os = str(entry.get("minOSVersion") or "").strip()
    if not min_os:
        raise ValueError(f"minOSVersion ausente para {version}.")


def validate_source_document(doc: dict) -> None:
    if not isinstance(doc, dict):
        raise ValueError("Documento da fonte SideStore precisa ser um objeto JSON.")
    for key in ("name", "identifier", "sourceURL", "apps"):
        if key not in doc or not doc[key]:
            raise ValueError(f"Campo obrigatório ausente na raiz da fonte: {key}")
    if doc["sourceURL"] != OFFICIAL_SOURCE_URL:
        raise ValueError(f"sourceURL inesperado: {doc['sourceURL']!r}")
    if "tintColor" in doc and not HEX_COLOR_RE.match(str(doc["tintColor"])):
        raise ValueError(f"tintColor inválido na raiz: {doc['tintColor']!r}")
    apps = doc.get("apps")
    if not isinstance(apps, list) or len(apps) != 1:
        raise ValueError("A fonte oficial deve conter exatamente o aplicativo iOS BRUMCLASSICS.")
    app = apps[0]
    if app.get("bundleIdentifier") != OFFICIAL_BUNDLE_ID:
        raise ValueError(f"bundleIdentifier inesperado no app: {app.get('bundleIdentifier')!r}")
    for key in ("name", "developerName", "localizedDescription", "iconURL", "versions"):
        if not app.get(key):
            raise ValueError(f"Campo obrigatório ausente no app: {key}")
    versions = app["versions"]
    if not isinstance(versions, list) or not versions:
        raise ValueError("O campo versions da fonte precisa ter ao menos uma versão válida.")
    for entry in versions:
        validate_version_entry(entry)
    keys = [_version_sort_key(v) for v in versions]
    if keys != sorted(keys, reverse=True):
        raise ValueError("As versões da fonte SideStore devem estar ordenadas da mais recente para a mais antiga.")


def verify_remote_ipa(download_url: str, expected_size: int, expected_sha256: str) -> dict:
    with _urlopen_strict(download_url, timeout=120) as resp:
        status = getattr(resp, "status", 200)
        if status != 200:
            raise ValueError(f"HTTP inesperado ao verificar IPA remoto: {status}")
        hasher = hashlib.sha256()
        total = 0
        header = b""
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            if len(header) < 2:
                header += chunk[: 2 - len(header)]
            total += len(chunk)
            if total > MAX_REMOTE_IPA_BYTES:
                raise ValueError("IPA remoto excede o limite máximo esperado.")
            hasher.update(chunk)
    actual_sha = hasher.hexdigest().lower()
    if header != b"PK":
        raise ValueError("O arquivo remoto não possui cabeçalho ZIP/IPA válido.")
    if total != expected_size:
        raise ValueError(f"Tamanho remoto divergente: esperado {expected_size}, obtido {total}.")
    if actual_sha != expected_sha256.lower():
        raise ValueError(f"SHA-256 remoto divergente: esperado {expected_sha256}, obtido {actual_sha}.")
    return {"size": total, "sha256": actual_sha}


def build_source_document(
    new_versions: list[dict],
    existing_source_path: Path | None = None,
) -> dict:
    merged_by_key: dict[tuple[str, str], dict] = {}
    if existing_source_path and existing_source_path.is_file():
        existing_doc = json.loads(existing_source_path.read_text(encoding="utf-8"))
        for app in existing_doc.get("apps", []):
            if app.get("bundleIdentifier") == OFFICIAL_BUNDLE_ID:
                for entry in app.get("versions", []):
                    validate_version_entry(entry)
                    merged_by_key[(entry["version"], str(entry["buildVersion"]))] = entry

    for entry in new_versions:
        validate_version_entry(entry)
        merged_by_key[(entry["version"], str(entry["buildVersion"]))] = entry

    ordered = sorted(merged_by_key.values(), key=_version_sort_key, reverse=True)
    if not ordered:
        raise ValueError("Nenhuma versão válida disponível para gerar sidestore-source.json.")
    latest = ordered[0]

    app_description = (
        "Cliente iOS oficial do ecossistema BRUMCLASSICS com biblioteca offline sincronizada, "
        "Gaming Mode, Gamepad remoto de baixa latência, núcleos integrados Libretro (incluindo "
        "PPSSPP sem JIT para iPhone) e RetroAchievements oficial (rcheevos)."
    )

    doc = {
        "name": OFFICIAL_SOURCE_NAME,
        "identifier": OFFICIAL_SOURCE_ID,
        "sourceURL": OFFICIAL_SOURCE_URL,
        "subtitle": "Atualizações oficiais do BRUMCLASSICS+ para iPhone via SideStore.",
        "description": "Fonte oficial do BRUMCLASSICS+ para iOS apontando exclusivamente para IPAs verificados nas releases ios-v* no GitHub.",
        "iconURL": OFFICIAL_ICON_URL,
        "website": OFFICIAL_WEBSITE,
        "tintColor": OFFICIAL_TINT,
        "featuredApps": [OFFICIAL_BUNDLE_ID],
        "apps": [
            {
                "name": OFFICIAL_APP_NAME,
                "bundleIdentifier": OFFICIAL_BUNDLE_ID,
                "developerName": OFFICIAL_DEVELOPER,
                "subtitle": "Emulação CLASSICS, Gaming Mode e segunda tela no iPhone.",
                "localizedDescription": app_description,
                "iconURL": OFFICIAL_ICON_URL,
                "tintColor": OFFICIAL_TINT,
                "category": "games",
                "screenshotURLs": [],
                "version": latest["version"],
                "versionDate": latest["date"],
                "versionDescription": latest["localizedDescription"],
                "downloadURL": latest["downloadURL"],
                "size": latest["size"],
                "versions": ordered,
            }
        ],
        "news": [],
    }
    validate_source_document(doc)
    return doc


def fetch_github_ios_releases() -> list[dict]:
    api_url = "https://api.github.com/repos/GBrum0o0/BRUMCLASSICS/releases?per_page=100"
    headers = {"User-Agent": "BRUMCLASSICS-SideStore-Generator/1.0", "Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(api_url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        releases = json.loads(resp.read().decode("utf-8"))

    versions: list[dict] = []
    for release in releases:
        if release.get("draft") or release.get("prerelease"):
            continue
        tag = str(release.get("tag_name") or "")
        tag_match = re.match(r"^ios-v(\d+\.\d+\.\d+)$", tag)
        if not tag_match:
            continue
        expected_ver = tag_match.group(1)
        expected_asset = f"BRUMCLASSICS-MOVEL-IOS-{expected_ver}.ipa"
        asset = next((a for a in release.get("assets", []) if a.get("name") == expected_asset), None)
        if not asset:
            continue
        download_url = str(asset.get("browser_download_url") or "")
        if not ALLOWED_DOWNLOAD_RE.match(download_url):
            continue
        with _urlopen_strict(download_url, timeout=180) as ipa_resp:
            if getattr(ipa_resp, "status", 200) != 200:
                continue
            raw_ipa = ipa_resp.read(MAX_REMOTE_IPA_BYTES + 1)
            if len(raw_ipa) > MAX_REMOTE_IPA_BYTES:
                raise ValueError(f"IPA remoto {expected_asset} excede o tamanho máximo permitido.")
        meta = inspect_ipa_bytes_or_file(raw_ipa)
        if meta["version"] != expected_ver:
            raise ValueError(f"Versão interna do IPA ({meta['version']}) diverge da tag ({expected_ver}).")
        versions.append({
            "version": meta["version"],
            "buildVersion": meta["buildVersion"],
            "date": str(release.get("published_at") or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
            "localizedDescription": str(release.get("body") or f"BRUMCLASSICS+ iOS {meta['version']}").strip(),
            "downloadURL": download_url,
            "size": meta["size"],
            "sha256": meta["sha256"],
            "minOSVersion": meta["minOSVersion"],
        })
    if not versions:
        raise ValueError("Nenhuma release oficial iOS (ios-v*) publicada com IPA válido foi encontrada.")
    return versions


def write_json_atomic(output_path: Path, document: dict) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(document, indent=2, ensure_ascii=False) + "\n"
    fd, tmp_name = tempfile.mkstemp(prefix=".sidestore-source-", suffix=".tmp", dir=str(output_path.parent))
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(payload)
        os.replace(str(tmp_path), str(output_path))
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)
        raise


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gera e valida a fonte oficial SideStore do BRUMCLASSICS iOS.")
    parser.add_argument("--ipa", type=Path, help="Caminho do pacote .ipa oficial.")
    parser.add_argument("--validation-json", type=Path, help="Caminho opcional do IPA-VALIDATION.json.")
    parser.add_argument("--download-url", help="URL HTTPS oficial da release ios-v<versão> no GitHub.")
    parser.add_argument("--notes", help="Texto de notas da atualização.")
    parser.add_argument("--notes-file", type=Path, help="Arquivo de notas de lançamento.")
    parser.add_argument("--date", help="Data ISO-8601 UTC (padrão: agora em UTC).")
    parser.add_argument("--existing-source", type=Path, help="sidestore-source.json existente para preservar histórico.")
    parser.add_argument("--from-github-releases", action="store_true", help="Gera a partir das releases ios-v* publicadas no GitHub.")
    parser.add_argument("--verify-remote", action="store_true", help="Confirma HTTP 200, tamanho e SHA-256 no servidor antes de gravar.")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Caminho de saída do sidestore-source.json.")
    args = parser.parse_args(argv)

    if args.from_github_releases:
        versions = fetch_github_ios_releases()
    else:
        if not args.ipa or not args.download_url:
            parser.error("--ipa e --download-url são obrigatórios quando --from-github-releases não é usado.")
        meta = inspect_ipa_bytes_or_file(args.ipa)
        if args.validation_json:
            validation = json.loads(args.validation_json.read_text(encoding="utf-8"))
            if validation.get("ok") is not True:
                raise ValueError("IPA-VALIDATION.json não indica pacote aprovado.")
            if validation.get("bundleId") != OFFICIAL_BUNDLE_ID:
                raise ValueError("IPA-VALIDATION.json com bundleId inesperado.")
            if validation.get("version") != meta["version"] or str(validation.get("build")) != meta["buildVersion"]:
                raise ValueError("IPA-VALIDATION.json diverge da versão/build interna do .ipa.")
            if validation.get("experimentalBackends") is True:
                raise ValueError("Build experimental não é elegível para a fonte oficial SideStore.")
        notes = (args.notes or "").strip()
        if args.notes_file:
            notes = args.notes_file.read_text(encoding="utf-8").strip()
        if not notes:
            notes = f"BRUMCLASSICS+ iOS {meta['version']} (build {meta['buildVersion']})."
        entry = {
            "version": meta["version"],
            "buildVersion": meta["buildVersion"],
            "date": args.date or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "localizedDescription": notes,
            "downloadURL": args.download_url,
            "size": meta["size"],
            "sha256": meta["sha256"],
            "minOSVersion": meta["minOSVersion"],
        }
        validate_version_entry(entry)
        if args.verify_remote:
            verify_remote_ipa(entry["downloadURL"], entry["size"], entry["sha256"])
        versions = [entry]

    doc = build_source_document(versions, existing_source_path=args.existing_source)
    write_json_atomic(args.output, doc)
    print(json.dumps({
        "ok": True,
        "sourceURL": doc["sourceURL"],
        "versionCount": len(doc["apps"][0]["versions"]),
        "latestVersion": doc["apps"][0]["version"],
        "latestBuild": doc["apps"][0]["versions"][0]["buildVersion"],
        "sha256": doc["apps"][0]["versions"][0]["sha256"],
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
