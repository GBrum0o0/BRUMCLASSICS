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
  'BRUMCLASSICSMobile/PersonalUpdateService.swift',
  'BRUMCLASSICSMobile/ProfileView.swift', 'BRUMCLASSICSMobile/BCardView.swift',
  'BRUMCLASSICSMobile/MomentsView.swift', 'BRUMCLASSICSMobileTests/SnapshotTests.swift',
  'ios-update.json', 'github-actions/build-ios-personal.yml'
];

for (const relative of required) {
  if (!fs.existsSync(path.join(root, relative))) throw new Error(`Arquivo obrigatório ausente: ${relative}`);
}

const swiftFiles = fs.readdirSync(app).filter((name) => name.endsWith('.swift'));
const source = swiftFiles.map((name) => fs.readFileSync(path.join(app, name), 'utf8')).join('\n');
const requiredEndpoints = ['/v1/pair', '/v1/snapshot', '/v1/ws', '/v1/remote', '/v1/companion/notes', '/v1/companion/library-state', '/v1/companion/capture', '/v1/moments/'];
for (const endpoint of requiredEndpoints) if (!source.includes(endpoint)) throw new Error(`Endpoint não portado: ${endpoint}`);

const requiredCommands = ['bcard_launch'];
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

if (!source.includes('SecureStore.write')) throw new Error('Token não está protegido pelo Keychain.');
if (!source.includes('SHA256.hash(data: data)')) throw new Error('Certificate pinning ausente.');
if (!source.includes('completeFileProtectionUnlessOpen')) throw new Error('Proteção dos arquivos offline ausente.');
if (source.includes('NSAllowsArbitraryLoads')) throw new Error('Exceção ATS ampla não é permitida.');
if (!source.includes('com.brumclassics.mobile.ios') && !fs.readFileSync(path.join(root, 'project.yml'), 'utf8').includes('com.brumclassics.mobile.ios')) throw new Error('Bundle ID pessoal fixo ausente.');
if (!source.includes('checkForPersonalUpdate')) throw new Error('Verificação de atualização pessoal ausente.');

const updateManifest = JSON.parse(fs.readFileSync(path.join(root, 'ios-update.json'), 'utf8'));
if (!fs.readFileSync(path.join(root, 'github-actions/build-ios-personal.yml'), 'utf8').includes('ios/build/BRUMCLASSICS-MOVEL-IOS-*.ipa')) throw new Error('Upload do IPA não pode ficar preso a uma versão antiga.');
if (!/^\d+\.\d+\.\d+$/.test(updateManifest.version)) throw new Error('Versão inválida em ios-update.json.');
if (!String(updateManifest.buildUrl || '').startsWith('https://github.com/GBrum0o0/BRUMCLASSICS/')) throw new Error('URL do build pessoal inválida.');

const icon = fs.readFileSync(path.join(app, 'Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'));
if (icon.readUInt32BE(16) !== 1024 || icon.readUInt32BE(20) !== 1024) throw new Error('AppIcon precisa ter 1024 × 1024 pixels.');

const protocolMatch = source.match(/protocolVersion\s*>=\s*(\d+)/);
if (!protocolMatch || Number(protocolMatch[1]) !== 8) throw new Error('Versão do protocolo móvel divergente.');

console.log(JSON.stringify({ ok: true, swiftFiles: swiftFiles.length, endpoints: requiredEndpoints.length, commands: requiredCommands.length, protocolVersion: 8, appIcon: '1024x1024' }, null, 2));
