# Third-party notices

This App installs software from Debian, the official GitHub CLI repository,
and the official OpenAI Codex standalone release service. Their package
metadata and license files remain in the image.

The App redistributes the pinned code-server release from
<https://github.com/coder/code-server>. code-server is licensed under the MIT
License; its license is copied from the release archive to
`/usr/share/doc/code-server/copyright` in the image.

The official OpenAI Codex extension is downloaded as an unmodified,
target-specific VSIX from the Visual Studio Marketplace during the image build.
Its bundled `LICENSE.md` remains alongside the extension in the image. The App
does not publish or modify the VSIX in this source repository.

The App redistributes the static `ttyd` 1.7.7 binary from
<https://github.com/tsl0922/ttyd>. `ttyd` is licensed under the MIT License;
its license is included in `third_party/ttyd-LICENSE` and copied to
`/usr/share/doc/ttyd/copyright` in the image.

The terminal startup approach is informed by Home Assistant's official
Terminal & SSH App, licensed under Apache License 2.0. No source file from that
App is copied into this repository.
