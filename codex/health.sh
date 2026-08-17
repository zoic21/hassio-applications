#!/usr/bin/env bash
set -Eeuo pipefail

status_from_http() {
    local url="$1"

    if curl --fail --silent --show-error --max-time 3 "${url}" >/dev/null 2>&1; then
        printf 'healthy'
    else
        printf 'unhealthy'
    fi
}

status_from_command() {
    if "$@" >/dev/null 2>&1; then
        printf 'healthy'
    else
        printf 'unhealthy'
    fi
}

container_status="$(status_from_http http://127.0.0.1:8099/healthz)"
code_server_status="$(status_from_http http://127.0.0.1:1337/healthz)"
console_status="$(status_from_http http://127.0.0.1:8099/health/console)"
codex_status="$(status_from_command test -x /config/codex/packages/standalone/current/codex)"
ssh_status="$(status_from_command /usr/sbin/sshd -t -f /etc/ssh/sshd_config)"

remote_control_status=stopped
if timeout 5 codex app-server daemon version --json >/dev/null 2>&1; then
    remote_control_status=running
fi

jq -n \
    --arg container "${container_status}" \
    --arg code_server "${code_server_status}" \
    --arg console "${console_status}" \
    --arg codex "${codex_status}" \
    --arg ssh "${ssh_status}" \
    --arg remote_control "${remote_control_status}" \
    '{
        container: $container,
        code_server: $code_server,
        console: $console,
        codex: $codex,
        ssh: $ssh,
        remote_control: $remote_control
    }'
