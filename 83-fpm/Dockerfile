# ============ Stage 1: Build ext-http di Debian ============
FROM php:8.3-cli as extbuilder

RUN apt update && apt install -y git unzip gcc g++ make libcurl4-openssl-dev libevent-dev zlib1g-dev \
  && pecl install raphf-2.0.1 \
  && pecl install propro-2.1.0 \
  && pecl install pecl_http-4.2.2

# ============ Stage 2: Alpine Final ============
FROM alpine:3.21.0

LABEL maintainer="Yovangga Anandhika <dka.tech.dev@gmail.com>"

RUN apk update && apk add --no-cache \
  tzdata bash nano curl git zip unzip openssl \
  nginx nodejs npm mariadb-client \
  iputils iproute2 \
  imagemagick imagemagick-dev \
  libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev zlib-dev \
  icu-dev gettext-dev libxml2-dev oniguruma-dev \
  php php83 php83-fpm php83-cli php83-bcmath php83-common php83-opcache php83-phar php83-ctype \
  php83-curl php83-dom php83-exif php83-fileinfo php83-gd php83-gettext php83-iconv \
  php83-intl php83-json php83-mbstring php83-mysqli php83-mysqlnd php83-pdo \
  php83-pdo_mysql php83-pdo_sqlite php83-simplexml php83-soap php83-sockets \
  php83-sodium php83-sqlite3 php83-session php83-tokenizer php83-xml php83-xmlreader \
  php83-xmlwriter php83-zip php83-openssl php83-ldap \
  autoconf g++ make php83-dev php83-pear curl-dev libevent-dev \
  && npm install -g yarn \
  && pecl install imagick \
  && echo "extension=imagick.so" > /etc/php83/conf.d/00_imagick.ini \
  && rm -rf /tmp/pear /var/cache/apk/*

# Salin hasil build dari Debian ke Alpine
COPY --from=extbuilder /usr/local/lib/php/extensions/no-debug-non-zts-*/raphf.so /usr/lib/php83/modules/
COPY --from=extbuilder /usr/local/lib/php/extensions/no-debug-non-zts-*/propro.so /usr/lib/php83/modules/
COPY --from=extbuilder /usr/local/lib/php/extensions/no-debug-non-zts-*/http.so /usr/lib/php83/modules/

# Aktifkan ext-nya
RUN echo "extension=raphf.so"   > /etc/php83/conf.d/00_raphf.ini \
 && echo "extension=propro.so"  > /etc/php83/conf.d/00_propro.ini \
 && echo "extension=http.so"    > /etc/php83/conf.d/00_http.ini

# Set the timezone (e.g., Asia/Makassar)
ENV TZ=Asia/Makassar
# Create a user
RUN adduser -S www-data -G www-data
# Create the application directory
RUN mkdir -p /var/www && mkdir -p /var/run/php
# Copy Nginx configuration file
COPY .config/nginx /etc/nginx
# Copy PHP-FPM configuration file
COPY .config/php /etc/php83
# Create Log Dir
COPY .config/log /var/log/
# Set permissions
RUN chown -R www-data:www-data /var/www
# hapus folder bawaan nginx
RUN rm -rf /var/www/localhost
# Install Composer
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer
# Set the working directory
WORKDIR /var/www
# Install Laravel On Global
RUN composer create-project laravel/laravel . && composer require barryvdh/laravel-debugbar --dev
# Hapus Env Bawaan
RUN rm -rf .env composer.lock yarn.lock package.lock
# set permission laravel storage
RUN chown -R www-data:www-data . && chmod -R 777 .
# Configure entrypoint script
COPY bin/* /usr/local/bin/
# set Execution bin dir
RUN chmod +x /usr/local/bin/*
# Expose ports
EXPOSE 80 5173
# Set the entrypoint to the script
ENTRYPOINT ["entrypoint.sh"]