#!/bin/bash

# Update dan instalasi dependensi umum
apt update -y
apt install -y tar screen wget curl nano htop git wireguard iptables --no-install-recommends

# Instalasi Node.js dan PM2 jika belum terpasang
if ! node -v | grep -q "v18"; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    apt update -y
    apt install -y nodejs
    npm install -g n
    npm install -g pm2
    n 18
else
    echo "nodejs version 18.x.x already installed"
fi

# Menghapus folder cloud-iprotate jika sudah ada
if [[ -d "/opt/cloud-iprotate/" ]]; then
    rm -rf /opt/cloud-iprotate/
fi

# Install Shadowsocks Easy Setup
sudo curl https://raw.githubusercontent.com/ilyasbit/ss-easy-setup/main/install-only.sh | sudo bash -s

# Membuat folder untuk Shadowsocks
mkdir -p /etc/shadowsocks/

# Menghapus folder cloud-iprotate dan meng-clone ulang dari GitHub
rm -rf cloud-iprotate/
git clone https://github.com/ilyasbit/cloud-iprotate.git

# Memindahkan folder ke /opt dan menginstall dependensi
mv cloud-iprotate /opt/
cd /opt/cloud-iprotate/
npm install
cd ~

# Konfigurasi WireGuard dan NAT
echo "Menyiapkan WireGuard dan NAT di VPS Contabo..."

# Aktifkan IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Atur NAT untuk menyembunyikan IP AWS (gunakan IP Contabo)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables-save > /etc/iptables.rules

# Buat skrip iptables untuk dijalankan saat startup
cat > /etc/network/if-pre-up.d/iptables << EOF
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF
chmod +x /etc/network/if-pre-up.d/iptables

# Aktifkan WireGuard
systemctl enable wg-quick@wg0 || true

# Buat konfigurasi WireGuard di VPS Contabo
mkdir -p /etc/wireguard
PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo $PRIVATE_KEY | wg pubkey)

SERVER_KEY=$(wg genkey)
SERVER_PUB=$(echo $SERVER_KEY | wg pubkey)

# Konfigurasi server WireGuard di Contabo
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_KEY
Address = 10.8.0.1/24
ListenPort = 51820
SaveConfig = true

[Peer]
PublicKey = $PUBLIC_KEY
AllowedIPs = 10.8.0.2/32
EOF

# Konfigurasi klien WireGuard untuk AWS EC2
cat > /etc/wireguard/aws-client.conf << EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.8.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $(curl -s ifconfig.me):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Restart WireGuard untuk menerapkan konfigurasi
systemctl restart wg-quick@wg0

# Output file konfigurasi klien untuk AWS
echo "File konfigurasi klien:
======================"
cat /etc/wireguard/aws-client.conf

echo "Instalasi selesai!"
