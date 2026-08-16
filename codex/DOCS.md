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

The Web UI is a root shell in the App container. It starts in `/work`; run
`codex` to launch the Codex terminal interface.

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

## Codex remote control

The App embeds the official managed standalone Codex installation required by
remote control. After signing in, start it with:

```shell
codex remote-control start
```

The standalone release is linked into
`/config/codex/packages/standalone/current`, which is the fixed location used
by the remote-control daemon. No Codex download is needed during App startup.

## Codex permissions inside the container

The generated Codex configuration uses:

```toml
approval_policy = "on-request"
sandbox_mode = "danger-full-access"
```

This deliberately disables Codex's nested filesystem sandbox because the
dedicated container is already the isolation boundary. Approval prompts remain
enabled. You can change these values in `/config/codex/config.toml`.

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
  link to the image-managed standalone installation
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
