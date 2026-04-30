#!/usr/bin/env bats

setup() {
    TEST_DIR="$(mktemp -d)"
    cp "$BATS_TEST_DIRNAME/../sss" "$TEST_DIR/sss"
    chmod +x "$TEST_DIR/sss"
    cd "$TEST_DIR" || exit
    git init -q
    git config user.email "tessst@snake.ink"
    git config user.name "Tessst"
    # Força auto-detect para pt nos testes existentes
    export LANG=pt_BR.UTF-8
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Cria um repositório git local com ao menos um commit, para ussar como "remote" fake
_make_fake_remote() {
    remote_dir="$1"
    git init -q "$remote_dir"
    printf '#!/bin/sh\nprintf "fake module\\n"\n' > "$remote_dir/module"
    chmod +x "$remote_dir/module"
    git -C "$remote_dir" add .
    git -C "$remote_dir" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "init"
}

# --- Help & defaults ---

@test "sssem argumentosss mossstra comando help" {
    run ./sss
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso:"* ]]
}

@test "comando help mossstra o uso" {
    run ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso:"* ]]
}

@test "argumento --help mossstra o uso" {
    run ./sss --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso:"* ]]
}

# --- Auto-init ---

@test "auto-init cria a essstrutura .sss" {
    run ./sss help
    [ -d ".sss" ]
    [ -f ".sss/config.sh" ]
    [ -d ".sss/modules" ]
}

@test "auto-init adiciona .sss/modules/ em .gitignore" {
    touch .gitignore
    run ./sss help
    grep -qFx ".sss/modules/*" .gitignore
}

@test "auto-init não duplica entradasss em .gitignore" {
    printf '.sss/modules/*\n' > .gitignore
    run ./sss help
    [ "$(grep -c "^.sss/modules/\*" .gitignore)" -eq 1 ]
}

@test "auto-init é pulado quando não essstá em um repo git" {
    rm -rf .git
    run ./sss help
    [ "$status" -eq 0 ]
    [ ! -d ".sss" ]
}

# --- Unknown command ---

@test "comando desssconhecido retorna erro" {
    run ./sss unknown
    [ "$status" -eq 1 ]
    [[ "$output" == *"comando desconhecido"* ]]
}

# --- Config dispatch ---

@test "dessspacha para função cmd_ no config" {
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_greet() { printf "hi\n"; }
EOF
    run ./sss greet
    [ "$status" -eq 0 ]
    [ "$output" = "hi" ]
}

@test "passssa argumentosss para função cmd_" {
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_echo() { printf "%s\n" "$1"; }
EOF
    run ./sss echo "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "código de sssaída da função cmd_ é propagado" {
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_fail() { exit 42; }
EOF
    run ./sss fail
    [ "$status" -eq 42 ]
}

@test "essspaço como ssseparador de sssub-comando" {
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_docker_build() { printf "build: %s\n" "$1"; }
EOF
    run ./sss docker build prod
    [ "$status" -eq 0 ]
    [ "$output" = "build: prod" ]
}

@test "essspaço como ssseparador com múltiplosss níveisss" {
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_this_is_a_test() { printf "%s %s\n" "$1" "$2"; }
EOF
    run ./sss this is a test hello world
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "sssub-comando com underssscore ainda funciona" {
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_docker_build() { printf "ok\n"; }
EOF
    run ./sss docker_build
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

# --- Module dispatch ---

@test "dessspacha para executável do módulo" {
    mkdir -p .sss/modules/mymod
    cat > .sss/modules/mymod/module << 'EOF'
#!/bin/sh
printf "from module: %s\n" "$1"
EOF
    chmod +x .sss/modules/mymod/module
    run ./sss mymod hello
    [ "$status" -eq 0 ]
    [ "$output" = "from module: hello" ]
}

@test "config tem prioridade sssobre módulo com o messsmo nome" {
    mkdir -p .sss/modules/thing
    cat > .sss/modules/thing/module << 'EOF'
#!/bin/sh
printf "from module\n"
EOF
    chmod +x .sss/modules/thing/module
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_thing() { printf "from config\n"; }
EOF
    run ./sss thing
    [ "$status" -eq 0 ]
    [ "$output" = "from config" ]
}

# --- require ---

@test "require ssem url sai com erro" {
    run ./sss require
    [ "$status" -eq 1 ]
    [[ "$output" == *"require requer"* ]]
}

@test "require inssstala módulo e cria lockfile" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    run ./sss require "$remote"
    [ "$status" -eq 0 ]
    [ -d ".sss/modules/fake-remote" ]
    [ -f ".sss/modules.lock" ]
    grep -q "^fake-remote " .sss/modules.lock
}

@test "require registra constraint de branch" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    mkdir -p .sss/modules
    run ./sss require "$remote@$default_branch"
    [ "$status" -eq 0 ]
    grep -q "branch:$default_branch" .sss/modules.lock
}

@test "require registra constraint de tag" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    git -C "$remote" tag v1.0
    mkdir -p .sss/modules
    run ./sss require "$remote@v1.0"
    [ "$status" -eq 0 ]
    grep -q "tag:v1.0" .sss/modules.lock
}

