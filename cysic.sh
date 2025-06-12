#!/bin/bash

# Кольори
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

# Встановлення необхідних пакетів
echo -e "${GREEN}Перевірка та встановлення залежностей...${NC}"
sudo apt update -y &>/dev/null
for pkg in curl screen whiptail; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    echo -e "${PINK}Встановлюємо $pkg...${NC}"
    sudo apt install "$pkg" -y &>/dev/null
  fi
done

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

# Меню
CHOICE=$(whiptail --title "Меню керування Cysic" \
  --menu "Оберіть потрібну дію:" 20 70 10 \
    "1" "Встановити вузол" \
    "2" "Перевірити логи" \
    "3" "Оновити вузол" \
    "4" "Видалити вузол" \
  3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo -e "${RED}Скасовано. Вихід.${NC}"
  exit 1
fi

case $CHOICE in
  1)
    read -p "Вставте ваш адрес гаманця (0x...): " WALLET 
    curl -L https://github.com/cysic-labs/cysic-phase3/releases/download/v1.0.0/setup_linux.sh -o ~/setup_linux.sh
    bash ~/setup_linux.sh "$WALLET"

    cd ~/cysic-verifier/ || { echo -e "${RED}Помилка: не знайдено директорії cysic-verifier.${NC}"; exit 1; }
    screen -dmS cysic bash start.sh

    echo -e "${GREEN}✅ Встановлення завершено.${NC}"
    echo -e "${GREEN}ℹ️ Для перегляду логів: screen -r cysic${NC}"
    echo -e "${GREEN}🔚 Для виходу з екрану натисніть Ctrl+A, потім D${NC}"
    ;;

  2)
    screen -r cysic || echo -e "${RED}❌ Сесія не знайдена. Можливо вузол не запущено.${NC}"
    ;;

  3)
    echo -e "${PINK}Оновлення ще не реалізоване. Очікуйте.${NC}"
    ;;

  4)
    echo -e "${RED}🧹 Видаляємо вузол...${NC}"
    screen -XS cysic quit 2>/dev/null
    rm -rf ~/cysic-verifier ~/.cysic ~/setup_linux.sh
    echo -e "${GREEN}✅ Вузол повністю видалено.${NC}"
    ;;

  *)
    echo -e "${RED}Невірний вибір.${NC}"
    ;;
esac
