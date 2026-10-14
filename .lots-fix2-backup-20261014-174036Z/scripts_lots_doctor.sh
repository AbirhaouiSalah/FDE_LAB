#!/usr/bin/env bash
# scripts/lots/doctor.sh — Diagnostic de l'infra scripts/lots.
# Vérifie : bash ≥ 4, shebangs, exécutabilité, sourcing, symétrie L1..L7.
# Sortie : rapport ligne par ligne, exit 0 si tout OK, 1 sinon.

set -uo pipefail   # volontairement sans -e : on veut tout tester

# Couleurs inline (on ne source pas _lib.sh : c'est ce qu'on diagnostique)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; Z=$'\033[0m'
else
  R=""; G=""; Y=""; B=""; D=""; Z=""
fi

ok()   { printf '%s✅%s %s\n' "$G" "$Z" "$*"; }
bad()  { printf '%s❌%s %s\n' "$R" "$Z" "$*"; }
warn() { printf '%s⚠️ %s %s\n' "$Y" "$Z" "$*"; }
info() { printf '%sℹ️ %s %s\n' "$B" "$Z" "$*"; }
dim()  { printf '%s   %s%s\n' "$D" "$*" "$Z"; }
head() { printf '\n%s── %s ──%s\n' "$B" "$*" "$Z"; }

ISSUES=0
FIXES=()
add_issue() { ISSUES=$((ISSUES+1)); }
add_fix()   { FIXES+=("$1"); }

