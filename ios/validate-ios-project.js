'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;
const app = path.join(root, 'BRUMCLASSICSMobile');
const info = fs.readFileSync(path.join(app, 'Info.plist'), 'utf8');
if (!/<key>CFBundleExecutable<\/key>\s*<string>\$\(EXECUTABLE_NAME\)<\/string>/.test(info)) throw new Error('CFBundleExecutable deve apontar para EXECUTABLE_NAME.');
if (!fs.readFileSync(path.join(root, 'project.yml'), 'utf8').includes('PRODUCT_NAME: BRUMCLASSICSMobile')) throw new Error('Nome interno ASCII estável ausente.');
const required = [
  'project.yml', 'BRUMCLASSICSMobile/Info.plist', 'BRUMCLASSICSMobile/PrivacyInfo.xcprivacy',
  'BRUMCLASSICSMobile/BRUMCLASSICSMobileApp.swift', 'BRUMCLASSICSMobile/AppStore.swift',
  'BRUMCLASSICSMobile/BridgeClient.swift', 'BRUMCLASSICSMobile/Models.swift',
  'BRUMCLASSICSMobile/NotificationsView.swift',
  'BRUMCLASSICSMobile/GamingModeView.swift',
  'BRUMCLASSICSMobile/PersonalUpdateService.swift',
  'BRUMCLASSICSMobile/ProfileView.swift', 'BRUMCLASSICSMobile/BCardView.swift',
  'BRUMCLASSICSMobile/ROMFolderLibrary.swift',
  'BRUMCLASSICSMobile/IntegratedEmulatorView.swift',
  'BRUMCLASSICSMobile/Libretro/BrumLibretroAPI.h',
  'BRUMCLASSICSMobile/Libretro/BrumLibretroEngine.h',
  'BRUMCLASSICSMobile/Libretro/BrumLibretroEngine.mm',
  'BRUMCLASSICSMobile/BRUMCLASSICSMobile-Bridging-Header.h',
  'BRUMCLASSICSMobile/MomentsView.swift', 'BRUMCLASSICSMobileTests/SnapshotTests.swift',
  'ios-update.json'
];

for (const relative of required) {
  if (!fs.existsSync(path.join(root, relative))) throw new Error(`Arquivo obrigatório ausente: ${relative}`);
}

const swiftFiles = fs.readdirSync(app).filter((name) => name.endsWith('.swift'));
const source = swiftFiles.map((name) => fs.readFileSync(path.join(app, name), 'utf8')).join('\n');
const requiredEndpoints = ['/v1/pair', '/v1/snapshot', '/v1/ws', '/v1/remote', '/v1/companion/notes', '/v1/companion/library-state', '/v1/companion/capture', '/v1/moments/', '/v1/notifications/read', '/v1/notifications/read-all'];
for (const endpoint of requiredEndpoints) if (!source.includes(endpoint)) throw new Error(`Endpoint não portado: ${endpoint}`);

