# Quick start

Three paths, depending on your use case. The fastest way to try it: **On my machine**.

=== "On my machine"

    All your repositories, without adding anything to the projects or their `package.json`:

    ```bash
    npm install -g @simbie/repogarde     # yarn global add, pnpm add -g: same
    repogarde install --global           # asks for the language (fr / en), installs git cc
    ```

    Try it right away, in any repository:

    ```bash
    git switch -c feat/cart              # branch name checked
    git add . && git cc                  # commit assistant (type, scope, description…)
    git push -u origin feat/cart         # tests of the affected projects before sending
    repogarde code-mort                  # new dead code on the branch
    ```

    | Action | Command |
    |---|---|
    | Every command | `repogarde --help` |
    | Check | `git config --global core.hooksPath` → `…/repogarde/hooks` |
    | Update | `npm update -g @simbie/repogarde` (the hooks follow) |
    | Change language | `repogarde install --global --lang fr` |
    | A single repository | `cd my-project && repogarde install` |
    | Uninstall | `repogarde uninstall --global`, then `npm uninstall -g @simbie/repogarde` ([full uninstall](desinstallation.md)) |

    `npx` is refused for the global installation: its temporary folder can be deleted at any time. With nvm, each Node version has its own global packages: run `repogarde install --global` again after switching versions.

    **Without Node**: same result from a clone, updated with `git -C ~/repogarde pull` (the commands become `~/repogarde/install.sh`, `~/repogarde/bin/code-mort`…).

    ```bash
    git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git ~/repogarde
    ~/repogarde/install.sh --global
    ```

    A repository that contains a `lefthook.yml` uses its own configuration (pinned version), if lefthook is installed.

=== "A team project"

    1. Install [lefthook](https://lefthook.dev) on the developer machine:

        ```bash
        brew install lefthook          # macOS
        winget install evilmartians.lefthook   # Windows
        npm install -g lefthook        # any system with Node
        ```

    2. Add the templates from [`templates/project/`](https://github.com/SimBienvenueHoulBoumi/repogarde/tree/main/templates/project) to the project:

        | File | Role |
        |---|---|
        | `lefthook.yml` | local hooks, pinned repogarde version |
        | `.github/workflows/repogarde.yml` | GitHub CI (add the `setup-*` steps for the project's tools) |
        | `.github/workflows/release.yml` | [automatic releases](releases.md) (optional) |
        | `gitlab-ci.yml` | to merge into `.gitlab-ci.yml` |
        | `.repogarde.conf` | shared settings (optional) |

    3. Enable the hooks: `lefthook install`.
    4. Protect `main` and require the `repogarde` check: `bin/proteger` (see [In an organisation](industrialisation.md)).

    **Then, everyone who clones the project** installs lefthook once, then:

    ```bash
    git clone <project-url> && cd <project>
    lefthook install                     # project hooks, at the version pinned in lefthook.yml
    ```

    Nothing else: lefthook fetches repogarde at the project's version. With the "On my machine" installation, even this `lefthook install` is unnecessary. A Maven, Gradle or npm project can install it on the first build ([In an organisation](industrialisation.md)). Without hooks, the CI runs every check again.

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
