# Validação Android 0.25.0

- `versionCode 37` e `versionName 0.25.0`.
- Build `testDebugUnitTest assembleDebug` concluído com sucesso usando JDK 21, SDK 36 e NDK 27.
- `libmednafen_wswan_libretro.so` compilada para arm64-v8a e incluída no APK.
- Testes cobrem detecção `.ws/.wsc`, seleção do core e console RetroAchievements 53.
- Host C++ recompilado com fila de áudio protegida, validação da taxa e diagnóstico de `SHUTDOWN`.
