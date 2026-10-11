# ATS Copilot Dashboard

[![Dashboard CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/dashboard-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/dashboard-ci.yml)
[![A11y CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/a11y-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/a11y-ci.yml)
[![i18n CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/i18n-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/i18n-ci.yml)
[![Storybook CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/storybook-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/storybook-ci.yml)
[![Security CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/security-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/security-ci.yml)

Copilote IA pour le pré-screening des candidats FDE (France / Porto).

## Contexte

- **Client** : ALTEN — équipe Forward Deployed Engineer (FDE)
- **Use case** : copilote IA pour le pré-screening des candidats FDE
- **Principe cardinal** : l'humain décide toujours. Le dashboard est **read-only**
- **KPI cible** : −50 % sur le temps médian de pré-screening par candidat
- **Conformité** : RGPD, EU AI Act (Annexe III), résidence EU des données

## Prérequis

- Node ≥ 20 (recommandé : 22)
- pnpm ≥ 9 (`corepack enable && corepack prepare pnpm@9.6.0 --activate`)

## Démarrage rapide

```bash
./scripts/run.sh install
./scripts/run.sh dev      # http://localhost:5173
./scripts/run.sh check    # lint + typecheck + test + build
