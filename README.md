# Entorno Laravel con Docker (dev y prod)

## Qué es
Base de infraestructura Docker para proyectos Laravel (este repo no versiona `./src`, solo la infra). Se trabaja con dos archivos: uno base “prod-like” y un override para desarrollo, sin perfiles; eliges entorno por el archivo que incluyes. En dev los datos de MySQL viven en `./mysql_dev_data/` (portátil y sin versionar). En prod se mantiene el volumen nombrado `mysql_data` y se incluye phpMyAdmin.

## Comandos rápidos
- Desarrollo: `UID=$(id -u) GID=$(id -g) docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build`
- Producción/Staging (sin dominio): `UID=$(id -u) GID=$(id -g) WEB_PORT=8081 PMA_PORT=8090 docker compose up -d --build` (`WEB_PORT` y `PMA_PORT` son opcionales; por defecto exponen 8080 y 8090).

Atajos opcionales
- Carga los aliases en cada sesión de shell (no se instalan globalmente): `source ./docker-aliases.zsh` desde la raíz del proyecto. Si estás fuera del directorio, usa la ruta absoluta al script.
- Esto define `dcdev` (dev) y `dcprod` (prod/staging) sin perfiles ni archivos extra.
- Ejemplos rápidos:
  - Dev: `dcdev up -d --build`, `dcdev run --rm composer install`, `dcdev exec php php artisan migrate`
  - Prod/Staging: `dcprod up -d --build`

## Requisitos
- Docker y Docker Compose v2.
- Puertos libres: 8080 (app por defecto), 8090 (phpMyAdmin en dev y prod). Si quieres otros puertos públicos, ajusta `WEB_PORT` y `PMA_PORT`.
- El directorio `mysql_dev_data/` debe permanecer fuera de git; ya está en `.gitignore`/`.dockerignore`. También se ignora `src/` y `mysql_data/` en git (solo infra aquí).
- El archivo raíz `.env` (versionado) define tags/base images y puertos por defecto.

## Estructura rápida
- `docker-compose.yml`: base común (nginx + php-fpm + MySQL + phpMyAdmin). Código empaquetado (`target: app`), Xdebug apagado, `APP_ENV=production`. Puertos configurables con `WEB_PORT` (app) y `PMA_PORT` (phpMyAdmin). MySQL usa volumen nombrado `mysql_data`. Imágenes basadas en tags de `.env`.
- `docker-compose.dev.yml`: override dev (montajes de código, Xdebug, phpMyAdmin con restart relajado, servicio composer con imagen oficial, opcache ajustado). MySQL monta `./mysql_dev_data` para que los datos sean portátiles.
- `dockerfiles/`: nginx (copia config y `public/`), php (multi-stage con Xdebug opcional). Composer usa imagen oficial, no Dockerfile propio. Base images parametrizadas vía args/`.env`.
- `src/`: código de la app (no se versiona aquí); en dev se monta, en prod se copia en el build base. Nginx solo copia `public/`.

## Variables de entorno mínimas
- Crea `mysql/.env` (no se versiona):
  ```
  MYSQL_ROOT_PASSWORD=root.pa55
  MYSQL_DATABASE=laravel
  MYSQL_USER=laravel
  MYSQL_PASSWORD=laravel.pa55
  ```
- Prepara el `.env` de Laravel en `src/` (APP_KEY, DB_*, etc.).
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
UID=$(id -u) GID=$(id -g) WEB_PORT=8081 PMA_PORT=8090 \
docker compose up -d --build
```
Acceso: `http://IP-del-servidor:${WEB_PORT:-8080}` y phpMyAdmin en `http://IP-del-servidor:${PMA_PORT:-8090}`.
Incluye:
- Código empaquetado en la imagen (`target: app`), sin montajes de host.
- MySQL con volumen nombrado `mysql_data` (persistente en el host).
- phpMyAdmin con `restart: unless-stopped` apuntando a MySQL.
- Xdebug deshabilitado, `APP_ENV=production`, `APP_DEBUG=false`.
- Tags de imágenes y puertos vienen de `.env` (puedes sobreescribirlos al exportar variables).

## Operación segura con carpeta sincronizada (`mysql_dev_data`)
- Antes de cambiar de máquina o suspender: `docker compose down` (o `dcdev down`).
- Espera a que termine la sincronización de `mysql_dev_data/` (Syncthing/Drive/Dropbox/rsync).
- En la otra máquina: levantar de nuevo (`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d`).

## Apertura de puertos (seguridad)
- Asegúrate de abrir los puertos públicos que uses (`WEB_PORT` y `PMA_PORT`) en el firewall del host.
- Ejemplo firewalld (RHEL/CentOS/Fedora):
  ```bash
  sudo firewall-cmd --permanent --add-port=8081/tcp
  sudo firewall-cmd --permanent --add-port=8090/tcp
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
