#!/bin/bash
set -e

ENV=${APP_ENV:-local}

artisan_command() {
  echo "🚀 Running Artisan mode: $ENV ..."
  if [ "$ENV" = "production" ]; then
    php artisan config:cache || echo "⚠️  config:cache failed, skipping..."
    php artisan route:cache  || echo "⚠️  route:cache failed, skipping..."
    php artisan view:cache   || echo "⚠️  view:cache failed, skipping..."
    php artisan storage:link || echo "⚠️  storage:link failed, skipping..."
  elif [ "$ENV" = "local" ]; then
    php artisan config:clear || echo "⚠️  config:clear failed, skipping..."
    php artisan route:clear  || echo "⚠️  route:clear failed, skipping..."
    php artisan view:clear   || echo "⚠️  view:clear failed, skipping..."
    php artisan storage:link || echo "⚠️  storage:link failed, skipping..."
  fi
}

composer_install() {
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

install_yarn_dependencies() {
  echo "📦 Installing dependencies for environment: $ENV ..."

  if [ "$ENV" = "production" ]; then
    if yarn install --frozen-lockfile --production; then
      echo "✅ Production dependencies installed successfully."
    else
      echo "⚠️  yarn install (production) failed, but continuing..."
    fi

  elif [ "$ENV" = "local" ]; then
    if yarn install; then
      echo "✅ Local dependencies installed successfully."
    else
      echo "⚠️  yarn install (local) failed, but continuing..."
    fi
  else
    echo "❓ Unknown ENV: $ENV. Skipping dependency installation."
  fi
}

vite_command() {
  if [ "$ENV" = "production" ]; then
      echo "🏗️  Running Frontend Build ..."
      if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
        echo "🟢 Detected Vite config, using yarn build..."
      if yarn build; then
        echo "✅ Vite build completed."
      else
        echo "⚠️  yarn build failed or script not found!"
      fi

      elif [ -f "webpack.mix.js" ]; then
        echo "🟢 Detected Laravel Mix (Webpack), using yarn prod..."
      if yarn prod; then
        echo "✅ Webpack build completed."
      else
        echo "⚠️  yarn prod failed or script not found!"
      fi
    else
      echo "⚠️  No build config found (vite.config.* or webpack.mix.js). Skipping build."
    fi

  elif [ "$ENV" = "local" ]; then
    echo "🛠️  Running Dev Server..."
    if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
      echo "🟢 Detected Vite config, using yarn dev..."
    if yarn dev & then
      echo "✅ Dev server (Vite) is running in background."
    else
      echo "⚠️  yarn dev failed or script not found!"
    fi

    elif [ -f "webpack.mix.js" ]; then
      echo "🟢 Detected Laravel Mix (Webpack), using yarn watch..."
    if yarn watch & then
      echo "✅ Dev server (Webpack) is running in background."
    else
      echo "⚠️  yarn watch failed or script not found!"
    fi

    else
      echo "⚠️  No dev config found (vite.config.* or webpack.mix.js). Skipping dev server."
    fi
  fi
}

running_server() {
  if [ "$ENV" = "production" ]; then
      # Start PHP-FPM
        echo "Starting PHP-FPM System..."
        php-fpm83 -F &  # Jalankan PHP-FPM di latar belakang
        # Start Nginx
        echo "Starting Nginx System..."
        nginx &  # Jalankan Nginx di latar belakang
        # If no arguments were passed, wait for background processes
        echo "Logging Health Monitoring started ..."
        wait
    elif [ "$ENV" = "local" ]; then
       echo "Logging Health Monitoring started ..."
         php artisan serve --host=0.0.0.0 --port=80
    fi
}


composer_install
artisan_command
install_yarn_dependencies
vite_command
running_server



