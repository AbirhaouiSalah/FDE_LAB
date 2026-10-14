#!/usr/bin/env bash
# scripts/ci/_lib.sh — helpers CI communs. À sourcer.
set -euo pipefail

CI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CI_LIB_ROOT="$(cd "$CI_LIB_DIR/../.." && pwd)"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[ci   ]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }
