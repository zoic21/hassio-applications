#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

readonly OPTIONS_DEFAULT=/tmp/codex-options.json
readonly OPTIONS_PERSISTENT=/data/options.json
readonly RUNTIME_DIR=/run/codex-app

log_info() {
    printf '[Codex] %s\n' "$*"
}

log_error() {
    printf '[Codex] ERROR: %s\n' "$*" >&2
}

if [[ -s "${OPTIONS_PERSISTENT}" ]]; then
    readonly OPTIONS_FILE="${OPTIONS_PERSISTENT}"
else
    printf '{}\n' > "${OPTIONS_DEFAULT}"
    readonly OPTIONS_FILE="${OPTIONS_DEFAULT}"
    log_info "No Home Assistant options file found; using safe defaults."
fi

if ! jq -e 'type == "object"' "${OPTIONS_FILE}" >/dev/null 2>&1; then
    log_error "The Home Assistant options file is not a valid JSON object."
    exit 1
fi

option_string() {
    local filter="$1"
    jq -er "${filter} // empty | strings" "${OPTIONS_FILE}" 2>/dev/null || true
}

write_file() {
    local destination="$1"
    local mode="$2"
    local content="$3"
    local temporary

    temporary="$(mktemp "${destination}.tmp.XXXXXX")"
    printf '%s\n' "${content}" > "${temporary}"
    chmod "${mode}" "${temporary}"
    mv -f "${temporary}" "${destination}"
}

ensure_persistent_symlink() {
    local link_path="$1"
    local target_path="$2"
    local first_entry

    if [[ -L "${link_path}" ]]; then
        if [[ "$(readlink -- "${link_path}")" != "${target_path}" ]]; then
            log_error "${link_path} is not linked to ${target_path}."
            exit 1
        fi
        return
    fi

    if [[ -d "${link_path}" ]]; then
        first_entry="$(find "${link_path}" -mindepth 1 -print -quit)"
        if [[ -n "${first_entry}" ]]; then
            log_error "${link_path} exists and is not empty; refusing to replace it."
            exit 1
        fi
        rmdir -- "${link_path}"
        log_info "Removed empty image directory ${link_path}."
    elif [[ -e "${link_path}" ]]; then
        log_error "${link_path} exists and is not a directory or symlink."
        exit 1
    fi

    ln -s -- "${target_path}" "${link_path}"
}

configure_storage() {
    install -d -m 0700 \
        "${RUNTIME_DIR}" \
        /config/codex \
        /config/gh \
        /config/git \
        /config/shell \
        /config/ssh \
        /data/work

    touch /config/shell/bash_history
    chmod 0600 /config/shell/bash_history

    ensure_persistent_symlink /work /data/work
    ensure_persistent_symlink /root/.ssh /config/ssh

    if [[ ! -f /config/codex/config.toml ]]; then
        write_file /config/codex/config.toml 0600 $'cli_auth_credentials_store = "file"\napproval_policy = "on-request"\nsandbox_mode = "danger-full-access"'
        log_info "Created the persistent Codex configuration."
    fi
}

