#!/bin/sh
# Add to user cron
## m h  dom mon dow   command
#*/5 * * * * /tank/containers/docker/nextcloud/bin/cron.sh
set -e
d=/tank/containers/docker/nextcloud
cd $d
# https://github.com/nextcloud/docker/issues/1413
#/usr/local/bin/docker-compose exec --user www-data app php cron.php
#/usr/local/bin/docker-compose exec --user www-data app /usr/local/bin/php -f /var/www/html/cron.php
docker-compose exec --user www-data app /usr/local/bin/php -d memory_limit=-1 -f /var/www/html/cron.php
