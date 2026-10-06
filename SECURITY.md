# Politique de sécurité

## Versions supportées

| Version | Supportée |
|---|---|
| Dernière version majeure (`v1`) | ✅ correctifs de sécurité |
| Versions majeures précédentes | ❌ |

## Signaler une vulnérabilité

**Ne pas ouvrir d'issue publique.** Utiliser le signalement privé de GitHub :
onglet *Security* → *Report a vulnerability*.

Inclure : version concernée, scénario de reproduction, impact estimé.

Délais visés : accusé de réception sous 3 jours ouvrés, correctif ou plan d'action sous 30 jours.

## Ce que githooks fait pour la sécurité

- Détection de secrets (gitleaks) dans les hooks et en CI ; gitleaks installé en CI à **version figée avec somme SHA-256 vérifiée**.
- Actions GitHub figées par SHA, mises à jour par Dependabot.
- Aucun secret utilisé par les workflows hors `GITHUB_TOKEN` (lecture seule par défaut) et le jeton optionnel de release.
- Les hooks n'exécutent que les outils installés sur le poste ou déclarés par le projet ; aucun téléchargement au moment du commit.
