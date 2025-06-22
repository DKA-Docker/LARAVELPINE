#!/bin/bash
set -e

ENV=${APP_ENV:-local}

permission_command() {
  if [ "$ENV" == "local" ]; then
    echo "[LOCAL ENV] Granting dev-friendly permissions..."
    chown -R www-data:www-data .
    find . -mindepth 1 -not -path "./.git*" -exec chown -R www-data:www-data {} + -exec chmod -R 777 {} +
    echo "[LOCAL ENV] Folder => 775, File => 664. Aman buat develop, gak kebablasan 😎"
  elif [ "$ENV" == "production" ]; then
    echo "[PRODUCTION ENV] Locking down permissions..."
    chown -R www-data:www-data .
    find . -type d -not -path "./.git*" -exec chmod 755 {} \;
    find . -type f -not -path "./.git*" -exec chmod 644 {} \;
    chmod -R 775 storage bootstrap/cache database
    echo "[PRODUCTION ENV] ✅ Permissions locked. Laravel secure like a vault 🔒"
  fi
}

artisan_command() {
  echo "Running Artisan mode $ENV ..."
  if [ "$ENV" = "production" ]; then
    php artisan config:cache && php artisan route:cache && php artisan view:cache && php artisan storage:link
  elif [ "$ENV" = "local" ]; then
    php artisan config:clear && php artisan route:clear && php artisan view:clear && php artisan storage:link
  fi
}

composer_command() {
  if [ "$ENV" = "production" ]; then
    echo "detect composer install before run as prod ..."
    composer install --no-dev --optimize-autoloader
    echo "composer install run as prod successfully..."
  elif [ "$ENV" = "local" ]; then
     echo "detect composer install before run as dev ..."
     composer install
     echo "composer install run as dev successfully..."
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

