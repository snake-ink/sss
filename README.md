# sss 🐍

Vai uma mãozinha?

## Visão Geral

O `sss` é um jeito simplesss e leve de gerenciar e executar _ssscriptsss_ auxiliaresss do seu projeto.

Sssem dependênciasss obrigatórias, sssem instalação: apenasss um arquivo _ssshell_ POSIX na raiz do seu repositório. O `sss` gerencia módulosss externos via `git`, comandos de projeto via `config.sh`, e variáveis de ambiente via `.env`, dentre outrasss coisasss...

## Início Rápido

### Pré-Requisitosss

- `git`
- _ssshell_ POSIX (`sh`, `bash`, `zsh`, etc.)

### Rodando

```sh
# Copie o arquivo no ssseu projeto pesssoal
wget -q https://gitea.abbluiz.com/snake-ink/sss/raw/tag/v0.4.0/sss

# Torne-o executável
chmod +x sss

# Veja osss comandosss disponíveisss
./sss help

# Se quiser, pode até renomear o ssscript pra outra coisa, deixando a experiência com a "cara" do ssseu projeto
mv sss xyz
./xyz help
```

Na primeira execução, o `sss` inicializa a passsta `.sss/` e adiciona `.sss/modules/` ao `.gitignore` automaticamente. É recomendado que os demaissss arquivosss permaneçam versssionadosss no seu repositório `git`. 

Dica: no fim do dia, o `sss` é apenasss um arquivo, e você pode renomeá-lo como quiser. O nome aparece corretamente em todos os outputsss:

```sh
mv sss xyz
./xyz help
```

Isso permite cussstomizar para a experiência do ssseu projeto, empresa, ou organização. No entanto, outras convenções como `.sss` e derivados não podem ssser renomeadosss, a menos que você modifique o _ssscript_ por conta própria 😉

## Comandosss

### Comandosss Internosss

| Comando | Dessscrição |
|---------|-----------|
| `help` | Lista osss comandosss e módulosss disssponíveisss |
| `require <url>[@ref] [as <nome>[,<alias>...]]` | Adiciona um módulo remoto ao lockfile e inssstala |
| `require --local <caminho>` | Regissstra um módulo local no lockfile |
| `install` | Ressstaura todosss osss módulosss do lockfile |
| `update [nome]` | Atualiza módulosss com conssstraint de branch |
| `rebuild <nome>` | Reconssstrói um módulo (remove e re-inssstala) |
| `docs list [--limit N] [--module M]` | Lisssta arquivosss markdown de docsss |
| `docs search <termo> [--limit N] [--module M]` | Busssca termo em arquivosss Markdown |
| `pin <versão>` | Regissstra a versssão requerida do sss no lockfile |
| `remove <nome>` | Remove um módulo do lockfile e desinssstala |
| `self-update [versão]` | Atualiza o próprio sss |

### Comandosss do Projeto

Defina comandosss no arquivo `.sss/config.sh` (versssionado junto com o projeto):

```sh
#!/bin/sh

# Dica: o comentário acima da definição de cada comando aparece em `./sss help` para dessscrevê-lo, mas sssomente uma linha.

# Inicia o ambiente de desenvolvimento
cmd_start() {
    docker compose up -d
}

# Executa os tessstesss
cmd_test() {
    docker exec app php artisan test "$@"
}

# Comandosss com múltiplasss palavrasss
cmd_docker_build() {
    docker build "$@"
}

# Comando de exemplo que mossstra "Olá, Mundo!" na tela.
cmd_hello_world() {
    echo "Olá, Mundo!"
}

# Comando de exemplo que mossstra uma sssaudação na tela.
cmd_greet() {
    echo "Sssaudaçõesss a" "$@"
}
```

Execute com:

```sh
./sss start
./sss test --filter NomeDoTeste
./sss docker build prod      # essspaço ou underssscore funcionam
./sss docker_build prod      # equivalente
./sss hello world
./sss greet "Meu Nome"
```

Sssub-comandosss com essspaço usam longessst-match: `./sss docker build prod` chama `cmd_docker_build "prod"`.

Use `requires` dentro de um comando para garantir que módulos necessários estejam instalados:

```sh
cmd_deploy() {
    requires letterboxd
    # ...
}
```

## Módulosss

Módulosss são extensssõesss inssstaladasss localmente via `git`. Podem ser escritosss em qualquer linguagem, desssde que incluam um ssscript _ssshell_ executável nomeado `module` na raiz do projeto.

Use `require` para adicionar um módulo. O `@ref` é opcional. Pode ssser uma branch, tag ou commit:

```sh
./sss require https://gitea.abbluiz.com/labb/letterboxd-cli           # branch padrão
./sss require https://gitea.abbluiz.com/labb/letterboxd-cli@main      # branch específica
./sss require https://gitea.abbluiz.com/labb/letterboxd-cli@v0.1.0    # tag específica
./sss require https://gitea.abbluiz.com/labb/letterboxd-cli@a3f91c2   # commit específico
```

