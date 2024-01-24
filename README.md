# docker-mysql-backup

Run `mysqldump` to backup your databases. Your backups are saved in `/backup`. You can mount any directory of your host or a docker volume in /backup. Otherwise, a docker volume is created in the default location.

## Usage:

```bash
docker container run -d \
       --env MYSQL_USER=root \
       --env MYSQL_PASS=my_password \
       --link mysql
       --volume /path/to/my/backup/folder:/backup
       turnopil/docker-mysql-backup
```

## Variables


- `MYSQL_HOST`: The host/ip of your MySQL database.
- `MYSQL_HOST_FILE`: The file in the container where to find the host of your MySQL database (cf. docker secrets). You should use either MYSQL_HOST_FILE or MYSQL_HOST (see examples below).
- `MYSQL_PORT`: The port number of your MySQL database.
- `MYSQL_USER`: The username of your mysql database.
- `MYSQL_USER_FILE`: The file in the container where to find the user of your MySQL database (cf. docker secrets). You should use either MYSQL_USER_FILE or MYSQL_USER (see examples below).
- `MYSQL_PASS`: The password of your mysql database.
- `MYSQL_PASS_FILE`: The file in the container where to find the password of your MySQL database (cf. docker secrets). You should use either MYSQL_PASS_FILE or MYSQL_PASS (see examples below).
- `MYSQL_DATABASE`: The database name to dump. Default: `--all-databases`.
- `MYSQL_DATABASE_FILE`: The file in the container where to find the database name(s) in your MySQL database (cf. docker secrets). In that file, there can be several database names: one per line. You should use either MYSQL_DATABASE or MYSQL_DATABASE_FILE (see examples below).
- `MYSQLDUMP_OPTS`: Command line arguments to pass to `mysqldump` (see [mysqldump documentation](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html)).
- `MYSQL_SSL_OPTS`: Command line arguments to use [SSL](https://dev.mysql.com/doc/refman/5.6/en/using-encrypted-connections.html).
- `MAX_BACKUPS`: The number of backups to keep. When reaching the limit, the old backup will be discarded. No limit by default.
- `INIT_BACKUP`: If set, create a backup when the container starts.
- `INIT_RESTORE_LATEST`: If set, restores the latest backup.
- `EXIT_BACKUP`: If set, create a backup when the container stops.
- `GZIP_LEVEL`: Specify the level of gzip compression from 1 (quickest, least compressed) to 9 (slowest, most compressed), default is 6.
- `USE_PLAIN_SQL`: If set, back up and restore plain SQL files without gzip.
- `TZ`: Specify TIMEZONE in Container. E.g. "Europe/Berlin". Default is UTC.

If you want to make this image the perfect companion for your MySQL container, use [docker-compose](https://docs.docker.com/compose/). You can add more services that will be able to connect to the MySQL image using the name `my_mariadb`, note that you only expose port `3306` internally to the servers and not to the host:

### Docker-compose with MYSQL_PASS env var:

```yaml
version: "2"
services:
  mariadb:
    image: mariadb
    container_name: my_mariadb
    expose:
      - 3306
    volumes:
      - data:/var/lib/mysql
      # If there is no scheme, restore the last created backup (if exists)
      - ${VOLUME_PATH}/backup/latest.${DATABASE_NAME}.sql.gz:/docker-entrypoint-initdb.d/database.sql.gz
    environment:
      - MYSQL_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - MYSQL_DATABASE=${DATABASE_NAME}
    restart: unless-stopped

  docker-mysql-backup:
    image: turnopil/docker-mysql-backup
    depends_on:
      - mariadb
    volumes:
      - ${VOLUME_PATH}/backup:/backup
    environment:
      - MYSQL_HOST=my_mariadb
      - MYSQL_USER=root
      - MYSQL_PASS=${MARIADB_ROOT_PASSWORD}
      - MAX_BACKUPS=15
      - INIT_BACKUP=0
      # Make it small
      - GZIP_LEVEL=9
      # As of MySQL 8.0.21 this is needed
      - MYSQLDUMP_OPTS=--no-tablespaces
    restart: unless-stopped

volumes:
  data:
```

### Docker-compose using docker secrets:

The database root password is passed to docker container by using [docker secrets](https://docs.docker.com/engine/swarm/).

In example below, docker is in classic 'docker engine mode' (iow. not swarm mode) and secret sources are local files on host filesystem.

Alternatively, secrets can be stored in docker secrets engine (iow. not in host filesystem).

```yaml
version: "3.7"

secrets:
  # Place your secret file somewhere on your host filesystem, with your password inside
  mysql_root_password:
    file: ./secrets/mysql_root_password
  mysql_user:
    file: ./secrets/mysql_user
  mysql_password:
    file: ./secrets/mysql_password
  mysql_database:
    file: ./secrets/mysql_database

services:
  mariadb:
    image: mariadb:10
    container_name: my_mariadb
    expose:
      - 3306
    volumes:
      - data:/var/lib/mysql
      - ${VOLUME_PATH}/backup:/backup
    environment:
      - MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password
      - MYSQL_USER_FILE=/run/secrets/mysql_user
      - MYSQL_PASSWORD_FILE=/run/secrets/mysql_password
      - MYSQL_DATABASE_FILE=/run/secrets/mysql_database
    secrets:
      - mysql_root_password
      - mysql_user
      - mysql_password
      - mysql_database
    restart: unless-stopped

  backup:
    build: .
    image: turnopil/docker-mysql-backup
    depends_on:
      - mariadb
    volumes:
      - ${VOLUME_PATH}/backup:/backup
    environment:
      - MYSQL_HOST=my_mariadb
      # Alternatively to MYSQL_USER_FILE, we can use MYSQL_USER=root to use root user instead
      - MYSQL_USER_FILE=/run/secrets/mysql_user
      # Alternatively, we can use /run/secrets/mysql_root_password when using root user
      - MYSQL_PASS_FILE=/run/secrets/mysql_password
      - MYSQL_DATABASE_FILE=/run/secrets/mysql_database
      - MAX_BACKUPS=10
      - INIT_BACKUP=1
    secrets:
      - mysql_user
      - mysql_password
      - mysql_database
    restart: unless-stopped

volumes:
  data:

```

## Restore from a backup

### List all available backups :

See the list of backups in your running docker container, just write in your favorite terminal:

```bash
docker container exec <your_mysql_backup_container_name> ls /backup
```

### Restore using a compose file

To restore a database from a certain backup you may have to specify the database name in the variable MYSQL_DATABASE:

```YAML
docker-mysql-backup:
    image: turnopil/docker-mysql-backup
    command: "/restore.sh /backup/201708060500.${DATABASE_NAME}.sql.gz"
    depends_on:
      - mariadb
    volumes:
      - ${VOLUME_PATH}/backup:/backup
    environment:
      - MYSQL_HOST=my_mariadb
      - MYSQL_USER=root
      - MYSQL_PASS=${MARIADB_ROOT_PASSWORD}
      - MYSQL_DATABASE=${DATABASE_NAME}
```
### Restore using a docker command

```bash
docker container exec <your_mysql_backup_container_name> /restore.sh /backup/<your_sql_backup_gz_file>
```

if no database name is specified, `restore.sh` will try to find the database name from the backup file.

### Automatic backup and restore on container starts and stops

Set `INIT_RESTORE_LATEST` to automatically restore the last backup on startup.
Set `EXIT_BACKUP` to automatically create a last backup on shutdown.

```yaml
  docker-mysql-backup:
    image: turnopil/docker-mysql-backup
    depends_on:
      - mariadb
    volumes:
      - ${VOLUME_PATH}/backup:/backup
    environment:
      - MYSQL_HOST=my_mariadb
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASS=${MYSQL_PASSWORD}
      - MAX_BACKUPS=15
      - INIT_RESTORE_LATEST=1
      - EXIT_BACKUP=1
      # Make it small
      - GZIP_LEVEL=9
    restart: unless-stopped

volumes:
  data:
```

Docker database image could expose a directory you could add files as init sql script.

```yaml
  mysql:
    image: mysql
    expose:
      - 3306
    volumes:
      - data:/var/lib/mysql
      # If there is no scheme, restore using the init script (if exists)
      - ./init-script.sql:/docker-entrypoint-initdb.d/database.sql.gz
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${DATABASE_NAME}
    restart: unless-stopped
```

```yaml
  mariadb:
    image: mariadb
    expose:
      - 3306
    volumes:
      - data:/var/lib/mysql
      # If there is no scheme, restore using the init script (if exists)
      - ./init-script.sql:/docker-entrypoint-initdb.d/database.sql.gz
    environment:
      - MYSQL_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - MYSQL_DATABASE=${DATABASE_NAME}
    restart: unless-stopped
```
