param([Parameter(Mandatory = $true)][string]$AssetDirectory)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($AssetDirectory)
$sumFile = Join-Path $root 'SHA256SUMS.txt'
if (!(Test-Path -LiteralPath $sumFile)) { throw 'SHA256SUMS.txt não encontrado.' }

foreach ($line in Get-Content -LiteralPath $sumFile) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $parts = $line -split '\s{2,}', 2
  $expected = $parts[0].Trim().ToUpperInvariant()
  $target = Join-Path $root $parts[1].Trim()
  if (!(Test-Path -LiteralPath $target)) { throw "Arquivo ausente: $target" }
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash
  if ($actual -ne $expected) { throw "Hash divergente: $target" }
  Write-Host "OK $([IO.Path]::GetFileName($target))"
}

