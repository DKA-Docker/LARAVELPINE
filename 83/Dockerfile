# Use the official Alpine Linux image as a base
FROM alpine:3.21.0

# Maintainer
LABEL maintainer="Yovangga Anandhika <dka.tech.dev@gmail.com>"

# Install Bun
COPY --from=oven/bun:alpine /usr/local/bin/bun /usr/local/bin/bun

# Install system packages & PHP + build deps
RUN apk update && apk add --no-cache \
  tzdata bash nano curl git zip unzip openssl libc6-compat gcompat \
  mariadb-client postgresql-client \
  iputils iproute2 \
  imagemagick imagemagick-dev \
  libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev zlib-dev \
  icu-dev gettext-dev libxml2-dev oniguruma-dev \
  php83 php83-fpm php83-cli php83-posix php83-pcntl php83-redis php83-bcmath php83-common php83-opcache php83-phar php83-ctype \
  php83-curl php83-dom php83-exif php83-fileinfo php83-gd php83-gettext php83-iconv \
  php83-intl php83-json php83-mbstring php83-mysqli php83-mysqlnd php83-pdo \
  php83-pdo_mysql php83-pdo_sqlite php83-pdo_pgsql php83-pgsql php83-simplexml php83-soap php83-sockets \
  php83-sodium php83-sqlite3 php83-session php83-tokenizer php83-xml php83-xmlreader \
  php83-xmlwriter php83-zip php83-openssl php83-ldap \
  autoconf g++ make php83-dev php83-pear  \
  && pecl install imagick \
  && echo "extension=imagick.so" > /etc/php83/conf.d/00_imagick.ini \
  && rm -rf /tmp/pear /var/cache/apk/*

# Set the timezone (e.g., Asia/Makassar)
ENV TZ=Asia/Makassar

# Create a user
RUN adduser -S www-data -G www-data

# Create the application directory
RUN mkdir -p /var/www && mkdir -p /var/run/php

# Copy PHP-FPM configuration file
COPY .config/php /etc/php83

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
RUN yes | php artisan octane:install --server=frankenphp
RUN chmod +x frankenphp

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