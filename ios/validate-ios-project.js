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
  'BRUMCLASSICSMobile/GamingModeComponents.swift',
  'BRUMCLASSICSMobile/MurbRemoteGamepad.swift',
  'BRUMCLASSICSMobile/PersonalUpdateService.swift',
  'BRUMCLASSICSMobile/ProfileView.swift', 'BRUMCLASSICSMobile/BCardView.swift',
  'BRUMCLASSICSMobile/SaveMigrationBackup.swift',
  'BRUMCLASSICSMobile/ROMFolderLibrary.swift',
  'BRUMCLASSICSMobile/IntegratedEmulatorView.swift',
  'BRUMCLASSICSMobile/Libretro/BrumLibretroAPI.h',
  'BRUMCLASSICSMobile/Libretro/BrumLibretroEngine.h',
  'BRUMCLASSICSMobile/Libretro/BrumLibretroEngine.mm',
  'BRUMCLASSICSMobile/Libretro/BrumCoreDiagnostics.h',
  'BRUMCLASSICSMobile/Libretro/BrumCoreDiagnostics.m',
  'BRUMCLASSICSMobileTests/BrumCoreStartupTests.swift',
  'BRUMCLASSICSMobileTests/Fixtures/BrumTestCore.c',
  'BRUMCLASSICSMobile/BRUMCLASSICSMobile-Bridging-Header.h',
  'BRUMCLASSICSMobile/MomentsView.swift', 'BRUMCLASSICSMobileTests/SnapshotTests.swift',
  'BRUMCLASSICSMobile/Extensions/BrumExtensionContract.swift',
  'BRUMCLASSICSMobile/Extensions/PokedexSpeciesCatalogData.swift',
  'BRUMCLASSICSMobile/Extensions/PokedexUniversalStore.swift',
  'BRUMCLASSICSMobile/Extensions/PokedexUniversalView.swift',
  'BRUMCLASSICSMobile/Resources/pokedex-species-catalog-v1.json',
  'BRUMCLASSICSMobileTests/PokedexUniversalTests.swift',
  '../shared/brum-core/PokemonFireRedAdapter.hpp',
  '../shared/brum-core/PokemonFireRedAdapter.cpp',
  '../shared/brum-core/pokedex_tests.cpp',
  'ios-update.json'
];
required.push('prepare_ppsspp_assets.py', 'licenses/PPSSPP-FONTS.txt');

for (const relative of required) {
  if (!fs.existsSync(path.join(root, relative))) throw new Error(`Arquivo obrigatório ausente: ${relative}`);
}

