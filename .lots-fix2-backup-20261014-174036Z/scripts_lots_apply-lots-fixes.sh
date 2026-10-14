#!/usr/bin/env bash
# scripts/lots/apply-lots-fixes.sh
# Applique tous les correctifs identifiés pour rendre scripts/lots/ compatible bash 3.2.
#
# Usage:
#   bash scripts/lots/apply-lots-fixes.sh            # dry-run (défaut)
#   bash scripts/lots/apply-lots-fixes.sh --yes      # applique réellement
#   bash scripts/lots/apply-lots-fixes.sh --yes --no-backup
#
# Idempotent : relancer ne casse rien.

set -uo pipefail

# ─── Config ────────────────────────────────────────────────────────────────
APPLY=0
MAKE_BACKUP=1
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)     APPLY=1; shift ;;
    --no-backup)  MAKE_BACKUP=0; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--yes] [--no-backup] [--verbose]

  --yes, -y      Applique réellement les correctifs (défaut: dry-run)
  --no-backup    Ne crée pas de sauvegardes .bak-<timestamp>
  --verbose, -v  Détaille chaque action
EOF
      exit 0 ;;
    *) echo "option inconnue: $1" >&2; exit 2 ;;
  esac
done

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; Z=$'\033[0m'
else
  R=""; G=""; Y=""; B=""; D=""; Z=""
fi
say()   { printf '%s\n' "$*"; }
ok()    { printf '%s✅%s %s\n' "$G" "$Z" "$*"; }
bad()   { printf '%s❌%s %s\n' "$R" "$Z" "$*"; }
warn()  { printf '%s⚠️  %s\n' "$Y" "$Z" "$*"; }
info()  { printf '%sℹ️  %s\n' "$B" "$Z" "$*"; }
dim()   { printf '%s   %s%s\n' "$D" "$*" "$Z"; }
hdr()   { printf '\n%s══ %s ══%s\n' "$B" "$*" "$Z"; }
dry()   { printf '%s[dry]%s %s\n' "$D" "$Z" "$*"; }
verb()  { [[ "$VERBOSE" == "1" ]] && dim "$*" || true; }

# ─── Localisation ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

TS="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_DIR=".lots-fixes-backup-${TS}"

STATS_APPLIED=0
STATS_SKIPPED=0
STATS_FAILED=0

