# Validação 1.51.0 / MOVEL 0.15.0

- 445 testes automatizados do desktop aprovados.
- Remoção: persistência após reinício, identidade por loja/arquivo, isolamento entre lojas, recuperação do cadastro, backup, arquivo inválido e removals concorrentes.
- APK versionCode 23 / versionName 0.15.0; assinatura v2/v3 com o mesmo certificado anterior.
- Testes móveis HomeLibraryTest, PerformanceLiveStateTest e BCardLibraryTest aprovados.
- B-CARD: categoria explícita prevalece, fallback para cache antigo, instalados por seção, lista vazia e preservação de notas/favoritos/capas.
- Nenhum teste remove jogos reais ou modifica contas/saves do usuário.

Os testes Android de modelo e compilação não substituem um teste visual em telefone físico. Nenhum jogo real foi removido para validação.