function swiftSources(directory, prefix = '') {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const relative = path.join(prefix, entry.name);
    return entry.isDirectory() ? swiftSources(path.join(directory, entry.name), relative) : entry.name.endsWith('.swift') ? [relative] : [];
  });
}
const swiftFiles = swiftSources(app);
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
for (const marker of ['struct GamingModeView', 'GamingTabBar(selection:', 'JOGADOS RECENTEMENTE', 'BIBLIOTECA', 'EXTENSÕES', 'gaming-mode-extensions', 'PokedexGamingExtensionView', 'GamingModeCatalog.library', 'pocket.romFolderGames', 'GamingOrientation.request(.landscape)', 'selection != 2']) {
  if (!source.includes(marker) && !fs.readFileSync(path.join(app, 'Extensions/PokedexUniversalView.swift'), 'utf8').includes(marker)) throw new Error(`Gaming Mode incompleto: ${marker}`);
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
const homeBody = homeSource.split('struct HomeView: View')[1]?.split('struct SyncStatusCard: View')[0] || '';
if (homeBody.includes('SyncStatusCard()')) throw new Error('Área de sincronização (SyncStatusCard) deve permanecer removida da tela inicial.');
if (!homeBody.includes('BrumMobileFeatureFlags.showNotificationCenter')) throw new Error('Central de notificações deve estar protegida por feature flag na tela inicial.');
const dotSource = homeSource.split('struct ConnectionDot: View')[1]?.split('struct FeaturedGameCard: View')[0] || '';
if (!dotSource.includes('SyncIndicatorState') || dotSource.includes('"CONECTADO"') || dotSource.includes('"ERRO DE SINCRONIZAÇÃO"')) {
  throw new Error('Indicador de sincronização deve usar apenas símbolo visual sem textos na UI.');
}
const rootSource = fs.readFileSync(path.join(app, 'BRUMCLASSICSMobileApp.swift'), 'utf8');
if (rootSource.includes('case 3: NavigationStack { StatsView() }')) throw new Error('Seção Estatísticas deve estar ocultada na interface principal.');
const overlaySource = fs.readFileSync(path.join(app, 'BrumAchievementOverlay.swift'), 'utf8');
if (!overlaySource.includes('presentOnActiveEmulatorIfAvailable')) throw new Error('Popup de descoberta da Pokédex deve priorizar o emulador ativo.');
const adapterSource = fs.readFileSync(path.join(root, '../shared/brum-core/PokemonFireRedAdapter.cpp'), 'utf8');
if (!adapterSource.includes('isConfirmedPlayerPokemon')) throw new Error('Detecção de Pokémon iniciais e evoluções no FireRed está incompleta.');

if (!source.includes('SecureStore.write')) throw new Error('Token não está protegido pelo Keychain.');
if (!source.includes('SHA256.hash(data: data)')) throw new Error('Certificate pinning ausente.');
if (!source.includes('completeFileProtectionUnlessOpen')) throw new Error('Proteção dos arquivos offline ausente.');
if (source.includes('NSAllowsArbitraryLoads')) throw new Error('Exceção ATS ampla não é permitida.');
if (!source.includes('com.brumclassics.mobile.ios') && !fs.readFileSync(path.join(root, 'project.yml'), 'utf8').includes('com.brumclassics.mobile.ios')) throw new Error('Bundle ID pessoal fixo ausente.');
if (!source.includes('checkForPersonalUpdate')) throw new Error('Verificação de atualização pessoal ausente.');
if (info.includes('<string>sidestore</string>')) throw new Error('Esquema URL sidestore legado não deve estar declarado em Info.plist.');
if (!fs.readFileSync(path.join(app, 'ProfileView.swift'), 'utf8').includes('Verificar atualização')) throw new Error('Botão Verificar atualização ausente em ProfileView.');
if (fs.readFileSync(path.join(root, '..', '.github', 'workflows', 'build-ios-personal.yml'), 'utf8').includes('generate_sidestore_source.py')) throw new Error('Automação legada do SideStore deve permanecer removida do workflow iOS.');

const updateManifest = JSON.parse(fs.readFileSync(path.join(root, 'ios-update.json'), 'utf8'));
const publishedUpdateManifest = JSON.parse(fs.readFileSync(path.join(root, '..', 'ios-update.json'), 'utf8'));
const workflow = fs.readFileSync(path.join(root, '..', '.github', 'workflows', 'build-ios-personal.yml'), 'utf8');
const pspStep = workflow.match(/      - name: Compilar núcleo integrado PPSSPP sem JIT[\s\S]*?(?=\n      - name:)/)?.[0];
if (!pspStep || !pspStep.includes('bash build-heavy-experimental.sh ppsspp "$APP"') || pspStep.includes('if:')) throw new Error('PPSSPP precisa ser compilado no pacote normal.');
const pspBuild = fs.readFileSync(path.join(root, 'build-heavy-experimental.sh'), 'utf8');
if (!pspBuild.includes('COMMIT=7b4ddb426bbe9e287bb7f19b0cfaebb4ea0d41d8') || !pspBuild.includes('prepare_ppsspp_assets.py')) throw new Error('Build ou assets reproduzíveis do PPSSPP ausentes.');
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
const projectSpec = fs.readFileSync(path.join(root, 'project.yml'), 'utf8');
const marketingVersion = projectSpec.match(/MARKETING_VERSION:\s*([^\s]+)/)?.[1];
const projectBuild = Number(projectSpec.match(/CURRENT_PROJECT_VERSION:\s*(\d+)/)?.[1]);
if (!projectSpec.includes('path: ../LICENSES/PokeAPI-LICENSE.txt') || !fs.existsSync(path.join(root, '../LICENSES/PokeAPI-LICENSE.txt'))) throw new Error('Licença PokeAPI ausente dos recursos iOS.');
if (marketingVersion !== updateManifest.version || projectBuild !== updateManifest.build) throw new Error('Versão e build do projeto divergem do manifesto iOS.');
if (!workflow.includes('--target "$GITHUB_SHA"') || workflow.includes('--clobber')) throw new Error('Publicação iOS precisa fixar o commit e preservar binários publicados.');
if (!workflow.includes(`PESSOAL' }}-${marketingVersion}`) || !workflow.includes(`IOS-TESTES-${marketingVersion}`)) throw new Error('Nome do artefato iOS diverge da versão atual.');
const extensionSource = fs.readFileSync(path.join(app, 'Extensions/PokedexUniversalView.swift'), 'utf8');
if (!extensionSource.includes('Task { @MainActor [weak self] in')) throw new Error('Callback da Pokédex precisa retornar ao MainActor.');
if (!/^\d+\.\d+\.\d+$/.test(updateManifest.version)) throw new Error('Versão inválida em ios-update.json.');
if (!String(updateManifest.buildUrl || '').startsWith('https://github.com/GBrum0o0/BRUMCLASSICS/')) throw new Error('URL do build pessoal inválida.');
if (publishedUpdateManifest.version !== updateManifest.version || publishedUpdateManifest.build !== updateManifest.build || publishedUpdateManifest.buildUrl !== updateManifest.buildUrl) throw new Error('Manifesto público de atualização diverge do pacote iOS.');

const icon = fs.readFileSync(path.join(app, 'Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'));
if (icon.readUInt32BE(16) !== 1024 || icon.readUInt32BE(20) !== 1024) throw new Error('AppIcon precisa ter 1024 × 1024 pixels.');

const protocolMatch = source.match(/protocolVersion\s*>=\s*(\d+)/);
if (!protocolMatch || Number(protocolMatch[1]) !== 10) throw new Error('Versão do protocolo móvel divergente.');
if (!source.includes('LibrarySnapshot(protocolVersion: 10')) throw new Error('Snapshot atual precisa anunciar o protocolo móvel 10.');

console.log(JSON.stringify({ ok: true, swiftFiles: swiftFiles.length, endpoints: requiredEndpoints.length, commands: requiredCommands.length, protocolVersion: 10, minimumCompatibleProtocol: 10, appIcon: '1024x1024' }, null, 2));
