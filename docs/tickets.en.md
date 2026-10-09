# Tickets

Every change is tied to a **ticket** (GitHub issue): you know why it exists, who validated it, and where it stands, from the idea to production.

## A ticket's life cycle

| Status (label) | When | Trigger |
|---|---|---|
| `statut: à valider` | ticket created, by hand or automatically | creation |
| `statut: backlog` | ticket accepted | a maintainer adds the **`validé`** label |
| `statut: en cours` | work started | draft PR citing the ticket |
| `statut: en relecture` | PR ready | PR "Ready for review" |
| `statut: préprod` | merged into `develop`, testable | PR merged; comment on each `vX.Y.Z-next.N` pre-release |
| `statut: done` | in production | release on `main`: ticket **closed**, with the version |

Everything is automatic except validation: it is the only human decision, and GitHub only lets people with rights on the repository add the `validé` label.

## The rules

- **No PR without a ticket**: a PR cites its ticket in its description (`Ticket: #12`), or its branch carries it (`feat/12-cart`). Otherwise the ticket is **created automatically** from the PR, linked in its description, and "to be validated".
- **No merge without a validated ticket**: the PR's `ticket` check fails until its ticket has the `validé` label. It passes as soon as the label is added, nothing to re-run.
- **`git cc`** suggests `Ticket : #12` as a reference on a `feat/12-…` branch.
- Dependency bots, release PRs and `develop` → `main` deliveries need no ticket.

!!! note "Why `Ticket: #12` and not `Closes #12`"
    `Closes #12` closes the ticket as soon as it is merged into the default branch, that is `develop`: it would be "done" before reaching production. Here, the release on `main` closes it.

## Setup

```bash
repowarden tickets init          # labels, ticket template, tickets.yml workflow
git add .github && git cc       # then a PR
repowarden proteger --checks "repowarden,ticket"   # "ticket" check required
```

In `.github/workflows/release.yml`, tickets move to pre-production on each pre-release and to done on each release:

```yaml
  tickets:
    needs: release
    if: needs.release.outputs.release_created == 'true' || needs.release.outputs.prerelease_created == 'true'
    uses: SimBienvenueHoulBoumi/repowarden/.github/workflows/tickets.yml@v4
    permissions: { issues: write, pull-requests: write, statuses: write }
    with:
      tag: ${{ needs.release.outputs.tag_name || needs.release.outputs.prerelease_tag }}
```

No key or token: everything goes through the Actions token. The workflow uses `pull_request_target` without ever fetching the PR's code: PRs from forks are handled safely.

## Board

Statuses are labels: a [GitHub Project](https://docs.github.com/en/issues/planning-and-tracking-with-projects) in board view, grouped by label (or one column filtered per status), gives the backlog → done board. It is set up once, in GitHub's interface; the workflow does not touch it (personal-account Projects are not accessible to the Actions token).