const requiredCommands = ['bcard_launch'];
for (const marker of ['PocketRuntimeFiles', '/v1/classics/playtime', 'acknowledgedSeconds', 'startAccessingSecurityScopedResource']) {
  if (!source.includes(marker)) throw new Error(`Horas offline incompletas: ${marker}`);
}
for (const marker of ['PocketPlaySessionFiles', 'notePlaySessionBackgrounded', 'finishPlaySession', 'creditEstimated', 'recordLocalLaunch']) {
  if (!source.includes(marker)) throw new Error(`Conclusão automática de sessão incompleta: ${marker}`);
}
for (const marker of ['"filename": record.filename', '"title": game.title', 'receipt.gameId', 'PocketFeaturedGameCard(game:', 'ROMArtworkCache.shared.artwork']) {
  if (!source.includes(marker)) throw new Error(`Vínculo, horas ou capa recente incompletos: ${marker}`);
}
for (const marker of ['RetroArchLibraryRules.queryURL', 'RetroArchLibraryRules', 'receiveRetroArchLibrary', 'brumclassics', 'titleId']) {
  if (!source.includes(marker)) throw new Error(`Biblioteca RetroArch incompleta: ${marker}`);
}
if (!source.includes('retroarch-library-v2.json')) throw new Error('Cache antigo de abertura direta ainda pode sobreviver à reinstalação do RetroArch.');
for (const marker of ['ROMFolderScanner', 'ROMFolderAccess', 'choose-rom-folder', 'romFolderGames', 'refreshROMFolder']) {
  if (!source.includes(marker)) throw new Error(`Pasta de ROMs incompleta: ${marker}`);
}
for (const marker of ['ROMTitleRules.clean', 'beginShare(for game:', 'ROMExportStager.stage', 'RetroArchExports', 'pendingROMShare', 'completionWithItemsHandler']) {
  if (!source.includes(marker)) throw new Error(`Importação autorizada ou metadados de ROM incompletos: ${marker}`);
}
for (const marker of ['RetroArchAppStoreLaunchRules', '~/Documents/RetroArch/downloads/', 'importedIntoRetroArch = true']) {
  if (!source.includes(marker)) throw new Error(`Abertura após importação única incompleta: ${marker}`);
}
if (source.includes('URLQueryItem(name: "path", value: content.path)') || source.includes('func directLaunchURL(for game:')) throw new Error('Caminho externo não pode ser enviado ao RetroArch sem transferir a permissão do iOS.');
if (source.includes('CLASSICS in every everywhere')) throw new Error('Nome antigo e repetido de CLASSICS ainda está visível no aplicativo.');
if (source.includes('NA BIBLIOTECA DO PC · AINDA NÃO JOGÁVEIS NO IPHONE')) throw new Error('CLASSICS não pode listar jogos sem ROM detectada no iPhone.');
for (const command of requiredCommands) if (!source.includes(`"${command}"`)) throw new Error(`Comando remoto não portado: ${command}`);
for (const obsolete of ['CompanionControlView', 'PESQUISA NO LIVING ROOM', '"shutdown_pc"', '"sleep_pc"', '"quick_save"', '"quick_load"', '"set_volume"']) if (source.includes(obsolete)) throw new Error(`Controle remoto antigo ainda presente: ${obsolete}`);
if (!source.includes('struct CompanionView') || !source.includes('struct CompanionNotesForm')) throw new Error('Companion de anotações ausente.');
if (!source.includes('let playtimeMinutes: Double?')) throw new Error('Tempo fracionado não suportado.');
const bcardView = fs.readFileSync(path.join(app, 'BCardView.swift'), 'utf8').split('struct BCardView: View')[1];
if (!bcardView.includes('bcard-back') || !bcardView.includes('repeatForever') || !bcardView.includes('artworkOnly: true')) throw new Error('B-CARD flutuante e voltar ausentes.');
if (bcardView.includes('Picker(') || bcardView.includes('BrumLogo(') || bcardView.includes('Text(game.title)')) throw new Error('B-CARD ainda possui campos que devem ficar fora da capa.');
if (bcardView.split('private func send')[1].includes('offset = 0')) throw new Error('B-CARD lançado não pode retornar ao centro.');
for (const marker of ['ClassicsEverywhereView', 'PocketSetupView', 'PocketRules.launchURL', '/v1/classics/achievements/sync', 'API_GetGameInfoAndUserProgress.php']) if (!source.includes(marker)) throw new Error(`CLASSICS iPhone incompleto: ${marker}`);
if (!source.includes('companion-capture') || !source.includes('MobileSettingsView')) throw new Error('Captura ou configurações móveis ausentes.');
for (const marker of ['MobileNotificationSnapshot', 'NotificationsView', 'notifications_changed', 'markAllNotificationsRead']) if (!source.includes(marker)) throw new Error(`Central BRUM incompleta: ${marker}`);
for (const marker of ['struct GamingModeView', 'GamingTabBar(selection:', 'JOGADOS RECENTEMENTE', 'BIBLIOTECA', 'GamingModeCatalog.library', 'pocket.romFolderGames', 'GamingOrientation.request(.landscape)', 'selection != 2']) {
  if (!source.includes(marker)) throw new Error(`Gaming Mode incompleto: ${marker}`);
}
if (!source.includes('pocket.launchROM(rom, launcher: store)') || !source.includes('store.launchBCard(game)')) throw new Error('Gaming Mode não decide entre execução local e computador.');
const gamingSource = fs.readFileSync(path.join(app, 'GamingModeView.swift'), 'utf8');
for (const marker of ['GamingROMDetailView(rom: $0)', 'selectedROM = rom', 'CoreRegistry.installedCore', 'GamingModeCatalog.canOfferRetroArch', 'if IntegratedEmulatorSupport.system(for: rom) == .nintendo3DS { return false }']) {
  if (!source.includes(marker)) throw new Error(`Detalhes do Gaming Mode ou rota 3DS incompletos: ${marker}`);
}
if (gamingSource.includes('Prontos para jogar') || gamingSource.includes('INSTALADOS NO COMPUTADOR')) throw new Error('Gaming Mode antigo ainda está visível.');
for (const marker of ['IntegratedEmulatorSupport.supports', 'prepareIntegratedROM', 'stageForIntegratedPlay', 'JOGAR · BRUM CORE', 'finishIntegratedPlay']) {
  if (!source.includes(marker)) throw new Error(`Emulação integrada incompleta: ${marker}`);
}
for (const marker of ['CoordinatedFileAccess', 'NSFileCoordinator', 'REAUTORIZAR PASTA']) {
  if (!source.includes(marker)) throw new Error(`Acesso coordenado às ROMs incompleto: ${marker}`);
}
const integratedEngine = fs.readFileSync(path.join(app, 'Libretro', 'BrumLibretroEngine.mm'), 'utf8');
for (const marker of ['forward.fill', 'toggleFastForward', '_fastForwardEnabled ? 5 : _frameCadence.framesDue', '_suppressVideo', 'AVANÇO RÁPIDO · 5×']) {
  if (!integratedEngine.includes(marker)) throw new Error(`Avanço rápido do BRUM Core incompleto: ${marker}`);
}
for (const marker of ['brum::calculateViewport', 'brum::ScaleMode::crop', 'toggleDisplayMode', '_screenFillsDisplay = NO', 'Preencher tela', 'Mostrar imagem inteira']) {
  if (!integratedEngine.includes(marker)) throw new Error(`Preenchimento de tela do BRUM Core incompleto: ${marker}`);
}
if (integratedEngine.includes('[close.heightAnchor constraintEqualToConstant:38]') || integratedEngine.includes('[_fastForwardButton.heightAnchor constraintEqualToConstant:38]')) throw new Error('Controles superiores ainda possuem restrições de altura conflitantes.');
for (const marker of ['constraintEqualToAnchor:self.view.leadingAnchor', 'constraintEqualToAnchor:self.view.trailingAnchor', 'constraintEqualToAnchor:self.view.topAnchor', 'constraintEqualToAnchor:self.view.bottomAnchor']) {
  if (!integratedEngine.includes(marker)) throw new Error(`Tela cheia do BRUM Core incompleta: ${marker}`);
}
if (!source.includes('IntegratedEmulatorView(rom: rom, returnsToPortrait: false)')) throw new Error('BRUM Core precisa preservar o Gaming Mode horizontal ao sair.');
const homeSource = fs.readFileSync(path.join(app, 'HomeView.swift'), 'utf8');
if (homeSource.includes('classics-everywhere-link') || homeSource.includes('NavigationLink { BCardLibraryView()')) throw new Error('Início ainda expõe atalhos removidos de B-CARD ou CLASSICS Everywhere.');
if (!homeSource.includes('profile-home-link')) throw new Error('Perfil precisa estar acessível pelo Início.');

