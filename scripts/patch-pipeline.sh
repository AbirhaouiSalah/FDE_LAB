#!/usr/bin/env bash
# scripts/patch-pipeline.sh
#
# Applique les 4 correctifs du pipeline CI en local :
#   1. Corrige validate-all.sh (--if-present mal placé)
#   2. Crée scripts/check-i18n-parity.ts (si absent)
#   3. Crée src/i18n/fr.json et en.json (si absents)
#   4. Vérifie la syntaxe de tous les scripts modifiés
#
# Usage:
#   ./scripts/patch-pipeline.sh              # dry-run (affiche ce qui serait fait)
#   ./scripts/patch-pipeline.sh --yes        # applique les correctifs
#   ./scripts/patch-pipeline.sh --verify     # vérifie l'état actuel
#   ./scripts/patch-pipeline.sh --help

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }

# ─── Options ───────────────────────────────────────────────────────────────
DRY_RUN=1
VERIFY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)  DRY_RUN=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --verify)  VERIFY_ONLY=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argument inconnu: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[patch]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }

MODE="APPLY"
[ "$DRY_RUN" -eq 1 ] && MODE="DRY-RUN"
[ "$VERIFY_ONLY" -eq 1 ] && MODE="VERIFY"

log "Mode: $MODE"
log "Répertoire: $ROOT_DIR"

# ─── VÉRIFICATION ──────────────────────────────────────────────────────────
verify() {
  sep
  echo "  VÉRIFICATION DE L'ÉTAT ACTUEL"
  sep
  echo ""

  local issues=0

  # Check 1: validate-all.sh existe et est exécutable
  echo "▶ scripts/validate-all.sh:"
  if [ -f scripts/validate-all.sh ]; then
    if [ -x scripts/validate-all.sh ]; then
      echo "  ✅ présent et exécutable"
    else
      echo "  ⚠️  présent mais non exécutable"
      issues=$((issues+1))
    fi
    # Détecter le bug --if-present
    if grep -q "PM_RUN.*--if-present" scripts/validate-all.sh 2>/dev/null; then
      echo "  ❌ contient --if-present mal placé"
      issues=$((issues+1))
    fi
  else
    echo "  ❌ ABSENT"
    issues=$((issues+1))
  fi
  echo ""

  # Check 2: scripts/check-i18n-parity.ts
  echo "▶ scripts/check-i18n-parity.ts:"
  if [ -f scripts/check-i18n-parity.ts ]; then
    echo "  ✅ présent"
  else
    echo "  ❌ ABSENT"
    issues=$((issues+1))
  fi
  echo ""

  # Check 3: src/i18n
  echo "▶ src/i18n/:"
  if [ -f src/i18n/fr.json ] && [ -f src/i18n/en.json ]; then
    echo "  ✅ fr.json + en.json présents"
  else
    [ ! -f src/i18n/fr.json ] && echo "  ❌ fr.json absent"
    [ ! -f src/i18n/en.json ] && echo "  ❌ en.json absent"
    issues=$((issues+1))
  fi
  echo ""

  # Check 4: package.json scripts
  echo "▶ package.json (scripts test:a11y, test:i18n):"
  if [ -f package.json ]; then
    grep -q '"test:a11y"' package.json && echo "  ✅ test:a11y" || echo "  ❌ test:a11y manquant"
    grep -q '"test:i18n"' package.json && echo "  ✅ test:i18n" || echo "  ❌ test:i18n manquant"
  else
    echo "  ❌ package.json ABSENT"
    issues=$((issues+1))
  fi
  echo ""

  # Check 5: tsx installé
  echo "▶ tsx (pour check-i18n-parity.ts):"
  if [ -d node_modules/.bin ] && [ -L node_modules/.bin/tsx ]; then
    echo "  ✅ tsx disponible"
  elif command -v tsx >/dev/null 2>&1; then
    echo "  ✅ tsx dans PATH"
  else
    echo "  ⚠️  tsx peut être manquant"
  fi
  echo ""

  sep
  if [ "$issues" -eq 0 ]; then
    ok "État actuel : tout est en ordre"
  else
    warn "$issues problème(s) détecté(s) — appliquer les correctifs"
  fi
  sep

  return $issues
}

if [ "$VERIFY_ONLY" -eq 1 ]; then
  verify || true
  exit 0
fi

# ─── CORRECTIF 1 : patch validate-all.sh ───────────────────────────────────
sep
echo "  CORRECTIF 1/4 : validate-all.sh"
sep
echo ""

