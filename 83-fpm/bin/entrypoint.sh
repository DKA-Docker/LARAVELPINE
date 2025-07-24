#!/bin/bash
set -e

ENV=${APP_ENV:-local}

optimize_for_prod_env() {
  if composer install --no-dev --optimize-autoloader; then
    echo "✅ Production dependencies installed successfully."
  else
    echo "⚠️  yarn install (production) failed, but continuing..."
  fi
  if yarn install --frozen-lockfile --no-dev; then
    echo "✅ Production dependencies installed successfully."
  else
    echo "⚠️  yarn install (production) failed, but continuing..."
  fi
}
building_yarn() {
  echo "🏗️  Running Frontend Build ..."
  if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
    ############################################################
    echo "🟢 Detected Vite config, using yarn build..."
    if yarn build; then
      echo "✅ Vite build completed."
    else
      echo "⚠️  yarn build failed or script not found!"
    fi
  elif [ -f "webpack.mix.js" ]; then
    ############################################################
    echo "🟢 Detected Laravel Mix (Webpack), using yarn prod..."
    if yarn prod; then
      echo "✅ Webpack build completed."
    else
      echo "⚠️  yarn prod failed or script not found!"
    fi
    ############################################################
  else
    echo "⚠️  No build config found (vite.config.* or webpack.mix.js). Skipping build."
  fi
}

installing_packages() {
  echo "🛠️  Running NodeJS & Composer Package Combo..."
  ################## COMPOSER INSTALL ##################
  if composer install; then
      echo "Installing all composer packages Successfully."
  else
    echo "⚠️  composer install failed, but continuing..."
  fi
  ################## YARN INSTALL ######################
  if yarn install; then
    echo "✅ Local dependencies installed successfully."
  else
    echo "⚠️  yarn install (local) failed, but continuing..."
  fi
  # building yarn
}
artisan_command() {
  installing_packages
  echo "🧹 Reverting Artisan mode: $ENV ..."
  if [ "$ENV" = "production" ]; then
    building_yarn
    php artisan config:clear  || echo "⚠️  config:clear failed, skipping..."
    php artisan route:clear   || echo "⚠️  route:clear failed, skipping..."
    php artisan view:clear    || echo "⚠️  view:clear failed, skipping..."
    php artisan event:clear   || echo "⚠️  event:clear failed, skipping..."
    php artisan cache:clear   || echo "⚠️  app cache:clear failed, skipping..."
    php artisan queue:restart   || echo "⚠️  Queue restart failed, skipping..."
    echo "🧼 All production caches cleared and queue/migrate handled."
  elif [ "$ENV" = "local" ]; then
    php artisan config:cache  || echo "⚠️  config:cache failed, skipping..."
    php artisan view:clear    || echo "⚠️  view:clear failed, skipping..."
    php artisan route:clear   || echo "⚠️  route:clear failed, skipping..."
    php artisan event:clear   || echo "⚠️  event:clear failed, skipping..."
    php artisan storage:link  || echo "⚠️  storage:link failed, skipping..."
    php artisan migrate --force || echo "⚠️  Migration failed, skipping..."
    php artisan queue:restart   || echo "⚠️  Queue restart failed, skipping..."
    echo "💻 Local environment dev-safe & up-to-date."
  fi
}
running_dev_server() {
  artisan_command
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
  php artisan serve --host=0.0.0.0 --port=80
}
running_prod_server() {
  optimize_for_prod_env
  artisan_command
  # Start PHP-FPM
  echo "Starting PHP-FPM System..."
  php-fpm83 -F &  # Jalankan PHP-FPM di latar belakang
  # Start Nginx
  echo "Starting Nginx System..."
  nginx &  # Jalankan Nginx di latar belakang
  # If no arguments were passed, wait for background processes
  echo "Logging Health Monitoring started ..."
  wait
}
running_server() {
  if [ "$ENV" = "production" ]; then
    echo "Logging Health Monitoring started ..."
    running_prod_server
  elif [ "$ENV" = "local" ]; then
    echo "Logging Health Monitoring started ..."
    running_dev_server
  fi
}

running_server



