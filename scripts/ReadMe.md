# Scripts — organisation

Quatre sous-dossiers, un `_lib.sh` de helpers par dossier.

## `git/` — Git & propagation

Aucun script ici n'exécute `pnpm`/`npm`. Uniquement du git.

| Script | Rôle |
|---|---|
| `propagate.sh` | Pousse fichiers/dossiers sur toutes les `ats-lab/*` |
| `propagate-workflow.sh` | Cas particulier : `.github/workflows/` uniquement |
| `push-all.sh` | Push toutes les branches locales |
| `merge-to-main.sh` | Merge des `ats-lab/*` dans `main` |
| `merge-all-branches-to-main.sh` | Variante historique |
| `merge-main-into-branches.sh` | Propage `main` sur toutes les `ats-lab/*` |
| `cleanup-branches.sh` | Supprime les branches mergées |
| `backup.sh` | Backup horodaté (branches + bundle + working tree) |
| `restore-backup.sh` | Restaure les refs d'un backup |
| `diagnose.sh` | Rapport d'état des branches |
| `sync-and-merge.sh` | Sync remote puis merge |
| `publish.sh` | Push vers un remote donné |
| `publish-to-fde-lab.sh` | Publish dédié FDE_LAB |

## `build/` — Toolchain & dev

Aucun `git push`/`merge` ici.

| Script | Rôle |
|---|---|
| `run.sh` | Point d'entrée dev unifié (install/dev/build/test/lint/check) |
| `setup-toolchain.sh` | Toolchain minimale (package.json, configs) |
| `build-full-dashboard.sh` | Génère le dashboard complet |
| `run-dashboard.sh` | Lance Vite avec mock data |
| `generate-widgets.sh` | Génère les widgets Phase 1+2 |

## `quality/` — Tests, lint, corrections

| Script | Rôle |
|---|---|
| `check.sh` | Check complet : lint + typecheck + test + build + a11y + i18n |
| `test-unit.sh` | Vitest unit (`[pattern]` optionnel) |
| `test-a11y.sh` | Vitest + jest-axe |
| `test-e2e.sh` | Playwright (stub) |
| `lint.sh` | ESLint (+ `--fix`) |
| `typecheck.sh` | tsc --noEmit |
| `correction-eslint.sh` | Patch ESLint 9 + AppShell |
| `correction-tsc.sh` | Patch erreurs TypeScript |
| `correction-tests.sh` | Patch tests rouges |
| `check-i18n-parity.ts` | Vérifie parité FR/EN |

## `ci/` — GitHub Actions

| Script | Rôle |
|---|---|
| `ci-status.sh` | État du dernier run CI (gh CLI) |
| `ci-report.sh` | Affiche `.ci-reports/<branch>.md` |

## Conventions

- **Bash 3.2 safe** : pas de `mapfile`, `${arr[@]+"${arr[@]}"}` sur arrays vides, `set -euo pipefail`.
- **Couleurs** : définies dans chaque `_lib.sh`, désactivées si pas de TTY.
- **Backups** : tout script destructif écrit dans `.backups/<type>-<timestamp>/`.
- **Rollback** : `--rollback` quand disponible, sinon `cp -R`.

## Aliases utiles

```zsh
alias run='./scripts/build/run.sh'
alias qcheck='./scripts/quality/check.sh'
alias gpush='./scripts/git/propagate.sh'
