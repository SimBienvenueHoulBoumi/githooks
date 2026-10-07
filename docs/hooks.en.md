# Hooks and rules

## The hooks

| Hook | Role |
|---|---|
| `post-checkout` | Warns as soon as you switch to a badly named branch (non-blocking) |
| `pre-commit` | Rejects badly named branches, blocks direct commits on protected branches (`main`/`master` by default), detects secrets, formats **only the staged content** (unstaged work is preserved) |
| `prepare-commit-msg` | Prefixes the message based on the branch: on `feat/bean`, `git commit -m "add X"` → `feat(bean): add X` |
| `commit-msg` | Enforces [Conventional Commits](https://www.conventionalcommits.org), 72 characters maximum |
| `pre-push` | Rejects badly named branches and direct pushes to protected branches (`protectedBranches`, initial creation allowed); builds and tests **the pushed commit**, only for the affected projects |
| `post-merge` | After a `git pull`: deletes merged local branches (regular or squash merge) whose remote branch has been deleted; never a branch containing unintegrated work |

One-off bypass: `git commit --no-verify`, `git push --no-verify` — the [CI](ci.md) re-runs the checks.

## Commit messages

Format `<type>(<scope>): <description>`; `!` after the type for a breaking change (`feat!: …`).

| Type | Usage | Release |
|---|---|---|
| `feat` | new feature | minor version (1.**4**.0) |
| `fix` | bug fix | patch (1.4.**1**) |
| `perf` | performance | patch |
| `docs` | documentation | patch |
| `style`, `refactor`, `test`, `build`, `ci`, `chore`, `revert` | formatting, restructuring, tests, build, CI, maintenance, revert | none on their own |

A `!` (`feat!: …`) or a `BREAKING CHANGE:` footer produces a **major version**. See [automatic releases](industrialisation.md#2-versions-and-releases-automatic).

## Commit assistant: `git cc`

To write a compliant message without memorising the format, `git cc` guides you step by step (alias installed by `install.sh`):

```text
$ git cc
Type of change:
   1) feat      new feature
   2) fix       bug fix
   …
Type [feat]:                                    ← suggested from the branch feat/cart
Scope (optional, "-" for none) [cart]:
Breaking change (major version)? [y/N]:
Description (58 characters max): feat(cart): add the cart
Body (optional): explain why; empty line to finish.
> Customers keep their items between visits.
>
References (optional, e.g. Closes #12): Closes #12

──── Message ────
feat(cart): add the cart

Customers keep their items between visits.

Closes #12
─────────────────
Commit? [Y/n]:
```

| Step | Required | Help |
|---|---|---|
| Type | yes | menu, suggested from the branch |
| Scope | no | suggested from the branch |
| Breaking change | no | adds `!` and the `BREAKING CHANGE: …` footer |
| Description | yes | header length checked (72 characters) |
| Body | no | several lines: the why |
| References | no | `Closes #12`, `Refs #34`… |

`git commit` options are passed through (`git cc --no-verify`…); `bin/commit --dry-run` displays the message without committing. With lefthook and without `install.sh`: `git config --global alias.cc '!bash /path/to/repogarde/bin/commit'`.

## Branch naming

Format `<type>/<topic>` (topic in `a-z0-9._-`, `/` to subdivide): `feat/signup`, `fix/user/login`, `hotfix/db-timeout`.

- Warning on creation, rejected on commit and push, with the rename command to copy.
- Default exceptions: `main`, `master`, `develop`, `release/*` and bot branches (`release-please--*`, `dependabot/*`, `renovate/*`); `allowedBranches` setting.
- The type becomes the commit prefix and the topic its scope (omitted beyond 20 characters).
- Aliases: `feature/` → `feat`, `bugfix/` and `hotfix/` → `fix`.
- A message that is already compliant is never modified; merge, squash and amend are ignored.

!!! tip "Git has no hook on branch creation"
    The name is therefore checked on the first commit and on push. To enforce it on the server side, see the [server-side rules](ci.md#server-side-rules).
