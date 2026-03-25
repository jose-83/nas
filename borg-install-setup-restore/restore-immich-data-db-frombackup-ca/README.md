## Restore Backup
First we have this:
```bash
borg list /data/borg/immich-borg 
Enter passphrase for key /data/borg/immich-borg: 
# output > raspberrypi-2026-03-22_03-43-03 Sun, 2026-03-22 03:45:33 

# Also, I have this in the following folder: hossein@hossein-pc:/data/borg/db-dumps$ 
ls 
# output > immich-database-2026-03-22_03-43-03.sql
```

From the list, we need to choose our snapshot. We need to create a folder to extract our snapshot:
```bash
sudo mkdir -p /mnt/immich
cd /mnt/immich
borg extract /data/borg/immich-borg::raspberrypi-2026-03-22_03-43-03 # may take hours and needs encryption passphrase
```
It will be extracted as:
```bash
data/mnt/immich/data/media/photos/library 
/data/mnt/immich/data/media/photos/library/backups 
/data/mnt/immich/data/media/photos/library/encoded-video 
/data/mnt/immich/data/media/photos/library/library 
/data/mnt/immich/data/media/photos/library/profile 
/data/mnt/immich/data/media/photos/library/thumbs 
/data/mnt/immich/data/media/photos/library/upload
# db dump can be found here:
/data/mnt/immich/home/pi5/immich-backups/db-dumps$ ls # output > immich-database.sql
```

1. Start only Postgres
```bash
 docker compose up -d database 
```
2. Restore DB
Your dump is here:
```bash
/data/mnt/immich/home/pi5/immich-backups/db-dumps/immich-database.sql
```
Run:
```bash
cat /data/mnt/immich/home/pi5/immich-backups/db-dumps/immich-database.sql | \
docker exec -i immich_postgres psql --dbname=immich --username=postgres
```
(Adjust container name if needed)

3. Start everything
```bash
docker compose up -d
```