@test "require registra constraint de commit" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    commit="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    run ./sss require "$remote@$commit"
    [ "$status" -eq 0 ]
    grep -q "commit:$commit" .sss/modules.lock
}

@test "require com messsma constraint é idempotente" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    ./sss require "$remote" >/dev/null
    run ./sss require "$remote"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nada a fazer"* ]]
    [ "$(grep -c "^fake-remote " .sss/modules.lock)" -eq 1 ]
}

@test "require com constraint diferente atualiza o lockfile" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    git -C "$remote" tag v1.0
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    mkdir -p .sss/modules
    ./sss require "$remote@$default_branch" >/dev/null
    run ./sss require "$remote@v1.0"
    [ "$status" -eq 0 ]
    grep -q "tag:v1.0" .sss/modules.lock
    [ "$(grep -c "^fake-remote " .sss/modules.lock)" -eq 1 ]
}

# --- install ---

@test "install ssem lockfile reporta nenhum" {
    mkdir -p .sss/modules
    run ./sss install
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nenhum"* ]]
}

@test "install ressstaura módulossss do lockfile" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$resolved" > .sss/modules.lock
    run ./sss install
    [ "$status" -eq 0 ]
    [ -d ".sss/modules/fake-remote" ]
}

@test "install pula módulossss já inssstalados" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$resolved" > .sss/modules.lock
    run ./sss install
    [ "$status" -eq 0 ]
    [[ "$output" == *"pulando"* ]]
}

# --- update ---

@test "update ssem lockfile reporta nenhum" {
    mkdir -p .sss/modules
    run ./sss update
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nenhum"* ]]
}

@test "update pula módulossss fixadosss em tag" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    git -C "$remote" tag v1.0
    resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    git -C .sss/modules/fake-remote checkout -q v1.0
    printf 'fake-remote %s tag:v1.0 %s\n' "$remote" "$resolved" > .sss/modules.lock
    run ./sss update
    [ "$status" -eq 0 ]
    [[ "$output" == *"fixado"* ]]
}

@test "update pula módulossss fixadosss em commit" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    printf 'fake-remote %s commit:%s %s\n' "$remote" "$resolved" "$resolved" > .sss/modules.lock
    run ./sss update
    [ "$status" -eq 0 ]
    [[ "$output" == *"fixado"* ]]
}

@test "update atualiza módulo de branch e essscreve commit no lockfile" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    old_resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$old_resolved" > .sss/modules.lock

    # Adiciona um novo commit no remote
    printf 'v2\n' > "$remote/version"
    git -C "$remote" add .
    git -C "$remote" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "v2"
    new_resolved="$(git -C "$remote" rev-parse HEAD)"

    run ./sss update
    [ "$status" -eq 0 ]
    grep -q "$new_resolved" .sss/modules.lock
}

# --- remove ---

@test "remove ssem nome sssai com erro" {
    run ./sss remove
    [ "$status" -eq 1 ]
    [[ "$output" == *"remove needs"* ]]
}

@test "remove ssem lockfile sssai com erro" {
    run ./sss remove fakemod
    [ "$status" -eq 1 ]
    [[ "$output" == *"não está instalado"* ]]
}

