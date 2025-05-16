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
CHOICE=$(whiptail --title "Управління вузлом Aztec" \
  --menu "Виберіть дію:" 16 60 6 \
    "1" "Встановити вузол" \
    "2" "Перевірити логи" \
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
    echo -e "${GREEN} Перевірка та встановлення необхідних утиліт...${NC}"
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
    echo -e "${RED}Видаляю вузол...${NC}"
    docker stop aztec-sequencer && docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer"
    echo -e "${GREEN}Вузол видалено.${NC}"
    give_ack
    ;;

  6)
    echo -e "${YELLOW}Оновлення ноди Aztec...${NC}"
    cd "$HOME/aztec-sequencer" || { echo -e "${RED}Папку з нодою не знайдено.${NC}"; exit 1; }

    echo -e "${GREEN}Отримуємо актуальний тег...${NC}"
    NEW_TAG=$(curl -s "https://registry.hub.docker.com/v2/repositories/aztecprotocol/aztec/tags?page_size=100" \
      | jq -r '.results[].name' \
      | grep -E '^0\..*-alpha-testnet\.[0-9]+$' \
      | grep -v 'arm64' \
      | sort -V | tail -1)

    if [ -z "$NEW_TAG" ]; then
      echo -e "${RED}❌ Не вдалося визначити тег. Використовуємо alpha-testnet.${NC}"
      NEW_TAG="alpha-testnet"
    fi

    echo -e "${CYAN}Оновлюємо образ до: $NEW_TAG${NC}"
    docker pull aztecprotocol/aztec:"$NEW_TAG"

    echo -e "${YELLOW}Зупиняємо поточний контейнер...${NC}"
    docker stop aztec-sequencer && docker rm aztec-sequencer

    echo -e "${YELLOW}Очищаємо старі дані...${NC}"
    rm -rf "$HOME/aztec-sequencer/data"/*
    mkdir -p "$HOME/aztec-sequencer/data"

    echo -e "${GREEN}Запускаємо оновлену ноду...${NC}"
    docker run --platform linux/amd64 -d \
      --name aztec-sequencer \
      --network host \
      --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data \
      -e LOG_LEVEL=debug \
      -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:"$NEW_TAG" \
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'

    if [ $? -ne 0 ]; then
      echo -e "${RED}❌ Оновлення завершилося з помилкою. Перевірте логи.${NC}"
    else
      echo -e "${GREEN}✅ Оновлення пройшло успішно.${NC}"
      docker logs --tail 100 -f aztec-sequencer
    fi
    give_ack
    ;;

  *)
    echo -e "${RED}Неправильний вибір. Вихід.${NC}"
    exit 1
    ;;
esac
