# Remote SSH via Cloudflare Tunnel
This assumes you already have a Cloudflare Tunnel container running on your server.

## Server prep (SSH + Tunnel hostname)
Ensure SSH server is running:
```bash
sudo systemctl status ssh || sudo systemctl status sshd
```
In Cloudflare Zero Trust → Networks → Tunnels → select your tunnel → Public Hostnames → Add:
Hostname: weg.sabri.life

Service: ssh://localhost:22
(If cloudflared runs in Docker bridge mode, use ssh://172.17.0.1:22 instead.)
Restart the tunnel container:
```bash
docker compose restart cloudflared
```

## (Recommended) Gate with Cloudflare Access
Zero Trust → Access → Applications → Add → Self-hosted
Domain: weg.sabri.life
Policy: Allow only your user:email-address (like immich)
Save.

## Install cloudflared on your laptop
macOS:
```bash
brew install cloudflared
cloudflared --version
```
Linux (Debian/Ubuntu):
```bash
sudo apt update
sudo apt install cloudflared -y || {
  curl -fsSL https://packages.cloudflare.com/gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://packages.cloudflare.com/cloudflared $(. /etc/os-release && echo $VERSION_CODENAME) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
  sudo apt update && sudo apt install cloudflared -y
}
cloudflared --version
```

## One-liner connect OR nice SSH config
```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname ssh.yourdomain.com" user@ssh.yourdomain.com
ssh -o ProxyCommand="cloudflared access ssh --hostname tunnel.sabri.life" pi5@tunnel.sabri.life
ssh -o ProxyCommand="cloudflared access ssh --hostname weg.sabri.life" hossein@weg.sabri.life
```
Nice ~/.ssh/config:
```bash
Host nas
  HostName tunnel.sabri.life
  User pi5
  ProxyCommand cloudflared access ssh --hostname %h
```
Then,
```bash
ssh nas
```

