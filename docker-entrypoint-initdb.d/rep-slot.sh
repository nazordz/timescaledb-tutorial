#! /bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --password "$POSTGRES_PASSWORD"  <<-EOSQL
    SELECT * FROM pg_create_physical_replication_slot('replica_1_slot');
EOSQL
