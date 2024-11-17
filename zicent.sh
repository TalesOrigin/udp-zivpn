#!/bin/bash
# Zivpn UDP Module installer
# Creator Zahid Islam
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
plain='\033[0m'
NC='\033[0m' # No Color

echo -e "Updating server"
sudo apt-get update && apt-get upgrade -y
systemctl stop zivpn.service 1> /dev/null 2> /dev/null
echo -e "Downloading UDP Service"
wget https://github.com/nyeinkokoaung404/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn
mkdir /etc/zivpn 1> /dev/null 2> /dev/null
wget https://raw.githubusercontent.com/nyeinkokoaung404/udp-zivpn/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

echo "Generating cert files:"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"

echo "Applying network optimizations for UDP performance"
# Increase UDP buffer sizes (optimized for performance, larger buffers for high throughput)
sysctl -w net.core.rmem_default=67108864  # 64 MB buffer for receiving
sysctl -w net.core.wmem_default=67108864  # 64 MB buffer for sending
sysctl -w net.core.rmem_max=67108864  # Maximum buffer for receiving
sysctl -w net.core.wmem_max=67108864  # Maximum buffer for sending

# Set UDP memory usage limits
sysctl -w net.ipv4.udp_mem='2097152 4194304 8388608'  # More aggressive memory tuning for UDP
sysctl -w net.ipv4.udp_rmem_min=33554432  # Minimum UDP receive buffer
sysctl -w net.ipv4.udp_wmem_min=33554432  # Minimum UDP send buffer

# Tune network queue length for handling high traffic (increased for high-load environments)
sysctl -w net.core.netdev_max_backlog=10000

# **Optimize Interrupt Handling**: Balance IRQ on all cores to process packets in parallel
if [ -f /proc/irq/default_smp_affinity ]; then
  echo "ff" > /proc/irq/default_smp_affinity  # Ensure network IRQs are spread across all CPU cores
fi

# **Set CPU performance mode**: Ensure CPU is always running at maximum performance (for low latency)
echo "Setting CPU performance mode"
if command -v cpupower &> /dev/null; then
  cpupower frequency-set -g performance
elif [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
  echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
fi

# Set the network optimization for low-latency routing (reducing queuing delays)
sysctl -w net.ipv4.tcp_low_latency=1  # This setting improves performance by reducing queuing delays

# **Check and update the CPU affinity for network interrupts**: This helps reduce latency in multi-core systems
if [ -f /proc/irq/default_smp_affinity ]; then
  echo "ff" > /proc/irq/default_smp_affinity
fi

# Configure the service file to ensure VPN service starts correctly
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

# Update the config.json with the provided passwords
sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

# Enable and start the VPN service
systemctl enable zivpn.service
systemctl start zivpn.service

# Firewall and port forwarding rules to allow UDP traffic
iptables -t nat -A PREROUTING -i $(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1) -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp

# Clean up temporary files
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
