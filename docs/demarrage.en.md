# Quick start

Three paths, depending on your use case. The fastest way to try it: **On my machine**.

=== "On my machine"

    All your repositories, without adding anything to the projects or their `package.json`:

    ```bash
    npm install -g @simbie/repogarde     # 1. the package (yarn global add, pnpm add -g: same)
    repogarde install --global           # 2. enables the hooks: asks for the language, installs git cc
    repogarde                            # 3. checks: machine status and next step
    ```

    Step 2 is required: for security, the package runs nothing at install time (no `postinstall` script).

    Try it right away, in any repository:

    ```bash
    git switch -c feat/cart              # branch name checked
    git add . && git cc                  # commit assistant (type, scope, description…)
    git push -u origin feat/cart         # tests of the affected projects before sending
    repogarde code-mort                  # new dead code on the branch
    ```

    | Action | Command |
    |---|---|
    | Machine status, next step | `repogarde` (or `repogarde statut`) |
    | Every command | `repogarde --help` |
    | Check | `git config --global core.hooksPath` → `…/repogarde/hooks` |
    | Update | `npm update -g @simbie/repogarde` (the hooks follow) |
    | Change language | `repogarde install --global --lang fr` |
    | A single repository | `cd my-project && repogarde install` |
    | Uninstall | `repogarde uninstall --global`, then `npm uninstall -g @simbie/repogarde` ([full uninstall](desinstallation.md)) |

    `npx` is refused for the global installation: its temporary folder can be deleted at any time. With nvm, each Node version has its own global packages: run `repogarde install --global` again after switching versions.

    **Internal npm registry** (company, proxy): `npm install -g @simbie/repogarde --registry <url>`, or `registry=<url>` in `~/.npmrc`; see [internal sources](industrialisation.md#8-internal-sources-closed-network-nexus-artifactory).

    **Without Node**: same result from a clone, updated with `git -C ~/repogarde pull` (the commands become `~/repogarde/install.sh`, `~/repogarde/bin/code-mort`…).

    ```bash
    git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git ~/repogarde
    ~/repogarde/install.sh --global
    ```

    A repository that contains a `lefthook.yml` uses its own configuration (pinned version), if lefthook is installed.

=== "A team project"

    1. **Everyone** installs repogarde once on their machine ("On my machine" tab): `npm install -g @simbie/repogarde`, then `repogarde install --global`.

    2. **The project** adds the templates from [`templates/project/`](https://github.com/SimBienvenueHoulBoumi/repogarde/tree/main/templates/project):

        | File | Role |
        |---|---|
        | `.github/workflows/repogarde.yml` | GitHub CI: re-runs the checks on every PR, it is authoritative (add the `setup-*` steps for the project's tools) |
        | `.repogarde.conf` | shared settings, including `version`: minimum repogarde version expected on developer machines |
        | `.github/workflows/release.yml` | [automatic releases](releases.md) (optional) |
        | `gitlab-ci.yml` | for GitLab, to merge into `.gitlab-ci.yml` |

    3. **Make the CI required** to merge: `repogarde proteger` (see [In an organisation](industrialisation.md)).

    A machine whose repogarde is older than the project `version` is warned on every commit, with the update command. Without hooks, the CI re-runs every check anyway.

    **Exact version per project (advanced)**: with [lefthook](https://lefthook.dev) and the `lefthook.yml` template, each project downloads repogarde at its own pinned version. Everyone then installs lefthook once (`brew install lefthook`, `npm install -g lefthook`, `winget install evilmartians.lefthook`), then runs `lefthook install` in the project; the machine's repogarde hooks automatically delegate to the project's `lefthook.yml`.

=== "An organisation"

    The [In an organisation guide](industrialisation.md) covers hosting repogarde, versions, automatic installation on developer machines (Maven, Gradle, npm) and GitHub / GitLab branch protection.

=== "Contributing to repogarde"

    ```bash
    git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git && cd repogarde
    ./install.sh                         # repogarde checks itself
    bats test/                           # tests (bats-core), also run on push
    ```

    See [Contributing](contribuer.md).

## Prerequisites

| Item | Required | Notes |
|---|---|---|
| git + bash | yes | macOS, Linux, Windows via [Git for Windows](https://gitforwindows.org) |
| Tools for the languages used | depending on the projects | a missing tool is skipped on the developer machine |
| [gitleaks](https://github.com/gitleaks/gitleaks) | recommended | `brew install gitleaks` · `apt install gitleaks` · `winget install gitleaks` |
