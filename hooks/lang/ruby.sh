#!/usr/bin/env bash
# Ruby (Rails…) : rubocop -a / standardrb, rails test / rspec / rake test
register ruby "Gemfile" '(\.(rb|rake|gemspec)|(^|/)(Rakefile|Gemfile))$'

ruby_format() {
    if grep -qs '^    rubocop ' Gemfile.lock; then
        step "Ruby : rubocop -a"
        bundle exec rubocop -a --format quiet --fail-level F "$@"
    elif grep -qs '^    standard ' Gemfile.lock; then
        step "Ruby : standardrb --fix"
        bundle exec standardrb --fix "$@" || true # les offenses non corrigeables ne bloquent pas
    else
        tool_missing "Ruby : ni rubocop ni standard dans le Gemfile, formatage ignoré."
    fi
}

ruby_test() {
    has bundle || { warn "Ruby : bundler absent, tests ignorés."; return 0; }
    if [ -x bin/rails ]; then step "Ruby : rails test"; bin/rails test
    elif [ -d spec ] && grep -qs '^    rspec' Gemfile.lock; then step "Ruby : rspec"; bundle exec rspec
    elif [ -f Rakefile ]; then step "Ruby : rake test"; bundle exec rake test
    else info "Ruby : aucun lanceur de tests trouvé."
    fi
}
