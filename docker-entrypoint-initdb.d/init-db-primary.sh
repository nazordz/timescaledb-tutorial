#! /bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --password "$POSTGRES_PASSWORD"  <<-EOSQL
    SET password_encryption = 'scram-sha-256';
    CREATE ROLE repuser WITH REPLICATION PASSWORD 'password' LOGIN;
EOSQL