@test "remove de módulo não no lockfile sssai com erro" {
    mkdir -p .sss
    touch .sss/modules.lock
    run ./sss remove fakemod
    [ "$status" -eq 1 ]
    [[ "$output" == *"não está instalado"* ]]
}

@test "remove remove diretório do módulo e entrada do lockfile" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$(git -C .sss/modules/fake-remote rev-parse HEAD)" > .sss/modules.lock
    run ./sss remove fake-remote
    [ "$status" -eq 0 ]
    [ ! -d ".sss/modules/fake-remote" ]
    ! grep -q "^fake-remote " .sss/modules.lock
}

@test "remove limpa .gitignore" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$(git -C .sss/modules/fake-remote rev-parse HEAD)" > .sss/modules.lock
    printf '.sss/modules/*\n!.sss/modules/fake-remote/\n' > .gitignore
    run ./sss remove fake-remote
    [ "$status" -eq 0 ]
    ! grep -q "fake-remote" .gitignore
}

@test "remove funciona quando módulo está no lockfile mas diretório está faltando" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    mkdir -p .sss
    resolved="$(git -C "$remote" rev-parse HEAD)"
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$resolved" > .sss/modules.lock
    run ./sss remove fake-remote
    [ "$status" -eq 0 ]
    ! grep -q "^fake-remote " .sss/modules.lock
}

@test "remove não apaga diretório de módulo local" {
    mkdir -p localmod
    printf '#!/bin/sh\nexit 0\n' > localmod/module
    chmod +x localmod/module
    run ./sss require --local ./localmod
    [ "$status" -eq 0 ]
    [ -d "localmod" ]
    run ./sss remove localmod
    [ "$status" -eq 0 ]
    [ -d "localmod" ]
    ! grep -q "^localmod " .sss/modules.lock
}

# --- pin ---

@test "pin ssem versssão sssai com erro" {
    run ./sss pin
    [ "$status" -eq 1 ]
    [[ "$output" == *"pin requer"* ]]
}

@test "pin registra versssão no lockfile" {
    mkdir -p .sss
    run ./sss pin 1.2.3
    [ "$status" -eq 0 ]
    grep -q "^sss 1.2.3$" .sss/modules.lock
}

@test "pin não é bloqueado por versssão incorreta no lockfile" {
    mkdir -p .sss
    printf 'sss 999.0.0\n' > .sss/modules.lock
    run ./sss pin 0.1.0
    [ "$status" -eq 0 ]
    grep -q "^sss 0.1.0$" .sss/modules.lock
}

@test "pin sssobre-essscreve versssão existente no lockfile" {
    mkdir -p .sss
    ./sss pin 1.0.0 >/dev/null
    run ./sss pin 2.0.0
    [ "$status" -eq 0 ]
    grep -q "^sss 2.0.0$" .sss/modules.lock
    [ "$(grep -c "^sss " .sss/modules.lock)" -eq 1 ]
}

# --- self-update / version check ---

@test "não bloqueia quando não há entrada sss no lockfile" {
    mkdir -p .sss
    touch .sss/modules.lock
    run ./sss help
    [ "$status" -eq 0 ]
}

@test "não bloqueia quando versssão bate com lockfile" {
    mkdir -p .sss
    version="$(grep '^SSS_VERSION=' ./sss | sed 's/SSS_VERSION=//;s/"//g')"
    printf 'sss %s\n' "$version" > .sss/modules.lock
    run ./sss help
    [ "$status" -eq 0 ]
}

@test "bloqueia quando versssão não bate com lockfile" {
    mkdir -p .sss
    printf 'sss 999.0.0\n' > .sss/modules.lock
    run ./sss help
    [ "$status" -eq 1 ]
    [[ "$output" == *"999.0.0"* ]]
}

@test "self-update não é bloqueado por versssão incorreta" {
    mkdir -p .sss
    printf 'sss 999.0.0\n' > .sss/modules.lock
    # Ssem curl/wget o comando falha, masss não pelo version check
    run ./sss self-update
    [[ "$output" != *"999.0.0 requerida"* ]]
}

