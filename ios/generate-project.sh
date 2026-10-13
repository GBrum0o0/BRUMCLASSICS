#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen não encontrado. Instale com: brew install xcodegen"
  exit 1
fi
mkdir -p build/test-fixtures
xcrun --sdk iphonesimulator clang -dynamiclib -arch arm64 -arch x86_64 \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" -mios-simulator-version-min=16.0 \
  -Wall -Wextra -Werror BRUMCLASSICSMobileTests/Fixtures/BrumTestCore.c \
  -o build/test-fixtures/BrumTestCore.dylib
xcodegen generate
echo "Projeto criado: $(pwd)/BRUMCLASSICSMobile.xcodeproj"
