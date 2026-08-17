# Codex App documentation

## Installation

1. In Home Assistant, open **Settings → Apps → App store**.
2. Open the repository menu and add:
   `https://github.com/zoic21/hassio-applications`
3. Refresh the store, select **Codex**, and install it.
4. Start the App and select **Open Web UI**.

After the first successful build, the maintainer must make the GHCR packages
`hassio-applications-codex`, `amd64-hassio-applications-codex`, and
`aarch64-hassio-applications-codex` public. Home Assistant must be able to pull
the generic image anonymously.

The Web UI opens a deliberately small launcher:

- **VS Code** opens code-server on `/work` and is the main V1.5 interface.
- **Console** opens the independent V1 ttyd root shell. Use it to repair the
  environment if code-server or the Codex extension fails.

Both interfaces run entirely in the browser. No desktop VS Code client is
required. The integrated VS Code terminal and the fallback console start in
`/work` and provide `codex`, `git`, `gh`, and `ssh`.

## Pinned V1.5 components

The experimental combination is intentionally reproducible:

| Component | Version |
| --- | --- |
| code-server | `4.132.0` (VS Code `1.132.0`) |
| official Codex extension | `openai.chatgpt` `26.803.41515` |
| managed standalone Codex CLI | `0.147.0` |
| ttyd fallback console | `1.7.7` |

The extension is downloaded as an unmodified, target-specific VSIX from the
official Visual Studio Marketplace at image build time. It is image-bundled;
user-installed extensions and all code-server user data are stored under
`/config/code-server`.

The versions and their architecture-specific SHA-256 values are Docker build
arguments in `Dockerfile`. Override the version and matching checksums/asset
URLs together when testing another combination. Do not update only one member
of this matrix and assume compatibility.

## First ChatGPT login

Codex configuration and credentials are stored under `/config/codex` through
`CODEX_HOME`. For a headless installation, use the official device-code flow:

```shell
codex login --device-auth
```

Open the displayed URL on another device, sign in to ChatGPT, and enter the
one-time code. Device-code authentication may need to be enabled in the
ChatGPT security settings or by a workspace administrator. Check the result:

```shell
codex login status
```

Never put a ChatGPT password in the Home Assistant App configuration. Codex
uses file-backed credential storage in `/config/codex/auth.json`; treat this
file like a password.

Codex also officially supports API-key authentication when required. Configure
it from the terminal rather than placing it in this App's options:

```shell
printenv OPENAI_API_KEY | codex login --with-api-key
```

API-key use is billed through the OpenAI API account and is not required for
ChatGPT device authentication.

The CLI and IDE extension use the same `CODEX_HOME` and therefore share the
cached login and `config.toml`. Signing out from either client clears the
shared cached login. No ChatGPT password belongs in the App options.

## Codex remote control

The App embeds the official managed standalone Codex installation required by
remote control. After signing in, start it with:

```shell
codex remote-control start
codex remote-control pair
codex remote-control stop
```

`start` launches the managed App Server daemon, `pair` prints the short-lived
manual pairing mechanism, and `stop` stops the daemon. Add `--json` when
machine-readable output is useful. Remote Control uses outbound connections;
it does not require an inbound Internet port.

The standalone release is installed as real persistent data under
`/config/codex/packages/standalone`, including the official `current` link
managed by the installer. No Codex download is needed during App startup. The
first V1.5 start safely migrates the V0.1.2 whole-directory symlink to a real
persistent installation without changing `config.toml`, `auth.json`, MCP
configuration, or sessions.

Remote Control is deliberately not started automatically in V1.5. This keeps
authentication, enrollment, and session-sharing diagnostics observable.

## code-server and the Codex extension

code-server listens only on `127.0.0.1:1337`. The fallback ttyd console listens
only on `127.0.0.1:8100`. A small Nginx gateway is the only HTTP service exposed
to Home Assistant Ingress on container port `8099`; it preserves WebSocket
upgrades and the `/vscode` and `/console` base paths.

The official Codex extension is experimental on code-server. Automatic
extension updates are disabled to keep the tested combination stable. The
extension can still be replaced manually for a controlled experiment, but the
startup log always reports the image-bundled version.

code-server is started with `--enable-proposed-api openai.chatgpt` because the
official extension manifest declares the `chatSessionsProvider` and
`languageModelProxy` proposals. Removing that flag can make the sidebar appear
installed while its conversation plumbing is unavailable.

The official extension launches its own bundled `codex app-server` process over
stdio. The standalone `codex remote-control start` command launches a separate
managed App Server daemon. They share persistent Codex state, but they are not
the same process and this alone does not prove that a live thread can be owned
by both clients. Follow the exact validation protocol in
`V1_5_VALIDATION.md` before claiming shared-session support.

## Codex permissions inside the container

The generated Codex configuration uses:

```toml
approval_policy = "on-request"
sandbox_mode = "danger-full-access"
```

This deliberately disables Codex's nested filesystem sandbox because the
dedicated container is already the isolation boundary. Approval prompts remain
enabled. You can change these values in `/config/codex/config.toml`.

MCP configuration remains in this same file and is shared by CLI, App Server,
and the IDE extension. Verify it with `codex mcp list`; V1.5 does not introduce
a separate VS Code MCP configuration.

## Git identity

The optional settings below populate the persistent global Git configuration
at `/config/git/config`:

```yaml
git_user_name: "Your Name"
git_user_email: "you@example.com"
```

They may be left empty. Verify the effective configuration with:

```shell
git config --global --list
```

## GitHub over SSH

Paste a private key in the App's YAML configuration using a block scalar. The
App writes it to `/config/ssh/id_github` with mode `0600` and configures it for
`github.com`:

```yaml
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
ssh_public_key: "ssh-ed25519 AAAA... you@example.com"
```

GitHub's official Ed25519, ECDSA, and RSA host keys are included in the image.
Host-key verification remains enabled. Add keys for other Git servers with
`ssh_known_hosts`, or provide advanced OpenSSH client settings with
`ssh_client_config`.

Test GitHub SSH access and Git operations:

```shell
ssh -T git@github.com
git clone git@github.com:owner/repository.git
git -C repository fetch
git -C repository pull
git -C repository push
```

An encrypted private key is supported, but OpenSSH will request its passphrase
when the key is used unless you start and populate an `ssh-agent` yourself.

## GitHub CLI

For headless use, set `github_token` in the App configuration. At startup it is
written with mode `0600` under the ephemeral `/run` directory and exposed to
interactive shells as `GH_TOKEN`. The value is never printed by the startup
script and is not duplicated in `/config`.

Alternatively, leave the option empty and run `gh auth login` interactively;
the resulting GitHub CLI configuration persists in `/config/gh`.

For a fine-grained personal access token, select only the repositories Codex
must access. A practical baseline is:

- **Metadata:** read-only (mandatory for fine-grained tokens)
- **Contents:** read/write when API-based content or release changes are needed
- **Pull requests:** read/write
- **Issues:** read/write only if issue listing/commenting is required

Git pushes over SSH use the SSH key, not the GitHub token. Test the CLI with:

```shell
gh auth status
gh repo view
gh issue list
gh pr list
gh pr view 123
gh pr diff 123
```

Commands such as `gh pr create`, `gh pr comment`, and `gh api` require the
corresponding repository permissions.

## Additional Debian packages

Packages listed in `packages` are checked on every start. Only missing packages
are installed:

```yaml
packages:
  - cmake
  - sqlite3
  - shellcheck
  - ffmpeg
```

An invalid name or an APT failure stops startup with a clear error. Codex can
also run `apt` directly as root. Packages installed manually disappear when
the container is recreated; packages in this option are reinstalled.

## Persistence

The App deliberately keeps `/root` ephemeral and separates persistent state:

- `/config/codex`: Codex configuration, login cache, history, state, and the
  persistent managed standalone installation
- `/config/code-server`: settings, workspace state, and user-installed
  extensions
- `/config/ssh`: SSH client/server keys, authorized keys, and configuration
- `/config/gh`: GitHub CLI configuration created by interactive login
- `/config/git`: global Git configuration
- `/config/shell`: Bash history
- `/work`: symlink to the App-private persistent `/data/work` directory

`/config` uses Home Assistant's supported `addon_config` mapping. `/work` uses
the App's private `/data` volume and survives restarts, updates, and container
recreation. Both areas are included in Home Assistant App backups; large Git
repositories can therefore increase backup size.

The root filesystem, `/run`, and packages installed manually are not
persistent. Home Assistant retains `/data/options.json`, including configured
secret options, as part of the App data.

## Diagnostics and health checks

Startup logs report the Codex version and standalone path, code-server version,
Codex extension version, SSH status, and Remote Control daemon status. They do
not print tokens, credentials, pairing codes, or private keys.

Run the detailed local check from either terminal:

```shell
codex-app-health
```

It reports independent JSON statuses for the Ingress gateway, code-server,
fallback console, Codex standalone install, SSH configuration, and Remote
Control daemon. The container `HEALTHCHECK` probes only the Ingress gateway at
`/healthz`; an extension failure or a restarting code-server therefore does
not make the whole App unhealthy or remove the recovery console.

## Additional mounts

Home Assistant mappings are declared statically in `config.yaml`; App options
cannot create arbitrary Docker bind mounts at runtime. This V1 therefore does
not expose a misleading `mounts` option and does not mount Home Assistant's
configuration, `share`, `media`, devices, or Docker socket.

If a future version needs a supported `share` or `media` mapping, it must be
added explicitly to the App manifest with a fixed access mode and container
path. Arbitrary host paths remain unsupported by Home Assistant Apps.

## SSH server and reverse forwarding

Remote SSH login is key-only. Add one or more public keys:

```yaml
ssh_authorized_keys:
  - "ssh-ed25519 AAAA... mac@example"
ssh_allow_tcp_forwarding: true
```

Then open the App's **Network** section and map container port `22/tcp` to an
unused host port, for example `2222`. Without a port mapping, the server is not
reachable from the LAN. Password login is always disabled.

To expose a service listening only on port 8765 of a Mac to the Codex
container, run this on the Mac:

```shell
ssh -p 2222 -N \
  -R 127.0.0.1:8765:127.0.0.1:8765 \
  root@HOME_ASSISTANT_IP
```

Codex inside the App can then connect to `127.0.0.1:8765`. `GatewayPorts` is
disabled, so the reverse-forwarded listener is not exposed beyond the
container. This only prepares the tunnel; Fusion 360 and MCP configuration are
outside the scope of this version.

## Security model

Codex runs as root and has outbound network access inside its dedicated
container. It can use APT, Git, GitHub CLI, SSH, `/config`, and `/work`.

The App does **not** request privileged mode, Docker API/socket access, host
networking, host devices, Home Assistant configuration, Home Assistant API, or
Supervisor API access. The Ingress terminal is limited to Home Assistant
administrators.

## Maintainer release process

`codex/config.yaml` is the single source of truth for the App version. Before
merging an image-affecting change, bump that version and update
`codex/CHANGELOG.md`. The GitHub Actions workflow reads the same manifest,
builds the per-architecture images, and publishes the generic multiarchitecture
manifest plus `latest`.

There is deliberately no Semantic Release configuration, independent Docker
version, or legacy `build.yaml` file.
