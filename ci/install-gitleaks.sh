#!/usr/bin/env bash
# Compatibilité (templates v1.0.x) : voir ci/install-tool.sh
exec bash "$(dirname "${BASH_SOURCE[0]}")/install-tool.sh" gitleaks "$@"
