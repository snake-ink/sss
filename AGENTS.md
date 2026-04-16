## sss

Ferramenta CLI de scripts para projetos git. Um único arquivo shell (`sss`) copiado para a raiz do projeto. Sem dependências além do próprio shell e do git.

## Rodando os testes

```sh
./sss test                        # suite completa
./sss test -- --filter "nome"     # teste específico por nome
```

Os testes usam [Bats](https://github.com/bats-core/bats-core) via submódulo em `test/bats/`. O comando `test` está definido em `.sss/config.sh`.

Para rodar o bats diretamente:

```sh
./test/bats/bin/bats test/sss.bats
./test/bats/bin/bats test/sss.bats --filter "nome do teste"
```

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

**Lockfile `.sss/modules.lock`:**

- Primeira linha (opcional): `sss <versão>` — versão do próprio script requerida pelo projeto
- Módulos remotos: `<nome> <url> <tipo>:<ref> <commit-resolvido>`
- Módulos locais: `<nome> <caminho> local -`
- `_install` e `_update` pulam entradas com `mod_name == sss`
- `pin` e `self-update` pulam o version check em `_init` (assim como `self-update`) para evitar deadlock ao trocar de versão

**Dispatch de módulos vs config:**

Config tem prioridade. Ordem de tentativa:
1. `cmd_<nome>` definido no `config.sh`
2. Executável em `.sss/modules/<nome>/module`
3. Entrada `local` no lockfile apontando para `<caminho>/module`

**Helper `requires`:**

Disponível dentro de qualquer `cmd_*` no config. Verifica se os módulos listados estão disponíveis (instalados em `.sss/modules/` ou registrados como `local` no lockfile com diretório existente); falha com mensagem orientando o usuário a rodar `install` caso algum esteja ausente:

```sh
cmd_test() {
    requires sss-docker
    docker exec app php artisan test
}
```

**Variáveis de ambiente:**

O arquivo definido em `SSS_ENV` (padrão: `.env` na raiz do projeto), se existir, é carregado logo após `_init` — antes mesmo do dispatch de comandos. Isso significa que o próprio `.env` pode sobrescrever configurações do `sss`, como `SSS_LANG` e `SSS_ENV`:

```sh
# .env
export SSS_LANG=en
export SSS_ENV=.env.local
```

Se `.env` redefinir `SSS_ENV` para outro caminho, o script carrega o novo arquivo em sequência.

Para usar outro arquivo sem depender do `.env`: `SSS_ENV=.env.local ./sss start`

**i18n:**

Todas as mensagens de saída passam pela função `_t <chave> [args...]`. O idioma é definido pela variável `SSS_LANG`:
- `pt` — padrão
- `en` — inglês

## Convenções

- **Idioma:** comentários e outputs em **português**; nomes de variáveis e funções em inglês
- **Snake speak:** aplicado de forma estética apenas em documentação e comentários — **não** em outputs de comando
- **POSIX sh:** o script core deve ser compatível com POSIX sh (`#!/bin/sh`); módulos podem usar qualquer linguagem
- **Versão:** `SSS_VERSION` no topo do script deve ser atualizada a cada release; o lockfile referencia essa versão

## Adicionando testes

Testes ficam em `test/sss.bats`. Repos git locais são usados como "remotes" fake para evitar dependência de rede — use o helper `_make_fake_remote` já definido no arquivo de testes.
