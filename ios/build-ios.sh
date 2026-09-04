#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
./generate-project.sh
xcodebuild -project BRUMCLASSICSMobile.xcodeproj -scheme BRUMCLASSICSMobile -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' clean test
echo "Validação do simulador concluída. Para um IPA, selecione sua equipe Apple no Xcode e use Product > Archive."
