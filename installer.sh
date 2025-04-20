#!/bin/bash

# Dante SOCKS5 Installer
# Run this script as root on your VPS

# Configuration
PORT=1234
USERNAME="jkt"
PASSWORD="j"
INTERFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')  # Auto-detect network interface

# Install Dante
echo "Updating packages and installing Dante..."
apt update && apt install dante-server -y

# Create config file
echo "Creating Dante configuration..."
cat << EOF > /etc/danted.conf
logoutput: syslog
user.privileged: root
user.unprivileged: nobody
internal: 0.0.0.0 port=$PORT
external: $INTERFACE
socksmethod: username
clientmethod: none
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
EOF

# Create user
echo "Creating SOCKS5 user..."
useradd -r -s /bin/false $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Allow firewall
echo "Configuring firewall..."
ufw allow $PORT

# Restart service
echo "Restarting Dante service..."
systemctl restart danted
systemctl enable danted

# Display connection info
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "SOCKS5 Installation Complete!"
echo "Server IP: $IP"
echo "Port: $PORT"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo ""
echo "Test command:"
echo "curl --socks5 $USERNAME:$PASSWORD@$IP:$PORT ifconfig.me"