@test "self-update ssem versssão e ssem lockfile sai com erro" {
    run ./sss self-update
    [ "$status" -eq 1 ]
    [[ "$output" == *"nenhuma versão"* ]]
}

@test "install pula entrada sss no lockfile" {
    mkdir -p .sss/modules
    version="$(grep '^SSS_VERSION=' ./sss | sed 's/SSS_VERSION=//;s/"//g')"
    printf 'sss %s\n' "$version" > .sss/modules.lock
    run ./sss install
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nenhum"* ]]
}

@test "update pula entrada sss no lockfile" {
    mkdir -p .sss/modules
    version="$(grep '^SSS_VERSION=' ./sss | sed 's/SSS_VERSION=//;s/"//g')"
    printf 'sss %s\n' "$version" > .sss/modules.lock
    run ./sss update
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nenhum"* ]]
}

# --- requires helper ---

@test "requires falha quando módulo não essstá inssstalado" {
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_go() {
    requires meu-modulo
    printf "ok\n"
}
EOF
    run ./sss go
    [ "$status" -eq 1 ]
    [[ "$output" == *"meu-modulo"* ]]
    [[ "$output" == *"install"* ]]
}

@test "requires não falha quando módulo essstá inssstalado" {
    mkdir -p .sss/modules/meu-modulo
    cat > .sss/config.sh << 'EOF'
cmd_go() {
    requires meu-modulo
    printf "ok\n"
}
EOF
    run ./sss go
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

# --- Dependênciasss do sssistema ---

@test "falha sssem git em repo git" {
    run env PATH="" ./sss help
    [ "$status" -eq 1 ]
    [[ "$output" == *"git"* ]]
}

# --- Local modules ---

@test "require --local registra módulo local no lockfile" {
    mkdir -p localmod
    printf '#!/bin/sh\nprintf "local\n"\n' > localmod/module
    chmod +x localmod/module
    run ./sss require --local ./localmod
    [ "$status" -eq 0 ]
    grep -q "^localmod ./localmod local -$" .sss/modules.lock
}

@test "despacha para módulo local" {
    mkdir -p localmod
    cat > localmod/module << 'EOF'
#!/bin/sh
printf "from local: %s\n" "$1"
EOF
    chmod +x localmod/module
    ./sss require --local ./localmod > /dev/null
    run ./sss localmod hello
    [ "$status" -eq 0 ]
    [ "$output" = "from local: hello" ]
}

@test "install verifica módulo local" {
    mkdir -p localmod
    printf '#!/bin/sh\nexit 0\n' > localmod/module
    chmod +x localmod/module
    mkdir -p .sss
    printf 'localmod ./localmod local -\n' > .sss/modules.lock
    run ./sss install
    [ "$status" -eq 0 ]
    [[ "$output" == *"verificado"* ]]
}

@test "install falha quando módulo local não existe" {
    mkdir -p .sss/modules
    printf 'localmod ./missing local -\n' > .sss/modules.lock
    run ./sss install
    [ "$status" -eq 1 ]
}

@test "update pula módulo local" {
    mkdir -p localmod
    printf '#!/bin/sh\nexit 0\n' > localmod/module
    chmod +x localmod/module
    mkdir -p .sss
    printf 'localmod ./localmod local -\n' > .sss/modules.lock
    run ./sss update
    [ "$status" -eq 0 ]
    [[ "$output" == *"local"* ]]
    [[ "$output" == *"pulando"* ]]
}

@test "requires funciona para módulo local" {
    mkdir -p localmod
    printf '#!/bin/sh\nexit 0\n' > localmod/module
    chmod +x localmod/module
    mkdir -p .sss
    printf 'localmod ./localmod local -\n' > .sss/modules.lock
    cat > .sss/config.sh << 'EOF'
cmd_go() {
    requires localmod
    printf "ok\n"
}
EOF
    run ./sss go
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "requires falha quando módulo local está faltando" {
    mkdir -p .sss
    printf 'localmod ./missing local -\n' > .sss/modules.lock
    cat > .sss/config.sh << 'EOF'
cmd_go() {
    requires localmod
    printf "ok\n"
}
EOF
    run ./sss go
    [ "$status" -eq 1 ]
}

# --- Environment variables ---

@test "env vars disponíveis em config.sh" {
    mkdir -p .sss
    printf 'export MY_VAR=hello\n' > .env
    cat > .sss/config.sh << 'EOF'
cmd_env_test() {
    printf "%s\n" "$MY_VAR"
}
EOF
    run ./sss env_test
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

@test "env vars disponíveis em módulo" {
    mkdir -p .sss/modules/envmod
    printf '#!/bin/sh\nprintf "%%s\\n" "$MY_VAR"\n' > .sss/modules/envmod/module
    chmod +x .sss/modules/envmod/module
    printf 'export MY_VAR=from_module\n' > .env
    run ./sss envmod
    [ "$status" -eq 0 ]
    [ "$output" = "from_module" ]
}

# --- i18n ---

@test "help em inglês" {
    run env SSS_LANG=en ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"Internal commands:"* ]]
    [[ "$output" == *"Shows this help"* ]]
}

@test "erro de comando desconhecido em inglês" {
    run env SSS_LANG=en ./sss unknown
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown command"* ]]
}

@test "SSS_LANG pode vir do .env" {
    printf 'export SSS_LANG=en\n' > .env
    run ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "SSS_ENV pode redirecionar para outro arquivo via .env" {
    printf 'export SSS_ENV=.env.local\n' > .env
    printf 'export LOCAL_VAR=ok\n' > .env.local
    mkdir -p .sss
    cat > .sss/config.sh << 'EOF'
cmd_check() {
    printf "%s\n" "$LOCAL_VAR"
}
EOF
    run ./sss check
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

# --- Aliases ---

@test "require <url> as canonical,alias cria um clone e entradas de alias" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    run ./sss require "$remote" as fake-remote,alias1,alias2
    [ "$status" -eq 0 ]
    [ -d ".sss/modules/fake-remote" ]
    [ "$(grep -c "^fake-remote " .sss/modules.lock)" -eq 1 ]
    [ "$(grep -c "^alias1 " .sss/modules.lock)" -eq 1 ]
    [ "$(grep -c "^alias2 " .sss/modules.lock)" -eq 1 ]
    grep -q "alias:fake-remote:alias1" .sss/modules.lock
    grep -q "alias:fake-remote:alias2" .sss/modules.lock
}

@test "sss alias invoca módulo canonical com nome do alias como primeiro argumento" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    ./sss require "$remote" as fake-remote,myalias > /dev/null
    run ./sss myalias hello world
    [ "$status" -eq 0 ]
    [ "$output" = "fake module" ]
}

@test "install pula aliases e verifica canonical existe" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$resolved" > .sss/modules.lock
    printf 'myalias %s alias:fake-remote:myalias -\n' "$remote" >> .sss/modules.lock
    run ./sss install
    [ "$status" -eq 0 ]
    [[ "$output" == *"alias"* ]]
    [[ "$output" == *"fake-remote"* ]]
    [ -d ".sss/modules/fake-remote" ]
}

