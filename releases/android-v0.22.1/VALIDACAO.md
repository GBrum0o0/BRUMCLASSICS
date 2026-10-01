# Validação Android 0.22.1

- `versionCode 32` e `versionName 0.22.1`.
- Android SDK 36, NDK 27.0.12077973 e CMake 3.22.1.
- Host JNI `libbrumcore.so` e núcleo `libmgba_libretro.so` compilados para arm64-v8a.
- Serialização e restauração dos três slots ligadas ao núcleo mGBA fixado.
- APK verificado para confirmar os dois binários nativos e os avisos de licença.
- Compilação Java, lint vital e testes de contrato aprovados.
- mGBA fixado no commit `7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6`, sob MPL-2.0.
- Nenhuma ROM, BIOS, save ou credencial foi incluída.