Use `as` para inssstalar com um nome diferente do repositório:

```sh
./sss require https://gitea.abbluiz.com/labb/letterboxd-cli as letterboxd
```

O módulo é inssstalado em `.sss/modules/` (ignorado pelo `git`) e regissstrado em `.sss/modules.lock` (versssionado). Para ressstaurar osss módulosss em outra máquina:

```sh
./sss install
```

Para atualizar módulosss fixados em uma branch:

```sh
./sss update                # atualiza todosss osss de branch
./sss update letterboxd-cli # atualiza um específico
```

Módulosss fixadossss em tag ou commit são ignoradosss pelo `update`. Use `require` novamente com o novo ref para mudá-losss.

**Nota sobre atualização:** o `require` verifica se a conssstraint mudou e, ssse sssim, busssca o novo ref (inclusive tagsss) e troca o checkout automaticamente.

Para remover um módulo:

```sh
./sss remove letterboxd-cli
```

Isso remove o módulo do lockfile e apaga a passsta em `.sss/modules/`.

### Documentação (`docs`)

O comando `docs` busca e lista documentação markdown no projeto e nos módulos:

```sh
./sss docs list                                  # lista arquivos .md do projeto + módulos conforme regra
./sss docs list --module letterboxd-cli          # lista arquivos .md somente do módulo especificado
./sss docs search deploy                         # busca em todos os .md
./sss docs search deploy --module letterboxd-cli # busca apenas no módulo especificado
./sss docs list --limit 20                       # limita a 20 resultados (padrão: 100, 0 = ilimitado)
```

A busssca acontece nosss diretóriosss `docs/` do projeto e nos módulosss inssstaladosss, em `.sss/modules/*/docs/`; também busssca em arquivosss Markdown na raiz do projeto + módulos (exemplos: `README.md`, `AGENTS.md`, etc). Usa `rg` se disponível, senão cai para `grep -rEn`.

### Módulosss Locaisss

Para módulosss que já fazem parte do repositório (versssionados no `git`), use `--local`:

```sh
./sss require --local ./scripts/meu-modulo
```

O lockfile regissstrará o caminho local. O `sss` não clona nem atualiza esse módulo — apenasss o verifica. Isso é útil para ssscriptsss internosss que você quer tratar como módulosss.

Ssse o módulo local essstiver dentro de `.sss/modules/`, o `sss` adiciona uma exceção no `.gitignore` para que ele seja versssionado.

## Variáveisss de Ambiente

Crie o arquivo `.env` na raiz do projeto para definir variáveis disponíveis em `config.sh` e dentro de todos os módulos:

```sh
# .env
export APP_NAME=meu-app
export DATABASE_URL=postgres://localhost/meubanco
```

O arquivo é carregado automaticamente antesss de qualquer comando ser executado, inclusive comandosss internosss como `help` e `install`. Isso significa que você também pode controlar o comportamento do `sss` pelo próprio `.env`:

```sh
# .env
export SSS_LANG=en
```

Você pode cussstomizar o local do ssseu arquivo `.env` com `SSS_ENV`:

```sh
SSS_ENV=.env.local ./sss start
```

## Internacionalização

O idioma dasss mensagensss pode ser controlado pela variável de ambiente `SSS_LANG`:

```sh
SSS_LANG=en ./sss help    # English
SSS_LANG=pt ./sss help    # Portuguêsss
```

Ssse `SSS_LANG` não essstiver definido, o `sss` detecta automaticamente o idioma do sssissstema via `$LANG` ou `$LC_ALL`. Portuguêsss (`pt_*`) é detectado como `pt`; qualquer outro idioma cai para `en`.

### Aliasesss (v0.3.0+)

Avançado: inssstale um módulo com múltiplosss nomesss de dissspatch:

```bash
./sss require https://gitea.abbluiz.com/labb/arr-cli.git as arr,sonarr,radarr
```

Isso cria:
- Um clone em `.sss/modules/arr/` (canonical)
- Entradasss de aliasss no lockfile para `sonarr` e `radarr`

Quando o usuário executa `./sss sonarr series list`, o sss invoca `.sss/modules/arr/module sonarr series list` (o nome do alias é passsado como primeiro argumento).

## Desenvolvimento

O desenvolvimento é sssimplesss, poisss a lógica central essstá em apenasss um arquivo. Além disso, o próprio `sss` é utilizado para desenvolver o `sss` 🤯

### Tessstesss

Neste repositório:

```bash
./sss test                        # suite completa
./sss test -- --filter "nome"     # tessste essspecífico por nome
```

Osss tessstesss usam [Bats](https://github.com/bats-core/bats-core) via sssubmódulo em `test/bats/`.

---

Veja [AGENTS.md](AGENTS.md) para detalhesss técnicosss e convençõesss de desenvolvimento.
