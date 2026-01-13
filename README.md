# Entorno Laravel con Docker (dev y prod)

## Qué es
Base genérica para correr proyectos Laravel en contenedores, con perfiles separados para desarrollo y producción/staging.

## Comandos rápidos
- Desarrollo: `UID=$(id -u) GID=$(id -g) docker compose -f docker-compose.yml -f docker-compose.dev.yml --profile dev up -d --build`
- Producción/Staging (sin dominio): `UID=$(id -u) GID=$(id -g) docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile prod up -d --build` (accede en `http://IP:8081`)

Atajos opcionales
- Carga los aliases en cada sesión de shell (no se instalan globalmente): `source ./docker-aliases.zsh` desde la raíz del proyecto. Si estás fuera del directorio, usa la ruta absoluta al script.
- Esto define `dcdev` (perfil dev) y `dcprod` (perfil prod) apuntando a los compose locales.
- Ejemplos rápidos:
  - Dev: `dcdev up -d --build`, `dcdev run --rm composer install`, `dcdev run --rm artisan migrate`
  - Prod/Staging: `dcprod up -d --build`

## Requisitos
- Docker y Docker Compose v2.
- Puertos libres: 8080 (interno app), 8081 (expuesto en prod/staging), 8090 (phpMyAdmin solo dev).

## Estructura rápida
- `docker-compose.yml`: base común (nginx + php-fpm + MySQL, sin montajes).
- `docker-compose.dev.yml`: override dev (montajes, Xdebug, phpMyAdmin, composer/artisan).
- `docker-compose.prod.yml`: override prod/staging (mapea 8081, sin Xdebug ni montajes de código).
- `dockerfiles/`: nginx, php (multi-stage con Xdebug opcional) y composer.
- `src/`: código de la app (montado en dev, copiado en prod/staging).

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

## Desarrollo (perfil dev)
```bash
UID=$(id -u) GID=$(id -g) \
docker compose -f docker-compose.yml -f docker-compose.dev.yml --profile dev up -d --build
```
Incluye:
- Montaje de `./src` en nginx/php/composer/artisan.
- Xdebug activo (target `base`), phpMyAdmin en `http://localhost:8090`.

Comandos útiles (dev):
- Dependencias: `docker compose -f docker-compose.yml -f docker-compose.dev.yml --profile dev run --rm composer install`
- APP_KEY: `docker compose -f docker-compose.yml -f docker-compose.dev.yml --profile dev run --rm artisan key:generate`
- Migraciones: `docker compose -f docker-compose.yml -f docker-compose.dev.yml --profile dev run --rm artisan migrate`

## Producción / Staging sin dominio (perfil prod)
Puerta de salida: `8081` para no chocar con otros sitios. Mapeo interno `8081:8080`.
```bash
UID=$(id -u) GID=$(id -g) \
docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile prod up -d --build
```
Acceso: `http://IP-del-servidor:8081`
Incluye:
- Código empaquetado en la imagen (`target: app`), sin montajes de host.
- Nginx interno en 8080; publicado 8081.
- Xdebug deshabilitado, `APP_ENV=production`, `APP_DEBUG=false`.

## Proxy frontal (Traefik) opcional
Si usas Traefik como proxy único en 80/443:
- Habilita el contenedor Traefik aparte y conéctalo a la misma red de este stack.
- Ejemplo de labels ya incluidos en `docker-compose.prod.yml` (ajusta dominio):
  - `traefik.enable=true`
  - `traefik.http.routers.laravel.rule=Host(`tu-dominio.com`)
  - `traefik.http.routers.laravel.entrypoints=web` (o `websecure` para TLS)
  - `traefik.http.services.laravel.loadbalancer.server.port=8080`
- Para TLS automático, añade en Traefik `entrypoints` `websecure` y `certresolver` configurado (Let’s Encrypt), y cambia el router a `entrypoints=websecure` + `tls=true`.
- El contenedor sigue escuchando 8080; Traefik sirve 80/443.

Ejemplo mínimo de Traefik (compose separado):
```yaml
services:
  traefik:
    image: traefik:v2.11
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      # Descomenta y configura para Let’s Encrypt
      # - "--certificatesresolvers.le.acme.httpchallenge=true"
      # - "--certificatesresolvers.le.acme.httpchallenge.entrypoint=web"
      # - "--certificatesresolvers.le.acme.email=tu-correo"
      # - "--certificatesresolvers.le.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - laravel-docker
networks:
  laravel-docker:
    external: true
```
Levantar Traefik:
```bash
docker compose -f traefik.docker-compose.yml up -d
```

## Apertura de puertos (seguridad)
- Asegúrate de abrir el puerto público que uses (por defecto 8081) en el firewall del host.
- Ejemplo firewalld (RHEL/CentOS/Fedora):
  ```bash
  sudo firewall-cmd --permanent --add-port=8081/tcp
  sudo firewall-cmd --reload
  ```
- En otras distros, usa el equivalente (ufw/iptables) o la herramienta de tu proveedor cloud.

## Cuando haya dominio + TLS
- Con proxy frontal: deja el contenedor en 8080 y configura el router (labels) al dominio en Traefik/Caddy/Nginx.
- Sin proxy: cambia el mapeo a `80:8080` y gestiona certs en Nginx interno (no recomendado para múltiples proyectos).

## Parar y limpiar
- Detener: `docker compose down`
- Detener y borrar datos de MySQL: `docker compose down -v`

## Notas y buenas prácticas
- No actives el perfil `dev` en producción.
- Mantén `.dockerignore` al día para builds rápidos (ya ignora vendor/node_modules, storage, cache, .env, etc.).
- Para CI/CD, puedes añadir pasos de `composer install --no-dev` y cacheo de config durante el build del stage `app`.
