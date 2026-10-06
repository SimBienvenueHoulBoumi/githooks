# Hooks et règles

## Les hooks

| Hook | Rôle |
|---|---|
| `post-checkout` | Avertit dès qu'on arrive sur une branche mal nommée (non bloquant) |
| `pre-commit` | Refuse les branches mal nommées, bloque les commits directs sur `main`/`master`, détecte les secrets, formate **uniquement le contenu stagé** (le travail non stagé est préservé) |
| `prepare-commit-msg` | Préfixe le message d'après la branche : sur `feat/bean`, `git commit -m "ajoute X"` → `feat(bean): ajoute X` |
| `commit-msg` | Impose [Conventional Commits](https://www.conventionalcommits.org), 72 caractères maximum |
| `pre-push` | Refuse les branches mal nommées ; build et tests **du commit poussé**, seulement pour les projets touchés |
| `post-merge` | Après un `git pull` : supprime les branches locales mergées (classique ou squash) dont la branche distante a été supprimée ; jamais une branche contenant du travail non intégré |

Contournement ponctuel : `git commit --no-verify`, `git push --no-verify` — la [CI](ci.md) refait les vérifications.

## Messages de commit

Format `<type>(<scope>): <description>` ; `!` après le type pour un changement majeur (`feat!: …`).

| Type | Usage | Release |
|---|---|---|
| `feat` | nouvelle fonctionnalité | version mineure (1.**4**.0) |
| `fix` | correction de bug | correctif (1.4.**1**) |
| `perf` | performance | correctif |
| `docs` | documentation | correctif |
| `style`, `refactor`, `test`, `build`, `ci`, `chore`, `revert` | formatage, restructuration, tests, build, CI, maintenance, annulation | aucune à eux seuls |

Un `!` (`feat!: …`) ou un pied de page `BREAKING CHANGE:` donne une **version majeure**. Voir [releases automatiques](industrialisation.md#2-versions-et-releases-automatiques).

## Assistant de commit : `git cc`

Pour écrire un message conforme sans retenir le format, `git cc` guide pas à pas (alias installé par `install.sh`) :

```text
$ git cc
Type de changement :
   1) feat      nouvelle fonctionnalité
   2) fix       correction de bug
   …
Type [feat] :                                   ← proposé d'après la branche feat/panier
Scope (optionnel, « - » pour aucun) [panier] :
Changement incompatible (version majeure) ? [o/N] :
Description (58 caractères max) : feat(panier): ajoute le panier
Corps (optionnel) : explique le pourquoi ; ligne vide pour terminer.
> Le client garde ses articles entre deux visites.
>
Références (optionnel, ex. Closes #12) : Closes #12

──── Message ────
feat(panier): ajoute le panier

Le client garde ses articles entre deux visites.

Closes #12
─────────────────
Commiter ? [O/n] :
```

| Étape | Obligatoire | Aide |
|---|---|---|
| Type | oui | menu, proposé d'après la branche |
| Scope | non | proposé d'après la branche |
| Changement incompatible | non | ajoute `!` et le pied `BREAKING CHANGE: …` |
| Description | oui | longueur de l'en-tête contrôlée (72 caractères) |
| Corps | non | plusieurs lignes : le pourquoi |
| Références | non | `Closes #12`, `Refs #34`… |

Les options de `git commit` sont transmises (`git cc --no-verify`…) ; `bin/commit --dry-run` affiche le message sans commiter. Avec lefthook sans `install.sh` : `git config --global alias.cc '!bash /chemin/vers/repogarde/bin/commit'`.

## Nommage des branches

Format `<type>/<sujet>` (sujet en `a-z0-9._-`, `/` pour sous-découper) : `feat/inscription`, `fix/user/login`, `hotfix/timeout-db`.

- Averti à la création, refusé au commit et au push, avec la commande de renommage à copier.
- Exceptions par défaut : `main`, `master`, `develop`, `release/*` (réglage `allowedBranches`).
- Le type devient le préfixe du commit, le sujet son scope (omis au-delà de 20 caractères).
- Alias : `feature/` → `feat`, `bugfix/` et `hotfix/` → `fix`.
- Un message déjà conforme n'est jamais modifié ; merge, squash et amend sont ignorés.

!!! tip "Git n'a pas de hook à la création de branche"
    Le nom est donc vérifié au premier commit et au push. Pour l'imposer côté serveur, voir les [règles serveur](ci.md#regles-cote-serveur).
