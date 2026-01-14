# Entorno Laravel con Docker (dev y prod)

## Qué es
Base de infraestructura Docker para proyectos Laravel (este repo no versiona `./src`, solo la infra). Se trabaja con dos archivos: uno base “prod-like” y un override para desarrollo, sin perfiles; eliges entorno por el archivo que incluyes. En dev los datos de MySQL viven en `./mysql_dev_data/` (portátil y sin versionar). En prod se mantiene el volumen nombrado `mysql_data` y phpMyAdmin existe solo en dev.

## Comandos rápidos
- Desarrollo: `UID=$(id -u) GID=$(id -g) docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build`
  - phpMyAdmin: `http://localhost:${PMA_PORT:-8090}`
- Producción/Staging (sin dominio): `UID=$(id -u) GID=$(id -g) WEB_PORT=8081 docker compose up -d --build`
  - Acceso app: `http://IP:${WEB_PORT:-8080}`

Atajos opcionales
- Carga los aliases en cada sesión de shell (no se instalan globalmente): `source ./docker-aliases.zsh` desde la raíz del proyecto. Si estás fuera del directorio, usa la ruta absoluta al script.
- Esto define `dcdev` (dev) y `dcprod` (prod/staging) sin perfiles ni archivos extra.
- Ejemplos rápidos:
  - Dev: `dcdev up -d --build`, `dcdev run --rm composer install`, `dcdev exec php php artisan migrate`
  - Prod/Staging: `dcprod up -d --build`

## Requisitos
- Docker y Docker Compose v2.
- Puertos libres: 8080 (app por defecto) y 8090 solo para phpMyAdmin en dev. Si quieres otros puertos públicos, ajusta `WEB_PORT` (y `PMA_PORT` en dev).
- El directorio `mysql_dev_data/` debe permanecer fuera de git; ya está en `.gitignore`/`.dockerignore`. También se ignora `src/` y `mysql_data/` en git (solo infra aquí).
- El archivo raíz `.env` (versionado) define `PROJECT_NAME`/`COMPOSE_PROJECT_NAME`, tags/base images y puertos por defecto. Los recursos se nombran como `${PROJECT_NAME}-net` y `${PROJECT_NAME}-mysql-data`.

## Estructura rápida
- `docker-compose.yml`: base común (nginx + php-fpm + MySQL). Código empaquetado (`target: app`), Xdebug apagado, `APP_ENV=production`. Puerto configurable con `WEB_PORT` (app). MySQL usa volumen nombrado `${PROJECT_NAME}-mysql-data`. Red nombrada `${PROJECT_NAME}-net`. Imágenes basadas en tags de `.env`.
- `docker-compose.dev.yml`: override dev (montajes de código, Xdebug, phpMyAdmin con restart relajado y `PMA_PORT`, servicio composer con imagen oficial, opcache ajustado). MySQL monta `./mysql_dev_data` para que los datos sean portátiles. Declara la misma red `${PROJECT_NAME}-net` para coherencia.
- `dockerfiles/`: nginx (copia config y `public/`), php (multi-stage con Xdebug opcional). Composer usa imagen oficial, no Dockerfile propio. Base images parametrizadas vía args/`.env`.
- `src/`: código de la app (no se versiona aquí); en dev se monta, en prod se copia en el build base. Nginx solo copia `public/`.

## Variables de entorno mínimas
- Usa las plantillas versionadas y ajusta credenciales en el servidor:
  ```bash
  cp mysql/.env.example mysql/.env
  cp src/.env.example src/.env
  ```
  Luego rellena claves/DB y genera `APP_KEY` (`php artisan key:generate`). Si usas rsync para desplegar, añade `--exclude-from='exclude-for-prod.txt'`. Ajusta `PROJECT_NAME` en `.env` para nombrar red/volúmenes/contendedores.
- Usa tus UID/GID para permisos correctos: `UID=$(id -u) GID=$(id -g)`.

## Desarrollo
```bash
UID=$(id -u) GID=$(id -g) \
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```
Incluye:
- Montaje de `./src` en nginx/php/composer (recuerda que `src/` no se versiona aquí).
- Xdebug activo (target `base`), phpMyAdmin en `http://localhost:${PMA_PORT:-8090}`.
- Datos MySQL en `./mysql_dev_data` (no viajan a git; portátiles entre máquinas si sincronizas la carpeta).
- Opcache con `validate_timestamps=1` para reflejar cambios al guardar.

Comandos útiles (dev):
- Dependencias: `docker compose -f docker-compose.yml -f docker-compose.dev.yml run --rm composer install`
- APP_KEY: `docker compose -f docker-compose.yml -f docker-compose.dev.yml exec php php artisan key:generate`
- Migraciones: `docker compose -f docker-compose.yml -f docker-compose.dev.yml exec php php artisan migrate`

## Producción / Staging sin dominio
```bash
UID=$(id -u) GID=$(id -g) WEB_PORT=8081 \
docker compose up -d --build
```
Acceso: `http://IP-del-servidor:${WEB_PORT:-8080}`.
Incluye:
- Código empaquetado en la imagen (`target: app`), sin montajes de host.
- MySQL con volumen nombrado `mysql_data` (persistente en el host).
- Xdebug deshabilitado, `APP_ENV=production`, `APP_DEBUG=false`.
- Tags de imágenes y puertos vienen de `.env` (puedes sobreescribirlos al exportar variables).

## Despliegue con rsync
- Usa el archivo `exclude-for-prod.txt` para excluir dev/caches/secretos al copiar: 
  ```bash
  rsync -avz --exclude-from='exclude-for-prod.txt' /path/local/ /ruta/en/servidor/
  ```
- En el servidor copia las plantillas: `cp mysql/.env.example mysql/.env` y `cp src/.env.example src/.env`, luego ajusta credenciales y genera `APP_KEY`.
- No excluyas `src/vendor/` en prod: el PHP Dockerfile no ejecuta `composer install` (debe viajar en el rsync si ya está construido).

## Operación segura con carpeta sincronizada (`mysql_dev_data`)
- Antes de cambiar de máquina o suspender: `docker compose down` (o `dcdev down`).
- Espera a que termine la sincronización de `mysql_dev_data/` (Syncthing/Drive/Dropbox/rsync).
- En la otra máquina: levantar de nuevo (`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d`).

## Apertura de puertos (seguridad)
- Asegúrate de abrir el puerto público que uses para la app (`WEB_PORT`) en el firewall del host.
- Ejemplo firewalld (RHEL/CentOS/Fedora):
  ```bash
  sudo firewall-cmd --permanent --add-port=8081/tcp
  sudo firewall-cmd --reload
  ```
- En otras distros, usa el equivalente (ufw/iptables) o la herramienta de tu proveedor cloud.

## Parar y limpiar
- Detener: `docker compose down`
- Detener y borrar datos de MySQL: `docker compose down -v`

## Notas y buenas prácticas
- Simplificado a 2 archivos, sin perfiles. Datos dev en `mysql_dev_data/` fuera de git; datos prod en volumen `mysql_data`.
- Mantén `.dockerignore` al día para builds rápidos (ya ignora vendor/node_modules, storage, cache, .env, etc.).
- Para CI/CD, puedes añadir pasos de `composer install --no-dev` y cacheo de config durante el build del stage `app`.
