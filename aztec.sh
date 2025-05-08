#!/bin/bash

# Завантаження логотипу
bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)

# Визначення кольорів
GREEN="\e[32m"
PINK="\e[35m"
RED="\e[31m"
NC="\e[0m"

# Функція анімації
animate_loading() {
    for ((i = 1; i <= 5; i++)); do
        printf "\r${GREEN}Завантажуємо меню${NC}."
        sleep 0.3
        printf "\r${GREEN}Завантажуємо меню${NC}.."
        sleep 0.3
        printf "\r${GREEN}Завантажуємо меню${NC}..."
        sleep 0.3
        printf "\r${GREEN}Завантажуємо меню${NC}"
        sleep 0.3
    done
    echo ""
}

animate_loading

# Меню вибору
CHOICE=$(whiptail --title "Управління вузлом Aztec" \
  --menu "Виберіть дію:" 16 60 6 \
    "1" "Встановити вузол" \
    "2" "Показати логи" \
    "3" "Перевірити хеш" \
    "4" "Зареєструвати валідатора" \
    "5" "Видалити вузол" \
    "6" "Оновити вузол" \
  3>&1 1>&2 2>&3)

# Вихід при скасуванні
if [ $? -ne 0 ]; then
  echo -e "${RED}Скасовано. Вихід.${NC}"
  exit 1
fi

case "$CHOICE" in
  1)
  # Перевірка та встановлення необхідних утиліт
for util in figlet whiptail curl docker iptables jq; do
  if ! command -v "$util" &>/dev/null; then
    echo "$util не знайдено. Встановлюю..."
    sudo apt update && sudo apt install -y "$util"
  fi
done

    echo -e "${GREEN}Готую середовище...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install -y build-essential git jq lz4 make nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev clang bsdmainutils ncdu unzip

    if ! command -v docker &>/dev/null; then
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker "$USER"
    fi
    sudo systemctl start docker
    sudo chmod 666 /var/run/docker.sock

    sudo iptables -I INPUT -p tcp --dport 40400 -j ACCEPT
    sudo iptables -I INPUT -p udp --dport 40400 -j ACCEPT
    sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    mkdir -p "$HOME/aztec-sequencer/data" && cd "$HOME/aztec-sequencer"

    echo -e "${YELLOW}Отримую останню збірку Aztec (крім ARM64)...${NC}"
    LATEST=$(curl -s "https://registry.hub.docker.com/v2/repositories/aztecprotocol/aztec/tags?page_size=100" \
      | jq -r '.results[].name' \
      | grep -E '^0\..*-alpha-testnet\.[0-9]+$' \
      | grep -v 'arm64' \
      | sort -V | tail -1)

    if [ -z "$LATEST" ]; then
      echo -e "${RED}❌ Не вдалося знайти відповідний тег. Використовую alpha-testnet.${NC}"
      LATEST="alpha-testnet"
    fi

    echo -e "${GREEN}Використовуємо тег: $LATEST${NC}"
    docker pull aztecprotocol/aztec:"$LATEST"

    read -p "RPC Sepolia URL: " RPC_URL
    read -p "Beacon Sepolia URL: " CONS_URL
    read -p "Ваш приватний ключ: " PRIV_KEY
    read -p "Адреса гаманця: " WALLET_ADDR

    SERVER_IP=$(curl -s https://api.ipify.org)
    cat > .env <<EOF
ETHEREUM_HOSTS=$RPC_URL
L1_CONSENSUS_HOST_URLS=$CONS_URL
VALIDATOR_PRIVATE_KEY=$PRIV_KEY
P2P_IP=$SERVER_IP
WALLET=$WALLET_ADDR
EOF

    echo -e "${GREEN}Запускаю контейнер...${NC}"
    docker run --platform linux/amd64 -d \
      --name aztec-sequencer \
      --network host \
      --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data \
      -e LOG_LEVEL=debug \
      -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:"$LATEST" \
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'

    if [ $? -ne 0 ]; then
      echo -e "${RED}❌ Контейнер не запущено. Перевірте журнали помилок через:${NC}"
      echo "docker logs aztec-sequencer"
    else
      echo -e "${GREEN}✅ Вузол успішно запущено.${NC}"
      docker logs --tail 100 -f aztec-sequencer
    fi

    give_ack
    ;;

  2)
    echo -e "${GREEN}Показую логи...${NC}"
    docker logs --tail 100 -f aztec-sequencer | grep -v "Rollup__Invalid" | grep -v "type: 'error'"
    give_ack
    ;;

  3)
    echo -e "${GREEN}Запит хешу...${NC}"
    cd "$HOME/aztec-sequencer"
    TIP=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' http://localhost:8080)
    BLK=$(echo "$TIP" | jq -r '.result.proven.number')
    PROOF=$(curl -s -X POST -H "Content-Type: application/json" \
      -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[${BLK},${BLK}],\"id\":1}" http://localhost:8080 | jq -r '.result')
    echo -e "${GREEN}Блок: ${NC}$BLK"
    echo -e "${GREEN}Доказ:${NC} $PROOF"
    give_ack
    ;;

  4)
    echo -e "${GREEN}Запускаю реєстрацію валідатора...${NC}"
    cd "$HOME/aztec-sequencer"
    [ -f .env ] && export $(grep -v '^#' .env | xargs)
    tmpnv=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/TheGentIeman/Nodes/refs/heads/main/NewValidator.sh > "$tmpnv"
    chmod +x "$tmpnv"
    bash "$tmpnv"
    rm -f "$tmpnv"
    give_ack
    ;;

  5)
    echo -e "${RED}Видаляю вузол...${NC}"
    docker stop aztec-sequencer && docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer"
    echo -e "${GREEN}Вузол видалено.${NC}"
    give_ack
    ;;

  6)
    echo -e "${YELLOW}Оновлення вузла Aztec...${NC}"
    cd "$HOME/aztec-sequencer" || { echo -e "${RED}
