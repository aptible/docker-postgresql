# ![](https://gravatar.com/avatar/11d3bc4c3163e3d238d558d5c9d98efe?s=64) aptible/postgresql

[![Docker Repository on Quay.io](https://quay.io/repository/aptible/postgresql/status "Docker Repository on Quay.io")](https://quay.io/repository/aptible/postgresql)
[![Build Status](https://travis-ci.org/aptible/docker-postgresql.svg?branch=master)](https://travis-ci.org/aptible/docker-postgresql)

[![](http://dockeri.co/image/aptible/postgresql)](https://registry.hub.docker.com/u/aptible/postgresql/)

PostgreSQL, on top of Debian Wheezy.

## Installation and Usage

    docker pull quay.io/aptible/postgresql:${VERSION:-latest}

This is an image conforming to the [Aptible database specification](https://support.aptible.com/topics/paas/deploy-custom-database/). To run a server for development purposes, execute

    docker create --name data quay.io/aptible/postgresql
    docker run --volumes-from data -e USERNAME=aptible -e PASSPHRASE=pass -e DATABASE=db quay.io/aptible/postgresql --initialize
    docker run --volumes-from data -P quay.io/aptible/postgresql

The first command sets up a data container named `data` which will hold the configuration and data for the database. The second command creates a PostgreSQL instance with a username, passphrase and database name of your choice. The third command starts the database server.

### SSL

The PostgreSQL server is configured to enforce SSL for any TCP connection. It uses a self-signed certificate generated at startup time, or a certificate / key pair found in SSL_CERTIFICATE and SSL_KEY.

## Available Versions (Tags)

* `latest`: Currently PostgreSQL 12
* `12`: PostgreSQL 12
* `11`: PostgreSQL 11
* `10`: PostgreSQL 10
* `9.6`: PostgreSQL 9.6
* `9.5`: PostgreSQL 9.5
* `9.4`: PostgreSQL 9.4 (EOL 2020-02-13)
* `9.3`: PostgreSQL 9.3 (EOL 2018-11-08)

## Available Extensions

In the `--contrib` images, the following extensions are available.

| Extension | Avaiable in versions|
|-----------|---------------------|
| plpythonu | 9.3 - 11 |
| plpython2u | 9.3 - 11 |
| plpython3u | 9.3 - 12 |
| plperl | 9.3 - 12 |
| plperlu | 9.3 - 12 |
| mysql_fdw | 9.3 - 11 |
| PLV8 |  9.3 - 10|
| multicorn | 9.3 - 10 |
| wal2json |  9.4 - 12 |
| pg-safeupdate | 9.4 - 11 |
| pglogical | 9.4 - 12 |
| pg_repack | 9.4 - 11 |
| pgagent | 9.4 - 12 |
| pgagent|  9.4 - 11 |
| pgaudit |  9.5 - 12 |
| pgcron | 10 |

Aptible Support can update your Database to use the `--contrib` image.

## Tests

Tests are run as part of the `Dockerfile` build. To execute them separately within a container, run:

    bats test

## Deployment

To push the Docker image to Quay, run the following command:

    make release

## Continuous Integration

Images are built and pushed to Docker Hub on every deploy. Because Quay currently only supports build triggers where the Docker tag name exactly matches a GitHub branch/tag name, we must run the following script to synchronize all our remote branches after a merge to master:

    make sync-branches

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2019 [Aptible](https://www.aptible.com) and contributors.
