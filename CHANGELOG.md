# Changelog

## [1.2.0](https://github.com/SimBienvenueHoulBoumi/githooks/compare/v1.1.1...v1.2.0) (2026-10-06)


### Fonctionnalités

* **post-merge:** supprime les branches locales mergées ([5336330](https://github.com/SimBienvenueHoulBoumi/githooks/commit/53363305d9344b7172a31ff02a882a926bdf54a4))
* **post-merge:** supprime les branches locales mergées ([306cd2a](https://github.com/SimBienvenueHoulBoumi/githooks/commit/306cd2ac9c4171ca1ddd5cba26f31705037e9108))


### Documentation

* suppression automatique des branches mergées ([9015039](https://github.com/SimBienvenueHoulBoumi/githooks/commit/9015039243ef2983af4057bf959dd71966448dac))

## [1.1.1](https://github.com/SimBienvenueHoulBoumi/githooks/compare/v1.1.0...v1.1.1) (2026-10-06)


### Corrections

* **action:** installe actionlint (mode strict) ([dff1f02](https://github.com/SimBienvenueHoulBoumi/githooks/commit/dff1f02876b7e8dbc56b95781d67406ea8a08d26))
* **action:** installe actionlint, scripts appelés via bash ([d0a464b](https://github.com/SimBienvenueHoulBoumi/githooks/commit/d0a464be6fb5e916ffb8218aa1d7a0966e2f74b3))


### Documentation

* **readme:** technologies prises en charge ([550a54e](https://github.com/SimBienvenueHoulBoumi/githooks/commit/550a54e4b961c6b07d5f051f89c0f2dd984a49c7))

## [1.1.0](https://github.com/SimBienvenueHoulBoumi/githooks/compare/v1.0.1...v1.1.0) (2026-10-06)


### Fonctionnalités

* **ci:** option MegaLinter (GitHub et GitLab) ([3289a3c](https://github.com/SimBienvenueHoulBoumi/githooks/commit/3289a3c5d3b362cd142a684074f679e6f200fcb9))
* exclusion de chemins, outils du projet, e2e 17 langages ([768c5ed](https://github.com/SimBienvenueHoulBoumi/githooks/commit/768c5edd1750bf03dd7fdaf1680d10d4e02e3e64))
* **iac:** Ansible, Helm, Kubernetes, Docker, Terraform, Packer, Actions ([8fe71c7](https://github.com/SimBienvenueHoulBoumi/githooks/commit/8fe71c76731a9b8846b0d8619a5c767da6fe3806))
* maturité (IaC, e2e réels, perf, sécurité, MegaLinter) ([bd23580](https://github.com/SimBienvenueHoulBoumi/githooks/commit/bd235801f46503eaec6ec5d19ce295674bc68557))


### Corrections

* **python:** cache de bytecode neuf, pas de faux succès des tests ([d1d4cb6](https://github.com/SimBienvenueHoulBoumi/githooks/commit/d1d4cb63cd222b6e7da767a37973b09006556c38))


### Performances

* config lue une fois, Gradle ciblé, caches de téléchargement ([57ac929](https://github.com/SimBienvenueHoulBoumi/githooks/commit/57ac92943bab182fb496a681f7405dfcf350d7a0))
* hooks plus rapides, CI Windows parallélisée ([190b4a9](https://github.com/SimBienvenueHoulBoumi/githooks/commit/190b4a92c150990b91ae720e7e280fdfe93cec85))
* **lang:** détection sans sous-processus (300 fichiers : 53 s → 0,7 s) ([1784d1f](https://github.com/SimBienvenueHoulBoumi/githooks/commit/1784d1f6a8a4d108ab4e6cbf86addd91c4ac7637))


### Documentation

* conventions de performance et de nommage des tests ([0351033](https://github.com/SimBienvenueHoulBoumi/githooks/commit/0351033a7ddf034b52bcdbfde19c6f181aa62fa3))
* licence MIT ([76e918a](https://github.com/SimBienvenueHoulBoumi/githooks/commit/76e918aa279547d589cfe04dc010c59f96c4ec96))
* sécurité, contribution, modèles d'issues, Dependabot ([08e23ab](https://github.com/SimBienvenueHoulBoumi/githooks/commit/08e23abe5802cae7a55199dd1bc99c08a73b0242))

## [1.0.1](https://github.com/SimBienvenueHoulBoumi/githooks/compare/v1.0.0...v1.0.1) (2026-10-05)


### Corrections

* **release:** merge auto de la release, tag majeur, versions calculées ([fc4fb05](https://github.com/SimBienvenueHoulBoumi/githooks/commit/fc4fb05d844ddedee9bf890798096592544e0c72))
* **release:** releases entièrement automatiques ([06dbd8c](https://github.com/SimBienvenueHoulBoumi/githooks/commit/06dbd8cd86b318502f79f11f85fa7b5136f539f3))

## 1.0.0 (2026-10-05)


### Fonctionnalités

* **branch-name:** impose le nommage des branches avec aide au renommage ([f1f1bee](https://github.com/SimBienvenueHoulBoumi/githooks/commit/f1f1bee447b0b869ddf4771b3d0a662572731c16))
* **ci:** vérifications CI GitHub/GitLab et délégation à lefthook ([ee01c00](https://github.com/SimBienvenueHoulBoumi/githooks/commit/ee01c004f44eb5a9312078f039452cd779184a6f))
* hooks git réutilisables avec détection du langage ([85a9eda](https://github.com/SimBienvenueHoulBoumi/githooks/commit/85a9eda41657453f267e360063e15ccc5dfffc41))
* **lang:** détection par fichier, monorepos, scripts et 17 langages ([f1c12fe](https://github.com/SimBienvenueHoulBoumi/githooks/commit/f1c12fe618152d311ef133fc696d2dfd2a9f8518))
* **lefthook:** config partagée lefthook réutilisant les hooks ([bbbfafa](https://github.com/SimBienvenueHoulBoumi/githooks/commit/bbbfafa6572e567b52729685822317fb3e84c61d))
* **lefthook:** délégation sans avertissement core.hooksPath ([67ceca4](https://github.com/SimBienvenueHoulBoumi/githooks/commit/67ceca4ecfc1f24fe17acf5d6a16629a7ed6b566))
* **prepare-commit-msg:** préremplit le message selon la branche ([55b4b23](https://github.com/SimBienvenueHoulBoumi/githooks/commit/55b4b236d3bff2680661b0aa0bff65b66de2a6fb))
* **release:** releases auto, templates projet, tests CI et lefthook ([506cbf4](https://github.com/SimBienvenueHoulBoumi/githooks/commit/506cbf47bd9cff73d67dcd583382a1dfe4be821d))
* usage en organisation (lefthook, CI GitHub/GitLab, releases auto) ([97bf540](https://github.com/SimBienvenueHoulBoumi/githooks/commit/97bf5408bf832ba9fbc47d2f0a0ae5b0f80805fd))


### Corrections

* remplace les A && B || C signalés par shellcheck (SC2015) ([df04e1a](https://github.com/SimBienvenueHoulBoumi/githooks/commit/df04e1a016d24d33e43192172ff15f1b3361ec80))
* **staging:** préserve le travail non stagé et teste le commit poussé ([a9de8f1](https://github.com/SimBienvenueHoulBoumi/githooks/commit/a9de8f150c4a834eb2f4692f113ddde852fd5f7d))
* **staging:** travail non stagé préservé, tests du commit poussé, multi-langages ([0ba8aed](https://github.com/SimBienvenueHoulBoumi/githooks/commit/0ba8aede12d8430c960a1635d1ddb7e0d6efd99c))
* **windows:** find_up compare des chemins au même format ([5cea8c8](https://github.com/SimBienvenueHoulBoumi/githooks/commit/5cea8c843cdcba99495d30ec19e97e3a1b719cc1))


### Documentation

* guide de déploiement en organisation ([46014cb](https://github.com/SimBienvenueHoulBoumi/githooks/commit/46014cb5c485b224cd33fb728fcd966807b3f6e0))
* **readme:** documente GitLab/GitHub/Bitbucket et le développement ([6abecd0](https://github.com/SimBienvenueHoulBoumi/githooks/commit/6abecd08acfe15bd927b54b544357bdafcd6d49c))
* **readme:** langages supportés, .githooks.conf, ajout d'un langage ([d1fb20a](https://github.com/SimBienvenueHoulBoumi/githooks/commit/d1fb20a7ce6363eb5741d3d0e34ea026414dc143))
* **readme:** rend l'installation indépendante de la machine ([6497e1d](https://github.com/SimBienvenueHoulBoumi/githooks/commit/6497e1da39da1943da80e497462fc910a125280f))
