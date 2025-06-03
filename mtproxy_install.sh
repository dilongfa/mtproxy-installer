#!/bin/bash

# MTProxy Installation Script for Debian 12
# Author: Auto-generated script
# Description: Installs and configures MTProxy on Debian 12

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons."
   print_status "Please run as a regular user with sudo privileges."
   exit 1
fi

# Check if running on Debian
if ! grep -q "Debian" /etc/os-release; then
    print_error "This script is designed for Debian systems only."
    exit 1
fi

print_header "MTProxy Installation Script for Debian 12"

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required dependencies including additional ones for compilation
print_status "Installing dependencies..."
sudo apt install -y git build-essential libssl-dev zlib1g-dev curl wget \
    libc6-dev gcc-multilib make cmake pkg-config

# Create mtproxy user
print_status "Creating mtproxy user..."
if ! id "mtproxy" &>/dev/null; then
    sudo useradd -r -s /bin/false -d /var/lib/mtproxy -m mtproxy
    print_status "User 'mtproxy' created successfully."
else
    print_warning "User 'mtproxy' already exists."
fi

# Try multiple MTProxy sources (original and community fork)
print_status "Attempting to build MTProxy..."
cd /tmp

# Remove any existing directories
if [ -d "MTProxy" ]; then
    rm -rf MTProxy
fi
if [ -d "MTProxy-community" ]; then
    rm -rf MTProxy-community
fi

BUILD_SUCCESS=false

# First try the community fork (more maintained)
print_status "Trying community fork first..."
if git clone https://github.com/GetPageSpeed/MTProxy.git MTProxy-community; then
    cd MTProxy-community
    
    # Apply fixes for modern systems
    print_status "Applying compatibility fixes..."
    
    # Fix for newer GCC versions
    if [ -f "Makefile" ]; then
        sed -i 's/-Werror//g' Makefile 2>/dev/null || true
    fi
    
    # Try building with community fork
    if make -j$(nproc) 2>/dev/null; then
        BUILD_SUCCESS=true
        print_status "Community fork build successful!"
    else
        print_warning "Community fork build failed, trying original with fixes..."
        cd /tmp
    fi
fi

# If community fork failed, try original with fixes
if [ "$BUILD_SUCCESS" = false ]; then
    print_status "Trying original repository with fixes..."
    
    if git clone https://github.com/TelegramMessenger/MTProxy.git; then
        cd MTProxy
        
        # Apply multiple compatibility fixes
        print_status "Applying compatibility fixes for original repo..."
        
        # Fix 1: Remove -Werror flag that causes compilation to fail on warnings
        if [ -f "Makefile" ]; then
            sed -i 's/-Werror//g' Makefile 2>/dev/null || true
        fi
        
        # Fix 2: Update compiler flags for newer systems
        if [ -f "Makefile" ]; then
            sed -i 's/-march=native/-march=native -fcommon/g' Makefile 2>/dev/null || true
        fi
        
        # Fix 3: Add missing includes for newer glibc
        find . -name "*.c" -exec sed -i '1i#include <string.h>' {} \; 2>/dev/null || true
        find . -name "*.c" -exec sed -i '1i#include <unistd.h>' {} \; 2>/dev/null || true
        
        # Try building with fixes
        if make -j$(nproc) CFLAGS="-fcommon -Wno-error"; then
            BUILD_SUCCESS=true
            print_status "Original repository build successful with fixes!"
        else
            print_error "Both builds failed. Trying alternative approach..."
            
            # Last resort: try with minimal flags
            if make CC=gcc CFLAGS="-O2 -fcommon -w"; then
                BUILD_SUCCESS=true
                print_status "Build successful with minimal flags!"
            fi
        fi
    fi
fi

# Check if build was successful
if [ "$BUILD_SUCCESS" = false ]; then
    print_error "Failed to build MTProxy from source."
    print_error "This may be due to compatibility issues with Debian 12."
    print_status "Alternative options:"
    print_status "1. Use Docker version: docker run -d -p443:443 telegrammessenger/proxy:latest"
    print_status "2. Try a pre-compiled binary"
    print_status "3. Use alternative proxy solutions like Shadowsocks"
    exit 1
fi

# Create directories
print_status "Setting up directories..."
sudo mkdir -p /var/lib/mtproxy
sudo mkdir -p /etc/mtproxy
sudo mkdir -p /var/log/mtproxy

# Copy binary (check which directory structure was used)
print_status "Installing MTProxy binary..."
if [ -f "objs/bin/mtproto-proxy" ]; then
    sudo cp objs/bin/mtproto-proxy /usr/local/bin/
elif [ -f "mtproto-proxy" ]; then
    sudo cp mtproto-proxy /usr/local/bin/
elif [ -f "bin/mtproto-proxy" ]; then
    sudo cp bin/mtproto-proxy /usr/local/bin/
else
    print_error "MTProxy binary not found! Build may have failed."
    find . -name "*mtproto*proxy*" -type f 2>/dev/null || true
    exit 1
fi
sudo chmod +x /usr/local/bin/mtproto-proxy

# Generate secret
print_status "Generating secret..."
SECRET=$(head -c 16 /dev/urandom | xxd -ps)
echo "SECRET=$SECRET" | sudo tee /etc/mtproxy/config > /dev/null

# Download proxy configuration
print_status "Downloading proxy configuration..."
sudo curl -s https://core.telegram.org/getProxySecret -o /etc/mtproxy/proxy-secret
sudo curl -s https://core.telegram.org/getProxyConfig -o /etc/mtproxy/proxy-multi.conf

