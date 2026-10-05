#!/usr/bin/env bash
# Python (Django, FastAPI, Flask, scripts…) : ruff/black, pytest ou manage.py test
register python "pyproject.toml setup.py setup.cfg requirements.txt Pipfile manage.py" '\.pyi?$' standalone

python_format() {
    if has ruff; then step "Python : ruff format"; ruff format -q "$@"
    elif has black; then step "Python : black"; black -q "$@"
    else tool_missing "Python : ni ruff ni black installé, formatage ignoré."
    fi
}

# Exécute dans l'environnement du projet (uv, poetry, pipenv, .venv)
python_run() {
    if [ -f uv.lock ] && has uv; then uv run "$@"
    elif [ -f poetry.lock ] && has poetry; then poetry run "$@"
    elif [ -f Pipfile.lock ] && has pipenv; then pipenv run "$@"
    elif [ -d .venv/bin ]; then PATH="$PWD/.venv/bin:$PATH" "$@"
    elif [ -d .venv/Scripts ]; then PATH="$PWD/.venv/Scripts:$PATH" "$@"
    else "$@"
    fi
}

python_test() {
    local rc=0
    # Django sans pytest-django : runner intégré
    if [ -f manage.py ] && ! grep -qs pytest-django pyproject.toml requirements*.txt setup.cfg Pipfile; then
        step "Python : manage.py test"
        python_run python manage.py test
        return
    fi
    step "Python : pytest"
    python_run pytest -q || rc=$?
    case "$rc" in
        5) echo "ℹ Python : aucun test trouvé."; return 0 ;;    # aucun test collecté
        127) warn "Python : pytest absent, tests ignorés."; return 0 ;;
    esac
    return "$rc"
}
