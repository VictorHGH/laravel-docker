# Entorno Docker Laravel (infra-only)
Infraestructura lista para usar Laravel con Docker. Pensado para: equipos que quieren levantar un stack Laravel rápido (dev/prod-like) y que gestionan el código de la app fuera de este repo (aquí sólo hay infra).

## Requisitos
- Docker + Docker Compose plugin.
- (Opcional) `rsync` para despliegue.

## Qué incluye
- Base/prod-like: Nginx, PHP-FPM (8.3), MySQL (8.0), volumen de datos, vendor generado en el build.
- Dev override: monta `./src`, Xdebug, phpMyAdmin (sólo dev), composer service.
- Nombre de proyecto y recursos semánticos via `.env` (`PROJECT_NAME`, `COMPOSE_PROJECT_NAME`).

## Variables de entorno (.env raíz)
- `PROJECT_NAME` / `COMPOSE_PROJECT_NAME`: prefijo para contenedores/red/volúmenes.
- `WEB_PORT`: puerto público de la app (default 8080).
- `PMA_PORT`: puerto de phpMyAdmin en dev (default 8090).
- Tags/base images: `MYSQL_IMAGE_TAG`, `PHPMYADMIN_IMAGE_TAG`, `COMPOSER_IMAGE_TAG`, `PHP_BASE_IMAGE`, `NGINX_BASE_IMAGE`, `XDEBUG_VERSION`, `REDIS_PECL_VERSION`.

## Estructura del repo
- `docker-compose.yml`: base/prod-like (Nginx, PHP, MySQL, vendor en build, red `${PROJECT_NAME}-net`, volumen `${PROJECT_NAME}-mysql-data`).
- `docker-compose.dev.yml`: override dev (montajes, Xdebug, phpMyAdmin en `PMA_PORT`, composer service, MySQL portátil `mysql_dev_data`).
- `dockerfiles/`: `php.dockerfile` (stage vendor con composer install), `nginx.dockerfile`, configs.
- `nginx/`: `default.conf` para la app.
- `mysql/`: `.env.example` (prod), `.env` (no versionado) requerido en runtime.
- `mysql_dev_data/`: datos MySQL dev (portátil, fuera de git).
- `src/`: código de la app (ignorado en git; incluye placeholders en `src/public`).
- `exclude-for-prod.txt`: exclusiones sugeridas para rsync a prod.

## Comandos rápidos
- Cargar aliases: `source ./docker-aliases.zsh`
- Dev: `dcdev up -d --build` (app en `WEB_PORT`, phpMyAdmin en `PMA_PORT`)
- Composer dev: `dcdev composer install` / `dcdev composer create-project laravel/laravel .`
- Artisan: `dcdev exec php php artisan <comando>`
- Detener dev: `dcdev down`
- Prod-like: `dcprod up -d --build` (asegura `src/composer.json` y `src/public` presentes)

## Flujo completo: crear un proyecto desde cero
1) Copiar la infraestructura a tu nuevo proyecto:
   - `cp -a /ruta/infra-base /ruta/nuevo-proyecto && cd /ruta/nuevo-proyecto`
2) Editar `.env` raíz:
   - Ajusta `PROJECT_NAME`, `WEB_PORT`, `PMA_PORT` y (si quieres) tags de imágenes.
3) Crear `mysql/.env` desde la plantilla:
   - `cp mysql/.env.example mysql/.env` y edita credenciales.
4) Preparar datos portátiles dev:
   - `mkdir -p mysql_dev_data`
5) Levantar DEV:
   - `source ./docker-aliases.zsh`
   - `dcdev up -d --build`
   - URLs: app en `http://localhost:${WEB_PORT:-8080}`, phpMyAdmin en `http://localhost:${PMA_PORT:-8090}`
6) Crear Laravel dentro de `src` (usar raíz `.` para que Nginx/PHP ya apunten bien):
   - `dcdev composer create-project laravel/laravel .`
7) Configurar `src/.env` de Laravel:
   - DB_HOST=mysql; DB creds según `mysql/.env`; APP_URL con tu host.
8) Inicializar app:
   - `dcdev exec php php artisan key:generate`
   - `dcdev exec php php artisan migrate`
9) Empezar a codificar:
   - Edita en `./src`; usa `dcdev exec php php artisan route:list`, `dcdev exec php php artisan make:controller ...`, etc.

## Operación diaria (dev)
- Arrancar/parar: `dcdev up -d` / `dcdev down`
- Composer: `dcdev composer install` / `dcdev composer update`
- Artisan: `dcdev exec php php artisan <cmd>`
- Logs nginx: `dcdev logs server -f`
- Logs php-fpm: `dcdev logs php -f`

## Producción / Staging
- Prerrequisitos: `src/composer.json` (ideal también `composer.lock`) y `src/public` deben existir antes de `dcprod up -d --build` (el build genera `vendor/` dentro de la imagen).
- Levantar: `dcprod up -d --build`
- Detener: `dcprod down`

## Deploy (rsync)
- Comando sugerido: `rsync -avz --exclude-from='exclude-for-prod.txt' ./ user@server:/ruta/`
- No excluir `src/public/` (Nginx lo copia en el build).
- No subir `mysql_dev_data`, `mysql/.env`, `src/.env`.
- Vendor: se genera en el build (stage vendor con `composer install --no-dev`); no es necesario subir `src/vendor/`.

## Notas de seguridad
- phpMyAdmin sólo en dev (no está en el compose base/prod).
- `mysql/.env` y `src/.env` no se versionan ni se suben a producción.
- Expón sólo los puertos necesarios (`WEB_PORT`, opcional `PMA_PORT` en dev).

## Troubleshooting
- phpMyAdmin no conecta: verifica que `mysql/.env` existe y el healthcheck de MySQL está sano; revisa `dcdev logs mysql`.
- Build prod falla por vendor: asegúrate de tener `src/composer.json` (y opcional `composer.lock`) antes de `dcprod build php`.
- 404/403 en Nginx: confirma que `src/public` existe y contiene `index.php`.
- Permisos en dev: usa tus UID/GID en `.env` (`UID=$(id -u) GID=$(id -g)` al levantar).
- Red/borrado: si tienes residuos, `dcdev down -v` elimina volúmenes (nota: borra datos dev en `mysql_dev_data`).
