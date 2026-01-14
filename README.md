# Entorno Docker Laravel (infra-only)

 Infraestructura lista para levantar un stack Laravel con Docker (dev y prod-like).
 Pensado para equipos que quieren levantar un entorno rápido y gestionan el código de la app fuera de este repo (aquí sólo hay infraestructura).

 ------------------------------------------------------------------------------

## Requisitos

 - Docker + Docker Compose plugin.
 - (Opcional) rsync para despliegue.

 ------------------------------------------------------------------------------

## Qué incluye

 Base / prod-like (docker-compose.yml)
 - Nginx
 - PHP-FPM (8.3)
 - MySQL (8.0)
 - Red y volumen con nombres semánticos (derivados de PROJECT_NAME)
 - Dependencias PHP (vendor/) generadas en el build (stage vendor con composer install --no-dev)

 Dev override (docker-compose.dev.yml)
 - Monta ./src como código de la app
 - Xdebug
 - phpMyAdmin (solo dev)
 - Servicio composer
 - MySQL portátil (persistencia en ./mysql_dev_data)

 ------------------------------------------------------------------------------

## Variables de entorno (archivo .env en la raíz)

 Variables principales:
 - PROJECT_NAME / COMPOSE_PROJECT_NAME: prefijo para contenedores/red/volúmenes.
 - WEB_PORT: puerto público de la app (default 8080).
 - PMA_PORT: puerto de phpMyAdmin en dev (default 8090).

 Versiones / tags:
 - MYSQL_IMAGE_TAG, PHPMYADMIN_IMAGE_TAG, COMPOSER_IMAGE_TAG
 - PHP_BASE_IMAGE, NGINX_BASE_IMAGE
 - XDEBUG_VERSION, REDIS_PECL_VERSION

 Nota: este .env es de infraestructura (no es el .env de Laravel dentro de src/).

 ------------------------------------------------------------------------------

## Estructura del repo

- docker-compose.yml: base/prod-like (Nginx, PHP, MySQL, vendor en build, red ${PROJECT_NAME}-net, volumen ${PROJECT_NAME}-mysql-data).
- docker-compose.dev.yml: override dev (montajes, Xdebug, phpMyAdmin en PMA_PORT, composer, MySQL portátil en mysql_dev_data).
- dockerfiles/: php.dockerfile (stage vendor con composer install), nginx.dockerfile, configs.
- nginx/: default.conf para la app.
- mysql/: .env.example (plantilla) y .env (no versionado).
- mysql_dev_data/: datos MySQL dev (portátil, fuera de git).
- src/: código de la app (ignorado en git); incluye placeholders en src/public para permitir builds sin app todavía.
- exclude-for-prod.txt: exclusiones sugeridas para rsync a prod.

------------------------------------------------------------------------------

## Comandos rápidos

 1) Cargar aliases:
   source ./docker-aliases.zsh

 2) DEV:
   dcdev up -d --build
   - App: http://localhost:${WEB_PORT:-8080}
   - phpMyAdmin: http://localhost:${PMA_PORT:-8090}

 3) Composer en dev:
   dcdev composer install
   dcdev composer create-project laravel/laravel .

 4) Artisan:
   dcdev exec php php artisan <comando>

 5) Detener dev:
   dcdev down

 6) PROD-like:
   dcprod up -d --build
   Nota: requiere que existan src/composer.json y src/public antes del build.

 ------------------------------------------------------------------------------

## Flujo completo: crear un proyecto desde cero

 1) Copiar la infraestructura a tu nuevo proyecto:
   cp -a /ruta/infra-base /ruta/nuevo-proyecto
   cd /ruta/nuevo-proyecto

 2) Editar .env (raíz):
   - Ajusta PROJECT_NAME, WEB_PORT, PMA_PORT y (si quieres) tags/versions.

 3) Crear mysql/.env desde la plantilla:
   cp mysql/.env.example mysql/.env
   - Edita credenciales dentro de mysql/.env

 4) Preparar datos portátiles dev:
   mkdir -p mysql_dev_data

 5) Levantar DEV:
   source ./docker-aliases.zsh
   dcdev up -d --build

 6) Crear Laravel dentro de src (usar . para que Nginx/PHP ya apunten bien):
   dcdev composer create-project laravel/laravel .

 7) Configurar src/.env de Laravel:
   - DB_HOST=mysql
   - DB creds según mysql/.env
   - APP_URL según tu host/puerto

 8) Inicializar app:
   dcdev exec php php artisan key:generate
   dcdev exec php php artisan migrate

 9) Empezar a codificar:
   - Edita en ./src
   - Ejemplos:
     dcdev exec php php artisan route:list
     dcdev exec php php artisan make:controller ExampleController

 ------------------------------------------------------------------------------
## Operación diaria (dev)

 - Arrancar / parar:
   dcdev up -d
   dcdev down

 - Composer:
   dcdev composer install
   dcdev composer update

 - Artisan:
   dcdev exec php php artisan <cmd>

 - Logs:
   dcdev logs server -f
   dcdev logs php -f
   dcdev logs mysql -f

 ------------------------------------------------------------------------------

## Producción / Staging

 Prerrequisitos (antes de dcprod up -d --build):
 - Deben existir src/composer.json y src/public (ideal también src/composer.lock).
 - El build genera vendor/ dentro de la imagen (no se sube por rsync).

 Levantar:
   dcprod up -d --build

 Detener:
   dcprod down

 ------------------------------------------------------------------------------

## Deploy (rsync)

 Comando sugerido:
   rsync -avz --exclude-from='exclude-for-prod.txt' ./ user@server:/ruta/

 Reglas importantes:
 - No excluir src/public/ (Nginx lo copia en el build).
 - No subir: mysql_dev_data, mysql/.env, src/.env.
 - Vendor: se genera en el build (composer install --no-dev), por eso sí puedes excluir src/vendor/ en exclude-for-prod.txt.

 ------------------------------------------------------------------------------

## Notas de seguridad

 - phpMyAdmin sólo en dev (no está en compose base/prod).
 - mysql/.env y src/.env no se versionan ni se suben a producción.
 - Expón sólo los puertos necesarios (WEB_PORT y PMA_PORT solo en dev).

 ------------------------------------------------------------------------------

## Troubleshooting

 - phpMyAdmin no conecta:
   - verifica que mysql/.env existe
   - revisa salud de MySQL:
     dcdev logs mysql -f

 - Build prod falla por dependencias:
   - asegúrate de tener src/composer.json (y opcional src/composer.lock) antes de:
     dcprod build php

 - 404/403 en Nginx:
   - confirma que src/public existe y contiene index.php.

 - Limpieza (cuidado: elimina datos):
   - dcdev down -v borra volúmenes; en dev tu MySQL portable está en mysql_dev_data (carpeta), pero revisa antes de borrar.

