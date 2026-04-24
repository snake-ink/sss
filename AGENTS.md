# sss — Contexto para Agentes

## O que é

Ferramenta CLI de scripts para projetos git. Um único arquivo shell (`sss`) copiado para a raiz do projeto. Sssem dependências além do próprio shell e do git.

## Stack

- POSIX sh (`#!/bin/sh`)
- git
- Bats (para testes)

## Estrutura do Projeto

```
.sss/           # diretório do sss (gitignored, exceto config.sh)
  config.sh     # comandos do projeto (versionado)
  modules/      # módulos instalados (gitignored)
  modules.lock  # lockfile dos módulos (versionado)
test/           # testes Bats
  bats/         # submódulo bats-core
  sss.bats      # suite de testes
```

## Comandos Comuns

```bash
./sss help        # listar comandos disponíveis
./sss test        # rodar testes
./sss require     # adicionar módulo
./sss install     # instalar módulos do lockfile
./sss update      # atualizar módulos de branch
./sss rebuild     # reconstruir módulo
```

## Convenções

- **Idioma:** comentários e outputs em **português**; nomes de variáveis e funções em inglês
- **Snake speak:** aplicado de forma estética apenas em documentação e comentários — **não** em outputs de comando
- **POSIX sh:** o script core deve ser compatível com POSIX sh; módulos podem usar qualquer linguagem
- **Versão:** `SSS_VERSION` no topo do script deve ser atualizada a cada release; o lockfile referencia essa versão

## Armadilhas

- O script usa `#!/bin/sh` — não usar bashisms
- `_init` é chamado antes do dispatch e verifica versão no lockfile (exceto para `self-update` e `pin`)
- O `.env` é carregado após `_init` — pode sobrescrever `SSS_LANG`, `SSS_ENV`, etc.
- Aliases no lockfile usam constraint `alias:<canonical>:<prepend-arg>`; não têm diretório próprio
- `rebuild` de alias falha — deve-se rebuild o canonical

## Documentação

- [README.md](README.md) — documentação de usuário
- [docs/plans/sss-improvements.md](../docs/plans/sss-improvements.md) — plano de melhorias

## Arquitetura

O script inteiro é um único arquivo POSIX sh. As funções internas usam prefixo `_` para distingui-las dos comandos de projeto (`cmd_*`).

**Fluxo de execução:**

1. Variáveis globais definidas no topo (`SELF`, `SSS_VERSION`, `SSS_DIR`, `SSS_LANG`, `SSS_ENV`, etc.)
2. `CMD` é lido de `$1` antes de chamar `_init` — necessário para `_init` saber pular o version check durante `self-update`
3. `_init` auto-inicializa `.sss/` se estiver em um repo git, e verifica a versão do lockfile
4. O `case "$CMD"` despacha para a função interna ou para:
   - Uma função `cmd_*` definida em `.sss/config.sh` (sourced sob demanda)
   - Um executável em `.sss/modules/<cmd>/module` (via `exec`)
   - Um módulo local registrado no lockfile (via `exec`)
   - Um alias no lockfile (resolvido para canonical com prepend-arg)

**Lockfile `.sss/modules.lock`:**

- Primeira linha (opcional): `sss <versão>` — versão do próprio script requerida pelo projeto
- Módulos remotos: `<nome> <url> <tipo>:<ref> <commit-resolvido>`
- Módulos locais: `<nome> <caminho> local -`
- Aliases: `<alias> <url> alias:<canonical>:<prepend-arg> -`
- `_install` e `_update` pulam entradas com `mod_name == sss`
- `pin` e `self-update` pulam o version check em `_init` para evitar deadlock ao trocar de versão

**Dispatch de módulos vs config:**

Config tem prioridade. Ordem de tentativa:
1. `cmd_<nome>` definido no `config.sh`
2. Alias no lockfile (`alias:*`) — resolve para canonical e exec com prepend-arg
3. Executável em `.sss/modules/<nome>/module`
4. Entrada `local` no lockfile apontando para `<caminho>/module`

**Helper `requires`:**

Disponível dentro de qualquer `cmd_*` no config. Verifica se os módulos listados estão disponíveis (instalados em `.sss/modules/` ou registrados como `local` no lockfile com diretório existente); falha com mensagem orientando o usuário a rodar `install` caso algum esteja ausente.

**Variáveis de ambiente:**

O arquivo definido em `SSS_ENV` (padrão: `.env` na raiz do projeto), se existir, é carregado logo após `_init` — antes mesmo do dispatch de comandos. Se `.env` redefinir `SSS_ENV` para outro caminho, o script carrega o novo arquivo em sequência.

**i18n:**

Todas as mensagens de saída passam pela função `_t <chave> [args...]`. O idioma é definido pela variável `SSS_LANG`:
- `pt` — padrão
- `en` — inglês

## Adicionando testes

Testes ficam em `test/sss.bats`. Repos git locais são usados como "remotes" fake para evitar dependência de rede — use o helper `_make_fake_remote` já definido no arquivo de testes.
