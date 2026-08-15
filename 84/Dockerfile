# Use the official Alpine Linux image as a base
FROM alpine:3.21.0

# Maintainer
LABEL maintainer="Yovangga Anandhika <dka.tech.dev@gmail.com>"

# Install system packages & PHP + build deps
RUN apk update && apk add --no-cache tini aws-cli \
  chromium nss freetype harfbuzz ca-certificates ttf-freefont nodejs npm \
  tzdata bash nano curl git zip unzip openssl libc6-compat gcompat \
  mariadb-client postgresql-client \
  iputils iproute2 \
  imagemagick \
  php84 php84-fpm php84-cli php84-posix php84-pcntl php84-pecl-redis php84-bcmath php84-common php84-opcache php84-phar php84-ctype \
  php84-curl php84-dom php84-exif php84-fileinfo php84-gd php84-gettext php84-iconv \
  php84-intl php84-json php84-mbstring php84-mysqli php84-mysqlnd php84-pdo \
  php84-pdo_mysql php84-pdo_sqlite php84-pdo_pgsql php84-pgsql php84-simplexml php84-soap php84-sockets \
  php84-sodium php84-sqlite3 php84-session php84-tokenizer php84-xml php84-xmlreader \
  php84-gmp php84-pecl-apcu php84-pecl-igbinary php84-pecl-uuid php84-pecl-yaml php84-pecl-mailparse php84-bz2 \
  php84-xmlwriter php84-zip php84-openssl php84-ldap php84-pecl-imagick \
  && ln -sf /usr/bin/php84 /usr/bin/php \
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
COPY .config/php /etc/php84

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
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]