$ErrorActionPreference = "Stop"

$commit = "8f00f500912a847062de432e38765c7285483e62"
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root "android\app\src\main\cpp\vendor\nestopia"
if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    git clone --filter=blob:none https://github.com/libretro/nestopia.git $target
}
git -C $target fetch origin $commit --depth 1
git -C $target checkout --detach $commit
if ((git -C $target rev-parse HEAD).Trim() -ne $commit) { throw "A revisão do Nestopia não confere." }
$licenses = Join-Path $root "android\app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $target "COPYING") -Destination (Join-Path $licenses "Nestopia-LICENSE.txt") -Force
Write-Host "Nestopia fixado em $commit"
