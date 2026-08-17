# Codex App V1.5 validation

This document separates verified build/runtime facts from tests that require a
real Home Assistant OS instance, a signed-in ChatGPT account, and a paired
phone. Do not convert `NOT TESTED` to `PASS` without performing the recorded
procedure.

## Reproducible component matrix

| Component | Pinned version | Verification |
| --- | --- | --- |
| code-server | `4.132.0` | Official Coder release tarball and per-architecture SHA-256 |
| VS Code base | `1.132.0` | Reported by code-server `4.132.0` |
| Codex extension | `openai.chatgpt` `26.803.41515` | Official Marketplace target-specific VSIX and SHA-256 |
| Extension-bundled Codex | `0.147.0-alpha.6.5` | Read from the pinned Linux x64 VSIX binary |
| Standalone Codex | `0.147.0` | Official `https://chatgpt.com/codex/install.sh` with pinned installer digest |
| ttyd | `1.7.7` | Existing V1 static binaries and digests |

The default Docker build arguments are the source of truth for the exact
digests. The extension asset is not copied into this Git repository.

## Architecture findings

### Ingress and code-server

The current Home Assistant Studio Code Server App runs code-server directly
behind Ingress with `ingress_stream: true`, persistent user/extension
directories, `--auth none`, and WebSockets. V1.5 reuses those proven mechanics
without copying its Home Assistant/Supervisor permissions.

V1.5 adds a minimal Nginx gateway:

- `/` serves the two-link launcher;
- `/vscode/` proxies the URI unchanged to code-server on loopback;
- `/console/` proxies to the existing ttyd console on loopback;
- WebSocket upgrade headers are preserved for both upstreams.

code-server derives its base path from the incoming request. A local HTTP test
against the unmodified `4.132.0` tarball confirmed that requesting `/vscode/`
produces workbench, static, manifest, callback, and proxy URLs relative to that
prefix.

### Official extension process model

The pinned extension manifest identifies the official extension as
`openai.chatgpt`. Inspection of its unmodified bundle shows that activation
calls its own `startCodexProcess()` and spawns:

```text
codex -c features.code_mode_host=true app-server --analytics-default-enabled
```

The connection is JSONL over the spawned process's stdio. The only executable
override exposed by the manifest is `chatgpt.cliExecutable`, explicitly marked
development-only. No supported setting for connecting the official extension
to an already-running App Server was found.

### Standalone Remote Control process model

Current Codex exposes `remote-control start`, `pair`, and `stop`. `start`
ensures a managed App Server daemon is running from
`CODEX_HOME/packages/standalone/current/codex`. Current App Server also exposes
experimental `remoteControl/*` protocol methods, including enable, status,
pairing, device list, and revoke.

Therefore the V1.5 official extension and `codex remote-control start` use two
App Server processes. They share `/config/codex` (auth, configuration, MCP, and
session storage), but they do not share one live App Server connection.

### Known compatibility risks

