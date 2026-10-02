$ErrorActionPreference = "Stop"

$commit = "3f946f277aef3aa99a95551618bbcd1dd2bda0d9"
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root "android\app\src\main\cpp\vendor\beetle-pce-fast"
if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    git clone --filter=blob:none https://github.com/libretro/beetle-pce-fast-libretro.git $target
}
git -C $target fetch origin $commit --depth 1
git -C $target checkout --detach $commit
if ((git -C $target rev-parse HEAD).Trim() -ne $commit) { throw "A revisão do Beetle PCE Fast não confere." }
$licenses = Join-Path $root "android\app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $target "COPYING") -Destination (Join-Path $licenses "Beetle-PCE-Fast-LICENSE.txt") -Force
Write-Host "Beetle PCE Fast fixado em $commit"
