#!/usr/bin/env bash
# Python (Django, FastAPI, Flask, scripts…) : ruff/black, pytest ou manage.py test
# Les outils du projet (.venv, uv) sont prioritaires : même version pour tous.
register python "pyproject.toml setup.py setup.cfg requirements.txt Pipfile manage.py" '\.pyi?$' standalone

# Exécute dans l'environnement du projet (uv, poetry, pipenv, .venv)
python_run() {
    if [ -f uv.lock ] && has uv; then uv run --no-sync "$@"
    elif [ -f poetry.lock ] && has poetry; then poetry run "$@"
    elif [ -f Pipfile.lock ] && has pipenv; then pipenv run "$@"
    elif [ -d .venv/bin ]; then PATH="$PWD/.venv/bin:$PATH" "$@"
    elif [ -d .venv/Scripts ]; then PATH="$PWD/.venv/Scripts:$PATH" "$@"
    else "$@"
    fi
}

# Vrai si l'outil $1 est disponible (dans le projet, sinon sur le poste)
python_has() { python_run "$1" --version >/dev/null 2>&1; }

python_format() {
    if python_has ruff; then step "Python : ruff format"; python_run ruff format -q "$@"
    elif python_has black; then step "Python : black"; python_run black -q "$@"
    else tool_missing "Python : ni ruff ni black installé, formatage ignoré."
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
    if ! python_has pytest; then warn "Python : pytest absent, tests ignorés."; return 0; fi
    step "Python : pytest"
    python_run pytest -q || rc=$?
    # 5 = aucun test collecté : pas une erreur
    if [ "$rc" -eq 5 ]; then echo "ℹ Python : aucun test trouvé."; return 0; fi
    return "$rc"
}
