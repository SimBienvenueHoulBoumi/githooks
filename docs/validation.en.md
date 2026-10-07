# Human approval

repogarde automates what is **mechanical and verifiable**:
- formatting;
- checking a message, a branch name or a PR target;
- computing a version, writing a changelog, creating a tag;
- building and signing a package.

These actions always produce the same result for the same input, and each one is traceable (CI logs, provenance attestations).

What requires **judgment** stays human:
- does this code do what we want?
- is this the right time to deliver?
- can we publish?

The risk is not the machine. It is human approval that is too light. This page describes how to make it mandatory.

## Decision points

| Decision | GitHub mechanism | repogarde |
|---|---|---|
| Review code before it gets in | required approvals; approval dismissed by a new commit; the last pusher cannot approve their own push | `bin/proteger --relecteurs N` |
| Have sensitive areas reviewed by their owners | `CODEOWNERS` file + required code owner review | `bin/proteger --codeowners` |
| Decide to publish | deployment environment: the job waits for approval from a designated person | `bin/proteger --environnement production` |
| Decide to deliver (`develop` flow) | `develop` → `main` delivery PR, always merged by a human | `tag` mode |
| Keep control over the release PR (`pr` mode) | human merge | `release-auto` with `merge-auto: false` |

With a required review, the release PR is never merged by the bot. The bot prepares it and has CI validate it, then it waits for human approval. Merging it publishes the release.

## Setup

Settings versioned in `.repogarde.conf`, applied by `bin/proteger` (can be re-run):

```ini
[repogarde]
    requiredReviews = 1              # approvals per PR
    codeOwnerReview = true           # CODEOWNERS review on their files
    environment = production         # deployments subject to approval
    environmentReviewers = alice bob # default: the current gh user
```

```text title=".github/CODEOWNERS"
# One pattern per line; the last matching rule wins
*                  @equipe-dev
# Workflows and protection
/.github/          @equipe-plateforme
# Build and dependencies
/pom.xml           @equipe-plateforme
/package.json      @equipe-plateforme
/src/**/security/  @equipe-securite
```

Then, in the workflows, each publishing job declares the environment:

```yaml
  publier:
    needs: release
    if: needs.release.outputs.release_created == 'true'
    environment: production   # waits for approval before running
```

The environment only accepts deployments from protected branches and `v*` tags: a working branch cannot publish.

## Solo project

GitHub does not allow approving your own PR. With `requiredReviews = 1` and a single developer, every merge would go through the **administrator bypass**, which remains allowed but is explicit and recorded in the PR history. For a solo project, the recommended settings are:
- `requiredReviews = 0`: CI is the authority on form;
- `environment = production` with yourself as approver: each publication requires a deliberate click.

## Traceability and emergency stop

- Every merge, approval, deployment and bypass is recorded (PR history, *Environments* tab, audit log).
- `v*` tags can only be created by the workflows (ruleset "repogarde (tags)"); each published package carries a verifiable provenance attestation.
- Suspend automatic releases: *Actions → release → Disable workflow*.
