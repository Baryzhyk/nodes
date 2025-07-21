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

install_node() {
  echo -e "${PINK}Оновлення системи...${NC}"
  apt update && apt upgrade -y
  apt install -y curl

  # Перевірка Node.js
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo -e "${RED}Node.js не знайдено. Встановлюємо...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt install -y nodejs
    echo -e "${GREEN}Node.js встановлено: $(node -v), npm: $(npm -v)${NC}"
  else
    echo -e "${GREEN}Node.js вже встановлено: $(node -v), npm: $(npm -v)${NC}"
  fi

  # Встановлення synchronizer-cli
  echo -e "${PINK}Встановлення synchronizer-cli...${NC}"
  npm install -g synchronizer-cli

  # Перевірка Docker
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker не знайдено. Встановлюємо...${NC}"
    synchronize install-docker
    synchronize fix-docker
  else
    echo -e "${GREEN}Docker вже встановлено: $(docker --version)${NC}"
  fi

  echo -e "${PINK}Ініціалізація ноди...${NC}"
  synchronize init

  echo -e "${PINK}Налаштування як systemd-сервіс...${NC}"
  synchronize service
  synchronize service-web
  cp ~/.synchronizer-cli/*.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable synchronizer-cli synchronizer-cli-web
  systemctl start synchronizer-cli synchronizer-cli-web

  echo -e "${GREEN}✅ Ноду встановлено та запущено!${NC}"
  exit 0
}

start_node() {
  systemctl daemon-reload
  systemctl enable synchronizer-cli synchronizer-cli-web
  systemctl start synchronizer-cli synchronizer-cli-web
  echo -e "${GREEN}Ноду запущено!${NC}"
  exit 0
}

stop_node() {
  systemctl stop synchronizer-cli synchronizer-cli-web
  echo -e "${RED}Ноду зупинено!${NC}"
  exit 0
}

check_logs() {
  echo -e "${GREEN}Показ логів ноди:${NC}"
  journalctl -u synchronizer-cli -f
  exit 0
}

check_points() {
  echo -e "${PINK}Ваші поінти:${NC}"
  synchronize points
  exit 0
}

animate_loading

# Меню
CHOICE=$(whiptail --title "Меню Synchronizer CLI" \
  --menu "Оберіть дію:" 18 60 6 \
  "1" "Встановити ноду" \
  "2" "Запустити ноду" \
  "3" "Зупинити ноду" \
  "4" "Перевірити логи" \
  "5" "Перевірити поінти" \
  "6" "Вийти" 3>&1 1>&2 2>&3)

case $CHOICE in
  1) install_node ;;
  2) start_node ;;
  3) stop_node ;;
  4) check_logs ;;
  5) check_points ;;
  6) echo "Вихід..."; exit 0 ;;
  *) echo "Невірний вибір." ; exit 1 ;;
esac
