#!/usr/bin/env bash
set -euo pipefail

# Build the two GLES candidates from pinned sources in the same job as the IPA.
# A candidate is still experimental until gameplay, audio and saves pass on an
# actual iPhone. Never fetch an expiring artifact from another workflow run.
if [ "$#" -ne 2 ]; then
  echo "usage: $0 <ppsspp|flycast> <app-directory>" >&2
  exit 2
fi

CORE="$1"
APP="$2"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/build/${CORE}-core"
BUILD="$SCRIPT_DIR/build/${CORE}-ios"
case "$CORE" in
  ppsspp)
    REPOSITORY=https://github.com/libretro/ppsspp.git
    COMMIT=7b4ddb426bbe9e287bb7f19b0cfaebb4ea0d41d8
    TARGET=ppsspp_libretro
    LIBRARY=ppsspp_libretro_ios.dylib
    LICENSE=LICENSE.TXT
    LICENSE_OUT=PPSSPP-LICENSE.txt
    ;;
  flycast)
    REPOSITORY=https://github.com/flyinghead/flycast.git
    COMMIT=59ed35a7ea7c1940d4c8ac221a662d0e6d6dc9ea
    TARGET=flycast_libretro
    LIBRARY=flycast_libretro_ios.dylib
    LICENSE=LICENSE
    LICENSE_OUT=Flycast-LICENSE.txt
    ;;
  *) echo "unknown core: $CORE" >&2; exit 2 ;;
esac

test -d "$APP/Frameworks"
git clone --filter=blob:none "$REPOSITORY" "$SOURCE"
git -C "$SOURCE" checkout --detach "$COMMIT"
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$COMMIT"
git -C "$SOURCE" submodule update --init --recursive --depth 1

COMMON_FLAGS=(
  -G Xcode
  -DCMAKE_SYSTEM_NAME=iOS
  -DCMAKE_SYSTEM_PROCESSOR=arm64
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DCMAKE_OSX_SYSROOT=iphoneos
  -DCMAKE_OSX_ARCHITECTURES=arm64
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO
)

case "$CORE" in
  ppsspp)
    git -C "$SOURCE" apply --unidiff-zero "$SCRIPT_DIR/patches/ppsspp-ios-libretro.patch"
    cmake -DSOURCE_DIR="$SOURCE" -P "$SOURCE/git-version.cmake"
    test -f "$SOURCE/git-version.cpp"
    cmake -S "$SOURCE" -B "$BUILD" "${COMMON_FLAGS[@]}" \
      -DIOS=ON -DLIBRETRO=ON -DUSING_GLES2=ON -DMOBILE_DEVICE=ON \
      '-DOPENGL_LIBRARIES=-framework OpenGLES'
    ;;
  flycast)
    cmake -S "$SOURCE" -B "$BUILD" "${COMMON_FLAGS[@]}" \
      -DIOS=ON -DLIBRETRO=ON -DUSE_VULKAN=OFF \
      -DCMAKE_C_FLAGS=-DIOS=1 -DCMAKE_CXX_FLAGS=-DIOS=1 \
      -DUSE_HOST_LIBZIP=OFF -DUSE_HOST_GLSLANG=OFF -DENABLE_CTEST=OFF
    ;;
esac

cmake --build "$BUILD" --config Release --target "$TARGET" --parallel "$(sysctl -n hw.ncpu)"
CORE_PATH=$(find "$BUILD" -type f -name "${TARGET}*.dylib" -print -quit)
test -n "$CORE_PATH"
cp "$CORE_PATH" "$APP/Frameworks/$LIBRARY"
cp "$SOURCE/$LICENSE" "$APP/Frameworks/$LICENSE_OUT"
chmod 755 "$APP/Frameworks/$LIBRARY"
file "$APP/Frameworks/$LIBRARY" | grep -q arm64

if [ "$CORE" = ppsspp ]; then
  mkdir -p "$APP/Frameworks/CoreAssets/PPSSPP"
  ditto "$SOURCE/assets" "$APP/Frameworks/CoreAssets/PPSSPP"
  test -n "$(find "$APP/Frameworks/CoreAssets/PPSSPP" -type f -print -quit)"
fi
