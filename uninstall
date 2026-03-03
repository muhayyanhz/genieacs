#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run this script as root${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting GenieACS full removal...${NC}"

# Stop and disable GenieACS services
for service in cwmp nbi fs ui; do
    systemctl stop genieacs-$service 2>/dev/null
    systemctl disable genieacs-$service 2>/dev/null
    rm -f /etc/systemd/system/genieacs-$service.service
done

# Stop and disable MongoDB
systemctl stop mongod 2>/dev/null
systemctl disable mongod 2>/dev/null

# Reload systemd
systemctl daemon-reload

echo -e "${YELLOW}Removing GenieACS (npm global)...${NC}"
npm uninstall -g genieacs 2>/dev/null

echo -e "${YELLOW}Removing MongoDB...${NC}"
apt-get purge -y mongodb-org* 2>/dev/null
rm -rf /var/lib/mongodb
rm -rf /var/log/mongodb

echo -e "${YELLOW}Removing MongoDB repository...${NC}"
rm -f /etc/apt/sources.list.d/mongodb-org-4.4.list

echo -e "${YELLOW}Removing NodeJS and NPM (optional)...${NC}"
apt-get purge -y nodejs npm 2>/dev/null

echo -e "${YELLOW}Removing GenieACS directories...${NC}"
rm -rf /opt/genieacs
rm -rf /var/log/genieacs
rm -f /etc/logrotate.d/genieacs

echo -e "${YELLOW}Removing GenieACS system user...${NC}"
userdel genieacs 2>/dev/null

echo -e "${YELLOW}Cleaning unused packages...${NC}"
apt-get autoremove -y
apt-get autoclean -y

echo -e "${GREEN}GenieACS completely removed from system.${NC}"
