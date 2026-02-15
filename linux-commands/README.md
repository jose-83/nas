## Linux commands

### List partitions and info about them
```bash
lsblk               # shows disks/partitions and where they’re mounted
findmnt /data       # shows what backs /data (sda3)
df -h / /data       # free space for OS and data
```
Also, prepare /data for apps/media/backup:
```bash
sudo mkdir -p /data/{apps,media,backup}
sudo chown -R "$USER:$USER" /data
```

Shows all running services:
```bash
systemctl list-units --type=service --state=running
```