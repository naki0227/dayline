# macOS context collection

## Privacy model

Terminal and Chrome collection are disabled by default and configured independently.
The collector is local-only: it writes v1 ContextEvents into the same Rust-owned
SQLite store used by Dayline. It never uploads them and never prints collected content.

- Terminal records the completed command, working directory, exit status, duration,
  and completion time. It does not record stdout, stderr, or individual keystrokes.
- Chrome reads URL, title, and last-visit time from the local `Default/History`
  database. Only `http` and `https` visits become events.
- Shell commands pass through Rust secret redaction before SQLite persistence.
- Both sources use 30-day retention and remain excluded from external output unless a
  separate, confirmed ActionProposal explicitly selects an artifact derived from them.

## Build and configure

```bash
make mac-agent-build
export DAYLINE_MAC_CONTEXT_BIN="$PWD/apps/MacContextAgent/.build/release/dayline-mac-context"

"$DAYLINE_MAC_CONTEXT_BIN" status
"$DAYLINE_MAC_CONTEXT_BIN" configure shell enabled
"$DAYLINE_MAC_CONTEXT_BIN" configure browser enabled
```

The policy file is created with mode `0600` below Application Support. Disabling a
source takes effect before the next read or persistence operation:

```bash
"$DAYLINE_MAC_CONTEXT_BIN" configure shell disabled
"$DAYLINE_MAC_CONTEXT_BIN" configure browser disabled
```

## Terminal hook

After setting `DAYLINE_MAC_CONTEXT_BIN`, add this to `.zshrc`:

```zsh
source /path/to/dayline/scripts/dayline-zsh-hook.zsh
```

The hook sends one JSON observation over stdin after each completed command. Command
content is never placed in the collector CLI arguments or its output.

## Chrome polling

Run this periodically with a user LaunchAgent or manually:

```bash
"$DAYLINE_MAC_CONTEXT_BIN" collect-chrome
```

The cursor starts one hour in the past and advances only after successful persistence.
macOS may require granting the invoking terminal or LaunchAgent Full Disk Access to
read Chrome history. Failures use finite category codes; paths, URLs, titles, command
content, and database error content are not logged.

`DAYLINE_DATA_DIRECTORY` and `DAYLINE_CHROME_HISTORY` are test/development overrides.
Production should leave them unset so the standard Application Support and Chrome
locations are used.
