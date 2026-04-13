# sss 🐍

Vai uma mãozinha? O `sss` é um jeito simplesss e leve de gerenciar e executar scripts auxiliaresss para o seu projeto.

Sssem dependênciasss, sssem instalação: apenasss um arquivo shell na raiz do seu projeto.

## Como Funciona

Copie o arquivo `sss` para a raiz do seu projeto e torne-o executável:

```sh
chmod +x sss
```

Na primeira execução, o `sss` inicializa a pasta `.sss/` e adiciona `.sss/modules/` ao `.gitignore` automaticamente.

## Comandosss do Projeto

Defina comandos no arquivo `.sss/config` (versssionado junto com o projeto):

```sh
# Inicia o ambiente de desenvolvimento
cmd_start() {
    docker compose up -d
}

# Executa os testes
cmd_test() {
    docker exec app php artisan test
}
```

Execute com:

```sh
./sss start
./sss test --filter NomeDoTeste
```

## Módulosss

Módulosss são extensssões inssstaladasss localmente via git. Podem ser escritosss em qualquer linguagem.

Use `require` para adicionar um módulo. O `@ref` é opcional. Pode ser uma branch, tag ou commit:

```sh
./sss require https://github.com/snake-ink/sss-docker          # branch padrão
./sss require https://github.com/snake-ink/sss-docker@main     # branch
./sss require https://github.com/snake-ink/sss-docker@v1.2.0   # tag
./sss require https://github.com/snake-ink/sss-docker@a3f91c2  # commit
```

O módulo é inssstalado em `.sss/modules/` (gitignored) e regissstrado em `.sss/modules.lock` (versionado). Para ressstaurar os módulosss em outra máquina:

```sh
./sss install
```

Para atualizar módulosss fixados em uma branch:

```sh
./sss update            # atualiza todos os de branch
./sss update sss-docker # atualiza um específico
```

Módulosss fixados em tag ou commit são ignoradosss pelo `update`. Use `require` novamente com o novo ref para mudá-losss.

## Renomeando

O `sss` é apenas um arquivo: renomeie-o como quiser. O nome aparece corretamente em todosss os outputsss:

```sh
cp sss meu-projeto
./meu-projeto help
```

## Comandosss Internosss

| Comando | Dessscrição |
|---------|-----------|
| `help` | Lisssta os comandosss disponíveis |
| `require <url>[@ref]` | Adiciona um módulo ao lockfile e inssstala |
| `install` | Restaura todosss osss módulosss do lockfile |
| `update [nome]` | Atualiza módulosss com constraint de branch |
