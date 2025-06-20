#!/bin/bash
set -e

PERMISSION_ROOT=${DKA_PERMISSION_ROOT:-false}
AUTO_MIGRATE=${DKA_AUTO_MIGRATE:-false}
ENV=${APP_ENV:-local}
COMPOSER_INSTALL=${ENV:-local}
ARTISAN_MODE=${ENV:-local}

artisan_migrate() {
  if [[ "$AUTO_MIGRATE" == "true" && "$ENV" == "local" ]]; then
    php artisan migrate
  fi
}

permission_command() {
  if [ "$PERMISSION_ROOT" = "true" ]; then
    echo "setup privileges www-data & storage, database, cache ..."
    chown -R www-data:www-data storage database bootstrap/cache && chmod -R 775 storage database bootstrap/cache
  fi
}

artisan_command() {
  echo "Artisan cache detected $ARTISAN_MODE ..."
  if [ "$ARTISAN_MODE" = "production" ]; then
    php artisan config:cache && php artisan route:cache && php artisan view:cache && php artisan storage:link
  elif [ "$ARTISAN_MODE" = "local" ]; then
    php artisan config:clear && php artisan route:clear && php artisan view:clear && php artisan storage:link
  fi
}

composer_command() {
  if [ "$COMPOSER_INSTALL" = "production" ]; then
    echo "detect composer install before run as prod ..."
    composer install --no-dev --optimize-autoloader
  elif [ "$COMPOSER_INSTALL" = "local" ]; then
     echo "detect composer install before run as dev ..."
     composer install
  fi
}

running_engine() {
  # Start PHP-FPM
  echo "Starting PHP-FPM System..."
  php-fpm83 -F &  # Jalankan PHP-FPM di latar belakang

  # Start Nginx
  echo "Starting Nginx System..."
  nginx &  # Jalankan Nginx di latar belakang

  # Tunggu jika tidak ada argumen, atau eksekusi argumen jika ada
  if [ "$#" -gt 0 ]; then
      # If arguments exist, execute them
      exec "$@"
  else
      # If no arguments were passed, wait for background processes
      echo "Logging Health Monitoring started ..."
      wait
  fi
}

permission_command
composer_command
artisan_command
artisan_migrate
running_engine "$@"

