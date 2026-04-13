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

1. Variáveis globais definidas no topo (`SELF`, `SSS_VERSION`, `SSS_DIR`, etc.)
2. `CMD` é lido de `$1` antes de chamar `_init` — necessário para `_init` saber pular o version check durante `self-update`
3. `_init` auto-inicializa `.sss/` se estiver em um repo git, e verifica a versão do lockfile
4. O `case "$CMD"` despacha para a função interna ou para:
   - Uma função `cmd_*` definida em `.sss/config.sh` (sourced sob demanda)
   - Um executável em `.sss/modules/<cmd>/module` (via `exec`)

**Lockfile `.sss/modules.lock`:**

- Primeira linha (opcional): `sss <versão>` — versão do próprio script requerida pelo projeto
- Demais linhas: `<nome> <url> <tipo>:<ref> <commit-resolvido>` — módulos instalados
- `_install` e `_update` pulam entradas com `mod_name == sss`

**Dispatch de módulos vs config:**

Config tem prioridade. Se `cmd_<nome>` existir no config após o source, ele é chamado; caso contrário, tenta `.sss/modules/<nome>/module`.

**Helper `requires`:**

Disponível dentro de qualquer `cmd_*` no config. Verifica se os módulos listados estão instalados em `.sss/modules/`; falha com mensagem orientando o usuário a rodar `install` caso algum esteja ausente:

```sh
cmd_test() {
    requires sss-docker
    docker exec app php artisan test
}
```

## Convenções

- **Idioma:** comentários e outputs em **português**; nomes de variáveis e funções em inglês
- **Snake speak:** palavras com `s` no output e em comentários substituem `s` por `sss` — aplicado de forma estética (palavras-chave, nomes de comandos e termos técnicos não são alterados)
- **POSIX sh:** o script core deve ser compatível com POSIX sh (`#!/bin/sh`); módulos podem usar qualquer linguagem
- **Versão:** `SSS_VERSION` no topo do script deve ser atualizada a cada release; o lockfile referencia essa versão

## Adicionando testes

Testes ficam em `test/sss.bats`. Repos git locais são usados como "remotes" fake para evitar dependência de rede — use o helper `_make_fake_remote` já definido no arquivo de testes.
