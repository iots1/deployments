#!/bin/sh

cd /var/www

# php artisan migrate:fresh --seed

# php artisan key:generate

php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
# php artisan queue:work database

touch storage/logs/laravel.log
chmod -R 777 /var/www/storage 

/usr/bin/supervisord -c /etc/supervisord.conf

# chmod -R ug+w /var/www/storage