if (!source.includes('SecureStore.write')) throw new Error('Token não está protegido pelo Keychain.');
if (!source.includes('SHA256.hash(data: data)')) throw new Error('Certificate pinning ausente.');
if (!source.includes('completeFileProtectionUnlessOpen')) throw new Error('Proteção dos arquivos offline ausente.');
if (source.includes('NSAllowsArbitraryLoads')) throw new Error('Exceção ATS ampla não é permitida.');
if (!source.includes('com.brumclassics.mobile.ios') && !fs.readFileSync(path.join(root, 'project.yml'), 'utf8').includes('com.brumclassics.mobile.ios')) throw new Error('Bundle ID pessoal fixo ausente.');
if (!source.includes('checkForPersonalUpdate')) throw new Error('Verificação de atualização pessoal ausente.');

const updateManifest = JSON.parse(fs.readFileSync(path.join(root, 'ios-update.json'), 'utf8'));
const publishedUpdateManifest = JSON.parse(fs.readFileSync(path.join(root, '..', 'ios-update.json'), 'utf8'));
const workflow = fs.readFileSync(path.join(root, '..', '.github', 'workflows', 'build-ios-personal.yml'), 'utf8');
if (!workflow.includes('ios/build/BRUMCLASSICS-MOVEL-IOS-*.ipa')) throw new Error('Upload do IPA não pode ficar preso a uma versão antiga.');
for (const marker of ['CORE_COMMIT="7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6"', 'mgba_libretro_ios.dylib', '-DCMAKE_SYSTEM_NAME=iOS', '--target mgba_libretro']) {
  if (!workflow.includes(marker)) throw new Error(`Build reproduzível do core mGBA incompleto: ${marker}`);
}
for (const marker of ['CORE_COMMIT="36771a16bfde7eb5c1c0315877b5e465e6f38858"', 'skyemu_libretro_ios.dylib', '--target skyemu_libretro']) {
  if (!workflow.includes(marker)) throw new Error(`Build reproduzível do core SkyEmu incompleto: ${marker}`);
}
for (const marker of ['CORE_COMMIT="194024931935eff2092e36fc4f8e53e62ed11097"', 'geolith_libretro_ios.dylib', 'platform=ios-arm64']) {
  if (!workflow.includes(marker)) throw new Error(`Build reproduzível do core Geolith incompleto: ${marker}`);
}
for (const marker of ['CORE_COMMIT="2d9106f2063d1a6e0661cc8938bb7f8eb737bcae"', 'gearsystem_libretro_ios.dylib', 'Gearsystem-LICENSE.txt', 'BRUMCLASSICS-Mobile-GPL-3.0.txt']) {
  if (!workflow.includes(marker)) throw new Error(`Build reproduzível do core Gearsystem incompleto: ${marker}`);
}
for (const marker of ['CORE_COMMIT="8f00f500912a847062de432e38765c7285483e62"', 'nestopia_libretro_ios.dylib', 'Nestopia-LICENSE.txt']) {
  if (!workflow.includes(marker)) throw new Error(`Build reproduzível do core Nestopia incompleto: ${marker}`);
}
for (const marker of ['CORE_COMMIT="3f946f277aef3aa99a95551618bbcd1dd2bda0d9"', 'mednafen_pce_fast_libretro_ios.dylib', 'Beetle-PCE-Fast-LICENSE.txt']) {
  if (!workflow.includes(marker)) throw new Error(`Build reproduzível do core Beetle PCE Fast incompleto: ${marker}`);
}
for (const marker of ['CORE_COMMIT="79d7f9de218b6ffa65a80bbdc5828532bc239232"', 'bsnes_mercury_performance_libretro_ios.dylib', 'bsnes-mercury-LICENSE.txt']) {
  if (!workflow.includes(marker)) throw new Error(`Build reproduzível do core bsnes-mercury incompleto: ${marker}`);
}
for (const marker of ['CORE_COMMIT="4b01295838ea89e3f1355bbe4cb5cf98aa6108cd"', 'mednafen_wswan_libretro_ios.dylib', 'Beetle-WonderSwan-LICENSE.txt']) {
  if (!workflow.includes(marker)) throw new Error(`Build reproduzível do core Beetle WonderSwan incompleto: ${marker}`);
}
if (!/^\d+\.\d+\.\d+$/.test(updateManifest.version)) throw new Error('Versão inválida em ios-update.json.');
if (!String(updateManifest.buildUrl || '').startsWith('https://github.com/GBrum0o0/BRUMCLASSICS/')) throw new Error('URL do build pessoal inválida.');
if (publishedUpdateManifest.version !== updateManifest.version || publishedUpdateManifest.build !== updateManifest.build || publishedUpdateManifest.buildUrl !== updateManifest.buildUrl) throw new Error('Manifesto público de atualização diverge do pacote iOS.');

const icon = fs.readFileSync(path.join(app, 'Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'));
if (icon.readUInt32BE(16) !== 1024 || icon.readUInt32BE(20) !== 1024) throw new Error('AppIcon precisa ter 1024 × 1024 pixels.');

const protocolMatch = source.match(/protocolVersion\s*>=\s*(\d+)/);
if (!protocolMatch || Number(protocolMatch[1]) !== 10) throw new Error('Versão do protocolo móvel divergente.');
if (!source.includes('LibrarySnapshot(protocolVersion: 10')) throw new Error('Snapshot atual precisa anunciar o protocolo móvel 10.');

console.log(JSON.stringify({ ok: true, swiftFiles: swiftFiles.length, endpoints: requiredEndpoints.length, commands: requiredCommands.length, protocolVersion: 10, minimumCompatibleProtocol: 10, appIcon: '1024x1024' }, null, 2));
