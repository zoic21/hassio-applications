# shellcheck shell=bash
# Shared shell environment for Ingress and SSH sessions.
export CODEX_HOME=/config/codex
export EDITOR=vim
export GH_CONFIG_DIR=/config/gh
export GIT_CONFIG_GLOBAL=/config/git/config
export HISTFILE=/config/shell/bash_history
export XDG_CACHE_HOME=/config/code-server/xdg-cache
export XDG_CONFIG_HOME=/config/code-server/xdg-config
export XDG_DATA_HOME=/config/code-server/xdg-data

if [[ -r /run/codex-app/github_token ]]; then
    IFS= read -r GH_TOKEN < /run/codex-app/github_token
    export GH_TOKEN
fi

if [[ $- == *i* ]]; then
    cd /work 2>/dev/null || true
fi
