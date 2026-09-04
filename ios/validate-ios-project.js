'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;
const app = path.join(root, 'BRUMCLASSICSMobile');
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

const requiredCommands = ['bcard_launch', 'navigate', 'search', 'activate', 'back', 'tab', 'set_volume', 'quick_save', 'quick_load', 'quit_game', 'sleep_pc', 'shutdown_pc'];
for (const command of requiredCommands) if (!source.includes(`"${command}"`)) throw new Error(`Comando remoto não portado: ${command}`);

if (!source.includes('SecureStore.write')) throw new Error('Token não está protegido pelo Keychain.');
if (!source.includes('SHA256.hash(data: data)')) throw new Error('Certificate pinning ausente.');
if (!source.includes('completeFileProtectionUnlessOpen')) throw new Error('Proteção dos arquivos offline ausente.');
if (source.includes('NSAllowsArbitraryLoads')) throw new Error('Exceção ATS ampla não é permitida.');
if (!source.includes('com.brumclassics.mobile.ios') && !fs.readFileSync(path.join(root, 'project.yml'), 'utf8').includes('com.brumclassics.mobile.ios')) throw new Error('Bundle ID pessoal fixo ausente.');
if (!source.includes('checkForPersonalUpdate')) throw new Error('Verificação de atualização pessoal ausente.');

const updateManifest = JSON.parse(fs.readFileSync(path.join(root, 'ios-update.json'), 'utf8'));
if (!/^\d+\.\d+\.\d+$/.test(updateManifest.version)) throw new Error('Versão inválida em ios-update.json.');
if (!String(updateManifest.buildUrl || '').startsWith('https://github.com/GBrum0o0/BRUMCLASSICS/')) throw new Error('URL do build pessoal inválida.');

const icon = fs.readFileSync(path.join(app, 'Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'));
if (icon.readUInt32BE(16) !== 1024 || icon.readUInt32BE(20) !== 1024) throw new Error('AppIcon precisa ter 1024 × 1024 pixels.');

const protocolMatch = source.match(/protocolVersion\s*>=\s*(\d+)/);
if (!protocolMatch || Number(protocolMatch[1]) !== 8) throw new Error('Versão do protocolo móvel divergente.');

console.log(JSON.stringify({ ok: true, swiftFiles: swiftFiles.length, endpoints: requiredEndpoints.length, commands: requiredCommands.length, protocolVersion: 8, appIcon: '1024x1024' }, null, 2));
