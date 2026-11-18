#!/usr/bin/env bash
set -euo pipefail

# Build the exact GPLv2-or-later MAME revision proven by the isolated arm64
# probe. This is only called for the unsigned experimental iPhone IPA.
if [ "$#" -ne 1 ]; then
  echo "usage: $0 <app-directory>" >&2
  exit 2
fi

APP="$1"
SOURCE="$PWD/build/mame2016-core"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMIT=ae07c2f88ff2482ba9f50ffc8c9e7e6fbfe97d0a
test -d "$APP/Frameworks"
git clone --filter=blob:none https://github.com/libretro/mame2016-libretro.git "$SOURCE"
git -C "$SOURCE" checkout --detach "$COMMIT"
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$COMMIT"
grep -q 'GNU General Public License version 2 or later' "$SOURCE/LICENSE.md"
git -C "$SOURCE" apply --unidiff-zero "$SCRIPT_DIR/patches/mame2016-ios-host-safety.patch"

# SUBTARGET=arcade links as mamearcade2016_libretro.dylib. The upstream
# generic post-build rename looks for the default subtarget and would fail.
make -C "$SOURCE" -f Makefile.libretro platform=ios-arm64 SUBTARGET=arcade \
  IOS_MINVER=16.0 CORE_SUFFIX= -j"$(sysctl -n hw.ncpu)"
CORE="$SOURCE/mamearcade2016_libretro.dylib"
test -f "$CORE"
file "$CORE" | grep -q arm64
cp "$CORE" "$APP/Frameworks/mamearcade2016_libretro_ios.dylib"
chmod 755 "$APP/Frameworks/mamearcade2016_libretro_ios.dylib"
cp "$SOURCE/LICENSE.md" "$APP/Frameworks/MAME2016-LICENSE.md"
cp "$SOURCE/3rdparty/README.md" "$APP/Frameworks/MAME2016-THIRD-PARTY.md"
cp "$SOURCE/3rdparty/softfloat/README.txt" "$APP/Frameworks/MAME2016-softfloat-NOTICE.txt"
cp "$SOURCE/3rdparty/expat/COPYING" "$APP/Frameworks/MAME2016-expat-LICENSE.txt"
cp "$SOURCE/3rdparty/libflac/COPYING.Xiph" "$APP/Frameworks/MAME2016-FLAC-LICENSE.txt"
cp "$SOURCE/3rdparty/libuv/LICENSE" "$APP/Frameworks/MAME2016-libuv-LICENSE.txt"
cp "$SOURCE/3rdparty/http-parser/LICENSE-MIT" "$APP/Frameworks/MAME2016-http-parser-LICENSE.txt"
cp "$SOURCE/3rdparty/lzma/DOC/lzma-sdk.txt" "$APP/Frameworks/MAME2016-LZMA-NOTICE.txt"
