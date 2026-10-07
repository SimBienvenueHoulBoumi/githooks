# Quick start

Choose the path that matches your use case.

=== "One project (recommended)"

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
        | `gitlab-ci.yml` | to merge into `.gitlab-ci.yml` |
        | `.repogarde.conf` | shared settings (optional) |

    3. Enable the hooks: `lefthook install`.
    4. Protect `main` and require the `repogarde` check: see [In an organisation](industrialisation.md).

=== "An organisation"

    The [In an organisation guide](industrialisation.md) covers hosting repogarde, versions, automatic installation on developer machines (Maven, Gradle, npm) and GitHub / GitLab branch protection.

=== "Personal use"

    All repositories on the machine, without adding anything to the projects:

    ```bash
    git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git ~/repogarde
    ~/repogarde/install.sh --global
    ```

    | Action | Command |
    |---|---|
    | Check | `git config --global core.hooksPath` → `…/repogarde/hooks` |
    | Update | `git -C ~/repogarde pull` |
    | A single repository | `cd my-project && ~/repogarde/install.sh` |
    | Uninstall | `~/repogarde/install.sh --uninstall --global` ([full uninstall](desinstallation.md)) |

    A repository that contains a `lefthook.yml` automatically uses its own configuration (pinned version).

## Prerequisites

| Item | Required | Notes |
|---|---|---|
| git + bash | yes | macOS, Linux, Windows via [Git for Windows](https://gitforwindows.org) |
| Tools for the languages used | depending on the projects | a missing tool is skipped on the developer machine |
| [gitleaks](https://github.com/gitleaks/gitleaks) | recommended | `brew install gitleaks` · `apt install gitleaks` · `winget install gitleaks` |
