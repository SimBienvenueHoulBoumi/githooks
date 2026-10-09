# Tickets

Chaque changement part d'un **ticket** (issue GitHub) : **la branche découle du ticket**, et chaque étape de la vie du ticket fait avancer la branche et la PR, de l'idée à la production, sans suivi manuel.

## Le cycle d'un ticket

| Statut (étiquette) | Quand | Effet automatique |
|---|---|---|
| `statut: à valider` | ticket créé (à la main, ou `repowarden ticket nouveau`) | — |
| `statut: backlog` | un mainteneur pose l'étiquette **`validé`**, ou ouvre lui-même le ticket (validé d'office) | **branche `<type>/<n°>-<titre>` créée** depuis `develop` et **liée au ticket** (panneau *Development*) ; commentaire avec la commande pour la récupérer |
| `statut: en cours` | quelqu'un s'assigne le ticket, ou pousse un premier commit sur sa branche | au premier push : **PR en brouillon** ouverte vers `develop`, `Ticket : #n`, assignée |
| `statut: en relecture` | PR « Ready for review » | la CI tourne ; une revue « Request changes » ramène le ticket en cours |
| `statut: préprod` | PR mergée dans `develop` | branche supprimée ; commentaire à chaque préversion `vX.Y.Z-next.N` |
| `statut: done` | release sur `main` | ticket **fermé**, avec la version |

Ticket fermé comme **abandonné** (*not planned*) : sa PR est fermée et sa branche supprimée.

Tout est automatique, sauf la validation : c'est la seule décision humaine, et GitHub ne laisse poser l'étiquette `validé` qu'aux personnes ayant les droits sur le dépôt. Un ticket **ouvert par un mainteneur** (droits d'écriture : propriétaire, membre, collaborateur) est **validé d'office** : l'ouvrir est déjà sa décision. Seuls les tickets de la communauté attendent l'étiquette. Pour une validation toujours séparée : entrée `auto-validate: never` du workflow `tickets.yml`. Le type de la branche vient de l'étiquette `type: …` du ticket (`feat` par défaut), son nom du titre (minuscules, sans accents).

## Sur le poste

```bash
repowarden ticket 12                          # se place sur la branche du ticket #12
repowarden ticket nouveau "Ajoute le panier"   # crée un ticket (à valider)
repowarden ticket                             # ticket de la branche courante
```

- `repowarden ticket <n>` récupère la branche créée à la validation. Si elle n'existe pas encore (suivi des tickets non installé), elle est créée et liée au ticket avec `gh issue develop`.
- **Branche sans ticket** : `repowarden` prévient (à l'arrivée sur la branche et dans `git cc`), **sans jamais bloquer** : tout le monde ne travaille pas avec des tickets. Si le projet fait gérer ses tickets par repowarden, il **propose d'en créer un** (`git cc` le crée et le cite sur un « oui ») ; sinon, il indique comment ne plus le voir : `git config repowarden.skip tickets`.
- `git cc` cite `Ticket : #12` sur une branche `feat/12-…`.

## Les règles

- **Pas de PR sans ticket** : une PR cite son ticket dans sa description (`Ticket : #12`), ou sa branche le porte (`feat/12-panier`). Sinon, le ticket est **créé automatiquement** à partir de la PR, relié à sa description, et « à valider ».
- **Pas de merge sans ticket validé** : la vérification `ticket` de la PR échoue tant que son ticket n'a pas l'étiquette `validé`. Elle passe dès que l'étiquette est posée, sans rien relancer. Le job `tickets` reste vert pendant l'attente : un job rouge signale une vraie panne.
- Les bots de dépendances, les PR de release et les livraisons `develop` → `main` n'ont pas besoin de ticket.
- La PR en brouillon est ouverte par le jeton des Actions, qui ne déclenche pas d'autre workflow : la CI tourne au push suivant, ou au passage « Ready for review » (`ready_for_review` dans les déclencheurs de la CI, comme dans le modèle de projet).

!!! note "Pourquoi `Ticket : #12` et pas `Closes #12`"
    `Closes #12` ferme le ticket dès le merge dans la branche par défaut, c'est-à-dire `develop` : il serait « done » avant d'être en production. Ici, c'est la release sur `main` qui le ferme.

## Mise en place

```bash
repowarden tickets init          # étiquettes, modèle de ticket, workflow tickets.yml
git add .github && git cc       # puis PR
repowarden proteger --checks "repowarden,ticket"   # vérification « ticket » exigée
```

Dans `.github/workflows/release.yml`, les tickets passent en préprod à chaque préversion et en done à chaque release :

```yaml
  tickets:
    needs: release
    if: needs.release.outputs.release_created == 'true' || needs.release.outputs.prerelease_created == 'true'
    uses: SimBienvenueHoulBoumi/repowarden/.github/workflows/tickets.yml@v4
    permissions: { contents: write, issues: write, pull-requests: write, statuses: write }
    with:
      tag: ${{ needs.release.outputs.tag_name || needs.release.outputs.prerelease_tag }}
```

Un `tickets.yml` existant n'est jamais écrasé : pour la branche créée à la validation et la PR en brouillon, y ajouter les événements `pull_request_review`, `issues` (`assigned`, `closed`), `push`, et la permission `contents: write` (voir le modèle écrit par `repowarden tickets init`).

Aucune clé ni jeton : tout passe par le jeton des Actions. Le workflow utilise `pull_request_target` sans jamais récupérer le code de la PR : les PR venant de forks sont traitées en sécurité.

## Tableau

Les statuts sont des étiquettes : un [GitHub Project](https://docs.github.com/fr/issues/planning-and-tracking-with-projects) en vue tableau, groupé par étiquette (ou avec une colonne filtrée par statut), donne le tableau backlog → done. Il se règle une fois, dans l'interface de GitHub ; le workflow n'y touche pas (les Projects d'un compte personnel ne sont pas accessibles au jeton des Actions).
