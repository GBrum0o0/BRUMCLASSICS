$ErrorActionPreference = "Stop"

$commit = "79d7f9de218b6ffa65a80bbdc5828532bc239232"
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root "android\app\src\main\cpp\vendor\bsnes-mercury"
if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    git clone --filter=blob:none https://github.com/libretro/bsnes-mercury.git $target
}
git -C $target fetch origin $commit --depth 1
git -C $target checkout --detach $commit
if ((git -C $target rev-parse HEAD).Trim() -ne $commit) { throw "A revisão do bsnes-mercury não confere." }
$licenses = Join-Path $root "android\app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $target "LICENSE") -Destination (Join-Path $licenses "bsnes-mercury-LICENSE.txt") -Force
Write-Host "bsnes-mercury fixado em $commit"
