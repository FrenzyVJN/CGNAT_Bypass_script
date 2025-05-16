#!/bin/bash
# WireGuard VPS Server Setup Script for CGNAT Bypass

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
  fi
}

# Function to install WireGuard
install_wireguard() {
  echo -e "${YELLOW}Installing WireGuard...${NC}"
  
  # Detect OS
  if [ -f /etc/debian_version ]; then
    apt-get update
    apt-get install -y wireguard-tools iptables curl
  elif [ -f /etc/redhat-release ]; then
    yum install -y epel-release
    yum install -y wireguard-tools iptables curl
  else
    echo -e "${RED}Unsupported OS. Please install WireGuard manually.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}WireGuard installed successfully!${NC}"
}

# Function to generate WireGuard keys
generate_keys() {
  echo -e "${YELLOW}Generating WireGuard keys...${NC}"
  
  mkdir -p /etc/wireguard
  cd /etc/wireguard
  umask 077
  
  wg genkey | tee server_private.key | wg pubkey > server_public.key
  wg genkey | tee client_private.key | wg pubkey > client_public.key
  
  SERVER_PRIVATE_KEY=$(cat server_private.key)
  SERVER_PUBLIC_KEY=$(cat server_public.key)
  CLIENT_PRIVATE_KEY=$(cat client_private.key)
  CLIENT_PUBLIC_KEY=$(cat client_public.key)
  
  echo -e "${GREEN}Keys generated successfully!${NC}"
}

# Function to create WireGuard server config
create_server_config() {
  echo -e "${YELLOW}Creating WireGuard server configuration...${NC}"
  
  # Get server's public IP
  SERVER_IP=$(curl -s ifconfig.me)
  
  cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = 10.8.0.1/24
ListenPort = 51820

# Enable IP forwarding
PostUp = sysctl net.ipv4.ip_forward=1
# Set up NAT for VPN clients
PostUp = iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
# Allow WireGuard traffic
PostUp = iptables -A INPUT -p udp -m udp --dport 51820 -j ACCEPT
# Allow forwarded traffic
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -A FORWARD -o wg0 -j ACCEPT

# Clean up when stopping WireGuard
PostDown = iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
PostDown = iptables -D INPUT -p udp -m udp --dport 51820 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = 10.8.0.2/32
EOF

  echo -e "${GREEN}Server configuration created successfully!${NC}"
}

# Function to enable and start WireGuard service
enable_wireguard() {
  echo -e "${YELLOW}Enabling and starting WireGuard service...${NC}"
  
  systemctl enable wg-quick@wg0
  systemctl start wg-quick@wg0
  
  echo -e "${GREEN}WireGuard service enabled and started!${NC}"
}

# Function to create client configuration
create_client_config() {
  echo -e "${YELLOW}Creating client configuration...${NC}"
  
  SERVER_IP=$(curl -s ifconfig.me)
  
  cat > /etc/wireguard/client.conf << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = 10.8.0.2/24

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_IP}:51820
AllowedIPs = 10.8.0.0/24
PersistentKeepalive = 25
EOF

  echo -e "${GREEN}Client configuration created successfully!${NC}"
}

# Function to configure port forwarding
configure_port_forwarding() {
  echo -e "${YELLOW}Configuring port forwarding...${NC}"
  read -p "Enter the ports to forward to your home server (comma-separated, e.g. 80,443): " ports
  
  IFS=',' read -ra PORT_ARRAY <<< "$ports"
  
  for port in "${PORT_ARRAY[@]}"; do
    # Add DNAT rule to forward incoming traffic to the client
    iptables -t nat -A PREROUTING -i eth0 -p tcp --dport "$port" -j DNAT --to-destination 10.8.0.2:"$port"
    iptables -t nat -A PREROUTING -i eth0 -p udp --dport "$port" -j DNAT --to-destination 10.8.0.2:"$port"
    
    # Update WireGuard config to include port forwarding rules
    sed -i "/PostDown = iptables -D FORWARD -o wg0 -j ACCEPT/a\\
PostUp = iptables -t nat -A PREROUTING -i eth0 -p tcp --dport $port -j DNAT --to-destination 10.8.0.2:$port\\n\\
PostUp = iptables -t nat -A PREROUTING -i eth0 -p udp --dport $port -j DNAT --to-destination 10.8.0.2:$port\\n\\
PostDown = iptables -t nat -D PREROUTING -i eth0 -p tcp --dport $port -j DNAT --to-destination 10.8.0.2:$port\\n\\
PostDown = iptables -t nat -D PREROUTING -i eth0 -p udp --dport $port -j DNAT --to-destination 10.8.0.2:$port" /etc/wireguard/wg0.conf
    
    echo -e "${GREEN}Port $port forwarding configured${NC}"
  done
  
  # Restart WireGuard to apply changes
  systemctl restart wg-quick@wg0
  
  echo -e "${GREEN}Port forwarding configured successfully!${NC}"
}

# Function to save iptables rules
save_iptables_rules() {
  echo -e "${YELLOW}Saving iptables rules...${NC}"
  
  if [ -f /etc/debian_version ]; then
    apt-get install -y iptables-persistent
    netfilter-persistent save
  elif [ -f /etc/redhat-release ]; then
    service iptables save
  else
    echo -e "${YELLOW}Could not detect how to save iptables rules on this OS.${NC}"
    echo -e "${YELLOW}Please manually save your iptables rules.${NC}"
  fi
  
  echo -e "${GREEN}iptables rules saved successfully!${NC}"
}

# Function to display connection information
display_info() {
  echo -e "${GREEN}====== WireGuard Setup Complete ======${NC}"
  echo -e "${YELLOW}Server Public IP:${NC} $(curl -s ifconfig.me)"
  echo -e "${YELLOW}Client Config:${NC}"
  echo -e "${GREEN}-----------------------------------${NC}"
  cat /etc/wireguard/client.conf
  echo -e "${GREEN}-----------------------------------${NC}"
  echo "Copy the above client configuration to your home server."
}

# Main function
main() {
  check_root
  install_wireguard
  generate_keys
  create_server_config
  enable_wireguard
  create_client_config
  configure_port_forwarding
  save_iptables_rules
  display_info
}

# Execute main function
main