if [ ! -f scripts/validate-all.sh ]; then
  err "scripts/validate-all.sh introuvable — skip"
else
  if grep -q "PM_RUN.*--if-present" scripts/validate-all.sh 2>/dev/null; then
    log "Bug --if-present détecté → patch nécessaire"

    if [ "$DRY_RUN" -eq 1 ]; then
      info "  [dry-run] aurait appliqué 4 remplacements :"
      info "    - \$PM_RUN lint --if-present  → \$PM_RUN --if-present lint"
      info "    - \$PM_RUN typecheck --if-present → \$PM_RUN --if-present typecheck"
      info "    - \$PM_RUN test --if-present -- → \$PM_RUN --if-present test --"
      info "    - \$PM_RUN build --if-present → \$PM_RUN --if-present build"
    else
      # Backup
      cp scripts/validate-all.sh scripts/validate-all.sh.bak

      # Remplacements
      sed -i '' 's|\$PM_RUN lint --if-present|$PM_RUN --if-present lint|g' scripts/validate-all.sh
      sed -i '' 's|\$PM_RUN typecheck --if-present|$PM_RUN --if-present typecheck|g' scripts/validate-all.sh
      sed -i '' 's|\$PM_RUN test --if-present -- |$PM_RUN --if-present test -- |g' scripts/validate-all.sh
      sed -i '' 's|\$PM_RUN build --if-present|$PM_RUN --if-present build|g' scripts/validate-all.sh

      # Vérifier qu'il n'en reste plus
      if grep -q "PM_RUN.*--if-present" scripts/validate-all.sh 2>/dev/null; then
        warn "  certaines occurrences restent :"
        grep -n "PM_RUN.*--if-present" scripts/validate-all.sh | sed 's/^/    /'
      else
        ok "  patché avec succès"
        info "  backup : scripts/validate-all.sh.bak"
      fi
    fi
  else
    ok "  déjà patché (pas de --if-present mal placé)"
  fi
fi
echo ""

# ─── CORRECTIF 2 : créer scripts/check-i18n-parity.ts ─────────────────────
sep
echo "  CORRECTIF 2/4 : scripts/check-i18n-parity.ts"
sep
echo ""

if [ -f scripts/check-i18n-parity.ts ]; then
  ok "  existe déjà"
else
  log "  absent → création"

  if [ "$DRY_RUN" -eq 1 ]; then
    info "  [dry-run] aurait créé scripts/check-i18n-parity.ts"
  else
    mkdir -p scripts
    cat > scripts/check-i18n-parity.ts <<'TS_EOF'
#!/usr/bin/env tsx
/**
 * scripts/check-i18n-parity.ts
 *
 * Vérifie que les clés i18n sont identiques entre FR et EN.
 * Exit 1 si des clés manquent d'un côté.
 */

import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const LOCALES = ['fr', 'en'] as const;
type Locale = typeof LOCALES[number];

function loadCatalog(locale: Locale): Record<string, string> {
  const path = resolve(ROOT, 'src', 'i18n', `${locale}.json`);
  try {
    return JSON.parse(readFileSync(path, 'utf-8'));
  } catch {
    console.error(`❌ Impossible de lire ${path}`);
    process.exit(1);
  }
}

const catalogs = Object.fromEntries(
  LOCALES.map((l) => [l, loadCatalog(l)])
) as Record<Locale, Record<string, string>>;

const allKeys = new Set<string>();
for (const l of LOCALES) {
  for (const k of Object.keys(catalogs[l])) allKeys.add(k);
}

let hasError = false;
const missing: Record<Locale, string[]> = { fr: [], en: [] };

for (const key of allKeys) {
  for (const l of LOCALES) {
    if (!(key in catalogs[l])) {
      missing[l].push(key);
      hasError = true;
    }
  }
}

if (!hasError) {
  console.warn(`✅ i18n parity OK (${allKeys.size} clés, ${LOCALES.length} locales)`);
  process.exit(0);
}

console.error('❌ i18n parity BROKEN');
for (const l of LOCALES) {
  if (missing[l].length > 0) {
    console.error(`\n  Clés manquantes dans ${l}.json :`);
    for (const k of missing[l]) console.error(`    - ${k}`);
  }
}
process.exit(1);
TS_EOF
    chmod +x scripts/check-i18n-parity.ts
    ok "  créé (1616 octets)"
  fi
fi
echo ""

# ─── CORRECTIF 3 : créer src/i18n/fr.json et en.json ─────────────────────
sep
echo "  CORRECTIF 3/4 : src/i18n/"
sep
echo ""

