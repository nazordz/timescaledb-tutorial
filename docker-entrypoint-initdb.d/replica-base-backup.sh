#! /bin/bash

rm -rf /var/lib/postgresql/data/*

pg_basebackup -h primary -D /var/lib/postgresql/data -U repuser -vP -W

touch /var/lib/postgresql/data/standby.signal