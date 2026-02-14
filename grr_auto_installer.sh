#!/bin/bash

############################################################
# GRR DFIR LAB - AUTO INSTALLER
# Author : Jawad Errougui
# Version: 1.0
# Target : GRR 3.2.4.5 (pre-Fleetspeak)
# Tested on: Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS
############################################################

set -e

VERSION="1.0"
LOG_FILE="/var/log/grr_auto_installer.log"
SILENT=false

if [[ "$1" == "--silent" ]]; then
    SILENT=true
fi

exec > >(tee -a "$LOG_FILE") 2>&1

BLUE="\033[1;34m"
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

info(){ $SILENT || echo -e "${BLUE}[INFO]${NC} $1"; }
success(){ $SILENT || echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning(){ $SILENT || echo -e "${YELLOW}[WARNING]${NC} $1"; }
error(){ echo -e "${RED}[ERROR]${NC} $1"; }

spinner_wait() {
    OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    IP=$(hostname -I | awk '{print $1}')
    HOST=$(hostname)
    USER=$(logname 2>/dev/null || echo $SUDO_USER)

    for i in {1..5}; do
        clear
        echo -e "${BLUE}"
        echo "====================================================="
        echo "            GRR DFIR LAB AUTO INSTALLER"
        echo ""
        echo "              Author: Jawad Errougui"
        echo "              Version: $VERSION"
        echo "        GRR Version: 3.2.4.5 (pre-Fleetspeak)"
        echo "  Tested on: Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS"
        echo "====================================================="
        echo ""
        echo -e "${YELLOW}Waiting ⏳${NC}"
        echo ""
        echo "OS        : $OS_VERSION"
        echo "IP        : $IP"
        echo "Hostname  : $HOST"
        echo "User      : $USER"
        echo "====================================================="
        echo -e "${NC}"
        sleep 1
    done
}

spinner_wait

progress_bar() {
    duration=$1
    for ((elapsed=1; elapsed<=duration; elapsed++)); do
        printf "\rProgress : ["
        for ((done=0; done<$elapsed; done++)); do printf "▇"; done
        for ((remain=$elapsed; remain<$duration; remain++)); do printf " "; done
        printf "] %s%%" $((elapsed*100/duration))
        sleep 1
    done
    echo ""
}

info "Initializing installer..."
progress_bar 3

if [[ $EUID -ne 0 ]]; then
   error "Please run as root:"
   echo "sudo ./install_grr.sh"
   exit 1
fi

success "Root privileges confirmed."

info "Checking operating system..."
if ! grep -qi ubuntu /etc/os-release; then
    error "This installer supports Ubuntu only."
    exit 1
fi
success "Ubuntu detected."

CPU=$(nproc)
RAM=$(free -h | awk '/Mem:/ {print $2}')
DISK=$(df -h / | awk 'NR==2 {print $4}')

echo ""
info "Hardware detected:"
echo "CPU Cores : $CPU"
echo "RAM       : $RAM"
echo "Free Disk : $DISK"
echo ""

info "Estimated installation time: 5 to 10 minutes depending on bandwidth."
sleep 2

SERVER_IP=$(hostname -I | awk '{print $1}')

info "Creating lab directory..."
LAB_DIR="/opt/grr-lab"
mkdir -p $LAB_DIR
cd $LAB_DIR
success "Lab directory created at $LAB_DIR"

info "Updating package lists..."
apt-get update -y
success "Package lists updated"

info "Installing prerequisites..."
apt-get install -y ca-certificates curl gnupg lsb-release
success "Prerequisites installed"

info "Installing Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if ! command -v docker >/dev/null 2>&1; then
    error "Docker installation failed."
    exit 1
fi

systemctl enable docker
systemctl start docker
success "Docker installed."

info "Creating Docker Compose file..."
cat <<EOF > docker-compose.yml
services:
  grr:
    image: grrdocker/grr:v3.2.4.5
    container_name: grr-server
    environment:
      EXTERNAL_HOSTNAME: $SERVER_IP
      ADMIN_PASSWORD: admin
    ports:
      - "8000:8000"
      - "8080:8080"
      - "8443:8443"
    volumes:
      - grr-data:/var/lib/grr
    restart: unless-stopped
volumes:
  grr-data:
EOF

info "Pulling GRR image..."
docker compose pull

info "Starting GRR server..."
docker compose up -d

echo ""
echo "⏳ Waiting for GRR to initialize (≈60-90 sec)..."
sleep 70

docker compose ps

echo ""
echo "===================================="
echo "GRR SERVER 3.2.4.5 READY!"
echo "===================================="
echo ""
echo "Access Web Interface:"
echo "http://$SERVER_IP:8000"
echo "Login: admin"
echo "Password: admin"
echo ""
echo "Logs:"
echo "sudo docker compose -f /opt/grr-lab/docker-compose.yml logs -f"
echo ""
echo "Stop:"
echo "sudo docker compose -f /opt/grr-lab/docker-compose.yml stop"
echo ""
echo "Start:"
echo "sudo docker compose -f /opt/grr-lab/docker-compose.yml start"
echo ""
echo "Reset LAB:"
echo "sudo docker compose -f /opt/grr-lab/docker-compose.yml down -v"
echo ""
