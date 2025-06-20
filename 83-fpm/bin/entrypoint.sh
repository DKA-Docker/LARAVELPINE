#!/bin/bash
set -e

PERMISSION_ROOT=${DKA_PERMISSION_ROOT:-false}

COMPOSER_INSTALL=${DKA_COMPOSER_INSTALL:-dev}
ARTISAN_CACHE=${DKA_ARTISAN_CACHE:-false}

permission_command() {
  if [ "$PERMISSION_ROOT" = "true" ]; then
    echo "setup privileges www-data & storage, database, cache ..."
    chown -R www-data:www-data storage database bootstrap/cache && chmod -R 775 storage database bootstrap/cache
  fi
}

artisan_command() {
  if [ "$ARTISAN_CACHE" = "true" ]; then
    echo "Artisan cache detected true ..."
    php artisan config:cache && php artisan route:cache && php artisan view:cache && php artisan storage:link
  else
    php artisan config:clear && php artisan route:clear && php artisan view:clear && php artisan storage:link
  fi
}

composer_command() {
  if [ "$COMPOSER_INSTALL" = "prod" ]; then
    echo "detect composer install before run as prod ..."
    composer install --no-dev --optimize-autoloader
  elif [ "$COMPOSER_INSTALL" = "dev" ]; then
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
running_engine "$@"

