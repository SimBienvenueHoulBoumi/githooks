#!/usr/bin/env bash
# Valide une PR par la CI du projet, puis la merge (workflow release-auto) :
#   ci/merger-pr.sh <n° de PR> <squash|merge>
# Le jeton des Actions ne déclenche pas la CI d'une PR qu'il ouvre : les
# workflows de $WORKFLOWS sont lancés en workflow_dispatch sur la branche de la
# PR, leur résultat réel est reporté en statuts sur le commit (vérifications
# exigées par la protection de la branche cible), puis la PR est mergée.
# Sert à la PR de release (squash) et au retour de main dans la branche
# d'intégration (mode cycle, merge commit) : aucune clé ni jeton à fournir.
# Environnement : GH_TOKEN, GH_REPO, WORKFLOWS, BASE (branche cible),
# MERGE_AUTO (true par défaut), GITHUB_OUTPUT (sorties merged, waiting_pr).
set -euo pipefail

pr="${1:?n° de PR}"
METHOD="${2:-squash}"
MERGE_AUTO="${MERGE_AUTO:-true}"
if [ "$METHOD" = squash ]; then
    APRES=" : la release est publiée par le run de ce merge"
    APRES_HUMAIN=" : son merge publiera la release."
else
    APRES="" APRES_HUMAIN="."
fi

# Erreurs 5xx passagères de l'API GitHub : nouvelles tentatives espacées
reessayer() {
  for i in 1 2 3 4 5; do
    "$@" && return 0
    echo "↻ échec ($i/5) : $*"
    sleep $((i * 15))
  done
  return 1
}
# Runs « pull_request » de la PR de release mis en attente d'approbation
# (GitHub traite le bot comme un contributeur externe) : approuvés,
# uniquement pour le commit exact de la branche de release
approuver_runs() {
  gh api "repos/$GH_REPO/actions/runs?status=action_required&head_sha=$sha" \
    --jq '.workflow_runs[].id' | while IFS= read -r id; do
      gh api -X POST "repos/$GH_REPO/actions/runs/$id/approve" >/dev/null &&
        echo "✔ run $id approuvé"
    done || true
}
branch="$(gh pr view "$pr" --json headRefName -q .headRefName)"
# Commit lu sur la branche ; la PR peut l'afficher avec un léger
# retard : on attend qu'elle suive (sinon --match-head-commit échoue)
sha="$(gh api "repos/$GH_REPO/commits/$branch" --jq .sha)"
for _ in $(seq 1 30); do
  [ "$(gh pr view "$pr" --json headRefOid -q .headRefOid)" = "$sha" ] && break
  sleep 5
done
echo "PR #$pr ($branch @ ${sha:0:7}) : CI"
runs=""
for wf in $WORKFLOWS; do
  reessayer gh workflow run "$wf" --ref "$branch"
done
for wf in $WORKFLOWS; do
  run_id=""
  for _ in $(seq 1 30); do
    run_id="$(gh run list --workflow "$wf" --branch "$branch" --event workflow_dispatch \
      --commit "$sha" --limit 1 --json databaseId -q '.[0].databaseId')"
    [ -n "$run_id" ] && break
    sleep 5
  done
  [ -n "$run_id" ] || { echo "✖ Run de $wf introuvable"; exit 1; }
  runs="$runs $run_id"
done
for id in $runs; do
  if ! gh run watch "$id" --exit-status --interval 30 >/dev/null; then
    # CI interrompue par un merge manuel (branche de release supprimée)
    [ "$(gh pr view "$pr" --json state -q .state)" != MERGED ] ||
      { echo "✔ PR #$pr mergée manuellement$APRES"; exit 0; }
    echo "✖ CI en échec : $(gh run view "$id" --json url -q .url)"
    exit 1
  fi
