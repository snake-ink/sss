# sss 🐍

Vai uma mãozinha? O `sss` é um jeito simplesss e leve de gerenciar e executar scripts auxiliaresss para o seu projeto.

Sssem dependênciasss, sssem instalação: apenasss um arquivo shell na raiz do seu projeto.

## Como Funciona

Copie o arquivo `sss` para a raiz do seu projeto e torne-o executável:

```sh
chmod +x sss
```

Na primeira execução, o `sss` inicializa a pasta `.sss/` e adiciona `.sss/modules/` ao `.gitignore` automaticamente.

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

## Comandos do Projeto

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
./sss require https://github.com/snake-ink/sss-docker          # branch padrão
./sss require https://github.com/snake-ink/sss-docker@main     # branch
./sss require https://github.com/snake-ink/sss-docker@v1.2.0   # tag
./sss require https://github.com/snake-ink/sss-docker@a3f91c2  # commit
```

Use `as` para instalar com um nome diferente do repositório:

```sh
./sss require https://github.com/snake-ink/sss-docker as docker
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

## Internacionalização

O idioma das mensagens é controlado pela variável de ambiente `SSS_LANG`:

```sh
SSS_LANG=en ./sss help    # inglês
SSS_LANG=pt ./sss help    # português (padrão)
```

## Renomeando

O `sss` é apenas um arquivo: renomeie-o como quiser. O nome aparece corretamente em todos os outputs:

```sh
cp sss meu-projeto
./meu-projeto help
```

## Comandos Internos

| Comando | Descrição |
|---------|-----------|
| `help` | Lista os comandos disponíveis |
| `require <url>[@ref]` | Adiciona um módulo remoto ao lockfile e instala |
| `require --local <caminho>` | Registra um módulo local no lockfile |
| `install` | Restaura todos os módulos do lockfile |
| `update [nome]` | Atualiza módulos com constraint de branch |
| `pin <versão>` | Registra a versão requerida do sss no lockfile |
| `remove <nome>` | Remove um módulo do lockfile e desinstala |
| `self-update [versão]` | Atualiza o próprio sss |
