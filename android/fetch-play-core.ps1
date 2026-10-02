$ErrorActionPreference = "Stop"

$commit = "83700b2c31e593bc94e845b4b31b797be84dda59"
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root "android\app\src\main\cpp\vendor\play"
$output = Join-Path $root "android\app\src\main\jniLibs\arm64-v8a\play_libretro_android.so"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$ndk = Join-Path $sdk "ndk\27.0.12077973"
$cmake = Join-Path $sdk "cmake\3.22.1\bin\cmake.exe"
$ninja = Join-Path $sdk "cmake\3.22.1\bin\ninja.exe"
$toolchain = Join-Path $ndk "build\cmake\android.toolchain.cmake"

if (-not (Test-Path -LiteralPath (Join-Path $source ".git"))) {
    git clone --filter=blob:none --recurse-submodules https://github.com/jpd002/Play-.git $source
}
git -C $source fetch origin $commit --depth 1
git -C $source checkout --detach $commit
git -C $source submodule update --init --recursive --depth 1
if ((git -C $source rev-parse HEAD).Trim() -ne $commit) { throw "A revisão do Play! não confere." }

$build = Join-Path $source "build-brum-android-arm64"
& $cmake -S $source -B $build -G Ninja `
    -DBUILD_LIBRETRO_CORE=ON -DBUILD_PLAY=OFF -DBUILD_TESTS=OFF -DENABLE_AMAZON_S3=OFF `
    -DCMAKE_BUILD_TYPE=Release -DANDROID_ABI=arm64-v8a "-DANDROID_NDK=$ndk" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain" `
    -DANDROID_NATIVE_API_LEVEL=26 -DANDROID_PLATFORM=android-26 -DANDROID_STL=c++_static `
    -DANDROID_TOOLCHAIN=clang "-DCMAKE_MAKE_PROGRAM=$ninja"
if ($LASTEXITCODE -ne 0) { throw "Falha ao configurar o Play!." }
& $cmake --build $build --target play_libretro --parallel
if ($LASTEXITCODE -ne 0) { throw "Falha ao compilar o Play!." }

$built = Join-Path $build "Source\ui_libretro\play_libretro_android.so"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
Copy-Item -LiteralPath $built -Destination $output -Force
$licenses = Join-Path $root "android\app\src\main\assets\core-licenses"
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $source "License.txt") -Destination (Join-Path $licenses "Play-LICENSE.txt") -Force
if ((Get-Item -LiteralPath $output).Length -lt 1MB) { throw "O núcleo Play! gerado é inválido." }
Write-Host "Play! ARM64 pronto em $output"
