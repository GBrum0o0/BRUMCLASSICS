$ErrorActionPreference = "Stop"

$commit = "4b01295838ea89e3f1355bbe4cb5cf98aa6108cd"
$target = Join-Path $PSScriptRoot "app\src\main\cpp\vendor\beetle-wswan"
$vendor = Split-Path -Parent $target

New-Item -ItemType Directory -Force -Path $vendor | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    git clone --filter=blob:none https://github.com/libretro/beetle-wswan-libretro.git $target
}
git -C $target fetch origin $commit
git -C $target checkout --detach $commit

$actual = git -C $target rev-parse HEAD
if ($actual -ne $commit) { throw "A revisão do Beetle WonderSwan não corresponde ao núcleo aprovado." }
$licenses = Join-Path $PSScriptRoot "app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $target "COPYING") -Destination (Join-Path $licenses "Beetle-WonderSwan-LICENSE.txt") -Force
Write-Host "Beetle WonderSwan preparado em $target ($actual)"
