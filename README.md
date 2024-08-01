# Timescaledb + replication with examples

# Configure `.env` and adjust it
```bash
$ cp .env.example .env
```

# Adjust user replica
Edit replica user and password in `00_ini.sql`

# Adjust health check environtment
```yaml
test: 'pg_isready -U postgres --dbname=postgres'
```
# Run container
```bash
$ docker compose up -d
```