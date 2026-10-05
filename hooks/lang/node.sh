#!/usr/bin/env bash
# JavaScript / TypeScript (React, Next.js, Vue, Angular, Nest…) : prettier, <pm> test
register node "package.json" '\.(js|jsx|ts|tsx|mjs|cjs|mts|cts|vue|svelte|astro|json|jsonc|css|scss|less|html|md|mdx|ya?ml|graphql)$' standalone

# Gestionnaire de paquets d'après le lockfile (y compris à la racine d'un monorepo)
node_pm() {
    if find_up pnpm-lock.yaml >/dev/null; then echo pnpm
    elif find_up yarn.lock >/dev/null; then echo yarn
    elif find_up bun.lockb >/dev/null || find_up bun.lock >/dev/null; then echo bun
    else echo npm
    fi
}

node_format() {
    local prettier
    prettier="$(find_up node_modules/.bin/prettier || command -v prettier || true)"
    [ -n "$prettier" ] || { tool_missing "Node : prettier introuvable (npm i -D prettier), formatage ignoré."; return 0; }
    step "Node : prettier"
    "$prettier" --write --ignore-unknown --log-level warn "$@"
}

node_test() {
    has node || { warn "Node : node absent, tests ignorés."; return 0; }
    # Ignore le script "test" par défaut généré par npm init
    if ! node -e 'const t=(require("./package.json").scripts||{}).test; process.exit(t && !/no test specified/.test(t) ? 0 : 1)'; then
        echo "ℹ Node : pas de script \"test\" dans package.json."
        return 0
    fi
    local pm; pm="$(node_pm)"
    has "$pm" || { warn "Node : $pm absent, tests ignorés."; return 0; }
    step "Node : $pm test"
    case "$pm" in
        bun) bun run test ;;
        npm) npm test --silent ;;
        *) "$pm" test ;;
    esac
}
