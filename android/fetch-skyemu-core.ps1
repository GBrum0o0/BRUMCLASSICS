$ErrorActionPreference = "Stop"

$commit = "36771a16bfde7eb5c1c0315877b5e465e6f38858"
$target = Join-Path $PSScriptRoot "app\src\main\cpp\vendor\skyemu"
$vendor = Split-Path -Parent $target

New-Item -ItemType Directory -Force -Path $vendor | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    git clone --depth 1 --branch v4 https://github.com/skylersaleh/SkyEmu.git $target
}
git -C $target fetch origin $commit
git -C $target checkout --detach $commit

$actual = git -C $target rev-parse HEAD
if ($actual -ne $commit) { throw "A revisão do SkyEmu não corresponde ao núcleo aprovado." }
$licenses = Join-Path $PSScriptRoot "app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $target "LICENSE") -Destination (Join-Path $licenses "SkyEmu-LICENSE.txt") -Force
Write-Host "SkyEmu preparado em $target ($actual)"
