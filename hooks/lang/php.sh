#!/usr/bin/env bash
# PHP (Laravel, Symfony…) : pint / php-cs-fixer, composer test / artisan / pest / phpunit
register php "composer.json" '\.php$'

php_format() {
    if [ -x vendor/bin/pint ]; then step_t lang.php.1; vendor/bin/pint -q "$@"
    elif [ -x vendor/bin/php-cs-fixer ]; then step "PHP : php-cs-fixer"; vendor/bin/php-cs-fixer fix -q "$@"
    elif has php-cs-fixer; then step "PHP : php-cs-fixer"; php-cs-fixer fix -q "$@"
    else tool_missing "PHP : ni pint ni php-cs-fixer, formatage ignoré."
    fi
}

php_test() {
    if grep -q '"test"[[:space:]]*:' composer.json && has composer; then step_t lang.php.2; composer test
    elif [ -f artisan ]; then step "PHP : artisan test"; php artisan test
    elif [ -x vendor/bin/pest ]; then step "PHP : pest"; vendor/bin/pest
    elif [ -x vendor/bin/phpunit ]; then step "PHP : phpunit"; vendor/bin/phpunit
    else info "PHP : aucun lanceur de tests trouvé (composer install ?)."
    fi
}
