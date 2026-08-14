# Use the official Alpine Linux image as a base
FROM alpine:3.23.0

# Maintainer
LABEL maintainer="Yovangga Anandhika <dka.tech.dev@gmail.com>"

# Install system packages & PHP + build deps
RUN apk update && apk add --no-cache aws-cli \
  chromium nss freetype harfbuzz ca-certificates ttf-freefont nodejs npm \
  tzdata bash nano curl git zip unzip openssl libc6-compat gcompat \
  mariadb-client postgresql-client \
  iputils iproute2 \
  imagemagick imagemagick-dev \
  libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev zlib-dev \
  icu-dev gettext-dev libxml2-dev oniguruma-dev \
  php85 php85-fpm php85-cli php85-posix php85-pcntl php85-redis php85-bcmath php85-common php85-phar php85-ctype \
  php85-curl php85-dom php85-exif php85-fileinfo php85-gd php85-gettext php85-iconv \
  php85-intl php85-json php85-mbstring php85-mysqli php85-mysqlnd php85-pdo \
  php85-pdo_mysql php85-pdo_sqlite php85-pdo_pgsql php85-pgsql php85-simplexml php85-soap php85-sockets \
  php85-sodium php85-sqlite3 php85-session php85-tokenizer php85-xml php85-xmlreader \
  php85-xmlwriter php85-zip php85-openssl php85-ldap php85-pecl-imagick \
  && ln -sf /usr/bin/php85 /usr/bin/php \
  && curl -fsSL https://bun.sh/install | bash \
  && mv /root/.bun/bin/bun /usr/local/bin/bun \
  && rm -rf /var/cache/apk/*

# Set the timezone (e.g., Asia/Makassar)
ENV TZ=Asia/Makassar \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Create a user
RUN adduser -S www-data -G www-data

# Create the application directory
RUN mkdir -p /var/www && mkdir -p /var/run/php

# Copy PHP-FPM configuration file
COPY .config/php /etc/php85

# Create Log Dir
COPY .config/log /var/log/

# Set permissions
RUN chown -R www-data:www-data /var/www

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Set the working directory
WORKDIR /var/www

# Install Laravel On Global
RUN composer create-project laravel/laravel .

# install addons package
RUN composer require barryvdh/laravel-debugbar --dev
RUN composer require laravel/octane
#RUN yes | php artisan octane:install --server=frankenphp
#RUN chmod +x frankenphp

# install packages with Bun
RUN bun install

# set permission laravel storage
RUN chown -R www-data:www-data storage && chown -R www-data:www-data bootstrap/cache
RUN chmod -R 775 storage && chmod -R 775 bootstrap/cache && chmod -R ug+rwx storage bootstrap/cache

# link storage secara default
RUN php artisan storage:link

# Configure entrypoint script
COPY bin/* /usr/local/bin/

# set Execution bin dir
RUN chmod +x /usr/local/bin/*

# Buat script Health Check
HEALTHCHECK --interval=5s --timeout=3s --retries=5 CMD /usr/local/bin/healthcheck.sh

# Expose ports
EXPOSE 80 5173

# Set the entrypoint to the script
ENTRYPOINT ["entrypoint.sh"]