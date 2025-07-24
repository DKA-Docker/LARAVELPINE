#!/bin/bash
set -e

ENV=${APP_ENV:-local}

# Cek dependencies penting
command -v composer >/dev/null 2>&1 || { echo >&2 "❌ Composer not found."; exit 1; }
command -v yarn >/dev/null 2>&1 || { echo >&2 "❌ Yarn not found."; exit 1; }

installing_packages() {
  echo "📦 Installing packages for: $ENV"
  if [ "$ENV" = "production" ]; then
    # Step 1: Install full composer & yarn for building
    composer install || echo "⚠️ composer install failed"
    yarn install --frozen-lockfile || echo "⚠️ yarn install failed"
  else
    # Local dev install
    composer install || echo "⚠️ composer install failed"
    yarn install || echo "⚠️ yarn install failed"
  fi
}

optimize_for_prod_env() {
  echo "🧪 Optimizing production dependencies..."
  composer install --no-dev --optimize-autoloader || echo "⚠️ composer --no-dev failed"
  yarn install --frozen-lockfile --no-dev || echo "⚠️ yarn --no-dev failed"
}

building_assets() {
  echo "🏗️  Building frontend assets..."
  if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
    echo "🟢 Vite detected"
    yarn build || echo "⚠️ yarn build failed!"
  elif [ -f "webpack.mix.js" ]; then
    echo "🟢 Laravel Mix (Webpack) detected"
    yarn prod || echo "⚠️ yarn prod failed!"
  else
    echo "⚠️ No frontend build config detected. Skipping..."
  fi
}

artisan_command() {
  echo "🧹 Artisan init for: $ENV"
  installing_packages
  if [ "$ENV" = "production" ]; then
    building_assets
    optimize_for_prod_env
    php artisan config:cache  || echo "⚠️ config:cache failed"
    php artisan route:cache   || echo "⚠️ route:cache failed"
    php artisan view:cache    || echo "⚠️ view:cache failed"
    php artisan event:cache   || echo "⚠️ event:cache failed"
    php artisan queue:restart || echo "⚠️ queue:restart failed"
    php artisan storage:link  || echo "⚠️ storage:link failed"
    echo "✅ Production ready."
  else
    php artisan config:clear  || echo "⚠️ config:clear failed"
    php artisan route:clear   || echo "⚠️ route:clear failed"
    php artisan view:clear    || echo "⚠️ view:clear failed"
    php artisan event:clear   || echo "⚠️ event:clear failed"
    php artisan storage:link  || echo "⚠️ storage:link failed"
    php artisan migrate --force || echo "⚠️ migration failed"
    php artisan queue:restart || echo "⚠️ queue:restart failed"
    echo "💻 Local environment is clean & updated."
  fi
}

running_dev_server() {
  artisan_command
  echo "🛠️ Running local dev servers..."
  if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
    echo "🟢 Starting Vite dev server..."
    yarn dev &  # Run Vite in background
  elif [ -f "webpack.mix.js" ]; then
    echo "🟢 Starting Laravel Mix watcher..."
    yarn watch &  # Run watcher in background
  else
    echo "⚠️ No dev server config detected."
  fi
  php artisan serve --host=0.0.0.0 --port=80
}

running_prod_server() {
  artisan_command
  echo "🚀 Starting production server stack..."
  php-fpm83 -F &  # PHP-FPM in foreground mode
  nginx &         # Start Nginx in background
  echo "📈 Health monitoring active."
  wait
}

running_server() {
  echo "🧭 Starting Laravel App in $ENV mode..."
  if [ "$ENV" = "production" ]; then
    running_prod_server
  else
    running_dev_server
  fi
}

# GO GO GO
running_server
