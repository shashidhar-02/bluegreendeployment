#!/bin/bash

# HashiCorp Vault Setup Script
set -e

echo "=================================="
echo "HashiCorp Vault Setup"
echo "=================================="

# Install Vault
if ! command -v vault &> /dev/null; then
    echo "Installing Vault..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install vault -y
fi

# Create Vault configuration
sudo mkdir -p /opt/vault/data

cat << 'EOF' | sudo tee /opt/vault/config.hcl
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
ui = true
EOF

# Create systemd service
cat << 'EOF' | sudo tee /etc/systemd/system/vault.service
[Unit]
Description=HashiCorp Vault
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
ExecStart=/usr/bin/vault server -config=/opt/vault/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Create vault user
sudo useradd --system --home /opt/vault --shell /bin/false vault || true
sudo chown -R vault:vault /opt/vault

# Start Vault
sudo systemctl daemon-reload
sudo systemctl enable vault
sudo systemctl start vault

sleep 5

# Initialize Vault
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init -key-shares=5 -key-threshold=3 > /tmp/vault-init-keys.txt

echo "=================================="
echo "Vault initialized successfully!"
echo "=================================="
echo "IMPORTANT: Save the keys from /tmp/vault-init-keys.txt"
echo "Unseal keys and root token are stored there."
echo ""
echo "To unseal Vault, run:"
echo "vault operator unseal <unseal-key-1>"
echo "vault operator unseal <unseal-key-2>"
echo "vault operator unseal <unseal-key-3>"
echo "=================================="