install_extra_packages() {
    local package status
    local -a requested=()
    local -a missing=()

    mapfile -t requested < <(jq -r '.packages[]? // empty' "${OPTIONS_FILE}")
    if (( ${#requested[@]} == 0 )); then
        return
    fi

    for package in "${requested[@]}"; do
        if [[ ! "${package}" =~ ^[a-z0-9][a-z0-9+.-]*(:[a-z0-9]+)?$ ]]; then
            log_error "Invalid Debian package name rejected: ${package}"
            exit 1
        fi

        status="$(dpkg-query -W -f='${db:Status-Status}' "${package}" 2>/dev/null || true)"
        if [[ "${status}" != "installed" ]]; then
            missing+=("${package}")
        fi
    done

    if (( ${#missing[@]} == 0 )); then
        log_info "All configured Debian packages are already installed."
        return
    fi

    log_info "Installing configured Debian packages: ${missing[*]}"
    if ! apt-get update; then
        log_error "apt-get update failed; configured packages were not installed."
        exit 1
    fi
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"; then
        log_error "A configured Debian package could not be installed."
        exit 1
    fi
    rm -rf /var/lib/apt/lists/*
    log_info "Configured Debian packages installed successfully."
}

configure_git() {
    local git_name git_email

    git_name="$(option_string '.git_user_name')"
    git_email="$(option_string '.git_user_email')"

    touch "${GIT_CONFIG_GLOBAL}"
    chmod 0600 "${GIT_CONFIG_GLOBAL}"

    if [[ -n "${git_name}" ]]; then
        git config --global user.name "${git_name}"
        log_info "Configured Git user name."
    fi
    if [[ -n "${git_email}" ]]; then
        git config --global user.email "${git_email}"
        log_info "Configured Git user email."
    fi
}

configure_github_token() {
    local github_token

    github_token="$(option_string '.github_token')"
    github_token="${github_token//$'\r'/}"

    if [[ "${github_token}" == *$'\n'* ]]; then
        log_error "The GitHub token contains an invalid newline."
        exit 1
    fi

    if [[ -n "${github_token}" ]]; then
        write_file "${RUNTIME_DIR}/github_token" 0600 "${github_token}"
        log_info "GitHub CLI token configured."
    else
        rm -f "${RUNTIME_DIR}/github_token"
        log_info "No GitHub token configured; gh can still be authenticated interactively."
    fi
}

configure_ssh_client() {
    local private_key public_key client_config known_hosts

    private_key="$(option_string '.ssh_private_key')"
    public_key="$(option_string '.ssh_public_key')"
    client_config="$(option_string '.ssh_client_config')"
    known_hosts="$(option_string '.ssh_known_hosts')"

    private_key="${private_key//$'\r'/}"
    public_key="${public_key//$'\r'/}"
    client_config="${client_config//$'\r'/}"
    known_hosts="${known_hosts//$'\r'/}"

    if [[ -n "${private_key}" ]]; then
        write_file /config/ssh/id_github 0600 "${private_key}"
        log_info "Configured the persistent SSH client private key."
    fi
    if [[ -n "${public_key}" ]]; then
        write_file /config/ssh/id_github.pub 0644 "${public_key}"
    fi

    if [[ -n "${known_hosts}" ]]; then
        write_file /config/ssh/known_hosts 0644 "${known_hosts}"
        log_info "Configured additional SSH known hosts."
    elif [[ ! -e /config/ssh/known_hosts ]]; then
        touch /config/ssh/known_hosts
        chmod 0644 /config/ssh/known_hosts
    fi

    if [[ -n "${client_config}" ]]; then
        write_file /config/ssh/config 0600 "${client_config}"
    elif [[ -f /config/ssh/id_github ]]; then
        write_file /config/ssh/config 0600 $'Host github.com\n    User git\n    IdentityFile /config/ssh/id_github\n    IdentitiesOnly yes\n\nHost *\n    ServerAliveInterval 60\n    ServerAliveCountMax 3'
    else
        write_file /config/ssh/config 0600 $'Host *\n    ServerAliveInterval 60\n    ServerAliveCountMax 3'
    fi
}

configure_ssh_server() {
    local allow_forwarding
    local -a authorized_keys=()

    install -d -m 0700 /config/ssh/host_keys

    if [[ ! -f /config/ssh/host_keys/ssh_host_ed25519_key ]]; then
        ssh-keygen -q -t ed25519 -N '' \
            -f /config/ssh/host_keys/ssh_host_ed25519_key
        log_info "Generated a persistent Ed25519 SSH server host key."
    fi
    if [[ ! -f /config/ssh/host_keys/ssh_host_rsa_key ]]; then
        ssh-keygen -q -t rsa -b 3072 -N '' \
            -f /config/ssh/host_keys/ssh_host_rsa_key
        log_info "Generated a persistent RSA SSH server host key."
    fi

    mapfile -t authorized_keys < <(jq -r '.ssh_authorized_keys[]? // empty' "${OPTIONS_FILE}")
    : > /config/ssh/authorized_keys
    for key in "${authorized_keys[@]}"; do
        [[ -n "${key}" ]] && printf '%s\n' "${key}" >> /config/ssh/authorized_keys
    done
    chmod 0600 /config/ssh/authorized_keys

    allow_forwarding="$(jq -r '.ssh_allow_tcp_forwarding // true' "${OPTIONS_FILE}")"
    case "${allow_forwarding}" in
        true) allow_forwarding=yes ;;
        false) allow_forwarding=no ;;
        *)
            log_error "ssh_allow_tcp_forwarding must be true or false."
            exit 1
            ;;
    esac

    sed "s/__ALLOW_TCP_FORWARDING__/${allow_forwarding}/g" \
        /usr/local/share/codex-app/sshd_config > /etc/ssh/sshd_config
    chmod 0600 /etc/ssh/sshd_config
    /usr/sbin/sshd -t -f /etc/ssh/sshd_config

    if (( ${#authorized_keys[@]} == 0 )); then
        log_info "SSH server has no authorized key; remote login is disabled."
    else
        log_info "SSH server authorized keys configured."
    fi
}

terminate_services() {
    local signal="${1:-TERM}"
    [[ -n "${SSHD_PID:-}" ]] && kill -s "${signal}" "${SSHD_PID}" 2>/dev/null || true
    [[ -n "${TTYD_PID:-}" ]] && kill -s "${signal}" "${TTYD_PID}" 2>/dev/null || true
}

# shellcheck disable=SC2329 # Invoked by the signal trap below.
handle_shutdown() {
    SHUTTING_DOWN=true
    log_info "Stopping Codex App services."
    terminate_services TERM
}

configure_storage
install_extra_packages
configure_git
configure_github_token
configure_ssh_client
configure_ssh_server

SHUTTING_DOWN=false
trap handle_shutdown TERM INT

log_info "Starting SSH server on container port 22."
/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config &
SSHD_PID=$!

log_info "Starting ttyd Web terminal for Home Assistant Ingress on port 8099."
/usr/local/bin/ttyd \
    --writable \
    --port 8099 \
    --cwd /work \
    --terminal-type xterm-256color \
    --client-option titleFixed=Codex \
    tmux -u new-session -A -s codex -c /work /bin/bash -l &
TTYD_PID=$!

if [[ "${SHUTTING_DOWN}" == true ]]; then
    terminate_services TERM
fi

if wait -n "${SSHD_PID}" "${TTYD_PID}"; then
    status=1
else
    status=$?
fi
if [[ "${SHUTTING_DOWN}" == true ]]; then
    wait || true
    exit 0
fi
log_error "A required service stopped unexpectedly (status ${status})."
terminate_services TERM
wait || true
exit "${status}"
