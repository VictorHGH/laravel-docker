# Docker Compose aliases for this Laravel base
# Uso: source este archivo desde el root del proyecto o con ruta absoluta:
#   source ./docker-aliases.zsh
# Detecta la ruta del proyecto basada en la ubicación del script.

# Ruta del script (zsh) y root del proyecto
SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

export COMPOSE_FILE_DEV="$PROJECT_ROOT/docker-compose.yml:$PROJECT_ROOT/docker-compose.dev.yml"

dcdev() {
  if [[ $# -eq 0 ]]; then
    COMPOSE_FILE="$COMPOSE_FILE_DEV" docker compose
    return
  fi

  if [[ "$1" == "composer" ]]; then
    shift
    COMPOSE_FILE="$COMPOSE_FILE_DEV" docker compose run --rm composer "$@"
  else
    COMPOSE_FILE="$COMPOSE_FILE_DEV" docker compose "$@"
  fi
}

alias dcprod='COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml" docker compose'
# Compose leerá COMPOSE_PROJECT_NAME de .env para nombrar recursos (no hardcodear aquí).

# Ejemplos:
#  Subir dev:    dcdev up -d --build
#  Composer:     dcdev run --rm composer install
#  Artisan:      dcdev exec php php artisan migrate
#  Subir prod:   dcprod up -d --build