@test "install falha quando canonical de alias não existe" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss
    printf 'myalias %s alias:missing:myalias -\n' "$remote" > .sss/modules.lock
    run ./sss install
    [ "$status" -eq 1 ]
}

@test "remove de alias remove apenas entrada do lockfile" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    ./sss require "$remote" as fake-remote,myalias > /dev/null
    [ -d ".sss/modules/fake-remote" ]
    run ./sss remove myalias
    [ "$status" -eq 0 ]
    [ -d ".sss/modules/fake-remote" ]
    ! grep -q "^myalias " .sss/modules.lock
    grep -q "^fake-remote " .sss/modules.lock
}

@test "remove de canonical com aliases falha listando os aliases" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    ./sss require "$remote" as fake-remote,alias1,alias2 > /dev/null
    run ./sss remove fake-remote
    [ "$status" -eq 1 ]
    [[ "$output" == *"alias1"* ]]
    [[ "$output" == *"alias2"* ]]
    [ -d ".sss/modules/fake-remote" ]
    grep -q "^fake-remote " .sss/modules.lock
}

@test "remove de canonical após remover todos aliases funciona" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    ./sss require "$remote" as fake-remote,myalias > /dev/null
    ./sss remove myalias > /dev/null
    run ./sss remove fake-remote
    [ "$status" -eq 0 ]
    [ ! -d ".sss/modules/fake-remote" ]
    ! grep -q "^fake-remote " .sss/modules.lock
}

