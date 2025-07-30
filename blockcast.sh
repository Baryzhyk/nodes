#!/bin/bash

# Перевірка root
if [ "$EUID" -ne 0 ]; then
  echo "Будь ласка, запустіть скрипт з правами root (sudo)"
  exit 1
fi

# Завантаження логотипу
bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)

# Кольори
GREEN="\e[32m"
PINK="\e[35m"
RED="\e[31m"
NC="\e[0m"

# Функція очікування
give_ack() {
  echo ""
  read -p "Натисніть Enter для повернення до меню..."
}

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

# --- Функції дій ---

install_node() {
  echo -e "${PINK}Оновлення системи...${NC}"
  apt update && apt upgrade -y
  apt install -y curl git jq docker docker-compose

  echo -e "${PINK}Клонування репозиторію...${NC}"
  git clone https://github.com/Blockcast/beacon-docker-compose.git
  cd beacon-docker-compose || exit 1

  echo -e "${PINK}Запуск docker-compose...${NC}"
  docker-compose up -d

  # Чекаємо, поки контейнер стане активним
   echo -e "${PINK}Очікування запуску blockcastd...${NC}"
for i in {1..10}; do
  STATUS=$(docker inspect -f '{{.State.Running}}' blockcastd 2>/dev/null)
  if [ "$STATUS" == "true" ]; then
    echo -e "${GREEN}✅ Контейнер blockcastd працює.${NC}"
    break
  else
    echo -e "${PINK}Спроба $i: контейнер ще неактивний. Очікування...${NC}"
    sleep 3
  fi
done
# Перевірка остаточна
if [ "$STATUS" != "true" ]; then
  echo -e "${RED}❌ Контейнер blockcastd не запустився. Перевірте логи: docker logs blockcastd${NC}"
  return
fi
# Ініціалізація
docker-compose exec blockcastd blockcastd init
  echo -e "${PINK}Локація вузла:${NC}"
  curl -s https://ipinfo.io | jq '.city, .region, .country, .loc'

  echo -e "${GREEN}✅ Ноду встановлено та запущено!${NC}"
  give_ack
}

check_logs() {
  echo -e "${PINK}Виведення логів...${NC}"
  docker logs blockcastd
  give_ack
}

update_node() {
  echo -e "${PINK}Оновлення ноди...${NC}"
  cd beacon-docker-compose || exit 1
  git pull
  docker-compose pull
  docker-compose up -d
  echo -e "${GREEN}✅ Оновлення завершено.${NC}"
  give_ack
}

uninstall_node() {
  echo -e "${RED}⚠ Видалення ноди...${NC}"
  cd beacon-docker-compose || exit 1
  docker-compose down
  docker-compose rm -f
  cd ..
  rm -rf beacon-docker-compose
  echo -e "${GREEN}✅ Ноду повністю видалено.${NC}"
  give_ack
}

# --- Меню ---
while true; do
  animate_loading
  CHOICE=$(whiptail --title "Меню керування Blockcast" \
    --menu "Оберіть потрібну дію:" 20 70 10 \
    "1" "Встановити вузол" \
    "2" "Перевірити логи" \
    "3" "Оновити вузол" \
    "4" "Видалити вузол" \
    "5" "Вихід" \
    3>&1 1>&2 2>&3)

  case $CHOICE in
    1) install_node ;;
    2) check_logs ;;
    3) update_node ;;
    4) uninstall_node ;;
    5) echo "Вихід..."; exit 0 ;;
    *) echo "Невідомий вибір..."; exit 1 ;;
  esac
done
