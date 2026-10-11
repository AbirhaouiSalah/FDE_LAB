# T<NN> — <Titre court>

**Branche :** `ats-lab/<type>/<scope>/<name>`
**Prérequis :** T<XX> mergée sur `main`
**Bloque :** T<YY>, T<ZZ>
**Effort estimé :** S / M / L

## Contexte
<2-3 phrases : pourquoi cette tâche existe>

## Livrables
- [ ] `<chemin/fichier1>`
- [ ] `<chemin/fichier2>`
- [ ] Tests : `<fichier>.test.tsx`, `<fichier>.a11y.test.tsx`, `<fichier>.stories.tsx`
- [ ] Couverture ≥ 80 % sur les fichiers modifiés

## Contraintes invariantes (rappel §4)
1. Jamais de PII
2. Suppression petits groupes (n < 5)
3. RBAC enforced
4. Version awareness (`rubric_version`)
5. Traçabilité (lien définition + last_refresh)
6. Pas de décisions automatiques (read-only)
7. FR-first + a11y (contraste AA, clavier)

## Critères d'acceptation
- [ ] `./scripts/run.sh check` passe
- [ ] `./scripts/run.sh test <pattern>` passe
- [ ] `<comportement observable 1>`
- [ ] `<comportement observable 2>`

## Commandes
```zsh
git checkout -b ats-lab/<type>/<scope>/<name> main
# ... éditer ...
./scripts/run.sh check
git add -A && git commit -m "<type>(<scope>): <desc>"
git push origin HEAD:refs/heads/ats-lab/<type>/<scope>/<name>