# --- rebuild ---

@test "rebuild ssem nome sssai com erro" {
    run ./sss rebuild
    [ "$status" -eq 1 ]
    [[ "$output" == *"rebuild needs"* ]]
}

@test "rebuild de módulo não instalado sssai com erro" {
    run ./sss rebuild fakemod
    [ "$status" -eq 1 ]
    [[ "$output" == *"não está instalado"* ]]
}

@test "rebuild remove diretório e re-clona módulo" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    ./sss require "$remote" > /dev/null
    printf 'extra\n' > .sss/modules/fake-remote/extra.txt
    [ -f ".sss/modules/fake-remote/extra.txt" ]
    run ./sss rebuild fake-remote
    [ "$status" -eq 0 ]
    [ ! -f ".sss/modules/fake-remote/extra.txt" ]
    [ -f ".sss/modules/fake-remote/module" ]
}

@test "rebuild de alias sssai com erro sugerindo canonical" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    ./sss require "$remote" as fake-remote,myalias > /dev/null
    run ./sss rebuild myalias
    [ "$status" -eq 1 ]
    [[ "$output" == *"fake-remote"* ]]
}

@test "rebuild de módulo local sssai com erro" {
    mkdir -p localmod
    printf '#!/bin/sh\nexit 0\n' > localmod/module
    chmod +x localmod/module
    ./sss require --local ./localmod > /dev/null
    run ./sss rebuild localmod
    [ "$status" -eq 1 ]
}

# --- Language auto-detect ---

@test "auto-detecta idioma pt do LANG" {
    run env LANG=pt_BR.UTF-8 SSS_LANG= ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso:"* ]]
}

