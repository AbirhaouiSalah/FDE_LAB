bash <<'OUTER'

cd ~/Applications/workspace/fde_lab/FDE_LAB || { echo "cd failed"; exit 1; }

write_lot() {
  local n="$1" name="$2" branch="$3" pivot="$4" files="$5" msg="$6"
  local target="scripts/lots/build-lot-${n}.sh"

  cat > "$target" <<LOT_HEADER
#!/usr/bin/env bash
# scripts/lots/build-lot-${n}.sh — L${n} ${name}
source "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

LOT_ID="L${n}"; LOT_TAG="\${LOT_ID}"; export LOT_TAG
LOT_BRANCH="${branch}"
LOT_NAME="${name}"
LOT_FILES="${files}"
COMMIT_MSG="${msg}"

parse_common_flags "\$@" || true

if command -v check_prereqs >/dev/null 2>&1; then check_prereqs || true; else require_repo_root || true; fi
ensure_branch "\${LOT_BRANCH}" || true

log_init "\${LOT_ID}"
log_step "\${LOT_ID} — \${LOT_NAME}"
log_dim "branche : \${LOT_BRANCH}"
log_dim "files   : \${LOT_FILES}"
log_dim "mode    : \$( [ "\${DRY_RUN}" = "1" ] && echo DRY-RUN || echo APPLY )"

# ═══════════════════════════════════════════════════════════════════════════
# Fichiers du lot — AJOUTER LES write_file ICI
# ═══════════════════════════════════════════════════════════════════════════
# Exemple :
# write_file "\${LOT_FILES}/exemple.ts" <<'FILEEOF'
# ... contenu ...
# FILEEOF

FILES_WRITTEN="\$(git -C "\$REPO_ROOT" status --porcelain "\${LOT_FILES}" 2>/dev/null | wc -l | tr -d ' ')"
lot_summary "\${LOT_ID}" "\${FILES_WRITTEN:-0}" ""
log_ok "\${LOT_ID} — complete"
LOT_HEADER

  chmod +x "$target"
  lines=$(wc -l < "$target" | tr -d ' ')
  echo "✅ $target : $lines lignes"
}

write_lot 1 "Fondations — api + rbac + i18n + server" \
  "ats-lab/feat/api/contracts" \
  "ats-lab/feat/api/contracts" \
  "src/api/ src/auth/ src/i18n/ server/" \
  "feat(L1): foundations"

write_lot 4 "Shell & Routing" \
  "ats-lab/comp/shell/app-shell" \
  "ats-lab/comp/shell/app-shell" \
  "src/app/ src/styles/" \
  "feat(L4): shell & routing"

write_lot 5 "Pages" \
  "ats-lab/comp/overview/page" \
  "ats-lab/comp/overview/page" \
  "src/pages/" \
  "feat(L5): pages"

write_lot 6 "Données de démo" \
  "ats-lab/docs/spec/dashboard" \
  "ats-lab/docs/spec/dashboard" \
  "src/mock/ docs/" \
  "feat(L6): mock data"

write_lot 7 "CI/CD & Qualité" \
  "ats-lab/chore/ci/frontend-pipeline" \
  "ats-lab/chore/ci/frontend-pipeline" \
  ".github/workflows/ scripts/quality/" \
  "chore(L7): ci/cd"

echo ""
echo "═══ Vérification syntaxe ═══"
for f in scripts/lots/build-lot-*.sh; do
  if bash -n "$f" 2>/dev/null; then
    echo "  ✅ $f"
  else
    echo "  ❌ $f"
    bash -n "$f" 2>&1 | head -2 | sed 's/^/     /'
  fi
done

echo ""
echo "═══ Tailles ═══"
wc -l scripts/lots/build-lot-*.sh

OUTER