$ErrorActionPreference = 'Stop'
$tracked = @(git ls-files)
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

if ($violations.Count) {
  Write-Error ("Arquivos ou caminhos privados detectados:`n" + ($violations -join "`n"))
}

Write-Host "Auditoria pública concluída: $($tracked.Count) arquivos rastreados."

