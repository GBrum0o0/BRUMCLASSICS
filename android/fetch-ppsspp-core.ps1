$ErrorActionPreference = "Stop"
$commit = "7b4ddb426bbe9e287bb7f19b0cfaebb4ea0d41d8"
$source = Join-Path $PSScriptRoot "app/src/main/cpp/vendor/ppsspp"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android/Sdk" }
$ndk = Join-Path $sdk "ndk/27.0.12077973"
$cmake = Join-Path $sdk "cmake/3.22.1/bin/cmake.exe"
$ninja = Join-Path $sdk "cmake/3.22.1/bin/ninja.exe"
function Check-Exit($message) { if ($LASTEXITCODE -ne 0) { throw $message } }
if (-not (Test-Path -LiteralPath (Join-Path $source ".git"))) {
    git clone --filter=blob:none https://github.com/libretro/ppsspp.git $source
    Check-Exit "Falha ao obter o PPSSPP."
}
git -C $source fetch origin $commit --depth 1
Check-Exit "Falha ao obter a revisão fixada."
git -C $source checkout --detach $commit
Check-Exit "Falha ao selecionar a revisão fixada."
if ((git -C $source rev-parse HEAD).Trim() -ne $commit) { throw "A revisão do PPSSPP não confere." }
git -C $source submodule update --init --recursive --depth 1
Check-Exit "Falha ao obter as dependências fixadas do PPSSPP."
$patch = Join-Path $PSScriptRoot "patches/ppsspp-context-lifecycle.patch"
git -C $source apply --reverse --check $patch 2>$null
if ($LASTEXITCODE -ne 0) {
    git -C $source apply $patch
    Check-Exit "Falha ao aplicar a correção de encerramento do PPSSPP."
}
$build = Join-Path $source "build-brum-android-arm64"
$pythonExe = $null
foreach ($candidate in @('python3', 'python', 'py')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if (-not $cmd) { continue }
    if ($candidate -eq 'py') {
        $resolved = (& py -3 -c "import sys; print(sys.executable)" 2>$null)
        if ($LASTEXITCODE -eq 0 -and $resolved) { $pythonExe = $resolved.Trim(); break }
    } elseif ($cmd.Source -notmatch 'WindowsApps\\python') {
        $pythonExe = $cmd.Source; break
    }
}
$cmakeArgs = @(
    '-S', $source, '-B', $build, '-G', 'Ninja',
    '-DLIBRETRO=ON', '-DHEADLESS=OFF', '-DUNITTEST=OFF', '-DUSE_DISCORD=OFF',
    '-DCMAKE_BUILD_TYPE=Release', '-DANDROID_ABI=arm64-v8a', "-DANDROID_NDK=$ndk",
    "-DCMAKE_TOOLCHAIN_FILE=$ndk/build/cmake/android.toolchain.cmake",
    '-DANDROID_PLATFORM=android-26', '-DANDROID_STL=c++_static', "-DCMAKE_MAKE_PROGRAM=$ninja",
    '-DCMAKE_C_FLAGS=-DHAVE_UNISTD_H=1'
)
if ($pythonExe) { $cmakeArgs += "-DPYTHON_EXECUTABLE=$pythonExe" }
& $cmake @cmakeArgs
Check-Exit "Falha ao configurar o PPSSPP."
& $cmake --build $build --target ppsspp_libretro --parallel 4
Check-Exit "Falha ao compilar o PPSSPP."
$destination = Join-Path $PSScriptRoot "app/src/main/jniLibs/arm64-v8a"
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item -LiteralPath (Join-Path $build "ppsspp_libretro_android.so") -Destination $destination -Force
$assets = Join-Path $PSScriptRoot "app/src/main/assets"
# See ios/prepare_ppsspp_assets.py for the pinned replacement font and licenses.
if ($pythonExe) { & $pythonExe (Join-Path $PSScriptRoot "../ios/prepare_ppsspp_assets.py") --android $source $assets }
else { py -3 (Join-Path $PSScriptRoot "../ios/prepare_ppsspp_assets.py") --android $source $assets }
Check-Exit "Falha ao preparar os recursos licenciados do PPSSPP."
