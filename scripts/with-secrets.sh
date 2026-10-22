#!/usr/bin/env bash
# Runs a command with the secrets declared in secretspec.toml, and nothing else from your shell: wrangler dev
# (with CLOUDFLARE_INCLUDE_PROCESS_ENV) binds every environment variable it sees as a Worker secret.
set -euo pipefail
cd "$(dirname "$0")/.."
exec secretspec run -- bash -c '
  keep=(PATH="$PATH" HOME="$HOME" TERM="${TERM:-dumb}" CLOUDFLARE_INCLUDE_PROCESS_ENV=true)
  for k in $(sed -n "s/^\([A-Z_][A-Z0-9_]*\) = .*/\1/p" secretspec.toml); do
    [ -n "${!k:-}" ] && keep+=("$k=${!k}")
  done
  exec env -i "${keep[@]}" "$@"
' with-secrets "$@"
