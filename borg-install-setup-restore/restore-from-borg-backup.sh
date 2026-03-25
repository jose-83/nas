# Go to immich-borg folder where you have config file and data folder
export BORG_REPO="/path/to/immich-borg"   # folder that contains config + data/
borg list "$BORG_REPO" # list of snapshots
borg info "$BORG_REPO::sabri-2025-09-12T23:53:57" # info about each snapshot
# copy your media and db dump

# You already have your docker-compose.yml and .env file
# if needed:
# docker compse down
# sudo rm -rf ./pgdata
docker compose up -d database
docker exec -i immich_postgres psql -U postgres -d postgres < immich-database.sql
docker compose up -d

# From immich doc:
# Restore
docker compose down -v  # CAUTION! Deletes all Immich data to start from scratch
## Uncomment the next line and replace DB_DATA_LOCATION with your Postgres path to permanently reset the Postgres database
# rm -rf DB_DATA_LOCATION # CAUTION! Deletes all Immich data to start from scratch
docker compose pull             # Update to latest version of Immich (if desired)
docker compose create           # Create Docker containers for Immich apps without running them
docker start immich_postgres    # Start Postgres server
sleep 10                        # Wait for Postgres server to start up
# Check the database user if you deviated from the default
gunzip --stdout "/path/to/backup/dump.sql.gz" \
| sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
| docker exec -i immich_postgres psql --dbname=postgres --username=<DB_USERNAME>  # Restore Backup
docker compose up -d            # Start remainder of Immich apps


# Note that for the database restore to proceed properly, it requires a completely fresh install
# (i.e. the Immich server has never run since creating the Docker containers). If the Immich app
# has run, Postgres conflicts may be encountered upon database restoration
# (relation already exists, violated foreign key constraints, multiple primary keys, etc.),
# in which case you need to delete the DB_DATA_LOCATION folder to reset the database.

# tip
# Some deployment methods make it difficult to start the database without also starting the server.
# In these cases, you may set the environment variable DB_SKIP_MIGRATIONS=true before starting the services.
# This will prevent the server from running migrations that interfere with the restore process.
# Be sure to remove this variable and restart the services after the database is restored.