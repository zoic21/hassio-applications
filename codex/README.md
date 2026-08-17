# Codex Home Assistant App

Run code-server and the official OpenAI Codex tooling in an isolated Debian 13
development environment through Home Assistant Ingress.

The main interface provides Explorer, editing, search, Source Control, an
integrated terminal, and the experimental official Codex extension. The V1
ttyd root console remains available independently as a recovery interface.

The App also includes the managed standalone Codex CLI required by Remote
Control, Git, GitHub CLI, OpenSSH client/server, Node.js, Python, common
development tools, persistent Codex/code-server configuration, and a
persistent `/work` directory.

See [DOCS.md](DOCS.md) for installation, authentication, GitHub, SSH, package,
storage, and security instructions. See
[V1_5_VALIDATION.md](V1_5_VALIDATION.md) for the experimental compatibility
matrix and the exact HAOS/mobile validation protocol.
