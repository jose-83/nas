## What I did already
```bash 
# ✅ Tailscale is installed
# ✅ SSH works from Pi → mini-PC
# ✅ Folder already exists on mini-PC: /data/borg/immich-borg
# Then:
$ export BORG_PASSPHRASE='in-proton-pass'
$ borg init --encryption=repokey-blake2   pc:/data/borg/immich-borg

## NOTE: I KEPT IT HERE:
borg key export pc:/data/borg/immich-borg ~/borg-key-backup
## AS WELL AS PROTON
```