# ─── 0. Localisation ───────────────────────────────────────────────────────
DOCTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${DOCTOR_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

head "0. Contexte"
info "repo  : $REPO_ROOT"
info "bash  : $(command -v bash) — $(bash --version | head -1)"

# ─── 1. Bash ≥ 4 ───────────────────────────────────────────────────────────
head "1. Version bash"
BASH_BIN="$(command -v bash)"
BV_MAJOR="$("$BASH_BIN" -c 'echo "${BASH_VERSINFO[0]}"')"
if [[ "$BV_MAJOR" -ge 4 ]]; then
  ok "bash $BV_MAJOR ≥ 4 ($BASH_BIN)"
  dim "declare -A, ${var,,}, etc. supportés"
else
  bad "bash $BV_MAJOR < 4 ($BASH_BIN) — declare -A indisponible"
  add_issue
  add_fix "brew install bash && export PATH=\"/opt/homebrew/bin:\$PATH\""
  # Détecter un bash 4+ ailleurs
  for cand in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [[ -x "$cand" ]] && "$cand" -c '[[ "${BASH_VERSINFO[0]}" -ge 4 ]]'; then
      warn "bash ≥ 4 trouvé : $cand — utilisez BASH_BIN=$cand"
    fi
  done
fi

# ─── 2. Fichiers attendus ──────────────────────────────────────────────────
head "2. Fichiers attendus dans scripts/lots/"
EXPECTED=(
  _lib.sh build-all.sh doctor.sh push-lot.sh README.md
  build-lot-1.sh build-lot-2.sh build-lot-3.sh build-lot-4.sh
  build-lot-5.sh build-lot-6.sh build-lot-7.sh
)
for f in "${EXPECTED[@]}"; do
  if [[ -f "scripts/lots/$f" ]]; then
    ok "présent   : scripts/lots/$f"
  else
    if [[ "$f" == "doctor.sh" ]]; then
      warn "absent    : scripts/lots/$f (c'est ce script — normal au 1er run)"
    else
      bad "manquant  : scripts/lots/$f"
      add_issue
    fi
  fi
done

# ─── 3. Shebangs ───────────────────────────────────────────────────────────
head "3. Shebangs (doit être #!/usr/bin/env bash)"
for f in scripts/lots/*.sh; do
  [[ -f "$f" ]] || continue
  first="$(head -1 "$f")"
  if [[ "$first" == "#!/usr/bin/env bash" ]]; then
    ok "$(basename "$f")"
  elif [[ "$first" == "#!"* ]]; then
    bad "$(basename "$f") : '$first' (attendu '#!/usr/bin/env bash')"
    add_issue
    add_fix "sed -i '' '1s|.*|#!/usr/bin/env bash|' $f   # macOS"
  else
    bad "$(basename "$f") : pas de shebang"
    add_issue
  fi
done

# ─── 4. Exécutabilité ──────────────────────────────────────────────────────
head "4. Permissions exécutables"
for f in scripts/lots/*.sh; do
  [[ -f "$f" ]] || continue
  if [[ -x "$f" ]]; then
    ok "$(basename "$f")"
  else
    warn "non exécutable : $(basename "$f")"
    add_fix "chmod +x $f"
  fi
done

# ─── 5. Sourcing de _lib.sh ────────────────────────────────────────────────
head "5. Sourcing _lib.sh en tête des build-lot-N.sh"
for n in 1 2 3 4 5 6 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || { warn "L$n : absent"; continue; }
  # Cherche la ligne de source
  src_line="$(grep -n 'source.*_lib\.sh' "$f" | head -1 | cut -d: -f1 || true)"
  if [[ -z "$src_line" ]]; then
    bad "L$n : aucun source _lib.sh trouvé"
    add_issue
    continue
  fi
  # Vérifie qu'aucune commande exécutable (hors shebang, set, commentaires) n'apparaît avant
  before="$(head -n "$((src_line-1))" "$f" | grep -vE '^\s*(#|$)' | grep -vE '^#!' | grep -vE '^\s*set ' || true)"
  if [[ -z "$before" ]]; then
    ok "L$n : source ligne $src_line, rien avant ✅"
  else
    warn "L$n : du code précède le source (ligne $src_line) :"
    printf '%s\n' "$before" | sed 's/^/      /'
    add_issue
    add_fix "déplacer 'source .../\\_lib.sh' en 1ère instruction de $f (après shebang + set)"
  fi
done

# ─── 6. Cohérence _lib.sh ──────────────────────────────────────────────────
head "6. _lib.sh — guards et filets"
LIB="scripts/lots/_lib.sh"
if [[ -f "$LIB" ]]; then
  grep -q 'BASH_VERSION' "$LIB" && ok "guard BASH_VERSION présent" || { bad "guard BASH_VERSION manquant"; add_issue; }
  grep -q 'BASH_VERSINFO' "$LIB" && ok "guard bash ≥ 4 présent"   || { bad "guard bash ≥ 4 manquant"; add_issue; }
  grep -q 'C_BLUE:=' "$LIB"     && ok "filet C_BLUE présent"      || { warn "filet couleurs absent (C_*:=)"; add_issue; }
  grep -q 'BASH_SOURCE\[0\]:-' "$LIB" && ok "fallback BASH_SOURCE présent" || { warn "fallback BASH_SOURCE absent"; add_issue; }
else
  bad "_lib.sh introuvable"
  add_issue
fi

# ─── 7. Cohérence build-all.sh ─────────────────────────────────────────────
head "7. build-all.sh — forçage bash"
BA="scripts/lots/build-all.sh"
if [[ -f "$BA" ]]; then
  if grep -qE '"\$BASH_BIN"\s+"\$\{?script' "$BA"; then
    ok "appel via \$BASH_BIN présent"
  elif grep -qE '^\s*if\s+"\$\{?script' "$BA"; then
    warn "appel direct '\"\${script}\"' détecté — peut casser si shebang invalide"
    add_fix "remplacer par : \"\$BASH_BIN\" \"\${script}\" \"\$@\""
    add_issue
  else
    info "pattern d'appel non reconnu, à vérifier manuellement"
  fi
else
  bad "build-all.sh introuvable"; add_issue
fi

# ─── 8. Dépendances outils ─────────────────────────────────────────────────
head "8. Outils externes"
for tool in git mktemp; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool : $(command -v "$tool")"
  else
    bad "$tool introuvable"; add_issue
  fi
done
# Gestionnaire de paquets
for pm in bun pnpm yarn npm; do
  if command -v "$pm" >/dev/null 2>&1; then
    ok "pm optionnel : $pm ($("$pm" --version 2>/dev/null | head -1))"
  fi
done

# ─── 9. Branch git courante ────────────────────────────────────────────────
head "9. Git"
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  branch="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo 'detached')"
  ok "branche : $branch"
  dirty="$(git -C "$REPO_ROOT" status --porcelain | wc -l | tr -d ' ')"
  if [[ "$dirty" -eq 0 ]]; then
    ok "working tree propre"
  else
    warn "working tree : $dirty fichier(s) modifié(s)"
  fi
else
  bad "pas de dépôt git à $REPO_ROOT"; add_issue
fi

# ─── 10. Smoke test bash sur un lot (dry-run, sans exécution) ──────────────
head "10. Smoke test — parse syntaxique de chaque build-lot-N.sh"
for n in 1 2 3 4 5 6 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || continue
  if "$BASH_BIN" -n "$f" 2>/dev/null; then
    ok "L$n : syntaxe OK"
  else
    bad "L$n : erreur de syntaxe bash"
    "$BASH_BIN" -n "$f" 2>&1 | sed 's/^/      /'
    add_issue
  fi
done

# ─── Synthèse ──────────────────────────────────────────────────────────────
head "Synthèse"
if [[ "$ISSUES" -eq 0 ]]; then
  printf '%s✅ Aucun problème détecté — infra prête.%s\n' "$G" "$Z"
  exit 0
fi

printf '%s❌ %d problème(s) détecté(s).%s\n\n' "$R" "$ISSUES" "$Z"

if [[ ${#FIXES[@]} -gt 0 ]]; then
  printf '%s── Correctifs suggérés ──%s\n' "$B" "$Z"
  # dédupliquer
  printf '%s\n' "${FIXES[@]}" | awk '!seen[$0]++' | while IFS= read -r line; do
    printf '  %s→%s %s\n' "$Y" "$Z" "$line"
  done
fi

printf '\n%sRelancer après correctifs :%s\n' "$D" "$Z"
printf '  bash scripts/lots/doctor.sh\n'
printf '  bash scripts/lots/build-all.sh --dry-run\n'
exit 1