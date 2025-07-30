#!/bin/bash

# Перевірка на root
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

# Функція для анімації завантаження
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

# Функція для встановлення ноди
install_node() {
  echo -e "${PINK}Оновлення системи...${NC}"
  apt update && apt upgrade -y
  apt install -y curl

  # Перевірка Docker
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker не знайдено. Встановлюємо...${NC}"
    # Синхронізація для встановлення Docker (замініть це на ваші власні команди)
    synchronize install-docker
    synchronize fix-docker
  else
    echo -e "${GREEN}Docker вже встановлено: $(docker --version)${NC}"
  fi

  # Клонуємо репозиторій для ноди
  git clone https://github.com/Blockcast/beacon-docker-compose.git
  cd beacon-docker-compose
  # Запускаємо Docker Compose
  docker-compose up -d

  # Очікуємо, поки образ встановиться
  docker-compose exec blockcastd blockcastd init

  # Виводимо інформацію про місто, регіон, країну та координати IP
  curl -s https://ipinfo.io | jq '.city, .region, .country, .loc'

  echo -e "${GREEN}✅ Ноду встановлено та запущено!${NC}"
  exit 0
}

# Функція для запуску ноди
start_node() {
  docker-compose exec blockcastd blockcastd init
}

# Функція для зупинки ноди
stop_node() { 
  cd beacon-docker-compose 
  docker-compose down
}

# Функція для перевірки логів
check_logs() {
  docker logs blockcastd
}

# Функція для видалення ноди
uninstall_node() {
  cd beacon-docker-compose
  docker-compose down
  docker-compose rm -f
  rm -rf beacon-docker-compose
}

# Основний код програми
case "$1" in
  install)
    install_node
    ;;
  start)
    start_node
    ;;
  stop)
    stop_node
    ;;
  logs)
    check_logs
    ;;
  uninstall)
    uninstall_node
    ;;
  *)
    echo "Неправильне використання. Використовуйте: $0 {install|start|stop|logs|uninstall}"
    exit 1
    ;;
esac

