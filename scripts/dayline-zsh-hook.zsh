# Dayline zsh integration. Source this file only after building dayline-mac-context.
# It records completed command metadata, never stdout, stderr, or individual keystrokes.

zmodload zsh/datetime

typeset -g DAYLINE_COMMAND_STARTED_AT=""
typeset -g DAYLINE_COMMAND_TEXT=""
typeset -g DAYLINE_COMMAND_CWD=""

_dayline_preexec() {
  DAYLINE_COMMAND_STARTED_AT="$EPOCHREALTIME"
  DAYLINE_COMMAND_TEXT="$1"
  DAYLINE_COMMAND_CWD="$PWD"
}

_dayline_precmd() {
  local exit_code="$?"
  local completed_at="$EPOCHREALTIME"
  local collector="${DAYLINE_MAC_CONTEXT_BIN:-}"
  if [[ -z "$collector" || -z "$DAYLINE_COMMAND_STARTED_AT" ]]; then
    return
  fi

  DAYLINE_COMMAND="$DAYLINE_COMMAND_TEXT" \
    DAYLINE_CWD="$DAYLINE_COMMAND_CWD" \
    DAYLINE_EXIT_CODE="$exit_code" \
    DAYLINE_STARTED_AT="$DAYLINE_COMMAND_STARTED_AT" \
    DAYLINE_COMPLETED_AT="$completed_at" \
    python3 -c 'import datetime,json,os,sys
started=float(os.environ["DAYLINE_STARTED_AT"])
completed=float(os.environ["DAYLINE_COMPLETED_AT"])
json.dump({
  "command": os.environ["DAYLINE_COMMAND"],
  "cwd": os.environ["DAYLINE_CWD"],
  "exitCode": int(os.environ["DAYLINE_EXIT_CODE"]),
  "durationMilliseconds": max(0, int((completed-started)*1000)),
  "occurredAt": datetime.datetime.fromtimestamp(completed, datetime.timezone.utc).isoformat().replace("+00:00", "Z")
}, sys.stdout)' | "$collector" record-shell >/dev/null 2>&1

  DAYLINE_COMMAND_STARTED_AT=""
  DAYLINE_COMMAND_TEXT=""
  DAYLINE_COMMAND_CWD=""
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _dayline_preexec
add-zsh-hook precmd _dayline_precmd
