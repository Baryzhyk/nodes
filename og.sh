#!/bin/bash

# Кольори
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

# Логотип
bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)

# Анімація
animate_loading() {
    for ((i = 1; i <= 5; i++)); do
        printf "\r${GREEN}Завантажуємо меню${NC}."
        sleep 0.3
        printf "\r${GREEN}Завантажуємо меню${NC}.."
        sleep 0.3
        printf "\r${GREEN}Завантажуємо меню${NC}..."
        sleep 0.3
        printf "\r${GREEN}Завантажуємо меню${NC}    "
        sleep 0.3
    done
    echo ""
}

animate_loading

# Перевірка whiptail
if ! command -v whiptail &> /dev/null; then
    echo -e "${RED}whiptail не встановлено. Встановлюємо...${NC}"
    sudo apt install whiptail -y
fi

# Меню
CHOICE=$(whiptail --title "Меню керування 0g" \
  --menu "Оберіть потрібну дію:" 20 70 10 \
    "1" "Встановити ноду" \
    "2" "Перевірити статус ноди" \
    "3" "Перевірити піри" \
    "4" "Перевірити логи" \
    "5" "Перезапустити ноду" \
    "6" "Видалити ноду" \
  3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo -e "${RED}Скасовано. Вихід.${NC}"
  exit 1
fi

case $CHOICE in
  1)
    echo -e "${GREEN}Оновлення системи та встановлення залежностей...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install -y curl iptables build-essential git wget lz4 jq make cmake gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev screen ufw

    echo -e "${GREEN}Встановлення Rust...${NC}"
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source $HOME/.cargo/env
    rustc --version

    echo -e "${GREEN}Встановлення Go...${NC}"
    wget https://go.dev/dl/go1.24.3.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.24.3.linux-amd64.tar.gz
    rm go1.24.3.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    go version

    echo -e "${GREEN}Завантажуємо вузол...${NC}"
    cd $HOME
    git clone https://github.com/0glabs/0g-storage-node.git
    cd 0g-storage-node
    git checkout v1.0.0
    git submodule update --init
    cargo build --release

    echo -e "${GREEN}Завантажуємо конфігурацію...${NC}"
    rm -f $HOME/0g-storage-node/run/config.toml
    curl -o $HOME/0g-storage-node/run/config.toml https://raw.githubusercontent.com/ruspacer/0g/refs/heads/main/config.toml

    read -p "Вставте приватний ключ вашого гаманця (0x…): " PRIVATE_KEY

    if [[ ! $PRIVATE_KEY =~ ^0x[a-fA-F0-9]{64}$ ]]; then
        echo -e "${RED}Неправильний формат приватного ключа!${NC}"
        exit 1
    fi

    echo -e "${GREEN}Додаємо приватний ключ у конфігурацію...${NC}"
    echo "miner_key = \"$PRIVATE_KEY\"" > $HOME/0g-storage-node/run/config.toml

    echo -e "${GREEN}Створюємо systemd сервіс...${NC}"
    sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}Запускаємо сервіс...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    sudo systemctl start zgs

    echo -e "${GREEN}✅ Встановлення завершено.${NC}"
    ;;

  2)
    echo -e "${GREEN}Перевірка статусу...${NC}"
    sudo systemctl status zgs
    echo -e "${GREEN}Для виходу натисніть Ctrl + C.${NC}"
    ;;

  3)
    echo -e "${GREEN}Перевірка пірів...${NC}"
    while true; do
        response=$(curl -s -X POST http://localhost:5678 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
        logSyncHeight=$(echo $response | jq '.result.logSyncHeight')
        connectedPeers=$(echo $response | jq '.result.connectedPeers')
        echo -e "logSyncHeight: \033[32m$logSyncHeight\033[0m, connectedPeers: \033[34m$connectedPeers\033[0m"
        sleep 5
    done
    ;;

  4)
    echo -e "${GREEN}Вивід поточних логів...${NC}"
    LOG_FILE="$HOME/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d)"
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        echo -e "${RED}Лог-файл не знайдено: $LOG_FILE${NC}"
    fi
    ;;

  5)
    echo -e "${GREEN}Перезапуск вузла...${NC}"
    sudo systemctl restart zgs
    ;;


  6)
    echo -e "${RED}Видаляємо вузол...${NC}"
    sudo systemctl stop zgs
    sudo systemctl disable zgs
    sudo rm -f /etc/systemd/system/zgs.service
    sudo systemctl daemon-reload
    rm -rf $HOME/0g-storage-node
    echo -e "${GREEN}✅ Вузол успішно видалено.${NC}"
    ;;
esac
