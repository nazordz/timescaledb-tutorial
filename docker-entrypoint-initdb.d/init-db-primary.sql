SET password_encryption = 'scram-sha-256';

CREATE ROLE repuser WITH REPLICATION PASSWORD 'password' LOGIN;

SELECT * FROM pg_create_physical_replication_slot('replica_1_slot');