# Set permissions
print_status "Setting permissions..."
sudo chown -R mtproxy:mtproxy /var/lib/mtproxy
sudo chown -R mtproxy:mtproxy /etc/mtproxy
sudo chown -R mtproxy:mtproxy /var/log/mtproxy
sudo chmod 600 /etc/mtproxy/*

# Check if we can bind to port 443, if not use alternative port
print_status "Checking port binding capabilities..."
PROXY_PORT=443
INTERNAL_PORT=8888

# Test if we can bind to port 443
if ! sudo -u mtproxy timeout 2 nc -l 443 2>/dev/null; then
    print_warning "Cannot bind to port 443 directly. Using port 8443 instead."
    PROXY_PORT=8443
fi

# Give mtproxy user capability to bind to privileged ports (if using 443)
if [ "$PROXY_PORT" = "443" ]; then
    print_status "Granting capability to bind privileged ports..."
    sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/mtproto-proxy
fi

# Create systemd service
print_status "Creating systemd service..."
sudo tee /etc/systemd/system/mtproxy.service > /dev/null <<EOF
[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
User=mtproxy
Group=mtproxy
WorkingDirectory=/var/lib/mtproxy
ExecStart=/usr/local/bin/mtproto-proxy -u mtproxy -p $INTERNAL_PORT -H $PROXY_PORT -S $SECRET --aes-pwd /etc/mtproxy/proxy-secret /etc/mtproxy/proxy-multi.conf -M 1
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mtproxy
# Allow binding to privileged ports
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
print_status "Enabling MTProxy service..."
sudo systemctl daemon-reload
sudo systemctl enable mtproxy

# Create configuration update script
print_status "Creating configuration update script..."
sudo tee /usr/local/bin/mtproxy-update > /dev/null <<'EOF'
#!/bin/bash
# MTProxy configuration update script

echo "Updating MTProxy configuration..."
curl -s https://core.telegram.org/getProxySecret -o /etc/mtproxy/proxy-secret
curl -s https://core.telegram.org/getProxyConfig -o /etc/mtproxy/proxy-multi.conf
chown mtproxy:mtproxy /etc/mtproxy/proxy-secret /etc/mtproxy/proxy-multi.conf
chmod 600 /etc/mtproxy/proxy-secret /etc/mtproxy/proxy-multi.conf
systemctl restart mtproxy
echo "Configuration updated and service restarted."
EOF

sudo chmod +x /usr/local/bin/mtproxy-update

# Setup logrotate
print_status "Setting up log rotation..."
sudo tee /etc/logrotate.d/mtproxy > /dev/null <<EOF
/var/log/mtproxy/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 640 mtproxy mtproxy
    postrotate
        /bin/systemctl reload mtproxy > /dev/null 2>&1 || true
    endscript
}
EOF

# Configure firewall (if ufw is installed)
if command -v ufw &> /dev/null; then
    print_status "Configuring firewall..."
    sudo ufw allow $PROXY_PORT/tcp
    sudo ufw allow $INTERNAL_PORT/tcp
fi

# Start MTProxy service
print_status "Starting MTProxy service..."
sudo systemctl start mtproxy

# Wait a moment for service to start
sleep 3

# Check service status
if sudo systemctl is-active --quiet mtproxy; then
    print_status "MTProxy service started successfully!"
else
    print_error "Failed to start MTProxy service. Check logs with: sudo journalctl -u mtproxy"
    exit 1
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")

# Generate proxy links
print_header "Installation Complete!"
echo
print_status "MTProxy has been successfully installed and started!"
echo
echo -e "${BLUE}Alternative Installation Methods:${NC}"
echo "If this installation fails on your system, try these alternatives:"
echo "• Docker: docker run -d -p 443:443 -p 8888:8888 --name mtproxy --restart=unless-stopped telegrammessenger/proxy:latest"
echo "• One-line installer: bash <(curl -s https://raw.githubusercontent.com/HirbodBehnam/MTProtoProxyInstaller/master/MTProtoProxyInstall.sh)"
echo
echo -e "${BLUE}Configuration Details:${NC}"
echo "• Service: mtproxy"
echo "• Port: 443 (external), 8888 (internal)"
echo "• Secret: $SECRET"
echo "• Config files: /etc/mtproxy/"
echo "• Logs: sudo journalctl -u mtproxy"
echo
echo -e "${BLUE}Proxy Links:${NC}"
echo "• Telegram Link: https://t.me/proxy?server=${SERVER_IP}&port=${PROXY_PORT}&secret=${SECRET}"
echo "• Manual Configuration:"
echo "  - Server: ${SERVER_IP}"
echo "  - Port: ${PROXY_PORT}"
echo "  - Secret: ${SECRET}"
echo
echo -e "${BLUE}Management Commands:${NC}"
echo "• Start: sudo systemctl start mtproxy"
echo "• Stop: sudo systemctl stop mtproxy"
echo "• Restart: sudo systemctl restart mtproxy"
echo "• Status: sudo systemctl status mtproxy"
echo "• Logs: sudo journalctl -u mtproxy -f"
echo "• Update config: sudo mtproxy-update"
echo
echo
print_warning "Remember to:"
print_warning "1. Open ports ${PROXY_PORT} and ${INTERNAL_PORT} in your firewall if needed"
print_warning "2. Update proxy configuration regularly with: sudo mtproxy-update"
print_warning "3. Monitor logs for any issues"
if [ "$PROXY_PORT" != "443" ]; then
    print_warning "4. Note: Using port ${PROXY_PORT} instead of 443 due to permission restrictions"
fi
echo
print_status "Installation completed successfully!"
