# Tickets

Chaque changement est rattaché à un **ticket** (issue GitHub) : on sait pourquoi il existe, qui l'a validé, et où il en est, de l'idée à la production.

## Le cycle d'un ticket

| Statut (étiquette) | Quand | Déclencheur |
|---|---|---|
| `statut: à valider` | ticket créé, à la main ou automatiquement | création |
| `statut: backlog` | ticket accepté | un mainteneur pose l'étiquette **`validé`** |
| `statut: en cours` | travail commencé | PR en brouillon qui cite le ticket |
| `statut: en relecture` | PR prête | PR « Ready for review » |
| `statut: préprod` | mergé dans `develop`, testable | merge de la PR ; commentaire à chaque préversion `vX.Y.Z-next.N` |
| `statut: done` | en production | release sur `main` : ticket **fermé**, avec la version |

Tout est automatique, sauf la validation : c'est la seule décision humaine, et GitHub ne laisse poser l'étiquette `validé` qu'aux personnes ayant les droits sur le dépôt.

## Les règles

- **Pas de PR sans ticket** : une PR cite son ticket dans sa description (`Ticket : #12`), ou sa branche le porte (`feat/12-panier`). Sinon, le ticket est **créé automatiquement** à partir de la PR, relié à sa description, et « à valider ».
- **Pas de merge sans ticket validé** : la vérification `ticket` de la PR échoue tant que son ticket n'a pas l'étiquette `validé`. Elle passe dès que l'étiquette est posée, sans rien relancer.
- **`git cc`** propose `Ticket : #12` en référence sur une branche `feat/12-…`.
- Les bots de dépendances, les PR de release et les livraisons `develop` → `main` n'ont pas besoin de ticket.

!!! note "Pourquoi `Ticket : #12` et pas `Closes #12`"
    `Closes #12` ferme le ticket dès le merge dans la branche par défaut, c'est-à-dire `develop` : il serait « done » avant d'être en production. Ici, c'est la release sur `main` qui le ferme.

## Mise en place

```bash
repogarde tickets init          # étiquettes, modèle de ticket, workflow tickets.yml
git add .github && git cc       # puis PR
repogarde proteger --checks "repogarde,ticket"   # vérification « ticket » exigée
```

Dans `.github/workflows/release.yml`, les tickets passent en préprod à chaque préversion et en done à chaque release :

```yaml
  tickets:
    needs: release
    if: needs.release.outputs.release_created == 'true' || needs.release.outputs.prerelease_created == 'true'
    uses: SimBienvenueHoulBoumi/repogarde/.github/workflows/tickets.yml@v3
    permissions: { issues: write, pull-requests: write, statuses: write }
    with:
      tag: ${{ needs.release.outputs.tag_name || needs.release.outputs.prerelease_tag }}
```

Aucune clé ni jeton : tout passe par le jeton des Actions. Le workflow utilise `pull_request_target` sans jamais récupérer le code de la PR : les PR venant de forks sont traitées en sécurité.

## Tableau

Les statuts sont des étiquettes : un [GitHub Project](https://docs.github.com/fr/issues/planning-and-tracking-with-projects) en vue tableau, groupé par étiquette (ou avec une colonne filtrée par statut), donne le tableau backlog → done. Il se règle une fois, dans l'interface de GitHub ; le workflow n'y touche pas (les Projects d'un compte personnel ne sont pas accessibles au jeton des Actions).
