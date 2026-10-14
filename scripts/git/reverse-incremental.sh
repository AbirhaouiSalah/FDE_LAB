#!/usr/bin/env bash
# scripts/git/reverse-incremental.sh
# Reconstruit main par fusion incrémentale des branches ats-lab/*.
# Usage: bash reverse-incremental.sh [--yes] [--force]

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

APPLY=0; FORCE=0
for a in "$@"; do
  case "$a" in
    --yes|-y) APPLY=1 ;;
    --force)  FORCE=1 ;;
  esac
done

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_BRANCH="backup/main-before-reverse-${TS}"
TMP_BRANCH="reverse-tmp-${TS}"

ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[!!] %s\n' "$*" >&2; }
bad()  { printf '[KO] %s\n' "$*" >&2; }
hdr()  { printf '\n=== %s ===\n' "$*"; }

hdr "0. Contexte"
echo "repo   : $(pwd)"
echo "mode   : $([ $APPLY -eq 1 ] && echo EXECUTE || echo DRY-RUN)"

[ -d .git ] || { bad "pas un dépôt git"; exit 1; }
[ -z "$(git status --porcelain)" ] || { bad "working tree non propre"; git status --short | /usr/bin/head -10; exit 1; }
ok "working tree propre"

hdr "1. Backup de main"
if [ "$APPLY" -eq 1 ]; then
  git branch "$BACKUP_BRANCH" main 2>/dev/null || true
  git push origin "$BACKUP_BRANCH" 2>/dev/null && ok "origin/$BACKUP_BRANCH" || warn "push backup échoué"
else
  echo "[dry] créerait $BACKUP_BRANCH"
fi

hdr "2. Branches ats-lab/*"
BRANCHES=()
while IFS= read -r b; do [ -n "$b" ] && BRANCHES+=("$b"); done < <(git ls-remote --heads origin 'refs/heads/ats-lab/*' | awk -F'refs/heads/' '{print $2}' | sort -u)
echo "${#BRANCHES[@]} branche(s)"

hdr "3. Branche temporaire $TMP_BRANCH"
if [ "$APPLY" -eq 1 ]; then
  git checkout main 2>/dev/null || { bad "checkout main échoué"; exit 1; }
  git branch -D "$TMP_BRANCH" 2>/dev/null || true
  git checkout -b "$TMP_BRANCH"
  ok "sur $TMP_BRANCH"
fi

hdr "4. Fusion incrémentale"
MERGED=0; FAILED=0; FAILED_LIST=()
for b in "${BRANCHES[@]}"; do
  [ "$b" = "ats-lab/main" ] && continue
  git rev-parse --verify "origin/$b" >/dev/null 2>&1 || { warn "$b introuvable"; FAILED=$((FAILED+1)); FAILED_LIST+=("$b"); continue; }
  if [ "$APPLY" -eq 1 ]; then
    if git -c user.name="${GIT_NAME:-AbirhaouiSalah}" \
          -c user.email="${GIT_EMAIL:-sabirhaouipro@gmail.com}" \
          merge --no-ff --allow-unrelated-histories -X theirs \
          -m "reverse: inject $b into main [skip ci]" "origin/$b" >/dev/null 2>&1; then
      ok "  ✅ $b"; MERGED=$((MERGED+1))
    else
      warn "  ⚠️  $b conflit → abort"; git merge --abort 2>/dev/null || true
      FAILED=$((FAILED+1)); FAILED_LIST+=("$b")
    fi
  else
    echo "  [dry] git merge -X theirs origin/$b"; MERGED=$((MERGED+1))
  fi
done

hdr "5. Bascule main"
if [ "$APPLY" -eq 1 ]; then
  if [ "$MERGED" -gt 0 ]; then
    git checkout main 2>/dev/null
    if [ "$FORCE" -eq 1 ]; then
      git reset --hard "$TMP_BRANCH"; ok "main = $TMP_BRANCH (--hard)"
    else
      git merge --ff-only "$TMP_BRANCH" && ok "ff vers $TMP_BRANCH" \
        || { bad "ff impossible — utiliser --force"; exit 1; }
    fi
    git push origin main && ok "push origin/main" || warn "push main échoué"
    git branch -D "$TMP_BRANCH" 2>/dev/null || true
  else
    warn "rien fusionné"; git checkout main 2>/dev/null || true
    git branch -D "$TMP_BRANCH" 2>/dev/null || true
  fi
fi

hdr "6. Résumé"
echo "merged  : $MERGED"
echo "failed  : $FAILED"
[ "${#FAILED_LIST[@]}" -gt 0 ] && printf '  - %s\n' "${FAILED_LIST[@]}"
echo ""
echo "Backup : $BACKUP_BRANCH"
echo "Rollback : git reset --hard origin/$BACKUP_BRANCH && git push --force origin main"
