# Contratos Técnicos — Pacote de Melhorias e Correções Mobile (26/11/2026)

Documento de referência para integração de Frontend / UI / QA (Codex) sobre a camada Backend/Nativa entregue no branch `antigravity/pack-20261126-mobile`.

---

## Tarefa 01 — Expansão do Pacote de Melhoria de Resolução (Mobile)

### iOS (`ios/BRUMCLASSICSMobile/GraphicsResolutionPack.swift`)
- **Singleton:** `GraphicsResolutionPack.shared`
- **Perfis:** `GraphicsProfile` (`.original`, `.automatic`, `.enhanced`, `.custom`)
- **Escala:** `GraphicsScaleMode` (`.original`, `.integer`, `.stretch`)
- **Filtros:** `GraphicsVideoFilter` (`.none`, `.crtScanlines`, `.lcdGrid`, `.bilinearSubtle`)
- **API pública para UI Settings:**
  - `GraphicsResolutionPack.catalog`
  - `loadSettings() -> GraphicsResolutionSettings`
  - `saveSettings(_ settings: GraphicsResolutionSettings)`
  - `resetSettings(systemID: String? = nil) -> GraphicsResolutionSettings`
  - `resolve(systemID: String, settings: GraphicsResolutionSettings? = nil, hardwareTier: GraphicsHardwareTier? = nil) -> ResolvedGraphicsConfig`
- **Integração no runtime (`BrumLibretroEngine.h` / `BrumLibretroEngine.mm` / `IntegratedEmulatorView.swift`):**
  - `controller.initialCoreVariables`, `controller.integerScalingEnabled` e `controller.videoFilterMode` são aplicados em `viewDidLoad` antes de inicializar o core libretro (preservando `ppsspp_cpu_core = "IR jit"` e `citra_use_cpu_jit = "disabled"`).

### Android (`com.brumclassics.mobile.emulation.GraphicsResolutionPack`)
- **API pública:** `catalog()`, `load(Context)`, `save(Context, Settings)`, `reset(Context, String)`, `resolveForDevice(Context, String systemId)`, `resolve(Settings, String systemId, String hardwareTier)`.
- **Integração no runtime:** `IntegratedEmulatorActivity` passa `resolved.coreVariables` para `BrumCoreBridge(corePath, romPath, launch, coreVariables)` e chama `emulatorView.setGraphicsPresentation(integerScalingEnabled, videoFilterMode)`.

---

## Tarefa 02 — Integração do Google Drive ao Gaming Mode Mobile

### iOS (`ios/BRUMCLASSICSMobile/ClassicDriveCloudService.swift`)
- **Estado de disponibilidade (`ClassicAvailabilityState`):** `.available` (verde — `"Disponível"`), `.onComputer` (cinza — `"No computador"`), `.inCloud` (`"Na nuvem (Google Drive)"`), `.downloading` (`"Baixando"`), `.incompatible` (`"Incompatível"`).
- **Actor `ClassicDriveCloudService`:**
  - `setStorageDirectory(_ directory: URL)` / `resolvedStorageDirectory()` / `availableFreeSpaceBytes()`
  - `startOrRefreshScan(folderURL: String) async throws -> ClassicDriveCheckpoint`
  - `continueScan() async throws -> ClassicDriveCheckpoint`
  - `downloadGame(fileID: String, onProgress:) async throws -> URL`
  - `cancelDownload(fileID: String)`
  - `availabilityState(for:supportedOnDevice:)`
  - Tokens opcionais são isolados no Keychain via `ClassicDriveKeychainStore` (nunca serializados no checkpoint JSON).

### Android (`com.brumclassics.mobile.classics.ClassicDriveCloudService` & `GamingModeRules.AvailabilityState`)
- **Estados:** `GamingModeRules.AvailabilityState` (`AVAILABLE`, `ON_COMPUTER`, `IN_CLOUD`, `DOWNLOADING`, `INCOMPATIBLE`) + `GamingModeRules.resolveAvailability(...)`.
- **Métodos principais:** `setStorageDirectory(File)`, `getAvailableFreeSpaceBytes()`, `startOrRefreshScan(String folderUrl)`, `continueScan()`, `downloadGameSync(String fileId, DownloadProgressListener)`, `cancelDownload(String fileId)`, `setBearerToken(String)` (via `SecureSecretStore`).
- **Execução offline (`ClassicsRepository`):** `registerDownloadedClassic(downloadedFile, relativePath, systemHint, driveFileId)` registra a ROM baixada com URI `file://`, preservando saves/RetroAchievements/progresso existentes, permitindo abertura sem Pasta SAF e sem conexão ao PC.

---

## Tarefa 03 — Correção e Diagnóstico do PPSSPP no Mobile

- **Patches de core:**
  - `android/patches/ppsspp-context-lifecycle.patch`
  - `ios/patches/ppsspp-ios-libretro.patch`
  - Corrigem reentrância de `EmuThreadStart` em `START_REQUESTED`, sincronismo de `coreParam.cpuCore`, população de `pixel_xres`/`pixel_yres`/`dp_xres`/`dp_yres` em `display.h` (`libretro/libretro.cpp`) e estado cacheado em `GLQueueRunner::fbo_unbind()`.
- **Camada nativa Android/iOS:**
  - Android: `brum_core.cpp` adia `resetCore()` para a thread `brum-core-loop`, remove `ppsspp_auto_frameskip`/`frameskip=1` forçados e expõe `BrumCoreBridge.diagnosticsJson()` / `BrumCoreView.diagnosticsJson()`.
  - iOS: `BrumLibretroEngine.mm` desativa `ppsspp_auto_frameskip`/`frameskip=1`/`fast_memory` sem JIT e mantém contadores diagnósticos (`videoCallbacks`, `nonBlackVideoCallbacks`, `hwRenderReadbackSuccess`, aviso aos 120 frames).
- **Limitação explícita de validação:** Ambiente atual sem iPhone/Xcode/macOS e com 0 dispositivos Android conectados via `adb`; validação em aparelho físico (5 min de gameplay real PPSSPP) pendente na fila de dispositivo real.
