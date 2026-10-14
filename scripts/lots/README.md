# scripts/lots — générateurs de lots

## Vue d'ensemble

Chaque `build-lot-N.sh` **génère** les artefacts d'un lot sur sa branche pivot,
puis délègue le push à `push-lot.sh`. L'orchestrateur `build-all.sh` enchaîne
L1..L7.

## Usage

```zsh
chmod +x scripts/lots/*.sh

# Dry-run (défaut) — n'écrit rien, ne commite rien, ne pousse rien
./scripts/lots/build-all.sh --dry-run
./scripts/lots/build-lot-5.sh --dry-run

# Exécution réelle
./scripts/lots/build-all.sh --yes
./scripts/lots/build-lot-5.sh --yes

# Sous-ensemble
./scripts/lots/build-all.sh --yes --only 1,3,5