# BRUMCLASSICS OFICIAL 1.45.2 — Atalho permanente

Esta versão corrige o erro **“executável não encontrado”** que podia ocorrer depois de atualizar o launcher e tentar abri-lo pelo ícone fixado na barra de tarefas.

## Causa

O executável portátil extrai internamente uma cópia temporária. Ao fixar a própria janela aberta, o Windows podia associar o ícone a essa cópia dentro da pasta temporária. Ela deixa de existir depois que o aplicativo fecha, embora o arquivo externo oficial continue intacto.

## Correção

- O launcher cria no menu Iniciar um atalho chamado **BRUMCLASSICS OFICIAL**.
- Esse atalho aponta sempre para o arquivo externo permanente `BRUMCLASSICS OFICIAL.exe`.
- O atalho e a janela usam o mesmo identificador do aplicativo.
- A integridade do atalho é conferida e reparada em toda inicialização.
- Nenhuma conta, coleção, save, capa ou configuração é migrada ou apagada.

## Ação única para instalações anteriores

1. Desafixe da barra de tarefas o ícone antigo que apresenta o erro.
2. Abra o menu Iniciar e pesquise **BRUMCLASSICS OFICIAL**.
3. Clique com o botão direito no resultado e selecione **Fixar na barra de tarefas**.

As próximas atualizações continuarão usando esse mesmo atalho.

O BRUMCLASSICS MOVEL permanece na versão 0.10.1 porque esta correção é exclusiva do Windows.
