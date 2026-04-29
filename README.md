# Raspberry Pi OS installation
- Install [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- Choose Raspberry Pi OS Lite (64 bit)
- Set ssh key. The private key is stored in Bitwarden Vault, and public key can be generated with the following command
```bash
ssh-keygen -f ~/.ssh/id_rpi -y > ~/.ssh/id_rpi.pub
```
- Disable telemetry
- Flash the microSD card

# SSH config
- Add the following lines to `~/.ssh/config` (assuming Pi hostname is `server`)
```
Host server
  HostName server.local
  User daniel
  IdentityFile ~/.ssh/id_rpi
```
- Connect to RPi
```bash
ssh htpc
```
- Password authentication disabled by default (publickey only) by `/etc/ssh/sshd_config.d/50-cloud-init.conf`

# ArgonOne case
- Install case fan script
```bash
curl https://download.argon40.com/argon1.sh | bash
```
- Configure fan
```bash
argon-config
```
- Verify
```bash
systemctl status argon*
```

# SD card durability

### Mount HDD
- Get `PARTUUID` from HDD
```bash
sudo blkid | grep HDD
```
- Add the following lines to `/etc/fstab`
```
PARTUUID=890569fd-5410-4324-9d1e-984f89e20fe0 /mnt/hdd ext4 defaults,nofail
/mnt/hdd/htpc /home/daniel/htpc none bind,nofail
```
- Apply changes
```bash
sudo systemctl daemon-reload
```

### Relocate `/var`
- Find existing mount points
```bash
findmnt
for path in /tmp /var/run /var/lock; do findmnt $path; done # These should be tmpfs already
```
- Copy directory to HDD
```bash
sudo mkdir -p /mnt/hdd/var
sudo rsync -aAX /var/ /mnt/hdd/var/
# Verify symlinks were preserved (should show -> /run and -> /run/lock)
ls -la /mnt/hdd/var/run /mnt/hdd/var/lock
```
- Add to fstab
```
/mnt/hdd/var /var none bind,nofail
```
- Verify
```bash
sudo systemctl daemon-reload
findmnt /var 
df -h /var ~/htpc /tmp /var/run /var/lock
ls -la /var/run /var/lock # should still be symlinks
```

### Configure swap
> Use [rpi-swap](https://github.com/raspberrypi/rpi-swap). For now leave everything as default, since swap file in `/var/swap` is relocated to HDD

# Networking
- Confirm NetworkManager is running
```bash
systemctl is-active NetworkManager # Should output: active
nmcli device status # Lists all interfaces (eth0, wlan0, etc.) and their state
```
- Disable netplan
```bash
sudo cp /run/NetworkManager/system-connections/* /etc/NetworkManager/system-connections/
for f in /etc/netplan/*.yaml; do sudo mv "$f" "$f.bak"; done
sudo reboot now
```
- Find connection names
```bash
nmcli con show 
sudo nmcli con mod netplan-eth0 connection.id eth0 # Rename ethernet connection
sudo nmcli con mod netplan-wlan0-DIGIFIBRA-PLUS-xtxd connection.id wlan0 # Rename wi-fi connection
```
- Set connection properties
```bash
sudo nmcli con mod eth0 \
	ipv4.method manual \
	ipv4.addresses 192.168.1.100/24 \
	ipv4.gateway 192.168.1.1 \
	ipv4.dns "1.1.1.1 1.0.0.1" \
	ipv4.route-metric 100 \
	connection.autoconnect yes \
	connection.autoconnect-priority 100 \
	ipv6.method disabled

sudo nmcli con mod wlan0 \
	ipv4.method manual \
	ipv4.addresses 192.168.1.101/24 \
	ipv4.gateway 192.168.1.1 \
	ipv4.dns "1.1.1.1 1.0.0.1" \
	ipv4.route-metric 200 \
	connection.autoconnect yes \
	connection.autoconnect-priority 50 \
	ipv6.method disabled
```
> **Why these values:**
> - `ipv4.route-metric`: Lower = preferred for outbound traffic. eth0 at 100 always beats wlan0 at 200 when both are connected. If eth0 drops, wlan0 takes over automatically.
> - `connection.autoconnect-priority`: Controls which connection nmcli brings up first at boot. Higher = first. Arbitrary values, just needs eth0 higher.
> - `ipv4.dns`: Pi points directly to Cloudflare, not to itself, so that unresponsive Pi-hole doesn't break internet on Pi. Router DHCP DNS settings don't affect the Pi since it uses `ipv4.method manual` and never sends a DHCP request.
- Disable EEE (Energy-Efficien Ethernet)
```bash
sudo tee /etc/systemd/system/eth-eee-off.service << 'EOF'
[Unit]
Description=eee off
Wants=network.target network-online.target
After=network-online.target

[Service]
Type=simple
RemainAfterExit=yes
ExecStart=/usr/sbin/ethtool --set-eee eth0 eee off
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable eth-eee-off.service
sudo systemctl start eth-eee-off
```
- Apply config
```bash
sudo nmcli con up eth0
sudo nmcli con up wlan0
```
- Verify
```bash
ethtool --show-eee eth0 | grep status # Should say "disabled"
ip addr show eth0 | grep "inet " # Should show 192.168.1.100
ip addr show wlan0 | grep "inet " # Should show 192.168.1.101
nmcli con show eth0 | grep -E "ipv4\.(method|dns:|addresses|gateway|route-metric)|connection\.autoconnect(:|-priority)|ipv6\.method"
nmcli con show wlan0 | grep -E "ipv4\.(method|dns:|addresses|gateway|route-metric)|connection\.autoconnect(:|-priority)|ipv6\.method"
ip route show default # eth0 should have lower metric
```
- To disable cloud-init altogether run
```bash
sudo touch /etc/cloud/cloud-init.disabled
```

# Tailscale
- Install [Tailscale](https://tailscale.com/)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```
- Start
```bash
sudo tailscale up
```
- Enable MagicDNS in [Tailscale admin console](https://login.tailscale.com/admin/dns)
- Disable Tailscale DNS routing on Pi itself. 
```bash
sudo tailscale set --accept-dns=false
# Update DNS resolver to Cloudflare configured earlier
sudo nmcli con up wlan0
sudo nmcli con up eth0
```
>This is to ensure Pi has internet access event if Pi-hole is down. Containers that would benefit from routing their traffic through Pi-hole can set it as DNS in compose file
- Edit `~/.ssh/config` on host machine
```
Host server server.local 192.168.1.100
	User daniel
	IdentityFile ~/.ssh/id_rpi
```
- Set Pi IP address as nameserver in Tailscale admin console -> DNS settings
```bash
tailscale ip -4
```

# Docker install
> [Install Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)
- Set up Docker's `apt` repository
```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```
- Install the Docker packages
```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
- Verify 
```bash
sudo systemctl status docker
sudo docker run hello-world
```
- Create the `docker` group
```bash
sudo groupadd docker
```
- Add your user to the `docker` group
```bash
sudo usermod -aG docker $USER
```
- Re-evaluate group membership
```bash
newgrp docker
```
- Verify
```bash
docker run hello-world # Should work without 'sudo'
```
- Configure docker to start on boot
```bash
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```
- Create docker config to enable log rotation
```bash
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "7"
  }
}
EOF
```
- Verify
```bash
sudo systemctl restart docker
docker run --name test hello-world
docker inspect test --format '{{json .HostConfig.LogConfig}}'
```
- Cleanup
```bash
docker container prune
docker image prune -a
```
- Start docker
```bash
cd ~/htpc
chmod +x up.sh
./up.sh
```