# Hooks et règles

## Les hooks

| Hook | Rôle |
|---|---|
| `post-checkout` | Avertit dès qu'on arrive sur une branche mal nommée (non bloquant) |
| `pre-commit` | Refuse les branches mal nommées, bloque les commits directs sur les branches protégées (`main`/`master` par défaut), détecte les secrets, formate **uniquement le contenu stagé** (le travail non stagé est préservé) |
| `prepare-commit-msg` | Préfixe le message d'après la branche : sur `feat/bean`, `git commit -m "ajoute X"` → `feat(bean): ajoute X` |
| `commit-msg` | Impose [Conventional Commits](https://www.conventionalcommits.org), 72 caractères maximum |
| `pre-push` | Refuse les branches mal nommées et le push direct sur les branches protégées (`protectedBranches`, création initiale permise) ; build et tests **du commit poussé**, seulement pour les projets touchés |
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

Pour écrire un message conforme sans retenir le format, `git cc` guide pas à pas (alias installé par `install.sh`), dans la langue choisie à l'installation :

```text
$ git cc
◆ repogarde · commit conventionnel
Entrée = valeur proposée entre [crochets] · Ctrl+C pour abandonner

◇ 1/5  Type de changement
   1  ✨  feat      nouvelle fonctionnalité
   2  🐛  fix       correction de bug
   …
Numéro ou nom [feat] :                          ← proposé d'après la branche feat/panier

◇ 2/5  Scope (optionnel)
Scope (« - » pour aucun) [panier] :

◇ 3/5  Changement incompatible ?
Incompatible ? [o/N] :

◇ 4/5  Description
  À l'impératif, sans majuscule initiale ni point final ; 58 caractères au plus.
feat(panier): ajoute le panier

◇ 5/5  Détails (optionnels)
> Le client garde ses articles entre deux visites.
>
Références (ex. Closes #12 ; Entrée pour aucune) : Closes #12

┌─ Message ───────────────────────────────────────────────
│ feat(panier): ajoute le panier
│
│ Le client garde ses articles entre deux visites.
│
│ Closes #12
└─────────────────────────────────────────────────────────
Commiter ? [O/n] :
```

| Étape | Obligatoire | Aide |
|---|---|---|
| Type | oui | menu (numéro ou nom), proposé d'après la branche |
| Scope | non | proposé d'après la branche ; un scope invalide est corrigé et proposé (« doc test » → `doc-test`) |
| Changement incompatible | non | ajoute `!` et le pied `BREAKING CHANGE: …`, décrit aussitôt (10 caractères au moins) ; question sautée au premier commit du dépôt |
| Description | oui | longueur de l'en-tête contrôlée (72 caractères) ; point final retiré |
| Corps | non | plusieurs lignes : le pourquoi ; une ligne vide (ou seulement `;`, `.`) termine |
| Références | non | exemple adapté à la plateforme : `Closes #12`, `!34` (GitLab), `PROJ-42` (Bitbucket) |

**Sur une branche protégée** (`main`…), le commit serait refusé : l'assistant le dit dès l'étape 2 et propose une branche `<type>/<scope>` (Entrée pour la créer, tes modifications suivent ; « n » pour abandonner). Une réponse incomplète est complétée (`feat` → `feat/<scope>`), un nom approximatif corrigé (`Mon Essai` → `feat/mon-essai`).

**Saisie robuste** : flèches et effacement dans un terminal, touches parasites ignorées ; une réponse oui/non invalide est redemandée ; Ctrl+D abandonne. Si un hook refuse le commit, le message est conservé (`git commit -F .git/repogarde-message` après correction).

Les options de `git commit` sont transmises (`git cc --no-verify`…) ; `git cc --dry-run` affiche le message sans commiter. Réponses fournies par un script (une par ligne sur l'entrée standard) : `git cc --strict`, pour qu'une réponse refusée arrête tout au lieu de lire la ligne suivante comme une nouvelle réponse. Avec lefthook sans `install.sh` : `git config --global alias.cc '!bash /chemin/vers/repogarde/bin/commit'`.

## Nommage des branches

Format `<type>/<sujet>` (sujet en `a-z0-9._-`, `/` pour sous-découper) : `feat/inscription`, `fix/user/login`, `hotfix/timeout-db`.

- Averti à la création, refusé au commit et au push, avec la commande de renommage à copier.
- Exceptions par défaut : `main`, `master`, `develop`, `release/*` et les branches des bots (`release-please--*`, `dependabot/*`, `renovate/*`) ; réglage `allowedBranches`.
- Le type devient le préfixe du commit, le sujet son scope (omis au-delà de 20 caractères).
- Alias : `feature/` → `feat`, `bugfix/` et `hotfix/` → `fix`.
- Un message déjà conforme n'est jamais modifié ; merge, squash et amend sont ignorés.

!!! tip "Git n'a pas de hook à la création de branche"
    Le nom est donc vérifié au premier commit et au push. Pour l'imposer côté serveur, voir les [règles serveur](ci.md#regles-cote-serveur).
