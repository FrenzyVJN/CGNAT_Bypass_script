```markdown
# CGNAT Bypass with WireGuard VPN and Reverse Proxy ![GitHub forks](https://img.shields.io/github/forks/yourusername/cgnat-bypass?style=social) ![GitHub stars](https://img.shields.io/github/stars/yourusername/cgnat-bypass?style=social)

A robust solution for exposing home servers behind Carrier-Grade NAT (CGNAT) using a free-tier VPS as a secure relay. Combines WireGuard VPN with Nginx reverse proxy for reliable service exposure.

## Features 🔌
- **Dual-stack architecture** with WireGuard tunnel (Layer 3) and Nginx proxy (Layer 7)
- **Automatic iptables configuration** for persistent port forwarding
- **Modular bash scripts** for both VPS and home server setup
- **TCP/UDP support** with selective port exposure
- **Zero-cost infrastructure** compatible with Azure and Oracle Cloud free tiers
- **Easy to use** with minimal configuration required
- **Secure** with WireGuard encryption and Nginx reverse proxy
- **Open-source** with community contributions welcome

## Prerequisites 📋
- Free VPS account (Oracle Cloud, AWS, Azure, etc.)
- Linux-based home server (x86_64 or ARM architecture)
- Basic familiarity with SSH and terminal operations

## Installation 🛠️

### VPS Configuration
```
wget https://raw.githubusercontent.com/FrenzyVJN/CGNAT_Bypass_script/refs/heads/main/server-setup.sh
chmod +x server_setup.sh
sudo ./server_setup.sh
```

### Home Server Configuration
```
wget https://raw.githubusercontent.com/FrenzyVJN/CGNAT_Bypass_script/refs/heads/main/client-setup.sh
chmod +x client_setup.sh
sudo ./client_setup.sh
```
### Key Management
Rotate WireGuard keys quarterly:
```
wg genkey | tee new_private.key | wg pubkey > new_public.key
wg set wg0 peer $(cat old_public.key) remove
wg set wg0 peer $(cat new_public.key) allowed-ips 10.8.0.2/32
```

## Configuration ⚙️
### Nginx TCP Proxy (Required for SSH)
```
# /etc/nginx/stream.d/ssh.conf
stream {
    server {
        listen 22;
        proxy_pass 10.8.0.2:22;
    }
}
```

### Persistent IP Forwarding
```
# /etc/sysctl.conf
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
```

## Troubleshooting 🚨
### Connection Tests
```
# Verify WireGuard tunnel
sudo wg show

# Test port forwarding
nc -zv VPS_IP 22

# Check packet flow
sudo tcpdump -i eth0 port 51820 -vv
```

### Common Issues
- **SSH Timeouts**: Ensure Nginx stream module is enabled
- **Port Conflicts**: Verify VPS security group settings
- **NAT Issues**: Confirm `net.ipv4.ip_forward=1` on VPS

## Contributing 🤝
Found an issue? Open a ticket or submit a PR:
1. Fork repository
2. Create feature branch (`git checkout -b improvement/feature`)
3. Commit changes (`git commit -am 'Add amazing feature'`)
4. Push to branch (`git push origin improvement/feature`)
5. Open Pull Request

## License 📄
MIT License - See [LICENSE](LICENSE) for full text

For complete configuration details, see the [WireGuard Documentation](https://www.wireguard.com/).