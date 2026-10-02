$ErrorActionPreference = "Stop"

$commit = "2d9106f2063d1a6e0661cc8938bb7f8eb737bcae"
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root "android\app\src\main\cpp\vendor\gearsystem"
if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    git clone --filter=blob:none https://github.com/drhelius/Gearsystem.git $target
}
git -C $target fetch origin $commit --depth 1
git -C $target checkout --detach $commit
if ((git -C $target rev-parse HEAD).Trim() -ne $commit) { throw "A revisão do Gearsystem não confere." }
$licenses = Join-Path $root "android\app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $target "LICENSE") -Destination (Join-Path $licenses "Gearsystem-LICENSE.txt") -Force
Write-Host "Gearsystem fixado em $commit"