- [`openai/codex#30398`](https://github.com/openai/codex/issues/30398) records
  code-server failures caused by proposed Chat Session APIs and the Node
  `navigator` migration.
- [`openai/codex#28726`](https://github.com/openai/codex/issues/28726) records
  sidebar freezes with newer extension/code-server combinations.
- [`openai/codex#37856`](https://github.com/openai/codex/issues/37856) uses the
  exact V1.5 extension and VS Code `1.132.0`; it shows that the extension can
  run in VS Code Web, but also records stale cross-client thread ownership.
- [`openai/codex#37403`](https://github.com/openai/codex/issues/37403) and
  [`openai/codex#37967`](https://github.com/openai/codex/issues/37967) record
  current live-thread writer/attachment conflicts between Remote Control and
  other Codex clients.
- [`openai/codex#23351`](https://github.com/openai/codex/issues/23351) records
  cases where locally persisted CLI/App Server threads are not indexed for
  later mobile resume.

These reports are evidence of risk, not a substitute for the HAOS/phone tests
below.

## Current result matrix

| Test | Result before HAOS/mobile validation | Evidence |
| --- | --- | --- |
| Home Assistant Ingress → code-server | NOT TESTED | Requires HAOS Ingress |
| VS Code terminal | NOT TESTED | Requires browser workbench |
| File editing | NOT TESTED | Requires browser workbench |
| Git UI | NOT TESTED | Requires browser workbench |
| Multiple repositories | NOT TESTED | Manual workspace procedure below |
| Codex CLI | BUILD CHECK | Docker build verifies version and managed path |
| Codex authentication | NOT TESTED | Requires user login |
| Codex extension loads | NOT TESTED | VSIX identity/integrity verified; activation needs browser |
| Codex extension conversation | NOT TESTED | Requires user login and browser |
| Codex MCP | NOT TESTED | Requires configured MCP servers |
| Remote Control start | NOT TESTED | Command/help checked at build; start requires login/network |
| Remote Control pairing | NOT TESTED | Requires account and phone |
| ChatGPT mobile sees session | NOT TESTED | Requires paired phone |
| Same thread VS Code ↔ mobile | NOT TESTED | Highest-risk test; exact protocol below |
| SSH | BUILD CHECK | `sshd -t` runs at every start |
| Reverse SSH capability | CONFIGURED | Key-only SSH and loopback-only `AllowTcpForwarding` retained |
| Persistence after restart | NOT TESTED | Requires App restart/recreation on HAOS |

`BUILD CHECK` becomes `PASS` only after the multi-architecture image build
succeeds. `CONFIGURED` means the implementation is present but the network path
was not exercised.

## HAOS validation procedure

### 1. Startup and independent services

1. Update/install the App and capture startup logs.
2. Confirm the reported Codex, standalone path, code-server, extension, SSH,
   and Remote Control status lines contain no secret values.
3. Run `codex-app-health` in the fallback console.
4. Open VS Code, then stop only code-server from the console for a controlled
   restart test. Confirm the gateway and fallback console remain available and
   code-server is restarted by its supervisor.

### 2. VS Code Web and Git

1. Open `/work`, create/edit/save a file, search for its content, and reopen it.
2. In the integrated terminal, run `pwd`, `codex --version`, `git --version`,
   `gh --version`, and `ssh -V`. `pwd` must be `/work`.
3. Clone or use two test repositories and one non-Git directory.
4. Create `/work/v15-test.code-workspace`:

   ```json
   {
     "folders": [
       { "path": "/work/repo1" },
       { "path": "/work/repo2" },
       { "path": "/work/docs" }
     ]
   }
   ```

5. Open that workspace. Confirm both repositories appear independently in
   Source Control and new terminals start in the selected folder.
6. Exercise `git status`, `git diff`, `git pull`, and a disposable commit/push.
7. Exercise `gh auth status`, `gh repo view`, and `gh pr list`.

### 3. Codex extension and MCP

1. Confirm `openai.chatgpt@26.803.41515` in the Extensions view.
2. Sign in with the same ChatGPT account/workspace used on the phone.
3. Create a conversation, request a harmless file edit, approve it, inspect the
   diff, and send a follow-up in the same thread.
4. Run `pgrep -af 'codex.*app-server'` and retain the output. The extension is
   expected to have its own stdio App Server process.
5. Run `codex mcp list`, exercise one configured MCP tool, restart the App, and
   confirm the same MCP remains configured.

### 4. Remote Control

From the fallback console:

```shell
codex login status
codex remote-control start
codex remote-control pair
codex app-server daemon version --json
```

Pair ChatGPT mobile using the displayed short-lived mechanism. Confirm the
phone can start a disposable task, display progress, receive an approval,
approve a harmless command, display the result/diff, and send a follow-up.
No router/NAT port should be opened.

### 5. Exact same-thread test

Use unique markers so two similar-looking conversations cannot be confused.

1. In the VS Code extension, create a thread titled or prompted with
   `V15-VSCODE-TO-MOBILE-<timestamp>` and make one harmless committed or
   uncommitted file change.
2. Leave the VS Code window connected. On mobile, refresh Remote and look for
   that exact thread. Record whether it is absent, read-only, blocked by an
   active writer, or fully interactive.
3. If visible, send a phone follow-up that creates a second uniquely named
   file and force one approval request. Verify the approval and resulting file
   in both mobile and VS Code.
4. Send another follow-up from VS Code. Record any ownership/reconnect error
   verbatim.
5. Close the VS Code tab/window, repeat mobile continuation, then reopen VS
   Code and try to continue the same exact thread.
6. Repeat in reverse with `V15-MOBILE-TO-VSCODE-<timestamp>` created from
   mobile.

A thread is `PASS` only if its exact prior messages, changes, approvals, and
new follow-ups remain in one thread in both directions. Merely seeing the same
project or files is not session sharing.

## Decision rule

- Choose **Architecture A** only if the pinned extension remains responsive and
  the exact same-thread test passes in both directions across restarts.
- Choose **Architecture B** if code-server, Git, terminal, and Remote Control
  work but the official extension is unstable or cannot share the Remote
  Control daemon/thread. Current source inspection and open issues make this
  the leading hypothesis. A small future extension could connect to one
  managed App Server and use its `remoteControl/*` APIs.
- Choose **Architecture C** only if code-server itself fails the Ingress,
  WebSocket, editing, terminal, Git, or mobile-display tests. An extension-only
  failure is not evidence against code-server.
