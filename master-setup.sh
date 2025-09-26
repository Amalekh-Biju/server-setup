#!/bin/bash
#
# master-setup.sh
# A single script to configure a static network AND install/configure Cloudflared.
#

# ---  User Configuration ---
# ⚠️ Paste your service install token from the Cloudflare dashboard here.
# --------------------------------------------------
SERVICE_TOKEN="eyJhIjoiMmUxMGZiYmFiOThhNzM1OGYwNWU2ODRmMjUyMzM4NDQiLCJ0IjoiYzgyMzg3ZmQtNGQ3Yi00Mjg3LTgyMmMtMjAwZWFhMmMyNWYxIiwicyI6Ik56VTBPR0V3TXprdE56bGhNQzAwTnpabUxUZzVabVl0WlRabU0yRmlObVkyTkdZMiJ9"
# --------------------------------------------------


# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root."
  exit 1
fi

# Stop immediately if any command fails
set -e

echo "--- PART 1: Configuring Static IP Network ---"
# Create the Netplan configuration file for a static IP
cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    enp1s0:
      addresses:
        - 10.76.22.112/19
      routes:
        - to: default
          via: 10.76.0.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

echo "Applying network configuration..."
netplan apply

echo "Testing network connection..."
# Ping Google's DNS 4 times to confirm connectivity
ping -c 4 8.8.8.8

echo "✅ Network configured successfully."
echo ""

# --- PART 2: Installing and Configuring Cloudflared ---
echo "--- PART 2: Installing and Configuring Cloudflared ---"

echo "Installing dependencies and adding Cloudflare repository..."
apt-get update
apt-get install -y curl lsb-release

# Add Cloudflare's GPG key
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add the Cloudflare APT repository
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list

echo "Installing cloudflared package..."
apt-get update
apt-get install -y cloudflared

echo "✅ Cloudflared successfully installed."

echo "Installing the cloudflared service with your token..."
cloudflared service install "$SERVICE_TOKEN"

echo "⏳ Waiting for the service to start..."
sleep 5

# Check the status of the service
systemctl status cloudflared --no-pager --full

echo ""
echo "🎉 Server setup is complete! Network and Cloudflared are configured."