# ─── Helpers ───────────────────────────────────────────────────────────────
backup_file() {
  local f="$1"
  [[ "$MAKE_BACKUP" == "0" ]] && return 0
  [[ -f "$f" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  local dest="${BACKUP_DIR}/$(echo "$f" | tr '/' '_').bak"
  cp "$f" "$dest" 2>/dev/null && verb "backup → $dest"
}

# Remplace un bloc multi-lignes (par regex compatibles bash 3.2)
# Usage : replace_block <fichier> <pattern_awk_debut> <pattern_awk_fin> <fichier_remplacement>
# Utilise awk (pas perl) pour rester 3.2-safe.
replace_block() {
  local file="$1" start_pat="$2" end_pat="$3" repl_file="$4"
  awk -v start="$start_pat" -v end="$end_pat" -v repl="$repl_file" '
    BEGIN { skip=0; replaced=0 }
    skip==0 && $0 ~ start { skip=1; while ((getline line < repl) > 0) print line; close(repl); replaced=1; next }
    skip==1 && $0 ~ end { skip=0; next }
    skip==0 { print }
    END { exit (replaced ? 0 : 1) }
  ' "$file"
}

# Écrit un fichier temporaire contenant le remplacement
tmp_content() {
  local f; f="$(mktemp -t lots-fix)"
  cat > "$f"
  echo "$f"
}

# Applique un remplacement atomique (write to tmp, mv if changed)
apply_file_content() {
  local target="$1" new_content="$2"
  if [[ -f "$target" ]] && cmp -s "$new_content" "$target"; then
    return 1   # inchangé
  fi
  if [[ "$APPLY" == "1" ]]; then
    backup_file "$target"
    mv "$new_content" "$target"
  else
    rm -f "$new_content"
    dry "écrirait $target"
  fi
  return 0
}

file_contains() {
  grep -qF "$2" "$1" 2>/dev/null
}

# ─── Pré-checks ────────────────────────────────────────────────────────────
hdr "0. Contexte"
info "repo       : $REPO_ROOT"
info "bash       : $(command -v bash) — ${BASH_VERSION}"
info "mode       : $([[ "$APPLY" == "1" ]] && echo "APPLY" || echo "DRY-RUN (relancer avec --yes)")"
info "backups    : $([[ "$MAKE_BACKUP" == "1" ]] && echo "activés → $BACKUP_DIR" || echo "désactivés")"

if [[ ! -d scripts/lots ]]; then
  bad "scripts/lots/ introuvable — mauvais répertoire ?"
  exit 2
fi

# ─── Fix 1 : _lib.sh — retirer le guard bash ≥ 4 ───────────────────────────
hdr "Fix 1 : _lib.sh — guard bash ≥ 4"
LIB=scripts/lots/_lib.sh
if [[ -f "$LIB" ]]; then
  if grep -q 'BASH_VERSINFO\[0\]:-0.*-lt 4\|BASH_VERSINFO\[0\].*-lt 4' "$LIB"; then
    info "guard bash ≥ 4 détecté → suppression"

    tmp="$(mktemp -t lib-fix)"
    awk '
      BEGIN { skip=0 }
      /^if \[ "\$\{BASH_VERSINFO\[0\]:-0\}" -lt 4 \]; then/ { skip=1; next }
      /^if \[ "\$\{BASH_VERSINFO\[0\]\}" -lt 4 \]; then/       { skip=1; next }
      skip==1 && /^fi$/ { skip=0; next }
      skip==0 { print }
    ' "$LIB" > "$tmp"

    if ! cmp -s "$tmp" "$LIB"; then
      if apply_file_content "$LIB" "$tmp"; then
        ok "_lib.sh : guard bash ≥ 4 supprimé"
        STATS_APPLIED=$((STATS_APPLIED+1))
      else
        rm -f "$tmp"
        dim "_lib.sh : aucun changement"
        STATS_SKIPPED=$((STATS_SKIPPED+1))
      fi
    else
      rm -f "$tmp"
      dim "_lib.sh : guard non trouvé (déjà patché ?)"
      STATS_SKIPPED=$((STATS_SKIPPED+1))
    fi
  else
    dim "_lib.sh : déjà compatible (pas de guard bash ≥ 4)"
    STATS_SKIPPED=$((STATS_SKIPPED+1))
  fi
else
  warn "_lib.sh absent — skip"
fi

# ─── Fix 2 : build-all.sh — retirer le check bash ≥ 4 ─────────────────────
hdr "Fix 2 : build-all.sh — check bash ≥ 4"
BA=scripts/lots/build-all.sh
if [[ -f "$BA" ]]; then
  if grep -q 'BASH_VERSINFO\[0\].*-ge 4\|FAIL_FAST_ON_INFRA' "$BA" && \
     grep -q 'bash < 4 détecté' "$BA"; then
    info "check bash ≥ 4 détecté → suppression"

    tmp="$(mktemp -t ba-fix)"
    awk '
      BEGIN { skip=0 }
      /^if ! "\$BASH_BIN" -c .\[\[ "\$\{BASH_VERSINFO\[0\]\}" -ge 4 \]\].; then/ { skip=1; next }
      /^if ! "\$BASH_BIN" -c .*BASH_VERSINFO.*-ge 4.*; then/ { skip=1; next }
      skip==1 && /^fi$/ { skip=0; next }
      skip==0 { print }
    ' "$BA" > "$tmp"

    # Ajoute un log informatif à la place (si absent)
    if ! grep -q 'bash_ver=' "$tmp"; then
      tmp2="$(mktemp -t ba-fix2)"
      awk '
        !inserted && /^log_step "build-all/ {
          print
          print "bash_ver=\"$(\"$BASH_BIN\" -c '\''echo \"${BASH_VERSION}\"'\'' 2>/dev/null || echo \"?\")\""
          print "log_dim \"bash          : $(command -v \"$BASH_BIN\") ($bash_ver)\""
          inserted=1
          next
        }
        { print }
      ' "$tmp" > "$tmp2"
      rm -f "$tmp"
      tmp="$tmp2"
    fi

    if ! cmp -s "$tmp" "$BA"; then
      if apply_file_content "$BA" "$tmp"; then
        ok "build-all.sh : check bash ≥ 4 retiré"
        STATS_APPLIED=$((STATS_APPLIED+1))
      else
        rm -f "$tmp"; STATS_SKIPPED=$((STATS_SKIPPED+1))
      fi
    else
      rm -f "$tmp"; dim "build-all.sh : aucun changement"
      STATS_SKIPPED=$((STATS_SKIPPED+1))
    fi
  else
    dim "build-all.sh : déjà compatible"
    STATS_SKIPPED=$((STATS_SKIPPED+1))
  fi
else
  warn "build-all.sh absent — skip"
fi

# ─── Fix 3 : doctor.sh — remplacer la section "Version bash" ───────────────
hdr "Fix 3 : doctor.sh — section Version bash"
DOC=scripts/lots/doctor.sh
if [[ -f "$DOC" ]]; then
  if grep -q 'bash ≥ 4 requis\|bash < 4 —' "$DOC"; then
    info "dogme bash ≥ 4 détecté → remplacement par version tolérante"

    # Écrit le nouveau bloc section 1 dans un fichier temporaire
    new_section="$(mktemp -t doc-sec)"
    cat > "$new_section" <<'NEWSEC'
# ─── 1. Version bash ───────────────────────────────────────────────────────
hdr "1. Version bash"
BASH_BIN="$(command -v bash || true)"
if [[ -z "$BASH_BIN" ]]; then
  bad "bash introuvable dans le PATH"
  add_issue
else
  BV="$("$BASH_BIN" --version 2>/dev/null | awk 'NR==1{print; exit}' || true)"
  BV_MAJOR="$("$BASH_BIN" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null || echo 0)"
  info "PATH → $BASH_BIN"
  info "version → ${BV:-<inconnue>}"
  if [[ "$(safe_int "$BV_MAJOR")" -ge 4 ]]; then
    ok "bash $BV_MAJOR ≥ 4"
  else
    warn "bash $BV_MAJOR détecté — OK si aucun script n'utilise 'declare -A'"
    declare_a_hits=0
    for f in scripts/lots/*.sh; do
      [[ -f "$f" ]] || continue
      if grep -q 'declare -A' "$f" 2>/dev/null; then
        bad "$(basename "$f") utilise 'declare -A' (bash ≥ 4 requis)"
        add_issue
        add_fix "remplacer 'declare -A' par une fonction 'case' dans $f"
        declare_a_hits=$((declare_a_hits+1))
      fi
    done
    [[ "$declare_a_hits" -eq 0 ]] && ok "aucun declare -A dans scripts/lots/ → bash 3.2 pleinement supporté"
  fi
fi
NEWSEC

    # Remplace le bloc entre "# ─── 1. Version bash" et "# ─── 2."
    tmp="$(mktemp -t doc-fix)"
    awk -v repl="$new_section" '
      BEGIN { skip=0 }
      /^# ─── 1\. Version bash/ { skip=1; while ((getline line < repl) > 0) print line; close(repl); next }
      /^# ─── 2\./ { skip=0 }
      skip==0 { print }
    ' "$DOC" > "$tmp"
    rm -f "$new_section"

    if ! cmp -s "$tmp" "$DOC"; then
      if apply_file_content "$DOC" "$tmp"; then
        ok "doctor.sh : section 1 remplacée (tolérante bash 3.2)"
        STATS_APPLIED=$((STATS_APPLIED+1))
      else
        rm -f "$tmp"; STATS_SKIPPED=$((STATS_SKIPPED+1))
      fi
    else
      rm -f "$tmp"; dim "doctor.sh : aucun changement"
      STATS_SKIPPED=$((STATS_SKIPPED+1))
    fi
  else
    dim "doctor.sh : déjà tolérant"
    STATS_SKIPPED=$((STATS_SKIPPED+1))
  fi
else
  warn "doctor.sh absent — skip"
fi

# ─── Fix 4 : build-lot-3.sh (et autres) — declare -A ───────────────────────
hdr "Fix 4 : declare -A dans les build-lot-N.sh"
declare_a_files=""
for f in scripts/lots/build-lot-*.sh; do
  [[ -f "$f" ]] || continue
  if grep -q 'declare -A' "$f" 2>/dev/null; then
    declare_a_files="$declare_a_files $f"
  fi
done

if [[ -z "$declare_a_files" ]]; then
  ok "aucun 'declare -A' détecté"
  STATS_SKIPPED=$((STATS_SKIPPED+1))
else
  for f in $declare_a_files; do
    warn "$f : 'declare -A' détecté — remplacement automatique impossible (logique métier)"
    # On affiche les lignes concernées pour permettre un patch manuel rapide
    dim "  lignes concernées :"
    grep -n 'declare -A' "$f" | sed 's/^/    /'
    dim "  → voir scripts/lots/PATCH-declare-A.md (généré)"
    STATS_FAILED=$((STATS_FAILED+1))
  done

  # Génère un guide de patch
  guide="scripts/lots/PATCH-declare-A.md"
  {
    echo "# Patch manuel : remplacer \`declare -A\` (bash 3.2)"
    echo ""
    echo "Généré le $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "## Fichiers concernés"
    echo ""
    for f in $declare_a_files; do
      echo "### \`$f\`"
      echo ""
      echo '```bash'
      grep -n -A 20 'declare -A' "$f" | head -40
      echo '```'
      echo ""
      echo "**Remplacement type :**"
      echo ""
      echo '```bash'
      echo "# Avant :"
      echo 'declare -A MAP=('
      echo '  [key1]="val1"'
      echo '  [key2]="val2"'
      echo ')'
      echo 'echo "${MAP[$k]}"'
      echo ""
      echo "# Après (bash 3.2 safe) :"
      echo 'lookup_map() {'
      echo '  case "$1" in'
      echo '    key1) echo "val1" ;;'
      echo '    key2) echo "val2" ;;'
      echo '    *) echo "$1" ;;'
      echo '  esac'
      echo '}'
      echo 'echo "$(lookup_map "$k")"'
      echo '```'
      echo ""
    done
  } > "$guide"
  info "guide généré : $guide"
fi

# ─── Fix 5 : build-lot-6.sh — ordre du source ──────────────────────────────
hdr "Fix 5 : build-lot-6.sh — ordre source / usage couleurs"
L6=scripts/lots/build-lot-6.sh
if [[ -f "$L6" ]]; then
  src_line_raw="$(grep -nE 'source[[:space:]]+.*_lib\.sh' "$L6" 2>/dev/null | awk -F: 'NR==1{print $1; exit}')"
  if [[ -z "$src_line_raw" ]]; then
    bad "L6 : pas de 'source _lib.sh' trouvé"
    STATS_FAILED=$((STATS_FAILED+1))
  else
    src_line="$src_line_raw"
    # Cherche du code exécutable avant le source (hors shebang, set, commentaires, blank)
    before_code="$(awk -v n="$((src_line-1))" '
      NR<=n && !/^[[:space:]]*(#|$)/ && !/^#!/ && !/^[[:space:]]*set /
    ' "$L6" || true)"

    if [[ -z "$before_code" ]]; then
      ok "L6 : source en 1ère instruction utile ✅"
      STATS_SKIPPED=$((STATS_SKIPPED+1))
    else
      warn "L6 : code avant le source — réorganisation"
      dim "  code détecté :"
      printf '%s\n' "$before_code" | sed 's/^/    /'

      # Stratégie : déplacer le source juste après la dernière ligne 'set ' ou shebang
      tmp="$(mktemp -t l6-fix)"
      awk -v srcline="$src_line" '
        NR==srcline { next }   # on retire la ligne source de sa position actuelle
        {
          print
          # Insère le source juste après le dernier set -... rencontré avant srcline
          if (NR < srcline && /^[[:space:]]*set [euxop]*/ && !inserted) {
            print ""
            print "# Source unique des helpers (doit être en 1ère instruction utile)"
            print "source \"$(dirname \"${BASH_SOURCE[0]}\")/_lib.sh\""
            inserted=1
          }
        }
        END {
          if (!inserted) {
            # fallback : insère après la 1ère ligne si aucun set trouvé
            print "# WARN: source non réinséré automatiquement — vérifier manuellement" > "/dev/stderr"
          }
        }
      ' "$L6" > "$tmp"

      if ! cmp -s "$tmp" "$L6"; then
        if apply_file_content "$L6" "$tmp"; then
          ok "L6 : source déplacé en tête"
          STATS_APPLIED=$((STATS_APPLIED+1))
        else
          rm -f "$tmp"; STATS_SKIPPED=$((STATS_SKIPPED+1))
        fi
      else
        rm -f "$tmp"; dim "L6 : aucun changement"
        STATS_SKIPPED=$((STATS_SKIPPED+1))
      fi
    fi
  fi
