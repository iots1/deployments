FROM --platform=linux/amd64 php:8.2-fpm

# Set working directory
WORKDIR /var/www

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    jpegoptim optipng pngquant gifsicle \
    unzip \
    git \
    curl \
    lua-zlib-dev \
    libmemcached-dev \
    nginx \
    nano

# Add docker php ext repo
# ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
ADD docker/install-php-extensions /usr/local/bin/

# Install php extensions
RUN chmod +x /usr/local/bin/install-php-extensions && \
    /usr/local/bin/install-php-extensions mbstring pdo_mysql zip exif pcntl gd memcached



# Install supervisor
RUN apt-get update && apt-get install -y supervisor

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Add user for laravel application
RUN groupadd -g 1000 www
RUN useradd -u 1000 -ms /bin/bash -g www www

# Copy code to /var/www
COPY --chown=www:www-data . /var/www

# add root to www group
RUN chmod -R ug+w /var/www/storage
RUN chmod -R ug+w /var/www/storage/logs

# RUN chmod -R 777 /var/www/storage
# RUN chmod -R 777 /var/www/storage/logs
RUN chmod -R 775 /var/www/public/assets/css/assets
RUN mkdir -p /var/www/storage/framework/sessions
RUN chmod -R 775 /var/www/storage/framework/sessions

# Copy nginx/php/supervisor configs
RUN cp docker/supervisor.conf /etc/supervisord.conf
RUN cp docker/php.ini /usr/local/etc/php/conf.d/app.ini
RUN cp docker/nginx.conf /etc/nginx/sites-enabled/default
RUN cp docker/etc/nginx/nginx.conf /etc/nginx/nginx.conf

# PHP Error Log Files
RUN mkdir /var/log/php
RUN touch /var/log/php/errors.log && chmod 777 /var/log/php/errors.log

ENV TZ=Asia/Bangkok
RUN date

# Deployment steps
RUN composer install --optimize-autoloader --no-dev
RUN chmod +x /var/www/docker/run.sh

EXPOSE 80
ENTRYPOINT ["/var/www/docker/run.sh"]
