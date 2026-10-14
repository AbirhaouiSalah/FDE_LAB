#!/usr/bin/env bash
# scripts/build/setup-toolchain.sh — installe la toolchain minimale si absente.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$BUILD_LIB_ROOT"

[ -f package.json ] || die "package.json introuvable"

if [ ! -d node_modules ]; then
  log "Installation des dépendances…"
  case "$(build_detect_pm)" in
    pnpm) pnpm install ;;
    yarn) yarn install ;;
    bun)  bun install ;;
    npm)  npm install ;;
  esac
fi
ok "Toolchain prête"