else
  warn "build-lot-6.sh absent — skip"
fi

# ─── Fix 6 : push-lot.sh — lien symbolique si trouvé ailleurs ──────────────
hdr "Fix 6 : push-lot.sh introuvable ?"
if [[ -f scripts/lots/push-lot.sh ]]; then
  ok "scripts/lots/push-lot.sh présent"
  STATS_SKIPPED=$((STATS_SKIPPED+1))
else
  found="$(find scripts -name push-lot.sh -maxdepth 4 2>/dev/null | head -1)"
  if [[ -n "$found" ]]; then
    warn "trouvé ailleurs : $found"
    if [[ "$APPLY" == "1" ]]; then
      ln -sf "../${found#scripts/}" scripts/lots/push-lot.sh 2>/dev/null && \
        ok "lien créé : scripts/lots/push-lot.sh → $found" && \
        STATS_APPLIED=$((STATS_APPLIED+1)) || {
        bad "échec création lien — à faire manuellement"
        STATS_FAILED=$((STATS_FAILED+1))
      }
    else
      dry "créerait un lien : scripts/lots/push-lot.sh → $found"
    fi
  else
    warn "push-lot.sh introuvable — création d'un stub ? (à faire manuellement)"
    STATS_SKIPPED=$((STATS_SKIPPED+1))
  fi
fi

# ─── Rapport ───────────────────────────────────────────────────────────────
hdr "Rapport"
printf '  %-14s %s\n' "appliqués"  "$STATS_APPLIED"
printf '  %-14s %s\n' "inchangés"  "$STATS_SKIPPED"
printf '  %-14s %s\n' "à faire"    "$STATS_FAILED"
[[ -d "$BACKUP_DIR" ]] && printf '  %-14s %s\n' "backups" "$BACKUP_DIR"

if [[ "$APPLY" == "0" ]]; then
  say ""
  warn "Mode DRY-RUN — relancer avec --yes pour appliquer"
fi

if [[ "$STATS_FAILED" -gt 0 ]]; then
  say ""
  info "Actions manuelles requises (declare -A) : voir scripts/lots/PATCH-declare-A.md"
fi

say ""
info "Étape suivante :"
dim "  bash scripts/lots/doctor.sh"
dim "  bash scripts/lots/build-all.sh --dry-run"

exit 0