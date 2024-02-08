# Notes

## Cron every 5 minutes
docker-compose exec -u www-data app php cron.php

We do this by adding 'cron.sh' to host user crontab.

```
user@host:/local/docker/nextcloud$ crontab -l
# m h  dom mon dow   command
*/5 * * * * /local/docker/nextcloud/cron.sh
```


## running nextcloud in docker

Add traefik proxy to trusted_proxies to config.php may be necessary:
```
  'trusted_proxies' =>
  array (
    0 => '172.18.0.2',
  ),
```
172.18.0.2 IP of the traefik container. I just checked the nextcloud logs and saw which IP was making the requests.
This IP could change though... so I assume this may need to be changed at some point.


## Run ./occ

```
docker-compose exec --user www-data app /var/www/html/occ "$@"
```


## datbase schema change v22

* https://help.nextcloud.com/t/update-to-22-failed-with-database-error-updated/120682/6

## Start mariadb in compatibility mode, so you don't have to reimport the DB.

* https://techoverflow.net/2021/08/17/how-to-fix-nextcloud-4047-innodb-refuses-to-write-tables-with-row_formatcompressed-or-key_block_size/

1. Dump nextcloud db
2. remove 'ROW_FORMAT=COMPRESSED'
3. import nextcloud db


## Allowed memory size of xxx bytes exhausted in current latest container

* https://github.com/nextcloud/docker/issues/1413
* https://github.com/nextcloud/docker/issues/1413#issuecomment-784329039

* Set PHP_MEMORY_LIMIT=512M or -1 somewhere in php.ini or nextcloud.ini

This works and is what I've been using
```
docker-compose exec --user www-data app /usr/local/bin/php -d memory_limit=-1 -f /var/www/html/cron.php
```

```
$ docker-compose exec --user www-data app env |grep -E "PHP_.*_LIMIT"
PHP_MEMORY_LIMIT=512M
PHP_UPLOAD_LIMIT=512M

$ docker-compose exec --user www-data app php cron.php
```

## Database:

### add missing indices
```
docker-compose exec --user www-data app /usr/local/bin/php -d memory_limit=-1 -f /var/www/html/occ db:add-missing-indices
```

### convert filecache bigint
```
docker-compose exec --user www-data app /usr/local/bin/php -d memory_limit=-1 -f /var/www/html/occ db:convert-filecache-bigint
```


## Client Connection Closed over and over again

Set client MaxChunkSize to something smaller: https://github.com/nextcloud/desktop/issues/4278

`$HOME/.config/Nextcloud/nextcloud.cfg`

```
[General]
maxChunkSize=50000000
```
This allowed me to add git repos into my nextcloud folder.

Fix is being worked on here: https://github.com/nextcloud/desktop/pull/4826
