# Changelog

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
