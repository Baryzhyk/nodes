#!/bin/bash

# Завантаження логотипу
bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)

# Визначення кольорів
GREEN="\e[32m"
PINK="\e[35m"
RED="\e[31m"
NC="\e[0m"

# --- ФУНКЦІЇ ---
give_ack() {
  echo ""
  read -p "Натисніть Enter для повернення до меню..."
}

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
CHOICE=$(whiptail --title "Меню керування Aztec" \
  --menu "Оберіть потрібну дію:" 20 70 9 \
    "1" "Встановити вузол" \
    "2" "Перевірити логи" \
    "3" "Перевірити хеш" \
    "4" "Зареєструвати валідатора" \
    "5" "Оновити вузол" \
    "6" "Видалити вузол" \
  3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo -e "${RED}Скасовано. Вихід.${NC}"
  exit 1
fi

case $CHOICE in
  1)
    echo -e "${GREEN}Встановлення залежностей...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install -y iptables-persistent curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

    if ! command -v docker &> /dev/null; then
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker "$USER"
    fi

    if ! getent group docker > /dev/null; then
      sudo groupadd docker
    fi
    sudo usermod -aG docker "$USER"

    sudo systemctl start docker
    sudo chmod 666 /var/run/docker.sock

    sudo iptables -I INPUT -p tcp --dport 40400 -j ACCEPT
    sudo iptables -I INPUT -p udp --dport 40400 -j ACCEPT
    sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    mkdir -p "$HOME/aztec-sequencer"
    cd "$HOME/aztec-sequencer"

    docker pull aztecprotocol/aztec:0.87.2

    read -p "Вставте ваш URL RPC Sepolia: " RPC
    read -p "Вставте ваш URL Beacon Sepolia: " CONSENSUS
    read -p "Вставте приватний ключ вашого гаманця (0x…): " PRIVATE_KEY
    read -p "Вставте адресу вашого гаманця (0x…): " WALLET

    SERVER_IP=$(curl -s https://api.ipify.org)

    cat > .env <<EOF
ETHEREUM_HOSTS=$RPC
L1_CONSENSUS_HOST_URLS=$CONSENSUS
VALIDATOR_PRIVATE_KEY=$PRIVATE_KEY
P2P_IP=$SERVER_IP
WALLET=$WALLET
GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=0x54F7fe24E349993b363A5Fa1bccdAe2589D5E5Ef
EOF

    mkdir -p "$HOME/aztec-sequencer/data"

    docker run -d \
      --name aztec-sequencer \
      --network host \
      --entrypoint /bin/sh \
      --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data \
      -e LOG_LEVEL=debug \
      -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:0.87.2 \
      -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'

    echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}Команда для перегляду логів:${NC}" 
    echo "docker logs --tail 100 -f aztec-sequencer"
    echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
    echo -e "${GREEN}Процес завершено.${NC}"
    sleep 2
    docker logs --tail 100 -f aztec-sequencer
    ;;

  2)
    docker logs --tail 100 -f aztec-sequencer
    ;;

  3)
    echo -e "${GREEN}Виконується запит хешу...${NC}"
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
    set -euo pipefail

   # Файл з параметрами ноди
   VARS_FILE="$HOME/aztec-sequencer/.env"
   if [ -f "$VARS_FILE" ]; then
   export $(grep -v '^\s*#' "$VARS_FILE" | xargs)
   fi

   # Кольори для виводу
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  NC='\033[0m'

  # Виконуємо команду додавання валідатора і зберігаємо вивід
  echo -e "${GREEN}Запускаємо процес додавання валідатора...${NC}"
  RAW_OUT=$(docker exec -i aztec-sequencer \
  sh -c 'node /usr/src/yarn-project/aztec/dest/bin/index.js add-l1-validator \
    --l1-rpc-urls "${ETHEREUM_HOSTS}" \
    --private-key "${VALIDATOR_PRIVATE_KEY}" \
    --attester "${WALLET}" \
    --proposer-eoa "${WALLET}" \
    --staking-asset-handler 0xF739D03e98e23A7B65940848aBA8921fF3bAc4b2 \
    --l1-chain-id 11155111' 2>&1) || true

  # Обробка перевищення квоти
  if echo "$RAW_OUT" | grep -q 'ValidatorQuotaFilledUntil'; then
  TS=$(echo "$RAW_OUT" | grep -oP '(?<=\()[0-9]+(?=\))' | head -n1)
  NOW=$(date +%s)
  DELTA=$(( TS - NOW ))
  HOURS=$(( DELTA / 3600 ))
  MINS=$(( (DELTA % 3600) / 60 ))
  printf "${RED}Вибачте, квота на реєстрацію валідаторів тимчасово вичерпана.\n"
  printf "Спробуйте ще раз через %d год %d хв.${NC}\n" "$HOURS" "$MINS"
else
  # В інших випадках виводимо оригінальну відповідь команди
  echo "$RAW_OUT"
fi
    ;;

  5)
    echo -e "${BLUE}Оновлення ноди Aztec...${NC}"
    docker pull aztecprotocol/aztec:0.87.2
    docker stop aztec-sequencer
    docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer/data/*"
    mkdir -p "$HOME/aztec-sequencer/data"
    docker run -d \
      --name aztec-sequencer \
      --network host \
      --entrypoint /bin/sh \
      --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data \
      -e LOG_LEVEL=debug \
      -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:0.87.2 \
      -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    echo -e "${GREEN}Оновлення завершено.${NC}"
    docker logs --tail 100 -f aztec-sequencer
    ;;

  6)
    echo -e "${BLUE}Видалення ноди Aztec...${NC}"
    docker stop aztec-sequencer
    docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer"
    echo -e "${GREEN}Ноду видалено.${NC}"
    ;;

  *)
    echo -e "${RED}Невірний вибір. Будь ласка, оберіть пункт з меню.${NC}"
    ;;
esac
