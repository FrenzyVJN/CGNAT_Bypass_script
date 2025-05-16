#!/bin/bash
# WireGuard Home Server Client Setup Script for CGNAT Bypass

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
    apt-get install -y wireguard-tools
  elif [ -f /etc/redhat-release ]; then
    yum install -y epel-release
    yum install -y wireguard-tools
  else
    echo -e "${RED}Unsupported OS. Please install WireGuard manually.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}WireGuard installed successfully!${NC}"
}

# Function to create WireGuard client config
create_client_config() {
  echo -e "${YELLOW}Creating WireGuard client configuration...${NC}"
  
  mkdir -p /etc/wireguard
  
  echo -e "${YELLOW}Please enter the WireGuard client configuration from your VPS:${NC}"
  echo -e "${YELLOW}(Paste the configuration and press Ctrl+D when done)${NC}"
  
  cat > /etc/wireguard/wg0.conf
  
  # Ensure correct permissions
  chmod 600 /etc/wireguard/wg0.conf
  
  echo -e "${GREEN}Client configuration created successfully!${NC}"
}

# Function to enable and start WireGuard service
enable_wireguard() {
  echo -e "${YELLOW}Enabling and starting WireGuard service...${NC}"
  
  systemctl enable wg-quick@wg0
  systemctl start wg-quick@wg0
  
  echo -e "${GREEN}WireGuard service enabled and started!${NC}"
}

# Function to install Nginx for reverse proxy
install_nginx() {
  echo -e "${YELLOW}Installing Nginx for reverse proxy...${NC}"
  
  # Detect OS
  if [ -f /etc/debian_version ]; then
    apt-get update
    apt-get install -y nginx
  elif [ -f /etc/redhat-release ]; then
    yum install -y nginx
  else
    echo -e "${RED}Unsupported OS. Please install Nginx manually.${NC}"
    exit 1
  fi
  
  systemctl enable nginx
  systemctl start nginx
  
  echo -e "${GREEN}Nginx installed and started successfully!${NC}"
}

# Function to configure Nginx as reverse proxy
configure_nginx() {
  echo -e "${YELLOW}Configuring Nginx as reverse proxy...${NC}"
  
  read -p "Enter your VPS public IP address: " VPS_IP
  read -p "Enter your domain name (or leave empty to use VPS IP): " DOMAIN
  
  if [ -z "$DOMAIN" ]; then
    DOMAIN=$VPS_IP
  fi
  
  read -p "Enter local service IP (default: 127.0.0.1): " LOCAL_IP
  LOCAL_IP=${LOCAL_IP:-127.0.0.1}
  
  read -p "Enter local service port (default: 8080): " LOCAL_PORT
  LOCAL_PORT=${LOCAL_PORT:-8080}
  
  # Create Nginx reverse proxy config
  cat > /etc/nginx/sites-available/reverse-proxy << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://$LOCAL_IP:$LOCAL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  # Enable the site
  if [ -d /etc/nginx/sites-enabled ]; then
    ln -sf /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/
  else
    # For RHEL-based systems
    mkdir -p /etc/nginx/conf.d/
    cp /etc/nginx/sites-available/reverse-proxy /etc/nginx/conf.d/reverse-proxy.conf
  fi
  
  # Test and reload Nginx
  nginx -t
  if [ $? -eq 0 ]; then
    systemctl reload nginx
    echo -e "${GREEN}Nginx reverse proxy configured successfully!${NC}"
  else
    echo -e "${RED}Nginx configuration test failed. Please check the configuration manually.${NC}"
  fi
}

# Function to check connection to VPS
check_connection() {
  echo -e "${YELLOW}Checking connection to VPS...${NC}"
  
  ping -c 4 10.8.0.1
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully connected to WireGuard server!${NC}"
  else
    echo -e "${RED}Failed to connect to WireGuard server. Please check your configuration.${NC}"
  fi
}

# Main function
main() {
  check_root
  install_wireguard
  create_client_config
  enable_wireguard
  check_connection
  
  echo -e "${YELLOW}Would you like to install and configure Nginx reverse proxy? (y/n)${NC}"
  read -r install_nginx_answer
  
  if [[ $install_nginx_answer =~ ^[Yy]$ ]]; then
    install_nginx
    configure_nginx
  fi
  
  echo -e "${GREEN}====== WireGuard Client Setup Complete ======${NC}"
  echo -e "${YELLOW}Your home server is now connected to your VPS via WireGuard.${NC}"
  echo -e "${YELLOW}VPS IP:${NC} $(grep "Endpoint" /etc/wireguard/wg0.conf | cut -d '=' -f2 | cut -d ':' -f1 | tr -d ' ')"
  echo -e "${YELLOW}Local WireGuard IP:${NC} $(grep "Address" /etc/wireguard/wg0.conf | cut -d '=' -f2 | tr -d ' ')"
}

# Execute main function
main
