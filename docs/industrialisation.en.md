# Deploying repogarde across an organization

repogarde enforces the same rules on every project (commit messages, branch naming, secrets, formatting, tests) at **three levels**:

| Level | Role | Can be bypassed? |
|---|---|---|
| Developer machine — hooks via [lefthook](https://lefthook.dev) | Immediate feedback, automatic fixes (formatting, commit prefix) | Yes (`--no-verify`) |
| CI — GitHub action / GitLab template | **Authoritative**: the same checks on every merge request | No |
| Server — branch protection | Blocks merging when CI fails, blocks direct pushes to `main` | No |

Local hooks save time; **CI and branch protection guarantee the rules**.

## 1. Hosting repogarde

The repository must be **readable by all developers and by CI**:

- GitLab: import/mirror the repository into an internal group (e.g. `outils/repogarde`);
- GitHub: public repository, or internal to the organization.

Replace `SimBienvenueHoulBoumi/repogarde` with that path in the templates (`templates/`).

## 2. Versions and releases (automatic)

Projects can get the same automatic releases: see [Versions and releases](releases.md). Below are the releases of repogarde itself.

Version numbers are **computed automatically** from Conventional Commits by [release-please](https://github.com/googleapis/release-please):

| Commits since the last release | New version |
|---|---|
| `fix: …` | patch: 1.4.**2** → 1.4.**3** |
| `feat: …` | feature: 1.**4**.2 → 1.**5**.0 |
| `feat!: …` or `BREAKING CHANGE:` in the body | major: **1**.4.2 → **2**.0.0 |

On every push to `main`, the `release` workflow:

1. updates the "release x.y.z" PR (changelog + version in the templates);
2. runs CI on that PR and waits for the required checks;
3. merges it, creates the `vX.Y.Z` tag and the release, moves the major tag `vX` and attaches a signed archive.

**No token to create**: the workflow only uses `GITHUB_TOKEN` (it triggers CI through `workflow_dispatch`, the only event type this token is allowed to trigger). Prerequisite: *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests*.

To suspend automatic releases: disable the `release` workflow (*Actions → release → Disable workflow*).

Recommended policy for projects: **pin an exact version** (`ref: v1.4.2`) and upgrade it deliberately (Renovate/Dependabot can propose the update). A stricter rule = major version.

## 3. Developer machine

Install lefthook once:

```bash
brew install lefthook          # macOS
winget install evilmartians.lefthook   # Windows
npm install -g lefthook        # any system with Node
go install github.com/evilmartians/lefthook/v2@latest
```

Then, in each project: `lefthook install` (once after cloning).

Recommended tools: `gitleaks` (secrets) and the formatters for the languages in use (see [Technologies](technologies.md)).

**Automatic installation** on the first build, so nobody has to remember it:

- Node: `npm install --save-dev lefthook` → hooks are installed on every `npm install`.
- Maven:
  ```xml
  <plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>exec-maven-plugin</artifactId>
    <executions>
      <execution>
        <id>lefthook-install</id>
        <phase>initialize</phase>
        <goals><goal>exec</goal></goals>
        <configuration>
          <executable>lefthook</executable>
          <arguments><argument>install</argument></arguments>
          <skip>${env.CI}</skip>
        </configuration>
      </execution>
    </executions>
  </plugin>
  ```
- Gradle (Kotlin DSL):
  ```kotlin
  val lefthookInstall by tasks.registering(Exec::class) {
      commandLine("lefthook", "install")
      isIgnoreExitValue = true
      onlyIf { System.getenv("CI") == null }
  }
  tasks.named("compileJava") { dependsOn(lefthookInstall) }
  ```
  These two snippets **fail the build if lefthook is not installed**: this is intentional (the machine must be set up). Outside CI only.
- Python / others: document `lefthook install` in the project README, or add it to `make setup`.

## 4. Adopting repogarde in a project

Copy from `templates/project/`:

| File | Role |
|---|---|
| `lefthook.yml` | Local hooks: repogarde rules (pinned version) + project-specific jobs |
| `.github/workflows/repogarde.yml` | GitHub CI (add the `setup-*` steps for the project's tools) |
| `gitlab-ci.yml` | To merge into `.gitlab-ci.yml` (choose an image with the project's tools) |
| `.repogarde.conf` | Shared settings: branch exceptions, disabled steps, custom commands |

`.repogarde.conf` is read **by both the hooks and CI**: an exception agreed on in code review applies everywhere.

With `strict: true` (GitHub) / `REPOGARDE_STRICT: "true"` (GitLab), a formatting or test tool missing from the CI image fails the check instead of being skipped.

## 5. Protecting branches (server)

### Squash merges

One PR = one commit on `main`, whose message is the **PR title**: a clean changelog, one line per PR. Settings (*Settings → General → Pull Requests*): allow only *squash merging*, default message *Pull request title*. repogarde CI checks that this title follows Conventional Commits; use `!` in the title for a breaking change (`feat!: …`).

### Merged branches: deleted automatically

- Server — GitHub: *Settings → General → Automatically delete head branches*; GitLab: *Settings → Merge requests → Enable "Delete source branch" option by default*.
- `develop` flow: a `release/…` or `hotfix/…` branch is merged twice (into `main` and `develop`); GitHub's automatic deletion would delete it after the first merge. The reusable workflow `nettoyage-branches.yml` keeps it as long as another open PR uses it (`bin/proteger` then disables automatic deletion):

  ```yaml
  on:
    pull_request:
      types: [closed]
  jobs:
    nettoyage:
      uses: SimBienvenueHoulBoumi/repogarde/.github/workflows/nettoyage-branches.yml@v3
      permissions: { contents: write, pull-requests: read }
  ```

- Developer machines: after a `git pull`, repogarde's `post-merge` hook deletes local branches whose remote branch is gone and whose changes are all in the current branch (regular merge or squash); a branch with unintegrated work is kept.

### GitHub

**In one command**, based on `.repogarde.conf` (protected branches, `develop` flow) — safe to re-run, `--dry-run` to preview before applying:

```bash
bin/proteger --checks "repogarde,build"   # comma-separated checks; gh logged in (admin)
```

The script sets up the "repogarde" ruleset (PR required, required checks up to date, no deletion and no force push), the merge methods (squash; with a `develop` flow: merge commit on `main`, squash or merge commit on `develop`, which becomes the default branch), reserves `v*` tags for workflows ("repogarde (tags)" ruleset), uses the PR title as the commit message and allows GitHub Actions to create PRs (automatic releases).

Manually: *Settings → Rules → Rulesets* (or *Branches → Branch protection rules*) on `main`:

- Require a pull request before merging
- Require status checks to pass → add **`repogarde`**
- Block force pushes
- (optional) Restrict branch names / commit metadata with the [regular expressions](ci.md#server-side-rules)

### GitLab

- *Settings → Repository → Protected branches*: `main` → *Allowed to push: No one*, *Allowed to merge: Developers*
- *Settings → Merge requests*: **Pipelines must succeed**
- (Premium) *Settings → Repository → Push rules*: branch name and commit message regex ([regular expressions](ci.md#server-side-rules))

## 6. What CI checks

`ci/check.sh` compares the branch with its base (merge request, previous push or default branch):

| Check | Fails if |
|---|---|
| `commits` | a message or the PR title is not Conventional Commits, exceeds 72 characters (format only for dependency bots), or is an unsquashed `fixup!`/`squash!` |
| `branch` | the branch name does not follow `<type>/<subject>` (exceptions aside); in a [`develop` flow](configuration.md#integration-branch-flow-develop), the PR targets the wrong branch (retargeted automatically with `fix-pr`) |
| `secrets` | gitleaks finds a secret in the branch's commits |
| `format` | a modified file is not formatted (the formatter runs, nothing is committed) |
| `tests` | the tests of an affected project fail (monorepo: only modified projects) |
| `deadcode` | **proven** dead code is introduced (unreachable, unused in its scope); candidates only warn ([Dead code](code-mort.md)) |

Errors appear as annotations on GitHub and in the job log on GitLab, with the command to fix them.

## 7. Machine with the global repogarde installation

`install.sh --global` (personal use) and lefthook coexist: in a repository containing a `lefthook.yml`, the global hooks delegate to lefthook (project config, pinned version), without `lefthook install` and without a `core.hooksPath` conflict.

## 8. Internal sources (closed network, Nexus, Artifactory…)

repogarde does not download project dependencies: it runs the projects' tools (`mvn`, `gradle`, `npm`, `pip`, `go`…), which use their usual configuration, on developer machines and in CI alike.

| Tool | Point to the internal source |
|---|---|
| Maven | `~/.m2/settings.xml`: `<mirrors>` |
| Gradle | `repositories { maven { url = uri("…") } }`, or an init script in `~/.gradle/init.d/` (plugins: `pluginManagement` in `settings.gradle.kts`) |
| npm, yarn, pnpm | `.npmrc`: `registry=…` (including to install `@simbie/repogarde`) |
| pip | `pip.conf`: `index-url` |
| Go | `GOPROXY` |
| MegaLinter (Docker) | registry mirror configured on the runner |

What repogarde fetches itself:

| Item | Internal source |
|---|---|
| repogarde (clone installation, lefthook) | internal Git mirror of the repository: `git_url` in `lefthook.yml`, `REPOGARDE_URL` variable of the GitLab template |
| GitHub Action `repogarde@v3` (GitHub Enterprise Server) | repository synced into the organisation ([actions-sync](https://docs.github.com/en/enterprise-server/admin/managing-github-actions-for-your-enterprise/managing-access-to-actions-from-githubcom/manually-syncing-actions-from-githubcom)), then `uses: <organisation>/repogarde@v3` |
| Tools installed in CI (gitleaks, PMD, actionlint) | **recommended**: already present in the runner image, nothing is downloaded then; otherwise `REPOGARDE_DOWNLOAD_MIRROR` |

`REPOGARDE_DOWNLOAD_MIRROR` replaces `https://github.com` in downloads, for example an Artifactory or Nexus "generic" repository proxying GitHub releases (`https://artifactory.example.com/artifactory/github`). The SHA-256 checksum **never** comes from the mirror: the default versions' checksums are pinned in repogarde; for another version, provide it in `GITLEAKS_SHA256` or `ACTIONLINT_SHA256`, otherwise the download is refused. A compromised mirror therefore cannot get a modified binary installed.
