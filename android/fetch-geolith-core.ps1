$ErrorActionPreference = "Stop"

$commit = "194024931935eff2092e36fc4f8e53e62ed11097"
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root "android\app\src\main\cpp\vendor\geolith"
if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    git clone --filter=blob:none https://github.com/libretro/geolith-libretro.git $target
}
git -C $target fetch origin $commit --depth 1
git -C $target checkout --detach $commit
if ((git -C $target rev-parse HEAD).Trim() -ne $commit) { throw "A revisão do Geolith não confere." }
$licenses = Join-Path $root "android\app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $target "LICENSE") -Destination (Join-Path $licenses "Geolith-LICENSE.txt") -Force
Write-Host "Geolith fixado em $commit"
