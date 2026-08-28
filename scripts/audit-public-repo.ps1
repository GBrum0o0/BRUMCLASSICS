$ErrorActionPreference = 'Stop'
$tracked = @(git ls-files)
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível listar os arquivos rastreados.' }
$blockedExtensions = @('.exe', '.apk', '.zip', '.7z', '.rar', '.srm', '.sav', '.state')
$blockedNames = @('library.json', 'accounts.json', 'collections.json', 'favorites.json', 'mobile-bridge.json')
$violations = @()

foreach ($file in $tracked) {
  $leaf = [IO.Path]::GetFileName($file)
  $extension = [IO.Path]::GetExtension($file).ToLowerInvariant()
  if ($blockedExtensions -contains $extension -or $blockedNames -contains $leaf.ToLowerInvariant()) {
    $violations += $file
  }
}

$absolutePaths = git grep -n -I -E '([A-Z]:\\Users\\|H:\\BRUMCLASSICS)' -- . ':!scripts/audit-public-repo.ps1' 2>$null
if ($LASTEXITCODE -eq 0) { $violations += $absolutePaths }
elseif ($LASTEXITCODE -ne 1) { throw 'Não foi possível verificar caminhos privados no repositório.' }

if ($violations.Count) {
  Write-Error ("Arquivos ou caminhos privados detectados:`n" + ($violations -join "`n"))
}

Write-Host "Auditoria pública concluída: $($tracked.Count) arquivos rastreados."
# git grep retorna 1 quando não encontra caminhos privados. Isso é sucesso
# nesta auditoria; não propagar esse código ao wrapper pwsh do GitHub Actions.
$global:LASTEXITCODE = 0
