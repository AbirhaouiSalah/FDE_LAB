#!/usr/bin/env bash
# scripts/quality/_lib.sh — helpers qualité communs. À sourcer.
set -euo pipefail

Q_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Q_LIB_ROOT="$(cd "$Q_LIB_DIR/../.." && pwd)"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[q    ]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

q_pm() {
  if [ -f "$Q_LIB_ROOT/pnpm-lock.yaml" ]; then echo pnpm; else echo npm; fi
}

q_exec() {
  case "$(q_pm)" in
    pnpm) pnpm exec "$@" ;;
    *)    npx "$@" ;;
  esac
}

q_run() {
  case "$(q_pm)" in
    pnpm) pnpm run "$@" ;;
    *)    npm run "$@" ;;
  esac
}
