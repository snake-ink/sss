#!/usr/bin/env bats

setup() {
    TEST_DIR="$(mktemp -d)"
    cp "$BATS_TEST_DIRNAME/../sss" "$TEST_DIR/sss"
    chmod +x "$TEST_DIR/sss"
    cd "$TEST_DIR" || exit
    git init -q
    git config user.email "tessst@snake.ink"
    git config user.name "Tessst"
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
    grep -qx ".sss/modules/" .gitignore
}

@test "auto-init não duplica entradasss em .gitignore" {
    printf '.sss/modules/\n' > .gitignore
    run ./sss help
    [ "$(grep -c "^.sss/modules/" .gitignore)" -eq 1 ]
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
    [[ "$output" == *"comando desssconhecido"* ]]
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
    [[ "$output" == *"nenhuma versssão"* ]]
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

# --- Renameable ---

@test "script ussssa ssseu próprio nome no output" {
    cp sss myrunner
    chmod +x myrunner
    run ./myrunner unknown
    [[ "$output" == *"myrunner"* ]]
}