mkdir -p src/i18n

if [ -f src/i18n/fr.json ]; then
  ok "  fr.json existe"
else
  log "  fr.json absent → création"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "  [dry-run] aurait créé src/i18n/fr.json"
  else
    cat > src/i18n/fr.json <<'JSON_EOF'
{
  "app.title": "Copilote ATS",
  "kpi.median_handling_time": "Temps de traitement médian",
  "common.refresh": "Dernière mise à jour",
  "common.loading": "Chargement…",
  "common.error": "Erreur",
  "common.empty": "Aucune donnée",
  "nav.overview": "Vue d'ensemble",
  "nav.pipeline": "Pipeline",
  "nav.queue": "File d'attente",
  "nav.quality": "Qualité",
  "nav.fairness": "Équité",
  "nav.operations": "Opérations",
  "nav.governance": "Gouvernance",
  "nav.rubric": "Grille d'évaluation",
  "smallgroup.hidden": "n<5",
  "smallgroup.tooltip": "Groupe trop petit pour être affiché (RGPD)"
}
JSON_EOF
    ok "  fr.json créé"
  fi
fi

if [ -f src/i18n/en.json ]; then
  ok "  en.json existe"
else
  log "  en.json absent → création"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "  [dry-run] aurait créé src/i18n/en.json"
  else
    cat > src/i18n/en.json <<'JSON_EOF'
{
  "app.title": "ATS Copilot",
  "kpi.median_handling_time": "Median handling time",
  "common.refresh": "Last refresh",
  "common.loading": "Loading…",
  "common.error": "Error",
  "common.empty": "No data",
  "nav.overview": "Overview",
  "nav.pipeline": "Pipeline",
  "nav.queue": "Queue",
  "nav.quality": "Quality",
  "nav.fairness": "Fairness",
  "nav.operations": "Operations",
  "nav.governance": "Governance",
  "nav.rubric": "Evaluation rubric",
  "smallgroup.hidden": "n<5",
  "smallgroup.tooltip": "Group too small to display (GDPR)"
}
JSON_EOF
    ok "  en.json créé"
  fi
fi
echo ""

# ─── CORRECTIF 4 : vérifier package.json ──────────────────────────────────
sep
echo "  CORRECTIF 4/4 : package.json (scripts)"
sep
echo ""

if [ ! -f package.json ]; then
  err "package.json introuvable"
else
  if grep -q '"test:i18n"' package.json && grep -q '"test:a11y"' package.json; then
    ok "  scripts test:i18n et test:a11y présents"
  else
    warn "  certains scripts manquent :"
    grep -q '"test:i18n"' package.json || echo "    - test:i18n"
    grep -q '"test:a11y"' package.json || echo "    - test:a11y"
  fi
fi
echo ""

# ─── VÉRIFICATION FINALE ──────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
  sep
  echo "  VÉRIFICATION POST-PATCH"
  sep
  echo ""

  # Test syntaxe validate-all.sh
  log "Test syntaxe validate-all.sh…"
  if bash -n scripts/validate-all.sh 2>/dev/null; then
    ok "  syntaxe OK"
  else
    err "  syntaxe cassée — restaure le .bak : cp scripts/validate-all.sh.bak scripts/validate-all.sh"
    exit 1
  fi

  # Test i18n parity
  log "Test i18n parity…"
  if command -v pnpm >/dev/null 2>&1; then
    if pnpm run test:i18n > /tmp/patch-i18n.log 2>&1; then
      ok "  i18n parity OK"
      grep -E "✅|OK" /tmp/patch-i18n.log | head_n 2 | sed 's/^/    /'
    else
      warn "  i18n parity KO :"
      tail -n 5 /tmp/patch-i18n.log | sed 's/^/    /'
    fi
  fi
  echo ""

  sep
  echo "  RÉSUMÉ"
  sep
  echo ""
  ok "Correctifs appliqués"
  info ""
  info "Prochaines étapes :"
  info "  1. ./scripts/validate-all.sh --quick    # tester rapidement"
  info "  2. ./scripts/validate-all.sh            # valider complètement"
  info "  3. Si tout est vert → git add + commit + push"
  echo ""
  sep
else
  sep
  warn "DRY-RUN — aucun changement appliqué"
  info ""
  info "Pour appliquer : ./scripts/patch-pipeline.sh --yes"
  info "Pour vérifier : ./scripts/patch-pipeline.sh --verify"
  sep
fi