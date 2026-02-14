#!/bin/bash
############################################################
# GRR DFIR LAB - LINUX GRR AGENT AUTO INSTALLER
# Author : Jawad Errougui
# Version: 1.0
# Target : GRR 3.2.4.5 (pre-Fleetspeak)
# Tested on: Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS
############################################################

set -e

VERSION="1.0"
LOG_FILE="/var/log/grr_agent_installer.log"
SILENT=false

exec > >(tee -a "$LOG_FILE") 2>&1

YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m"
BLUE="\033[1;34m"

info(){ $SILENT || echo -e "${YELLOW}[INFO]${NC} $1"; }
success(){ $SILENT || echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning(){ $SILENT || echo -e "${YELLOW}[WARNING]${NC} $1"; }
error(){ echo -e "${RED}[ERROR]${NC} $1"; }

spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'

    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

spinner_wait() {
    clear
    echo -e "${YELLOW}"
    echo "====================================================="
    echo "          GRR DFIR LAB : GRR AGENT INSTALLER"
    echo ""
    echo "            Author: Jawad Errougui"
    echo ""
    echo "              Version: $VERSION"
    echo "      GRR Agent Version: 3.2.4.5 (pre-Fleetspeak)"
    echo "  Tested on: Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS"
    echo "====================================================="
    echo -e "${NC}"
}

spinner_wait

if [[ $EUID -ne 0 ]]; then
   error "Please run as root:"
    echo ""
   echo "sudo ./deploy_linux_grr_agents.sh" "$1" "$2"
   echo ""
   exit 1
fi

success "Root privileges confirmed."

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <IP_CLIENT> <USERNAME>"
    exit 1
fi

IP_CLIENT="$1"
USERNAME="$2"

if ! command -v sshpass &> /dev/null; then
    warning "sshpass n'est pas installé."

    read -p "Voulez-vous l'installer maintenant ? (y/n) : " INSTALL

    if [[ "$INSTALL" =~ ^[Yy]$ ]]; then
        info "[*] Installation de sshpass en cours..."

        (
            apt-get update -y &>/dev/null
            apt-get install sshpass -y &>/dev/null
        ) &

        spinner

        if command -v sshpass &> /dev/null; then
            VERSION_SSHPASS=$(sshpass -V 2>&1 | head -n1 | awk '{print $2}')
            success "[+] sshpass installé avec succès (version $VERSION_SSHPASS)"
        else
            error "Echec de l'installation de sshpass."
            exit 1
        fi
    else
        error "sshpass est requis. Abandon du script."
        exit 1
    fi
fi

echo ""

set +e

MAX_TRIES=3
TRY=1

while [ $TRY -le $MAX_TRIES ]; do
    read -s -p "Mot de passe pour $USERNAME@$IP_CLIENT : " PASSWORD
    echo ""

    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USERNAME@$IP_CLIENT" "exit" &>/dev/null
    STATUS=$?

    if [ $STATUS -eq 0 ]; then
        success "[+] Mot de passe correct."
        break
    else
        error "[!] Mot de passe incorrect. Essai $TRY/$MAX_TRIES"
        TRY=$((TRY+1))
        if [ $TRY -gt $MAX_TRIES ]; then
            error "Mot de passe incorrect $MAX_TRIES fois. Abandon du script."
            exit 1
        fi
    fi
done

set -e

info "[*] Test de connectivité avec $IP_CLIENT..."
ping -c 1 $IP_CLIENT &> /dev/null || { error "$IP_CLIENT n'est pas joignable."; exit 1; }
success "[+] $IP_CLIENT est joignable."

AGENT_INFO=$(sshpass -p "$PASSWORD" ssh "$USERNAME@$IP_CLIENT" \
"AGENT_OS=\$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'); \
AGENT_RAM=\$(free -h | awk 'NR==2 {print \$2\" total, \"\$3\" used\"}'); \
AGENT_DISK=\$(df -h / | awk 'NR==2 {print \$2\" total, \"\$4\" available\"}'); \
echo '====================================================='; \
echo '                  GRR AGENT $IP_CLIENT'; \
echo '====================================================='; \
echo \"OS     : \$AGENT_OS\"; \
echo \"RAM    : \$AGENT_RAM\"; \
echo \"Disk   : \$AGENT_DISK\"; \
echo '====================================================='")

echo -e "${CYAN}$AGENT_INFO${NC}"

info "[*] Vérification de l'installation existante du client GRR..."
AGENT_INSTALLE=$(sshpass -p "$PASSWORD" ssh "$USERNAME@$IP_CLIENT" "dpkg -l | grep grr" || true)
if [ ! -z "$AGENT_INSTALLE" ]; then
    warning "[!] GRR est déjà installé sur $IP_CLIENT."
    read -p "Voulez-vous le désinstaller et installer la nouvelle version ? (y/n) : " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        info "[*] Désinstallation de l'ancien GRR..."
        sshpass -p "$PASSWORD" ssh "$USERNAME@$IP_CLIENT" "sudo systemctl stop grr; sudo dpkg --purge --force-all grr"
        success "[+] Ancien GRR désinstallé."
    else
        info "[*] Installation annulée par l'utilisateur."
        exit 0
    fi
fi

GRR_DIR="/root/grr_installers/installers"
GRR_DEB="$GRR_DIR/grr_3.2.4.5_amd64.deb"

if [ ! -f "$GRR_DEB" ]; then
    info "[*] Copie des binaires GRR depuis le conteneur Docker..."
    mkdir -p /root/grr_installers
    sudo docker cp grr-server:/usr/share/grr-server/executables/installers /root/grr_installers
    if [ ! -f "$GRR_DEB" ]; then
        error "Le fichier $GRR_DEB est introuvable après copie depuis Docker !"
        exit 1
    fi
    success "[+] Binaries copiés dans $GRR_DIR"
fi

info "[*] Copie du client GRR vers $IP_CLIENT..."
sshpass -p "$PASSWORD" scp "$GRR_DEB" "$USERNAME@$IP_CLIENT:/tmp/"
success "[+] Fichier copié."

info "[*] Installation du client GRR sur $IP_CLIENT..."
sshpass -p "$PASSWORD" ssh "$USERNAME@$IP_CLIENT" "sudo dpkg -i /tmp/$(basename $GRR_DEB) && sudo systemctl enable grr && sudo systemctl start grr"
success "[+] GRR installé et service démarré."

echo ""
echo "========================================================"
echo -e "${BLUE}[+] GRR Agent 3.2.4.5 prêt sur $IP_CLIENT${NC}"
echo "========================================================"
echo ""