@test "auto-detecta idioma en do LANG" {
    run env LANG=en_US.UTF-8 SSS_LANG= ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "auto-detecta idioma en quando LANG não é pt" {
    run env LANG=fr_FR.UTF-8 SSS_LANG= ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "LC_ALL tem prioridade sobre LANG" {
    run env LANG=pt_BR.UTF-8 LC_ALL=en_US.UTF-8 SSS_LANG= ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "SSS_LANG definido manualmente sobrescreve auto-detect" {
    run env LANG=pt_BR.UTF-8 SSS_LANG=en ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# --- Install divergent HEAD ---

@test "install re-checkout quando HEAD diverge do lockfile" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    old_resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    # Adiciona novo commit no remote
    printf 'v2\n' > "$remote/version"
    git -C "$remote" add .
    git -C "$remote" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "v2"
    new_resolved="$(git -C "$remote" rev-parse HEAD)"
    # Lockfile com novo commit, mas clone local ainda no antigo
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$new_resolved" > .sss/modules.lock
    run ./sss install
    [ "$status" -eq 0 ]
    [[ "$output" == *"divergiu"* ]] || [[ "$output" == *"diverged"* ]]
    # Lockfile deve ser atualizado com o novo commit
    grep -q "$new_resolved" .sss/modules.lock
}

# --- Update fetch + reset ---

@test "update usa fetch + reset em vez de pull" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    old_resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$old_resolved" > .sss/modules.lock
    # Adiciona novo commit no remote
    printf 'v2\n' > "$remote/version"
    git -C "$remote" add .
    git -C "$remote" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "v2"
    run ./sss update
    [ "$status" -eq 0 ]
    new_resolved="$(git -C "$remote" rev-parse HEAD)"
    grep -q "$new_resolved" .sss/modules.lock
}

@test "update não cria merge commit" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    default_branch="$(git -C "$remote" rev-parse --abbrev-ref HEAD)"
    old_resolved="$(git -C "$remote" rev-parse HEAD)"
    mkdir -p .sss/modules
    git clone -q "$remote" .sss/modules/fake-remote
    printf 'fake-remote %s branch:%s %s\n' "$remote" "$default_branch" "$old_resolved" > .sss/modules.lock
    # Cria um commit local (divergência)
    printf 'local-change\n' > .sss/modules/fake-remote/local.txt
    git -C .sss/modules/fake-remote add .
    git -C .sss/modules/fake-remote -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "local"
    # Adiciona commit no remote
    printf 'v2\n' > "$remote/version"
    git -C "$remote" add .
    git -C "$remote" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "v2"
    run ./sss update
    [ "$status" -eq 0 ]
    # Deve estar no commit do remote, não ter merge commit
    new_resolved="$(git -C "$remote" rev-parse HEAD)"
    [ "$(git -C .sss/modules/fake-remote rev-parse HEAD)" = "$new_resolved" ]
    # Log deve ter apenas 2 commits (init + v2), não 3
    [ "$(git -C .sss/modules/fake-remote rev-list --count HEAD)" -eq 2 ]
}

# --- docs ---

@test "docs list lista arquivos markdown do projeto" {
    mkdir -p docs
    printf '# Hello\n' > docs/readme.md
    printf '# World\n' > docs/guide.md
    run ./sss docs list
    [ "$status" -eq 0 ]
    [[ "$output" == *"readme.md"* ]]
    [[ "$output" == *"guide.md"* ]]
}

@test "docs search busca termo em arquivos markdown" {
    mkdir -p docs
    printf '# Hello world\n' > docs/readme.md
    printf '# Other\n' > docs/guide.md
    run ./sss docs search world
    [ "$status" -eq 0 ]
    [[ "$output" == *"readme.md"* ]]
    [[ "$output" == *"world"* ]]
    [[ "$output" != *"guide.md"* ]]
}

@test "docs list limita resultados com --limit" {
    mkdir -p docs
    printf '# test\n' > docs/a.md
    printf '# test\n' > docs/b.md
    printf '# test\n' > docs/c.md
    run ./sss docs list --limit 2
    [ "$status" -eq 0 ]
    # Deve mostrar no máximo 2 resultados + mensagem de truncamento
    [[ "$output" == *"a.md"* ]] || [[ "$output" == *"b.md"* ]] || [[ "$output" == *"c.md"* ]]
    [[ "$output" == *"--limit 0"* ]] || [[ "$output" == *"limit"* ]]
}

@test "docs list lista arquivos de módulo específico com --module" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p "$remote/docs"
    printf '# Module doc\n' > "$remote/docs/readme.md"
    git -C "$remote" add .
    git -C "$remote" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "add docs"
    mkdir -p .sss/modules
    ./sss require "$remote" > /dev/null
    run ./sss docs list --module fake-remote
    [ "$status" -eq 0 ]
    [[ "$output" == *"readme.md"* ]]
}

@test "docs search busca em módulo específico com --module" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p "$remote/docs"
    printf '# Module deploy\n' > "$remote/docs/readme.md"
    git -C "$remote" add .
    git -C "$remote" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "add docs"
    mkdir -p .sss/modules
    ./sss require "$remote" > /dev/null
    run ./sss docs search deploy --module fake-remote
    [ "$status" -eq 0 ]
    [[ "$output" == *"readme.md"* ]]
    [[ "$output" == *"deploy"* ]]
}

@test "docs mostra mensagem quando módulo não tem docs" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    mkdir -p .sss/modules
    ./sss require "$remote" > /dev/null
    run ./sss docs list --module fake-remote
    [ "$status" -eq 1 ]
    [[ "$output" == *"Markdown"* ]]
}

@test "docs mostra mensagem quando não há docs" {
    run ./sss docs list
    [ "$status" -eq 1 ]
    [[ "$output" == *"Markdown"* ]] || [[ "$output" == *"nenhum"* ]] || [[ "$output" == *"no docs"* ]]
}

@test "docs search sem termo mostra erro" {
    run ./sss docs search
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires"* ]] || [[ "$output" == *"requer"* ]]
}

@test "docs sem subcomando mostra uso" {
    run ./sss docs
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]] || [[ "$output" == *"Uso:"* ]]
}

