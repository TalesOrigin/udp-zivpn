#!/bin/bash
# Zivpn UDP Module installer - ARM for CentOS
# Creator Zahid Islam

echo -e "Updating server"
sudo dnf update -y && sudo dnf upgrade -y

# Stop the existing service if running
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "Downloading UDP Service"
wget https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn

# Create the necessary directories and download configuration
mkdir /etc/zivpn 1> /dev/null 2> /dev/null
wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

# Generating cert files
echo "Generating cert files:"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"

# Adjust sysctl settings
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

# Create systemd service file for ZIVPN
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo -e "ZIVPN UDP Passwords"
read -p "Enter passwords separated by commas, example: passwd1,passwd2 (Press enter for Default 'zi'): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zi")
fi

new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"

# Update the config.json file with user passwords
sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

# Enable and start the ZIVPN service
systemctl enable zivpn.service
systemctl start zivpn.service

# Open necessary ports with firewalld (CentOS default)
echo "Opening necessary UDP ports in firewalld"
firewall-cmd --permanent --add-port=6000-19999/udp
firewall-cmd --permanent --add-port=5667/udp
firewall-cmd --reload

# Remove any temporary files if created
rm zi2.* 1> /dev/null 2> /dev/null

echo -e "ZIVPN Installed"
