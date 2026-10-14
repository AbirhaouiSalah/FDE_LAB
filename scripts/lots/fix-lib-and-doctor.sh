#!/usr/bin/env bash
# scripts/lots/fix-lib-and-doctor.sh
# Corrige les bugs dans _lib.sh, doctor.sh, apply-lots-fixes.sh.
# Idempotent, dry-run par défaut.

set -uo pipefail

APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) APPLY=1; shift ;;
    -h|--help) echo "Usage: $0 [--yes]"; exit 0 ;;
    *) echo "option inconnue: $1" >&2; exit 2 ;;
  esac
done

# Couleurs simples
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; Z=$'\033[0m'
else R=""; G=""; Y=""; B=""; D=""; Z=""; fi
ok()   { printf '%s✅%s %s\n' "$G" "$Z" "$*"; }
bad()  { printf '%s❌%s %s\n' "$R" "$Z" "$*"; }
warn() { printf '%s⚠️  %s\n' "$Y" "$Z" "$*"; }
info() { printf '%sℹ️  %s\n' "$B" "$Z" "$*"; }
hdr()  { printf '\n%s══ %s ══%s\n' "$B" "$*" "$Z"; }
dry()  { printf '%s[dry]%s %s\n' "$D" "$Z" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

TS="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_DIR=".lots-fix2-backup-${TS}"

backup() {
  local f="$1"; [[ -f "$f" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp "$f" "${BACKUP_DIR}/$(echo "$f" | tr '/' '_')"
}

write_atomic() {
  local target="$1" src="$2"
  if [[ -f "$target" ]] && cmp -s "$src" "$target"; then
    rm -f "$src"; return 1
  fi
  if [[ "$APPLY" == "1" ]]; then
    backup "$target"
    # préserver les droits
    if [[ -f "$target" ]]; then
      local mode; mode="$(stat -f '%Lp' "$target" 2>/dev/null || echo "")"
      mv "$src" "$target"
      [[ -n "$mode" ]] && chmod "$mode" "$target" 2>/dev/null || true
    else
      mv "$src" "$target"
    fi
  else
    rm -f "$src"; dry "écrirait $target"
  fi
  return 0
}

# ─── 0. Contexte ───────────────────────────────────────────────────────────
hdr "0. Contexte"
info "repo : $REPO_ROOT"
info "mode : $([[ "$APPLY" == "1" ]] && echo APPLY || echo DRY-RUN)"

# Vérifie si 'head' est shadowé
HEAD_BIN="/usr/bin/head"
[[ -x "$HEAD_BIN" ]] || HEAD_BIN="head"
if command -v head >/dev/null 2>&1; then
  HEAD_PATH="$(command -v head)"
  if [[ "$HEAD_PATH" != "/usr/bin/head" ]] && [[ "$HEAD_PATH" != "/bin/head" ]]; then
    warn "head shadowé : $HEAD_PATH (un client HTTP ?)"
    info "on utilise : $HEAD_BIN"
  fi
fi

# ─── Fix A : nettoyer BOM sur tous les scripts ─────────────────────────────
hdr "Fix A : BOM UTF-8 sur scripts/lots/*.sh"
bom_fixed=0
for f in scripts/lots/*.sh; do
  [[ -f "$f" ]] || continue
  first3="$(head -c 3 "$f" 2>/dev/null | od -An -tx1 | tr -d ' ')"
  if [[ "$first3" == "efbbbf" ]]; then
    info "BOM détecté : $f"
    if [[ "$APPLY" == "1" ]]; then
      backup "$f"
      # Retire les 3 premiers octets
      tail -c +4 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      ok "  BOM retiré"
    else
      dry "  retirerait BOM de $f"
    fi
    bom_fixed=$((bom_fixed+1))
  fi
done
[[ "$bom_fixed" -eq 0 ]] && ok "aucun BOM détecté"

# ─── Fix B : _lib.sh — corriger le filet couleurs ──────────────────────────
hdr "Fix B : _lib.sh — filet couleurs"
LIB=scripts/lots/_lib.sh
if [[ -f "$LIB" ]]; then
  # Cherche toute ligne du type `: "${C_XXX?:}"` (avec ? au lieu de :=)
  if grep -qE ':\s*"\$\{C_[A-Z_]*\?:' "$LIB"; then
    info "lignes corrompues détectées → reconstruction du filet"
    tmp="$(mktemp -t libfix)"
    # Remplace le bloc entier du filet (de la 1ère ligne `: "${C_` jusqu'à la ligne `export C_`)
    /usr/bin/awk '
      BEGIN { skip=0; wrote=0 }
      /^:[[:space:]]*"\$\{C_(RESET|RST|BLUE)/ && !wrote {
        skip=1
        print "# Filet de sécurité : toute couleur non définie devient vide."
        print ": \"${C_RESET:=}\" \"${C_RST:=}\" \"${C_DIM:=}\" \"${C_BOLD:=}\""
        print ": \"${C_RED:=}\" \"${C_GREEN:=}\" \"${C_YELLOW:=}\" \"${C_BLUE:=}\""
        print ": \"${C_MAGENTA:=}\" \"${C_CYAN:=}\" \"${C_GRAY:=}\""
        print ": \"${C_GRN:=}\" \"${C_BLU:=}\" \"${C_YEL:=}\" \"${C_MAG:=}\" \"${C_CYN:=}\""
        print "export C_RESET C_RST C_DIM C_BOLD C_RED C_GREEN C_YELLOW C_BLUE \\"
        print "       C_MAGENTA C_CYAN C_GRAY C_GRN C_BLU C_YEL C_MAG C_CYN"
        wrote=1
        next
      }
      skip==1 && /^export C_/ { skip=0; next }
      skip==1 { next }
      { print }
    ' "$LIB" > "$tmp"

    if ! cmp -s "$tmp" "$LIB"; then
      if write_atomic "$LIB" "$tmp"; then
        ok "_lib.sh : filet couleurs reconstruit"
      fi
    else
      rm -f "$tmp"; warn "_lib.sh : reconstruction n'a rien changé — inspection manuelle"
    fi
  else
    ok "_lib.sh : filet couleurs OK"
  fi
else
  bad "_lib.sh introuvable"
fi

# ─── Fix C : doctor.sh — remplacer les head -1 + protéger $(( )) ───────────
hdr "Fix C : doctor.sh — head + arithmétique"
DOC=scripts/lots/doctor.sh
if [[ -f "$DOC" ]]; then
  # Backup avant modif
  [[ "$APPLY" == "1" ]] && backup "$DOC"

  # 1. Remplacer toutes les occurrences de `head -1` (sauf /usr/bin/head) par awk
  # 2. Remplacer `head -n "$N"` par `head_n "$N"` si _lib est sourcé… mais doctor ne source pas _lib → awk direct
  # 3. Ajouter la fonction head_n si absente
  # 4. Protéger les $(( src_line-1 ))
  tmp="$(mktemp -t docfix)"

  # On reconstruit le fichier ligne par ligne
  /usr/bin/awk '
    BEGIN { injected_headn=0 }

    # Injecter head_n() au début si absent
    /^set -uo pipefail/ && !injected_headn {
      print
      print ""
      print "# Fallback head (head système peut être shadowé par un client HTTP)"
      print "if [ -x /usr/bin/head ]; then HEAD_BIN=/usr/bin/head; else HEAD_BIN=head; fi"
      print "head_n() { \"$HEAD_BIN\" -n \"$1\"; }"
      injected_headn=1
      next
    }

    # Remplacer les patterns head -1 ou head -n N pipe par awk
    /head -1/ {
      gsub(/head -1/, "awk '"'"'NR==1{print; exit}'"'"'")
    }
    /head -n [0-9]+/ {
      gsub(/head -n [0-9]+/, "awk '"'"'NR==1{print; exit}'"'"'")
    }
    { print }
  ' "$DOC" > "$tmp"

  # Puis on cible spécifiquement la ligne 117 problématique : $((src_line-1))
  # On remplace par une variable safe
  tmp2="$(mktemp -t docfix2)"
  /usr/bin/awk '
    /before="\$\(head -n "\$\(\(src_line-1\)\)"/ {
      print "  src_line_safe=\"$( [[ \"${src_line:-}\" =~ ^[0-9]+$ ]] && echo \"$src_line\" || echo 1 )\""
      print "  before=\"$(/usr/bin/awk -v n=\"$((src_line_safe-1))\" '"'"'NR<=n && !/^[[:space:]]*(#|$)/ && !/^#!/ && !/^[[:space:]]*set /'"'"' \"$f\" || true)\""
      next
    }
    { print }
  ' "$tmp" > "$tmp2"
  rm -f "$tmp"

  if ! cmp -s "$tmp2" "$DOC"; then
    if write_atomic "$DOC" "$tmp2"; then
      ok "doctor.sh : head/arithmétique corrigés"
    fi
  else
    rm -f "$tmp2"
    warn "doctor.sh : patterns non trouvés — version déjà corrigée ?"
  fi
else
  bad "doctor.sh introuvable"
fi

# ─── Fix D : doctor.sh — section 1 tolérante (regex robuste) ───────────────
hdr "Fix D : doctor.sh — section 1 bash ≥ 4"
if [[ -f "$DOC" ]]; then
  # Détection large : la section dit "bash" ET "4" ET "requis" dans les 5 lignes après "1. Version bash"
  if /usr/bin/awk '
        /^hdr "1\. Version bash"/ { found=1; n=0 }
        found && n<15 && /bash.*4.*requis|bash.*< 4|>= 4/ { print "MATCH"; exit 0 }
        found { n++ }
        END { exit 1 }
      ' "$DOC" >/dev/null 2>&1; then
    info "section 1 dogmatique détectée → remplacement"
    newsec="$(mktemp -t newsec)"
    cat > "$newsec" <<'NEWSEC'
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
    [[ "$declare_a_hits" -eq 0 ]] && ok "aucun declare -A → bash 3.2 pleinement supporté"
  fi
fi
NEWSEC

    tmp="$(mktemp -t docsec)"
    /usr/bin/awk -v repl="$newsec" '
      BEGIN { skip=0 }
      /^hdr "1\. Version bash"/ { skip=1; while ((getline line < repl) > 0) print line; close(repl); next }
      /^hdr "2\./ { skip=0 }
      skip==0 { print }
    ' "$DOC" > "$tmp"
    rm -f "$newsec"

    if ! cmp -s "$tmp" "$DOC"; then
      if write_atomic "$DOC" "$tmp"; then
        ok "doctor.sh : section 1 remplacée"
      fi
    else
      rm -f "$tmp"; warn "doctor.sh : pas de changement (regex ?)"
    fi
  else
    ok "doctor.sh : section 1 déjà tolérante ou introuvable"
  fi
fi

# ─── Fix E : apply-lots-fixes.sh — head dans find push-lot.sh ──────────────
hdr "Fix E : apply-lots-fixes.sh — head shadowé"
AF=scripts/lots/apply-lots-fixes.sh
if [[ -f "$AF" ]]; then
  if grep -qE 'find .*push-lot\.sh.*\| head -1' "$AF" 2>/dev/null; then
    info "pattern 'find … | head -1' détecté → remplacement par awk"
    tmp="$(mktemp -t affix)"
    /usr/bin/awk '
      { gsub(/head -1/, "awk '"'"'NR==1{print; exit}'"'"'"); print }
    ' "$AF" > "$tmp"
    if ! cmp -s "$tmp" "$AF"; then
      if write_atomic "$AF" "$tmp"; then
        ok "apply-lots-fixes.sh : head remplacé"
      fi
    else
      rm -f "$tmp"
    fi
  else
    ok "apply-lots-fixes.sh : pas de 'find | head' problématique"
  fi
fi

# ─── Fix F : permissions exécutables ───────────────────────────────────────
hdr "Fix F : chmod +x scripts/lots/*.sh"
if [[ "$APPLY" == "1" ]]; then
  chmod +x scripts/lots/*.sh 2>/dev/null
  ok "chmod +x appliqué"
else
  dry "chmod +x scripts/lots/*.sh"
fi

# ─── Fix G : guide declare -A plus clair ───────────────────────────────────
hdr "Fix G : guide declare -A"
L3=scripts/lots/build-lot-3.sh
if [[ -f "$L3" ]] && grep -q 'declare -A' "$L3"; then
  info "build-lot-3.sh utilise declare -A — voir PATCH-declare-A.md"
  # On ajoute la ligne 53 exacte dans le guide
  guide="scripts/lots/PATCH-declare-A.md"
  if [[ "$APPLY" == "1" ]] && [[ -f "$guide" ]]; then
    {
      echo ""
      echo "## Ligne exacte à modifier dans build-lot-3.sh"
      echo ""
      echo '```'
      grep -n 'declare -A' "$L3"
      echo '```'
      echo ""
      echo "## Contexte (lignes 45-70)"
      echo ""
      echo '```bash'
      /usr/bin/awk 'NR>=45 && NR<=70' "$L3"
      echo '```'
    } >> "$guide"
    ok "guide enrichi"
  fi
fi

# ─── Rapport ───────────────────────────────────────────────────────────────
hdr "Rapport"
[[ -d "$BACKUP_DIR" ]] && info "backups : $BACKUP_DIR"
if [[ "$APPLY" == "0" ]]; then
  warn "Mode DRY-RUN — relancer avec --yes"
fi

echo ""
info "Étape suivante :"
echo "  bash scripts/lots/doctor.sh"
echo "  bash scripts/lots/build-all.sh --dry-run"