@test "docs list lista arquivos markdown na raiz do projeto" {
    printf '# Root doc\n' > README.md
    printf '# Other\n' > CONTRIBUTING.md
    run ./sss docs list
    [ "$status" -eq 0 ]
    [[ "$output" == *"README.md"* ]]
    [[ "$output" == *"CONTRIBUTING.md"* ]]
}

@test "docs search busca em arquivos markdown na raiz do projeto" {
    printf '# Hello world\n' > README.md
    printf '# Other\n' > CONTRIBUTING.md
    run ./sss docs search world
    [ "$status" -eq 0 ]
    [[ "$output" == *"README.md"* ]]
    [[ "$output" == *"world"* ]]
    [[ "$output" != *"CONTRIBUTING.md"* ]]
}

@test "docs list lista arquivos markdown na raiz do módulo" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    printf '# Root module doc\n' > "$remote/README.md"
    git -C "$remote" add .
    git -C "$remote" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "add root doc"
    mkdir -p .sss/modules
    ./sss require "$remote" > /dev/null
    run ./sss docs list --module fake-remote
    [ "$status" -eq 0 ]
    [[ "$output" == *"README.md"* ]]
}

@test "docs search busca em arquivos markdown na raiz do módulo" {
    remote="$TEST_DIR/fake-remote"
    _make_fake_remote "$remote"
    printf '# deploy instructions\n' > "$remote/README.md"
    printf '# Other\n' > "$remote/OTHER.md"
    git -C "$remote" add .
    git -C "$remote" -c user.email="tessst@snake.ink" -c user.name="Tessst" commit -q -m "add root docs"
    mkdir -p .sss/modules
    ./sss require "$remote" > /dev/null
    run ./sss docs search deploy --module fake-remote
    [ "$status" -eq 0 ]
    [[ "$output" == *"README.md"* ]]
    [[ "$output" == *"deploy"* ]]
    [[ "$output" != *"OTHER.md"* ]]
}

@test "docs list combina raiz e docs/" {
    printf '# Root\n' > README.md
    mkdir -p docs
    printf '# Deep\n' > docs/guide.md
    run ./sss docs list
    [ "$status" -eq 0 ]
    [[ "$output" == *"README.md"* ]]
    [[ "$output" == *"guide.md"* ]]
}

@test "docs list encontra arquivos em subdiretórios de docs/" {
    mkdir -p docs/sub
    printf '# Sub doc\n' > docs/sub/nested.md
    run ./sss docs list
    [ "$status" -eq 0 ]
    [[ "$output" == *"nested.md"* ]]
}

# --- Module descriptions in help ---

@test "help mostra descrição de módulo" {
    mkdir -p .sss/modules/mymod
    cat > .sss/modules/mymod/module << 'EOF'
#!/bin/sh
# My awesome module
printf "ok\n"
EOF
    chmod +x .sss/modules/mymod/module
    run ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"My awesome module"* ]]
}

@test "help mostra nome de módulo sem descrição quando não há comentário" {
    mkdir -p .sss/modules/mymod
    cat > .sss/modules/mymod/module << 'EOF'
#!/bin/sh
printf "ok\n"
EOF
    chmod +x .sss/modules/mymod/module
    run ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"mymod"* ]]
    [[ "$output" == *"--help"* ]]
    [[ "$output" == *"docs list --module mymod"* ]]
}

@test "help ignora comentário que não está na segunda linha" {
    mkdir -p .sss/modules/mymod
    cat > .sss/modules/mymod/module << 'EOF'
#!/bin/sh

# This should be ignored
printf "ok\n"
EOF
    chmod +x .sss/modules/mymod/module
    run ./sss help
    [ "$status" -eq 0 ]
    [[ "$output" == *"mymod"* ]]
    [[ "$output" != *"This should be ignored"* ]]
    [[ "$output" == *"--help"* ]]
}

# --- Renameable ---

@test "script ussssa ssseu próprio nome no output" {
    cp sss myrunner
    chmod +x myrunner
    run ./myrunner unknown
    [[ "$output" == *"myrunner"* ]]
}
