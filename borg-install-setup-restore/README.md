## Tailscale installation
```bash
sudo apt install curl
curl -fsSL https://tailscale.com/install.sh | sh
# gives you a link that you need to use for login and approval
sudo tailscale up 
```

## Tailscale useful commands

```bash
# Gives you the info of all of your nodes
tailscale status
# You can enable Tailscale SSH on your machine by running the following:
tailscale set --ssh
# Disconnects from network, daemon stays running
sudo tailscale down
# Stops the daemon entirely
sudo systemctl stop tailscaled
# Stops it from auto-starting on boot
sudo systemctl disable tailscaled
# Start Tailscale
sudo tailscale up
```

## Prepare SSH access from Pi 5 → mini-PC (for Borg over SSH)

On the Pi 5, create a key if you don’t have one:
```bash
ssh-keygen -t ed25519 -a 64 -f ~/.ssh/id_ed25519 -N ""
```

Copy the key to the mini-PC (LAN or Tailscale, either works):
```bash
ssh-copy-id hossein@MINIPC_HOSTNAME_OR_IP
```
Test:
```bash
ssh hossein@MINIPC_HOSTNAME_OR_IP "echo ok"
```

## Borg installation and setup
To install on Linux Debian/Ubuntu:
```bash
apt install borgbackup
BACKUP_PATH=/path/to/backup/folder
mkdir -p "$BACKUP_PATH" "$BACKUP_PATH/database-backup"

# Initialize LOCAL Borg repo (unencrypted, as in Immich docs)
borg init --encryption=none "$BACKUP_PATH/immich-borg"
```