done
# Vérifications exigées par la protection de la branche : résultat
# réel de chacune (cherché dans les runs lancés), reporté en statut
gh api "repos/$GH_REPO/rules/branches/$BASE" \
  --jq '.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context' |
  while IFS= read -r ctx; do
    conclusion="" url=""
    for id in $runs; do
      conclusion="$(gh run view "$id" --json jobs \
        -q ".jobs[] | select(.name==\"$ctx\") | .conclusion")"
      [ -n "$conclusion" ] && { url="$(gh run view "$id" --json url -q .url)"; break; }
    done
    if [ "$conclusion" != success ]; then
      echo "✖ $ctx : ${conclusion:-absent des workflows lancés (entrée « workflows »)}"
      exit 1
    fi
    gh api "repos/$GH_REPO/statuses/$sha" -f state=success -f context="$ctx" \
      -f target_url="$url" -f description="CI de la PR (workflow_dispatch)" >/dev/null
    echo "✔ $ctx"
  done
# D'autres vérifications peuvent aussi tourner sur la PR (workflows
# pull_request) : on attend que GitHub la déclare mergeable (toutes
# les vérifications terminées et vertes) ; sinon, pas de merge.
for _ in $(seq 1 90); do
  # Mergée (ou fermée) par une personne entre-temps : son merge
  # relance ce workflow, qui publie la release ; rien d'autre à faire
  case "$(gh pr view "$pr" --json state -q .state)" in
    MERGED) echo "✔ PR #$pr mergée manuellement$APRES"; exit 0 ;;
    CLOSED) echo "PR #$pr fermée sans merge"; exit 0 ;;
  esac
  state="$(gh pr view "$pr" --json mergeStateStatus -q .mergeStateStatus)"
  case "$state" in
    CLEAN | BEHIND) break ;;
    BLOCKED | UNKNOWN | UNSTABLE)
      # Relecture humaine exigée : la PR attend son approbation
      case "$(gh pr view "$pr" --json reviewDecision -q .reviewDecision)" in
        REVIEW_REQUIRED | CHANGES_REQUESTED)
          echo "::notice::PR #$pr validée par la CI, en attente d'approbation humaine$APRES_HUMAIN"
          echo "waiting_pr=$pr" >>"${GITHUB_OUTPUT:-/dev/null}"
          exit 0
          ;;
      esac
      approuver_runs
      sleep 30
      ;;
    *) echo "✖ PR #$pr non mergeable : $state"; exit 1 ;;
  esac
done
# La branche a avancé pendant la CI : version et changelog sont à
# recalculer (un simple « update branch » publierait les nouveaux
# commits sous l'ancienne version). Le run déclenché par ce push
# régénère la PR ; s'il n'y en a pas (push du jeton des Actions), on
# le lance.
if [ "$state" = BEHIND ] && [ "$METHOD" = squash ]; then
  wf="${GITHUB_WORKFLOW_REF#*/.github/workflows/}"
  wf="${wf%%@*}"
  suivant="$(gh run list --workflow "$wf" --branch "$GITHUB_REF_NAME" --limit 20 --json databaseId,status \
    -q "[.[] | select(.databaseId != $GITHUB_RUN_ID and .status != \"completed\")] | length")"
  [ "${suivant:-0}" != 0 ] || reessayer gh workflow run "$wf" --ref "$GITHUB_REF_NAME"
  echo "::notice::$GITHUB_REF_NAME a avancé pendant la CI : la PR #$pr est recalculée par le run suivant."
  exit 0
fi
case "$state" in CLEAN | BEHIND) ;; *) echo "✖ PR #$pr toujours $state après 45 min"; exit 1 ;; esac
if [ "$MERGE_AUTO" != true ]; then
  echo "::notice::PR #$pr validée par la CI, à merger par un humain (merge-auto: false)$APRES_HUMAIN"
  echo "waiting_pr=$pr" >>"${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi
reessayer gh pr merge "$pr" "--$METHOD" --match-head-commit "$sha"
echo "merged=true" >>"${GITHUB_OUTPUT:-/dev/null}"
# Branche de la PR de release supprimée (un merge du jeton des Actions ne
# déclenche pas le workflow de nettoyage) ; jamais main ni develop (retour)
case "$branch" in
    release-please--*) gh api -X DELETE "repos/$GH_REPO/git/refs/heads/$branch" >/dev/null 2>&1 || true ;;
esac
exit 0
