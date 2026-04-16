#!/bin/sh

# Roda os testes
cmd_test() {
    ./test/bats/bin/bats test/
}

# Cria link AGENTS.md -> .claude/CLAUDE.md
cmd_claude() {
    if [ ! -L ".claude/CLAUDE.md" ]; then
        ln -s AGENTS.md .claude/CLAUDE.md
        echo "Link AGENTS.md -> .claude/CLAUDE.md criado."
    else
        echo "Link AGENTS.md -> .claude/CLAUDE.md já existe."
    fi
}