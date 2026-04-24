# sss 🐍

> Vai uma mãozinha? O `sss` é um jeito simplesss e leve de gerenciar e executar scripts auxiliaresss para o seu projeto.

## Visão Geral

Sssem dependênciasss, sssem instalação: apenasss um arquivo shell POSIX na raiz do seu projeto. O `sss` gerencia módulos externos via git, comandos de projeto via `config.sh`, e variáveis de ambiente via `.env`.

## Quick Start

### Pré-Requisitos

- git
- shell POSIX (sh, bash, zsh, etc.)

### Rodando

```bash
# Copie o arquivo para seu projeto e torne-o executável
chmod +x sss

# Veja os comandos disponíveis
./sss help

# Instale um módulo
./sss require https://gitea.abbluiz.com/snake-ink/sss-docker

# Execute um comando de projeto (definido em .sss/config.sh)
./sss start
```

Na primeira execução, o `sss` inicializa a pasta `.sss/` e adiciona `.sss/modules/` ao `.gitignore` automaticamente.

## Desenvolvimento

### Testes

```bash
./sss test                        # suite completa
./sss test -- --filter "nome"     # teste específico por nome
```

Os testes usssam [Bats](https://github.com/bats-core/bats-core) via submódulo em `test/bats/`.

### Estrutura

```
.sss/           # diretório do sss (gitignored, exceto config.sh)
  config.sh     # comandos do projeto (versionado)
  modules/      # módulos instalados (gitignored)
  modules.lock  # lockfile dos módulos (versionado)
```

## Comandos

### Comandos Internos

| Comando | Descrição |
|---------|-----------|
| `help` | Lista os comandos disponíveis |
| `require <url>[@ref] [as <nome>[,<alias>...]]` | Adiciona um módulo remoto ao lockfile e instala |
| `require --local <caminho>` | Registra um módulo local no lockfile |
| `install` | Restaura todos os módulos do lockfile |
| `update [nome]` | Atualiza módulos com constraint de branch |
| `rebuild <nome>` | Reconstrói um módulo (remove e re-instala) |
| `pin <versão>` | Registra a versão requerida do sss no lockfile |
| `remove <nome>` | Remove um módulo do lockfile e desinstala |
| `self-update [versão]` | Atualiza o próprio sss |

### Aliases (v0.3.0+)

Instale um módulo com múltiplos nomes de dispatch:

```bash
./sss require https://gitea.abbluiz.com/labb/arr-cli.git as arr,sonarr,radarr
```

Isso cria:
- Um clone em `.sss/modules/arr/` (canonical)
- Entradas de alias no lockfile para `sonarr` e `radarr`

Quando o usuário executa `./sss sonarr series list`, o sss invoca `.sss/modules/arr/module sonarr series list` (o nome do alias é passsado como primeiro argumento).

### Comandos do Projeto

Defina comandos no arquivo `.sss/config.sh` (versssionado junto com o projeto):

```sh
# Inicia o ambiente de desenvolvimento
cmd_start() {
    docker compose up -d
}

# Executa os testes
cmd_test() {
    docker exec app php artisan test "$@"
}

# Comandosss com múltiplasss palavrasss
cmd_docker_build() {
    docker build .
}
```

Execute com:

```sh
./sss start
./sss test --filter NomeDoTeste
./sss docker build        # essspaço ou underssscore funcionam
./sss docker_build        # equivalente
```

Sssub-comandosss com essspaço usssam longest-match: `./sss docker build prod` chama `cmd_docker_build "prod"`.

Use `requires` dentro de um comando para garantir que módulos necessários estejam instalados:

```sh
cmd_deploy() {
    requires sss-docker
    # ...
}
```

## Módulos

Módulos são extensões instaladas localmente via git. Podem ser escritos em qualquer linguagem.

Use `require` para adicionar um módulo. O `@ref` é opcional. Pode ser uma branch, tag ou commit:

```sh
./sss require https://gitea.abbluiz.com/snake-ink/sss-docker          # branch padrão
./sss require https://gitea.abbluiz.com/snake-ink/sss-docker@main     # branch
./sss require https://gitea.abbluiz.com/snake-ink/sss-docker@v1.2.0   # tag
./sss require https://gitea.abbluiz.com/snake-ink/sss-docker@a3f91c2  # commit
```

Use `as` para instalar com um nome diferente do repositório:

```sh
./sss require https://gitea.abbluiz.com/snake-ink/sss-docker as docker
```

O módulo é instalado em `.sss/modules/` (gitignored) e registrado em `.sss/modules.lock` (versionado). Para restaurar os módulos em outra máquina:

```sh
./sss install
```

Para atualizar módulos fixados em uma branch:

```sh
./sss update            # atualiza todos os de branch
./sss update sss-docker # atualiza um específico
```

Módulos fixados em tag ou commit são ignorados pelo `update`. Use `require` novamente com o novo ref para mudá-los.

**Nota sobre atualização:** o `require` verifica se a constraint mudou e, se sim, busca o novo ref (inclusive tags) e troca o checkout automaticamente.

Para remover um módulo:

```sh
./sss remove sss-docker
```

Isso remove o módulo do lockfile e apaga a pasta em `.sss/modules/`.

### Módulos Locais

Para módulos que já fazem parte do repositório (commitados no git), use `--local`:

```sh
./sss require --local ./scripts/meu-modulo
```

O lockfile registrará o caminho local. O `sss` não clona nem atualiza esse módulo — apenas o verifica. Isso é útil para scripts internos que você quer tratar como módulos.

Se o módulo local estiver dentro de `.sss/modules/`, o `sss` adiciona uma exceção no `.gitignore` para que ele seja versionado.

## Variáveis de Ambiente

Crie o arquivo `.env` na raiz do projeto para definir variáveis disponíveis em `config.sh` e dentro de todos os módulos:

```sh
# .env
export APP_NAME=meu-app
export DATABASE_URL=postgres://localhost/meubanco
```

O arquivo é carregado automaticamente antes de qualquer comando ser executado — inclusive comandos internos como `help` e `install`. Isso significa que você também pode controlar o comportamento do `sss` pelo próprio `.env`:

```sh
# .env
export SSS_LANG=en
export SSS_ENV=.env.local
```

Para usar um caminho diferente sem depender do `.env`:

```sh
SSS_ENV=.env.local ./sss start
```

## Internacionalização

O idioma das mensagens é controlado pela variável de ambiente `SSS_LANG`:

```sh
SSS_LANG=en ./sss help    # inglês
SSS_LANG=pt ./sss help    # português (padrão)
```

## Renomeando

O `sss` é apenas um arquivo: renomeie-o como quiser. O nome aparece corretamente em todos os outputsss:

```sh
cp sss meu-projeto
./meu-projeto help
```

---

Veja [AGENTS.md](AGENTS.md) para detalhes técnicos e convenções de desenvolvimento.
