$ErrorActionPreference = "Stop"

$commit = "7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6"
$target = Join-Path $PSScriptRoot "app\src\main\cpp\vendor\mgba"
$vendor = Split-Path -Parent $target

New-Item -ItemType Directory -Force -Path $vendor | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    git clone --filter=blob:none https://github.com/libretro/mgba.git $target
}
git -C $target fetch origin $commit
git -C $target checkout --detach $commit

$actual = git -C $target rev-parse HEAD
if ($actual -ne $commit) { throw "A revisão do mGBA não corresponde ao núcleo aprovado." }
$licenses = Join-Path $PSScriptRoot "app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $target "LICENSE") -Destination (Join-Path $licenses "mGBA-LICENSE.txt") -Force
Write-Host "mGBA preparado em $target ($actual)"
