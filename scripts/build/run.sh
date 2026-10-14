#!/usr/bin/env bash
# scripts/build/run.sh — point d'entrée dev unifié.
# Délègue aux scripts quality/ pour lint/typecheck/test/a11y/check.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$BUILD_LIB_ROOT"

cmd="${1:-help}"; shift || true

case "$cmd" in
  install)   build_require_node; log "Installation via $(build_detect_pm)"; "$(build_detect_pm)" install; ok "deps OK" ;;
  dev)       build_require_node; build_require_deps; log "Vite dev…"; "$(build_detect_pm)" run dev ;;
  build)     build_require_node; build_require_deps; log "Build…"; "$(build_detect_pm)" run build; ok "dist/ prêt" ;;
  test)      exec "$BUILD_LIB_ROOT/scripts/quality/test-unit.sh" "$@" ;;
  lint)      exec "$BUILD_LIB_ROOT/scripts/quality/lint.sh" "$@" ;;
  typecheck) exec "$BUILD_LIB_ROOT/scripts/quality/typecheck.sh" "$@" ;;
  a11y)      exec "$BUILD_LIB_ROOT/scripts/quality/test-a11y.sh" "$@" ;;
  check)     exec "$BUILD_LIB_ROOT/scripts/quality/check.sh" "$@" ;;
  clean)     log "Nettoyage…"; rm -rf node_modules dist coverage .vite; ok "clean OK" ;;
  help|-h|--help)
    cat <<USAGE
scripts/build/run.sh — point d'entrée dev

  install              Installe les dépendances
  dev                  Vite dev
  build                Build production → dist/
  test [pattern]       Vitest (délègue à quality/test-unit.sh)
  lint [--fix]         ESLint (délègue à quality/lint.sh)
  typecheck            tsc --noEmit (délègue à quality/typecheck.sh)
  a11y                 Tests a11y (délègue à quality/test-a11y.sh)
  check                Check complet (délègue à quality/check.sh)
  clean                Supprime node_modules, dist, coverage

PM   : $(build_detect_pm)
Node : $(node -v 2>/dev/null || echo absent)
USAGE
    ;;
  *) die "commande inconnue: $cmd" ;;
esac
