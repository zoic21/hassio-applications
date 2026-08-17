# Changelog

## 0.2.0

- Add pinned code-server as the main browser IDE through Home Assistant Ingress.
- Bundle the pinned official `openai.chatgpt` Codex extension as an experimental
  integration.
- Keep the V1 ttyd terminal as an independent fallback console.
- Add a minimal launcher and WebSocket-capable Nginx gateway for VS Code and
  Console routes.
- Persist code-server settings and user-installed extensions under `/config`.
- Migrate the legacy standalone Codex directory link to a real persistent
  managed installation required by Remote Control.
- Add separate component health diagnostics and restart code-server without
  taking down the fallback console.
- Document the exact HAOS, Git, MCP, Remote Control, mobile, and same-thread
  validation protocol.

## 0.1.2

- Replace the npm Codex package with the official managed standalone install.
- Enable `codex remote-control start` without downloading Codex at runtime.

## 0.1.1

- Fix startup when Debian creates an empty `/root/.ssh` directory in the image.
- Safely replace empty image directories with persistent storage symlinks.

## 0.1.0

- Initial experimental release.
- Add Debian 13 development environment with OpenAI Codex CLI and GitHub CLI.
- Add ttyd Web terminal through Home Assistant Ingress.
- Add persistent `/config` and `/work` storage.
- Add optional Debian packages, Git identity, GitHub token, SSH client keys,
  authorized keys, and TCP forwarding.
- Add amd64 and aarch64 GHCR builds.
