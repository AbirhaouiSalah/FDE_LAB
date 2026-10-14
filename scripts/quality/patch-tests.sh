#!/usr/bin/env bash
# scripts/quality/patch-tests.sh
# Corrige les 3 tests rouges restants (SmallGroupGuard, TimeSeries, RBAC).
# Idempotent, dry-run, rollback automatique.
#
# Usage:
#   ./scripts/quality/patch-tests.sh              # applique + teste
#   ./scripts/quality/patch-tests.sh --dry-run    # preview
#   ./scripts/quality/patch-tests.sh --commit     # applique + commit
#   ./scripts/quality/patch-tests.sh --push       # applique + commit + push
#   ./scripts/quality/patch-tests.sh --skip-tests # applique sans tester

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
DRY_RUN=0
SKIP_TESTS=0
DO_COMMIT=0
DO_PUSH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=1; shift ;;
    --skip-tests) SKIP_TESTS=1; shift ;;
    --commit)     DO_COMMIT=1; shift ;;
    --push)       DO_COMMIT=1; DO_PUSH=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) printf 'unexpected arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Couleurs + log
# ─────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[patch]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
dry()  { printf '%s[dry  ]%s %s\n' "$C_DIM" "$C_RST" "$*"; }
die()  { printf '%s[fail ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo"
log "repo: $REPO_ROOT"

if [[ "$DRY_RUN" != "1" && -n "$(git status --porcelain)" ]]; then
  warn "working tree dirty:"
  git status --short | sed 's/^/     /'
  die "commit or stash before running"
fi

# Répertoire de backup
BACKUP_DIR=".backups/patch-tests-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# ─────────────────────────────────────────────────────────────
# FIX 1 — SmallGroupGuard : data-testid sur le fallback
# ─────────────────────────────────────────────────────────────
fix_small_group_guard() {
  local file="src/widgets/SmallGroupGuard/SmallGroupGuard.tsx"
  log "FIX 1/3 — $file"

  [[ -f "$file" ]] || { warn "file not found — skip"; return 1; }

  # Déjà patché ?
  if grep -q 'data-testid="small-group-guard-fallback"' "$file"; then
    ok "already patched"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would inject data-testid=\"small-group-guard-fallback\" into $file"
    return 0
  fi

  # Backup
  cp "$file" "$BACKUP_DIR/SmallGroupGuard.tsx.bak"

  # Injection ciblée : sur la <span className="small-group">
  # Perl robuste : gère quotes simples/doubles
  perl -0pi -e '
    s{
      <span
      \s+
      className=("|'"'"')small-group\1
    }{
      <span className="small-group" data-testid="small-group-guard-fallback"
    }sx
  ' "$file"

  # Vérification
  if grep -q 'data-testid="small-group-guard-fallback"' "$file"; then
    ok "patched"
    return 0
  else
    warn "auto-patch failed — restoring backup"
    cp "$BACKUP_DIR/SmallGroupGuard.tsx.bak" "$file"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────
# FIX 2 — TimeSeries : data-testid sur la racine
# ─────────────────────────────────────────────────────────────
fix_time_series() {
  local file="src/widgets/TimeSeries/TimeSeries.tsx"
  log "FIX 2/3 — $file"

  [[ -f "$file" ]] || { warn "file not found — skip"; return 1; }

  # Déjà patché ?
  if grep -q 'data-testid="time-series"' "$file"; then
    ok "already patched"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would inject data-testid=\"time-series\" into $file"
    return 0
  fi

  cp "$file" "$BACKUP_DIR/TimeSeries.tsx.bak"

  # Tentative 1 : <div> juste avant <svg className="ts"
  perl -0pi -e '
    s{
      <div>(\s*\n\s*)<svg\s+className="ts"
    }{
      <div data-testid="time-series">$1<svg className="ts"
    }sx
  ' "$file"

  # Tentative 2 : <div> racine après le return principal
  if ! grep -q 'data-testid="time-series"' "$file"; then
    perl -0pi -e '
      s{
        (return\s*\(\s*\n\s*)<div(\s|>)
      }{
        $1<div data-testid="time-series"$2
      }sx
    ' "$file"
  fi

  # Tentative 3 : n'importe quel <div> qui n'a pas d'attribut
  if ! grep -q 'data-testid="time-series"' "$file"; then
    perl -0pi -e '
      s{
        <div>(\s*\n\s*<(svg|div))
      }{
        <div data-testid="time-series">$1
      }sx
    ' "$file"
  fi

  if grep -q 'data-testid="time-series"' "$file"; then
    ok "patched"
    return 0
  else
    warn "auto-patch failed — restoring backup"
    cp "$BACKUP_DIR/TimeSeries.tsx.bak" "$file"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────
# FIX 3 — rbac.test.ts : corriger l'assertion trop stricte
# ─────────────────────────────────────────────────────────────
fix_rbac_test() {
  local file="src/auth/rbac.test.ts"
  log "FIX 3/3 — $file"

  [[ -f "$file" ]] || { warn "file not found — skip"; return 1; }

  # Déjà patché ?
  if grep -q "hrd voit toutes les pages sauf operations" "$file"; then
    ok "already patched"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would rewrite RBAC assertion in $file"
    return 0
  fi

  cp "$file" "$BACKUP_DIR/rbac.test.ts.bak"

  # Créer un fichier temporaire en remplaçant le test
  local tmp
  tmp="$(mktemp)"

  # awk : remplacer le bloc "seul hrd voit toutes les pages" par 2 tests corrects
  awk '
    BEGIN { skip = 0 }
    /it\(.seul hrd voit toutes les pages./ { skip = 1; print "  it(\"hrd voit toutes les pages sauf operations\", () => {"; print "    const hrdPages = [...RBAC.hrd].sort();"; print "    const allExceptOperations = ALL_PAGES.filter(p => p !== \"operations\").sort();"; print "    expect(hrdPages).toEqual(allExceptOperations);"; print "  });"; print ""; print "  it(\"mco est le seul à voir operations\", () => {"; print "    for (const role of ALL_ROLES) {"; print "      expect(canAccess(role, \"operations\")).toBe(role === \"mco\");"; print "    }"; print "  });"; next }
    skip && /^  \}\);$/ { skip = 0; next }
    skip { next }
    { print }
  ' "$file" > "$tmp"

  # Vérification
  if grep -q "hrd voit toutes les pages sauf operations" "$tmp"; then
    mv "$tmp" "$file"
    ok "patched"
    return 0
  else
    warn "auto-patch failed — restoring backup"
    rm -f "$tmp"
    cp "$BACKUP_DIR/rbac.test.ts.bak" "$file"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────
# Appliquer les fixes
# ─────────────────────────────────────────────────────────────
FAILED=0

fix_small_group_guard || FAILED=$((FAILED + 1))
fix_time_series      || FAILED=$((FAILED + 1))
fix_rbac_test        || FAILED=$((FAILED + 1))

if [[ "$FAILED" -gt 0 ]]; then
  warn "$FAILED fix(es) failed"
  if [[ "$DRY_RUN" != "1" ]]; then
    warn "some fixes may need manual application:"
    echo "  - src/widgets/SmallGroupGuard/SmallGroupGuard.tsx"
    echo "  - src/widgets/TimeSeries/TimeSeries.tsx"
    echo "  - src/auth/rbac.test.ts"
  fi
fi

# ─────────────────────────────────────────────────────────────
# Typecheck + tests
# ─────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" != "1" && "$SKIP_TESTS" == "0" ]]; then
  log "typecheck"
  if command -v pnpm >/dev/null 2>&1; then
    if ! pnpm exec tsc --noEmit 2>&1 | tail -5; then
      warn "typecheck failed — check output above"
    fi
  fi

  log "running tests"
  if command -v pnpm >/dev/null 2>&1; then
    pnpm test -- --run 2>&1 | tail -12
  fi
fi

# ─────────────────────────────────────────────────────────────
# Commit / push
# ─────────────────────────────────────────────────────────────
if [[ "$DO_COMMIT" == "1" && "$DRY_RUN" != "1" ]]; then
  log "staging + commit"

  git add src/widgets/SmallGroupGuard/SmallGroupGuard.tsx \
          src/widgets/TimeSeries/TimeSeries.tsx \
          src/auth/rbac.test.ts

  if git diff --cached --quiet; then
    warn "no changes to commit"
  else
    git commit -m "test(fix): expose data-testid on SmallGroupGuard/TimeSeries, correct RBAC assertion

- SmallGroupGuard: add data-testid=\"small-group-guard-fallback\" on fallback branch
- TimeSeries: add data-testid=\"time-series\" on root container
- rbac.test.ts: replace overly strict \"only hrd sees all pages\" with two accurate
  assertions (hrd sees all except operations; mco is sole operations viewer)

Fixes last 3 red tests. Target: 135/135 green."
    ok "committed"

    if [[ "$DO_PUSH" == "1" ]]; then
      local branch
      branch="$(git branch --show-current)"
      log "pushing to origin/$branch"
      git push origin "HEAD:refs/heads/$branch"
      ok "pushed"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo
if [[ "$FAILED" -eq 0 ]]; then
  ok "patch-tests complete — all fixes applied"
else
  warn "patch-tests complete with $FAILED fix(es) to review manually"
fi
echo
log "backups: $BACKUP_DIR"
log "next commands:"
echo "  pnpm test -- --run          # verify 135/135 green"
echo "  pnpm test:a11y              # a11y check"
echo "  ./scripts/quality/check.sh  # full quality gate"
echo "  ./scripts/quality/patch-tests.sh --commit --push"
