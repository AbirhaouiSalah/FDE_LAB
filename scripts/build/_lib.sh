#!/usr/bin/env bash
# scripts/build/_lib.sh — helpers build communs. À sourcer.
set -euo pipefail

BUILD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_LIB_ROOT="$(cd "$BUILD_LIB_DIR/../.." && pwd)"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[build]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

build_detect_pm() {
  if [ -f pnpm-lock.yaml ]; then echo "pnpm"
  elif [ -f yarn.lock ]; then echo "yarn"
  elif [ -f bun.lockb ]; then echo "bun"
  elif [ -f package-lock.json ]; then echo "npm"
  else
    command -v pnpm >/dev/null 2>&1 && { echo "pnpm"; return; }
    command -v yarn >/dev/null 2>&1 && { echo "yarn"; return; }
    command -v bun  >/dev/null 2>&1 && { echo "bun";  return; }
    command -v npm  >/dev/null 2>&1 && { echo "npm";  return; }
    die "aucun package manager détecté"
  fi
}

build_require_node() {
  command -v node >/dev/null 2>&1 || die "node introuvable"
  local major
  major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$major" -ge 20 ] || die "Node >= 20 requis (actuel: $(node -v))"
}

build_require_deps() {
  if [ ! -d node_modules ]; then
    warn "node_modules absent — installation"
    case "$(build_detect_pm)" in
      pnpm) pnpm install ;;
      yarn) yarn install ;;
      bun)  bun install ;;
      npm)  npm install ;;
    esac
  fi
}
