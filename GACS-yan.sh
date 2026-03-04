#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while ps -p $pid > /dev/null 2>&1; do
        printf "${CYAN} [%c] ${NC}" "$spinstr"
        spinstr=${spinstr#?}${spinstr%${spinstr#?}}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
}

run_command() {
    local cmd="$1"
    local msg="$2"

    printf "${YELLOW}%-50s${NC}" "$msg..."
    bash -c "$cmd" > /dev/null 2>&1 &
    spinner $!
    wait $!

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${RED}Failed${NC}"
        exit 1
    fi
}

echo -e "${BOLD}GenieACS Installer for Armbian / Debian Bullseye${NC}"

if [ "$EUID" -ne 0 ]; then
    echo "Run as root"
    exit 1
fi

echo -e "\n${BOLD}Starting installation...${NC}\n"

run_command "apt update -y" "Updating package list"

run_command "apt install -y curl gnupg build-essential" "Installing base packages"

# NodeJS 18 (recommended for GenieACS)
run_command "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -" "Adding NodeJS repo"

run_command "apt install -y nodejs" "Installing NodeJS"

# MongoDB repo for Debian 11
run_command "curl -fsSL https://pgp.mongodb.com/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb.gpg" "Adding MongoDB key"

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb.gpg ] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/4.4 main" > /etc/apt/sources.list.d/mongodb-org.list

run_command "apt update -y" "Updating repo"

run_command "apt install -y mongodb-org" "Installing MongoDB"

run_command "systemctl enable mongod" "Enable MongoDB"

run_command "systemctl start mongod" "Start MongoDB"

# Install GenieACS
run_command "npm install -g genieacs@1.2.13" "Installing GenieACS"

# Create user
run_command "useradd --system --no-create-home --user-group genieacs" "Creating genieacs user"

mkdir -p /opt/genieacs/ext
chown genieacs:genieacs /opt/genieacs/ext

mkdir -p /var/log/genieacs
chown genieacs:genieacs /var/log/genieacs

cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/cwmp.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/nbi.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/fs.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/ui.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
NODE_OPTIONS=--enable-source-maps
EOF

node -e "console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))" >> /opt/genieacs/genieacs.env

chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

# Systemd services
for service in cwmp nbi fs ui
do

cat << EOF > /etc/systemd/system/genieacs-$service.service
[Unit]
Description=GenieACS $service
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$service

[Install]
WantedBy=multi-user.target
EOF

done

systemctl daemon-reload

systemctl enable genieacs-cwmp
systemctl enable genieacs-nbi
systemctl enable genieacs-fs
systemctl enable genieacs-ui

systemctl start genieacs-cwmp
systemctl start genieacs-nbi
systemctl start genieacs-fs
systemctl start genieacs-ui

echo -e "\n${GREEN}Installation completed${NC}"
