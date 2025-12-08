# 1) Make a key on your Mac
# Strong, modern key
ssh-keygen -t ed25519 -a 100 -C "mac-to-xubuntu"
# Save to: /Users/<you>/.ssh/id_ed25519  (press Enter)
# Choose a passphrase (recommended)

# load into the macOS keychain so you won’t retype the passphrase every time)
eval "$(ssh-agent -s)"
/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# 2) Put your public key on the Xubuntu machine
brew install ssh-copy-id
ssh-copy-id user@192.168.x.x # linux machine ip

# 3) Test key login
ssh -i ~/.ssh/id_ed25519 user@192.168.x.x
# If you see no password prompt (only your key passphrase the first time), you’re good.

# 4) Make it convenient (Mac client config)
Create/edit ~/.ssh/config on your Mac:
Host xubuntu
  HostName [192.168.x.x]
  User [user]
  IdentityFile ~/.ssh/id_ed25519_xx
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
  ServerAliveInterval 30
  ForwardAgent no
# Now you can just: ssh xubuntu

# the same can be applied on the Linux machine to have a passwordless ssh connection from
# the linux machine to mac

# Example
# 1) Generate a key on Linux
ssh-keygen -t ed25519 -a 100 -C "linux-to-mac"
# Save to: ~/.ssh/id_ed25519 (press Enter)
# Choose a passphrase (recommended)
# (Optional) load it into your Linux agent so you don’t retype the passphrase each session:

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Tip: to auto-load on login, add those two lines to your shell rc file, or use a helper like keychain/GNOME Keyring.
# 2) Enable SSH on the Mac (the “server”) On your Mac:
# System Settings → General → Sharing → Remote Login → ON
# (Optionally restrict to your user account.)
# If you use the macOS firewall, make sure Remote Login is allowed. CLI alternative on the Mac:

# on Mac
sudo systemsetup -setremotelogin on
# If needed, (re)start the daemon:
sudo launchctl kickstart -k system/com.openssh.sshd

# 3) Put your Linux public key on the Mac From Linux (replace macuser and host/IP):
# If not installed:
#   Debian/Ubuntu: sudo apt install ssh-copy-id
#   Fedora: sudo dnf install openssh-clients
ssh-copy-id macuser@mac-hostname.local
# or: ssh-copy-id macuser@192.168.x.x
# The first time, you’ll enter the Mac account password (not SSH key passphrase).
# This appends your Linux public key to the Mac’s file: /Users/macuser/.ssh/authorized_keys.

# 4) Test key login From Linux:
ssh -i ~/.ssh/id_ed25519 macuser@mac-hostname.local

# You should not be asked for the Mac password (only your key’s passphrase the first time, unless you added it to ssh-agent).

# 5) Make it convenient (Linux client config)
# Create/edit ~/.ssh/config on Linux:
Host mac
  HostName mac-hostname.local      # or 192.168.x.x
  User macuser
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  ServerAliveInterval 30
  ForwardAgent no

# Now you can just:
ssh mac