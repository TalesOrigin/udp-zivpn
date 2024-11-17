#!/bin/bash
# Zivpn UDP Module installer (Modified for CentOS)
# Creator Zahid Islam (Adapted for CentOS by ChatGPT)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
plain='\033[0m'
NC='\033[0m' # No Color

echo -e "Updating server"
sudo dnf update -y
sudo dnf upgrade -y
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "Installing required packages"
# Install necessary packages
sudo dnf install wget openssl iptables  iptables-services -y

echo -e "Downloading UDP Service"
wget https://github.com/nyeinkokoaung404/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn
mkdir -p /etc/zivpn 1> /dev/null 2> /dev/null
wget https://raw.githubusercontent.com/nyeinkokoaung404/udp-zivpn/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

echo "Generating cert files:"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

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
read -p "Enter passwords separated by commas, example: pass1,pass2 (Press enter for Default 'zi'): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zi")
fi

new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"

sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

systemctl enable zivpn.service
systemctl start zivpn.service

# Update iptables rules (CentOS typically uses firewalld)
iptables -t nat -A PREROUTING -i $(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1) -p udp --dport 6000:19999 -j DNAT --to-destination :5667

# If firewalld is installed, use it instead of iptables
if systemctl is-active --quiet firewalld; then
    echo "Configuring firewalld rules"
    firewall-cmd --permanent --add-port=6000-19999/udp
    firewall-cmd --permanent --add-port=5667/udp
    firewall-cmd --reload
else
    echo "Firewalld not active, using iptables"
fi

rm zi.* 1> /dev/null 2> /dev/null
echo "+------------------------------------------------------------------+"
echo "|     ___   ___          ________          ___   ___               |"
echo "|    |\  \ |\  \        |\   __  \        |\  \ |\  \              |"
echo "|    \ \  \|_\  \       \ \  \|\  \       \ \  \|_\  \             |"
echo "|     \ \______  \       \ \  \/\  \       \ \______  \            |"
echo "|      \|_____|\  \       \ \  \/\  \       \|_____|\  \           |"
echo "|             \ \__\       \ \_______\             \ \__\          |"
echo "|              \|__|        \|_______|              \|__|          |"
echo "+------------------------------------------------------------------+"
echo -e "| Telegram Account : ${GREEN}@nkka404 ${NC}|Telegram Channel : ${RED}t.me/premium_channel_404${NC} |"
echo "+------------------------------------------------------------------+"
echo ""
echo -e "${YELLOW}ZIVPN UDP Installed🤞"
