# README — Scripts Git pour le projet ATS Copilot Dashboard

---

```markdown
# Scripts Git — ATS Copilot Dashboard

Collection de scripts Bash pour automatiser la gestion des branches `ats-lab/*`,
la propagation des modifications, les merges vers `main`, et le nettoyage du repo.

---

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Scripts disponibles](#scripts-disponibles)
   - [run.sh](#runsh)
   - [diagnose.sh](#diagnosesh)
   - [sync-all-branches-and-merge.sh](#sync-all-branches-and-mergesh)
   - [merge-main-into-branches.sh](#merge-main-into-branches-sh)
   - [merge-all-into-main.sh](#merge-all-into-mainsh)
   - [push-modification-to-all-branches.sh](#push-modification-to-all-branchessh)
   - [cleanup-branches.sh](#cleanup-branchessh)
4. [Workflows typiques](#workflows-typiques)
5. [Conventions de nommage](#conventions-de-nommage)
6. [Dépannage](#dépannage)
7. [Sécurité et backups](#sécurité-et-backups)

---

## Vue d'ensemble

Ce projet utilise un **workflow Git multi-branches** où :

- `main` = branche principale, toujours stable
- `ats-lab/*` = 23 branches de travail (une par scope fonctionnel)
- `backup/*` = backups automatiques créées avant chaque opération risquée

Les scripts automatisent les opérations répétitives sur ces branches :

```
┌────────────────────────────────────────────────────────────────┐
│  DIAGNOSTIC   →  diagnose.sh                                   │
│  MODIFICATION →  push-modification-to-all-branches.sh          │
│  ALIGNEMENT   →  merge-main-into-branches.sh                   │
│  SYNCHRO      →  sync-all-branches-and-merge.sh                │
│  MERGE RETOUR →  merge-all-into-main.sh                        │
│  NETTOYAGE    →  cleanup-branches.sh                           │
│  DEV LOCAL    →  run.sh                                        │
└────────────────────────────────────────────────────────────────┘
```

---

## Prérequis

- **macOS / Linux** (bash ≥ 3.2, testé sur macOS)
- **Node.js** ≥ 20 (via nvm / Herd)
- **pnpm** ≥ 9 (`corepack enable && corepack prepare pnpm@9.6.0 --activate`)
- **git** ≥ 2.30
- Accès en écriture à `git@github.com:AbirhaouiSalah/FDE_LAB.git`

**Vérification rapide :**

```bash
node --version    # >= 20
pnpm --version    # >= 9
git --version     # >= 2.30
git remote -v     # doit montrer origin
```

---

## Scripts disponibles

### `run.sh`

**Point d'entrée unique pour le dev local.**

```bash
./scripts/run.sh <commande> [args]
```

| Commande | Effet |
|---|---|
| `install` | Installe les dépendances (détecte pnpm/yarn/npm/bun) |
| `dev` | Démarre Vite sur http://localhost:5173 |
| `build` | Build de production → `dist/` |
| `test [pattern]` | Vitest (watch si TTY, run sinon) |
| `lint` | ESLint |
| `typecheck` | `tsc --noEmit` |
| `coverage` | Vitest + coverage |
| `a11y` | Tests d'accessibilité (skip si non configuré) |
| `i18n` | Parité FR/EN (skip si non configuré) |
| `check` | **lint + typecheck + test + build + a11y + i18n** |
| `clean` | Supprime `node_modules`, `dist`, `coverage` |

**Exemples :**

```bash
./scripts/run.sh check              # valide tout avant commit
./scripts/run.sh test KpiCard       # lance les tests du widget KpiCard
./scripts/run.sh dev                # démarre le serveur de dev
```

---

### `diagnose.sh`

**Analyse l'état des 24 branches `ats-lab/*` par rapport à `main`.**

```bash
./scripts/diagnose.sh [options]
```

| Option | Description |
|---|---|
| (aucune) | Tableau compact : AHEAD, BEHIND, TOOLCHAIN, SYNC |
| `--files` | Liste précise des fichiers manquants par branche |
| `--commits` | Liste des commits uniques par branche |
| `--full` | Détail complet par branche |
| `--branch <nom>` | Focus sur une seule branche |
| `--all` | Tout afficher |

**Ce que le script analyse :**

- **AHEAD** : combien de commits la branche a en plus de `main`
- **BEHIND** : combien de commits `main` a en plus de la branche
- **TOOLCHAIN** : fichiers de toolchain présents (sur 14)
- **SYNC** : le commit `chore(sync)` est-il présent (`✓`/`✗`)

**Exemples :**

```bash
./scripts/diagnose.sh                          # vue globale
./scripts/diagnose.sh --files                  # fichiers manquants
./scripts/diagnose.sh --branch comp/widgets/kpi-card   # focus
```

---

### `sync-all-branches-and-merge.sh`

**Propage la toolchain de `main` vers les 23 branches, puis merge les branches dans `main`.**

```bash
./scripts/sync-all-branches-and-merge.sh [options]
```

| Option | Description |
|---|---|
| `--dry-run` | Simule, ne pousse rien |
| `--yes` / `-y` | Pas de confirmation interactive |
| `--no-merge` | Propagation seulement (pas de merge retour) |
| `--only-merge` | Merge seulement (pas de propagation) |
| `--source <b>` | Branche source (défaut : `main`) |

**Ce que le script fait :**

1. **Phase 1** — Pour chaque branche :
   - Crée un worktree isolé
   - Copie **14 fichiers de toolchain** depuis `main`
   - Commit `chore(sync): propagate toolchain from main`
   - Push
2. **Phase 2** — Pour chaque branche avec commits uniques :
   - `git merge --no-ff --allow-unrelated-histories -X theirs`
   - Push `main`

**⚠️ Comportement :**

- La Phase 2 utilise `-X theirs` (= garde `main` en cas de conflit)
- Filtre les commits CI (`ci: report`, `ci: sync`, `chore(sync)`)
- Ne touche **pas** au working tree principal

**Exemples :**

```bash
./scripts/sync-all-branches-and-merge.sh --dry-run    # voir ce qui serait fait
./scripts/sync-all-branches-and-merge.sh --yes        # exécuter
./scripts/sync-all-branches-and-merge.sh --no-merge   # propager seulement
```

---

### `merge-main-into-branches.sh`

**Merge `main` dans chaque branche `ats-lab/*` (alignement complet).**

```bash
./scripts/merge-main-into-branches.sh [options]
```

| Option | Description |
|---|---|
| `--dry-run` | Simule |
| `--yes` / `-y` | Pas de confirmation |
| `--source <b>` | Branche source (défaut : `main`) |

**Ce que le script fait :**

Pour chaque branche :
1. Crée un worktree isolé
2. `git merge --no-ff --allow-unrelated-histories -X theirs main`
3. **Résolution automatique** des conflits `add/add` via `git checkout --theirs`
4. Commit + push

**Résultat :** chaque branche contient **tout `main`** + son historique propre.

**Quand l'utiliser :**

- Après avoir modifié `main` (toolchain, configs, code partagé)
- Pour que les branches aient **tout `main`** (pas juste la toolchain)
- Avant de commencer un développement sur une branche

**Exemples :**

```bash
./scripts/merge-main-into-branches.sh --dry-run
./scripts/merge-main-into-branches.sh --yes
```

---

### `merge-all-into-main.sh`

**Merge toutes les branches `ats-lab/*` dans `main`.**

```bash
./scripts/merge-all-into-main.sh [options]
```

| Option | Description |
|---|---|
| `--yes` / `-y` | Exécute (sinon dry-run) |
| `--dry-run` | Simulation |
| `--strategy ours\|theirs` | Stratégie de merge (défaut : `ours` = garder `main`) |
| `--keep-ci` | Ne pas filtrer les commits CI |
| `--target <b>` | Branche cible (défaut : `main`) |

**Ce que le script fait :**

1. **Analyse préliminaire** : liste les branches avec commits uniques
2. **Filtre** les commits CI automatiques (`ci: report`, `chore(sync)`, `merge: sync`)
3. Pour chaque branche avec commits utiles :
   - `git merge --no-ff --allow-unrelated-histories -X ours`
   - Commit `merge: sync ats-lab/xxx into main [skip ci]`
4. Push `main`

**Résultat :** `main` reçoit les commits de toutes les branches (avec un commit de merge par branche).

**Exemples :**

```bash
./scripts/merge-all-into-main.sh              # dry-run
./scripts/merge-all-into-main.sh --yes        # exécution
./scripts/merge-all-into-main.sh --yes --strategy theirs   # garder les branches
```

---

### `push-modification-to-all-branches.sh`

**Propage une modification locale sur les 23 branches `ats-lab/*`.**

```bash
./scripts/push-modification-to-all-branches.sh [options]
```

| Option | Description |
|---|---|
| `--yes` / `-y` | Exécute (sinon dry-run) |
| `--dry-run` | Simulation |
| `--message MSG` | **Obligatoire** — message de commit |
| `--files "f1 f2"` | Fichiers à propager (défaut : tous les modifiés) |
| `--branch-source BR` | Branche source des modifs (défaut : courante) |

**Ce que le script fait :**

1. Détecte les fichiers modifiés dans le working tree
2. Crée un **patch** des différences
3. Pour chaque branche :
   - Crée un worktree isolé
   - Applique le patch (avec fallback copie directe)
   - Commit `--message`
   - Push
4. **Ne touche PAS à `main`**

**⚠️ Comportement sur les conflits :**

- Si `git apply` réussit → ✅ propre
- Si `git apply` échoue → fallback : **écrase la version de la branche** avec celle de `main`
- Les commits propres de la branche sont **préservés** (nouveau commit ajouté par-dessus)

**Cas d'usage :**

- Propager une modif de toolchain (`eslint.config.js`, `package.json`)
- Propager un changement de config non-conflitctuel
- **Ne pas utiliser** pour propager du code que les branches modifient

**Exemples :**

```bash
# 1. Modifier un fichier sur main
nano eslint.config.js

# 2. Propager
./scripts/push-modification-to-all-branches.sh \
  --message "chore(eslint): add a11y rules" \
  --yes

# 3. Ou cibler des fichiers précis
./scripts/push-modification-to-all-branches.sh \
  --files "eslint.config.js tsconfig.json" \
  --message "chore: update configs" \
  --yes
```

**Après propagation :** utiliser `merge-all-into-main.sh` pour récupérer les commits dans `main`.

---

### `cleanup-branches.sh`

**Nettoie l'état du repo après les opérations.**

```bash
./scripts/cleanup-branches.sh [options]
```

| Option | Description |
|---|---|
| `--yes` / `-y` | Exécute (sinon dry-run) |
| `--keep-backups N` | Garde les N backups les plus récentes (défaut : 5) |
| `--remote` | Nettoie aussi les branches distantes |
| `--no-orphans` | Ne supprime pas les branches orphelines |

**Ce que le script nettoie :**

1. **Worktrees résiduels** (`.sync-worktrees`, `.align-worktrees`, `.push-worktrees`, `.modify-worktrees`)
2. **Branches locales temporaires** (`sync-tmp-*`, `align-tmp-*`, `push-tmp-*`, `mod-tmp-*`, `test-*`, `merge-test`)
3. **Branches locales orphelines** (sans équivalent remote, ex: `comp/*`, `feat/*` sans `ats-lab/`)
4. **Backups anciennes** (garde les N plus récentes)
5. **Branches distantes temporaires** (option `--remote`)
6. **Fichiers non traqués parasites** (`*.bak`, `*.log`, `TEST_SYNC.txt`, etc.)

**⚠️ Ce que le script NE fait PAS :**

- Ne supprime pas les branches `ats-lab/*`
- Ne supprime pas les branches `backup/*` au-delà de la rétention
- Ne touche pas aux branches protégées (`main`, `develop`, `staging`, `production`)

**Exemples :**

```bash
./scripts/cleanup-branches.sh                     # dry-run
./scripts/cleanup-branches.sh --yes               # exécution locale
./scripts/cleanup-branches.sh --yes --remote      # + nettoyage remote
./scripts/cleanup-branches.sh --yes --keep-backups 2   # garder 2 backups
```

---

## Workflows typiques

### Workflow 1 — Modification de toolchain propagée à toutes les branches

```bash
# 1. Modifier un fichier de config sur main
git checkout main
nano eslint.config.js

# 2. Propager aux branches
./scripts/push-modification-to-all-branches.sh \
  --message "chore(eslint): add a11y rules" \
  --yes

# 3. Récupérer les commits dans main
./scripts/merge-all-into-main.sh --yes

# 4. Nettoyer
./scripts/cleanup-branches.sh --yes
```

### Workflow 2 — Alignement complet des branches sur main

```bash
# 1. Vérifier l'état
./scripts/diagnose.sh

# 2. Aligner chaque branche sur main
./scripts/merge-main-into-branches.sh --yes

# 3. Vérifier
./scripts/diagnose.sh

# 4. Nettoyer
./scripts/cleanup-branches.sh --yes
```

### Workflow 3 — Synchronisation complète (toolchain + merge retour)

```bash
# 1. Dry-run pour voir ce qui serait fait
./scripts/sync-all-branches-and-merge.sh --dry-run

# 2. Exécuter
./scripts/sync-all-branches-and-merge.sh --yes

# 3. Nettoyer
./scripts/cleanup-branches.sh --yes
```

### Workflow 4 — Nettoyage après une session de dev

```bash
# 1. Voir les branches orphelines
./scripts/cleanup-branches.sh

# 2. Exécuter
./scripts/cleanup-branches.sh --yes

# 3. Vérifier
git branch --list
git worktree list
```

---

## Conventions de nommage

### Branches de travail

```
ats-lab/<type>/<scope>[/<sub-scope>]
```

**Types autorisés :** `comp` | `feat` | `fix` | `chore` | `docs` | `spike`

**Exemples :**
- `ats-lab/comp/widgets/kpi-card`
- `ats-lab/feat/auth/rbac`
- `ats-lab/docs/spec/dashboard`

**Regex validée par CI :**
```
^(ats-lab/)?(comp|feat|fix|chore|docs|spike)/[a-z0-9-]+(/[a-z0-9-]+)?$
```

### Branches de backup

```
backup/<type>-<timestamp>
```

**Types :**
- `pre-merge-<ts>` : avant `sync-all-branches-and-merge.sh`
- `pre-align-<ts>` : avant `merge-main-into-branches.sh`
- `pre-merge-all-<ts>` : avant `merge-all-into-main.sh`
- `pre-push-<ts>` : avant `push-modification-to-all-branches.sh`

**Rétention :** 5 backups locales par défaut (configurable).

### Branches temporaires

Ces branches sont créées **dans les worktrees** et supprimées automatiquement. Si tu en vois traîner :

- `sync-tmp-<pid>-<safe-name>`
- `align-tmp-<pid>-<safe-name>`
- `push-tmp-<pid>-<safe-name>`
- `mod-tmp-<pid>-<safe-name>`

**→ Nettoyer avec `cleanup-branches.sh`.**

---

## Dépannage

### Erreur : `Working tree non propre`

```
[err ] Working tree non propre — commit/stash d'abord
```

**Cause :** des fichiers sont modifiés dans le working tree.

**Fix :**

```bash
git status                    # voir les fichiers
git stash push -m "wip"       # sauvegarder
# ou
git add -A && git commit -m "wip"
```

Puis relancer le script.

### Erreur : `unbound variable` à la fin d'un script

```
script.sh: line X: VAR?: unbound variable
```

**Cause :** bug cosmétique, `set -u` combiné à `${VAR?}`.

**Impact :** aucun (le script a déjà fait son travail avant l'erreur).

**Fix :** corriger la ligne en `${VAR:-default}`. Signaler le bug pour correction.

### Erreur : `Unknown option: n` dans `head`

```
Usage: head [-options] <url>...
```

**Cause :** conflit avec un `head` Perl (LWP) dans le PATH.

**Fix permanent :**

```bash
echo 'alias head="/usr/bin/head"' >> ~/.zshrc
source ~/.zshrc
```

**Fix dans le script :** utiliser `head_n()` qui force `/usr/bin/head -n $1`.

### Erreur : `push rejected (non-fast-forward)`

**Cause :** le remote a des commits que tu n'as pas localement.

**Fix :**

```bash
git fetch origin
git pull --rebase origin <branche>
# résoudre les conflits si nécessaire
git push origin <branche>
```

### Erreur : `fatal: refusing to merge unrelated histories`

**Cause :** les branches `ats-lab/*` ont des historiques disjoints.

**Fix :** utiliser `--allow-unrelated-histories` (déjà fait par les scripts).

### Conflits `add/add` non résolus

**Cause :** le fichier existe des deux côtés avec des contenus différents et aucun ancêtre commun.

**Fix :** `merge-main-into-branches.sh` résout automatiquement via `git checkout --theirs`. Si un cas persiste :

```bash
# Dans un worktree
git checkout --theirs <fichier>
git add <fichier>
git commit --no-edit
```

### Worktrees résiduels

**Symptôme :** `.sync-worktrees/` ou `.align-worktrees/` existent encore.

**Fix :**

```bash
./scripts/cleanup-branches.sh --yes
# ou manuellement
git worktree remove --force .sync-worktrees/<nom>
rm -rf .sync-worktrees
```

---

## Sécurité et backups

### Backups automatiques

Chaque script crée une branche backup **avant** toute opération risquée :

| Script | Backup créée |
|---|---|
| `sync-all-branches-and-merge.sh` | `backup/pre-merge-<ts>` |
| `merge-main-into-branches.sh` | `backup/pre-align-<ts>` |
| `merge-all-into-main.sh` | `backup/pre-merge-all-<ts>` |
| `push-modification-to-all-branches.sh` | `backup/pre-push-<ts>` |

Les backups sont poussées sur `origin` → tu peux restaurer même après un `git reset --hard` local.

### Restauration depuis une backup

```bash
# 1. Lister les backups disponibles
git ls-remote --heads origin 'refs/heads/backup/*'

# 2. Restaurer main depuis une backup
git checkout main
git reset --hard origin/backup/pre-merge-all-20261011-203456
git push origin main --force-with-lease
```

**⚠️ `--force-with-lease`** refuse le push si quelqu'un d'autre a poussé entre-temps. C'est safe.

### Rétention des backups

Par défaut, `cleanup-branches.sh` garde les **5 backups les plus récentes**. Tu peux changer :

```bash
./scripts/cleanup-branches.sh --yes --keep-backups 10   # garder 10
./scripts/cleanup-branches.sh --yes --keep-backups 0    # ne rien garder
```

**Recommandation :** garder au moins **3 backups** pour avoir une marge en cas de pépin.

### Ce que les scripts ne font JAMAIS

- ❌ Ne suppriment pas les branches `ats-lab/*` sans confirmation
- ❌ Ne forcent pas `main` sans `--force-with-lease`
- ❌ Ne touchent pas au working tree principal (worktrees isolés)
- ❌ Ne poussent pas de PII dans les commits
- ❌ Ne modifient pas les attributs protégés (age, nationalité, photo)

---

## Aide-mémoire — Commandes rapides

```bash
# Dev local
./scripts/run.sh check                  # valider avant commit
./scripts/run.sh dev                    # serveur de dev

# Diagnostic
./scripts/diagnose.sh                   # état des branches
./scripts/diagnose.sh --files           # fichiers manquants

# Propagation
./scripts/push-modification-to-all-branches.sh --message "..." --yes

# Alignement
./scripts/merge-main-into-branches.sh --dry-run
./scripts/merge-main-into-branches.sh --yes

# Merge retour
./scripts/merge-all-into-main.sh --dry-run
./scripts/merge-all-into-main.sh --yes

# Nettoyage
./scripts/cleanup-branches.sh           # dry-run
./scripts/cleanup-branches.sh --yes     # exécution
```

---

## Contribution

Pour ajouter un nouveau script :

1. Créer `scripts/<nom>.sh`
2. Suivre la structure existante :
   - `set -euo pipefail`
   - Fonctions `log`, `ok`, `warn`, `err`, `sep`
   - Helper `head_n()` pour compat macOS
   - Support `--dry-run` et `--yes`
   - Backup automatique
3. Rendre exécutable : `chmod +x scripts/<nom>.sh`
4. Tester : `bash -n scripts/<nom>.sh`
5. Documenter dans ce README
6. Commit avec un message conventionnel

---

## Licence

Interne ALTEN — Labo FDE. Ne pas distribuer.

---

*Dernière mise à jour : 2026-10-11*
```

---

## 📋 Enregistrement

**Enregistre ce contenu dans `scripts/README.md` :**

```zsh
nano scripts/README.md
```

**Colle le contenu complet** (le bloc markdown ci-dessus, sans les ``` externes).

**Sauvegarde :** `Ctrl+O`, Entrée, `Ctrl+X`.

**Commit :**

```zsh
git add scripts/README.md
git commit -m "docs(scripts): add comprehensive README for git automation"
git push
```

---

## 🎯 Ce que le README couvre

| Section | Contenu |
|---|---|
| **Vue d'ensemble** | Schéma des 7 scripts |
| **Prérequis** | Node, pnpm, git |
| **Scripts** | 7 scripts documentés avec options, comportement, exemples |
| **Workflows** | 4 workflows typiques prêts à copier |
| **Conventions** | Nommage des branches, types, regex CI |
| **Dépannage** | 8 erreurs courantes + fix |
| **Sécurité** | Backups, restauration, rétention |
| **Aide-mémoire** | Commandes rapides |

**Le README est auto-suffisant** : un nouveau développeur peut comprendre l'écosystème en le lisant.

**Veux-tu que je l'ajuste** (langue, niveau de détail, sections supplémentaires) ?