# https://github.com/docker-library/php/issues/797
ARG PHP_EXTS="pdo pdo_mysql pcntl zip gd intl"
ARG PHP_EXT_HOSTS="zip libzip-dev freetype-dev libjpeg-turbo-dev libpng-dev libwebp-dev imagemagick imagemagick-pdf imagemagick-dev pkgconf icu icu-dev"
ARG PHP_EXTS_DEB="pdo pdo_mysql pcntl zip gd intl"
ARG PHP_EXTS_DEB_HOSTS="zip libzip-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev libmagickwand-dev libicu-dev"

# ========================================
# Install extensions
# ========================================
FROM composer:lts AS build
COPY . /app/
RUN mkdir storage && \
    mkdir storage/framework && \
    mkdir storage/framework/sessions && \
    mkdir storage/framework/views && \
    mkdir storage/framework/cache && \
    mkdir storage/app && \
    mkdir storage/app/public && \
    composer update --prefer-dist --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs



# ========================================
# For bg jobs
# ========================================
FROM alpine:3 AS beanstalkd

RUN apk update && apk add beanstalkd

EXPOSE 11300

CMD /usr/bin/beanstalkd -V



# ========================================
# FPM server to process requests
# ========================================
FROM php:8.4-fpm-alpine AS fpm_server

ARG PHP_EXTS
ARG PHP_EXT_HOSTS

WORKDIR /opt/apps/www

COPY docker/php/conf.d/php.ini /usr/local/etc/php/conf.d/php.ini

RUN apk update && apk add ${PHP_EXT_HOSTS} && \
    docker-php-ext-configure opcache --enable-opcache && \
    docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype && \
    docker-php-ext-configure intl && \
    pecl config-set php_ini /usr/local/etc/php/conf.d/php.ini && \
    pecl install imagick && \
    docker-php-ext-enable imagick && \
    docker-php-ext-install ${PHP_EXTS}

# As FPM uses the www-data user when running our application,
# we need to make sure that we also use that user when starting up,
# so our user "owns" the application when running
USER www-data

COPY --from=build --chown=www-data:www-data /app /opt/apps/www

RUN mkdir -p /opt/apps/www/storage/logs && \
    chmod -R 777 /opt/apps/www/storage && \
    php artisan telescope:publish && \
    php artisan horizon:publish



# ========================================
# For php artisan cli etc
# ========================================
FROM php:8.4-bullseye AS cli

ARG PHP_EXTS_DEB
ARG PHP_EXTS_DEB_HOSTS

WORKDIR /var/www/html

COPY docker/php/conf.d/php.ini /usr/local/etc/php/conf.d/php.ini
COPY --from=build --chown=www-data:www-data /app /var/www/html

RUN apt-get update && apt-get install -y ${PHP_EXTS_DEB_HOSTS} && \
    docker-php-ext-configure opcache --enable-opcache && \
    docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype && \
    docker-php-ext-configure intl && \
    pecl install imagick && \
    docker-php-ext-enable imagick &&\
    docker-php-ext-install ${PHP_EXTS_DEB}



# ========================================
# NGINX container
# ========================================
FROM nginx:1.23-alpine AS nginx_server
WORKDIR /opt/apps/www


# We need to add our NGINX template to the container for startup,
# and configuration.
COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template

# Copy in ONLY the public directory of our project.
# This is where all the static assets will live, which nginx will serve for us.
COPY --from=build /app/public /opt/apps/www/public
