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

# Меню
CHOICE=$(whiptail --title "Меню керування Datagram Node" \
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
    echo -e "${GREEN}Перевірка та встановлення залежностей...${NC}"
    sudo apt update -y &>/dev/null
    for pkg in curl screen whiptail wget; do
      if ! dpkg -s "$pkg" &>/dev/null; then
        echo -e "${PINK}Встановлюємо $pkg...${NC}"
        sudo apt install "$pkg" -y &>/dev/null
      fi
    done

    read -p "Введіть License Key: " WALLET

    mkdir -p ~/datagram && cd ~/datagram || exit
    wget -q https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux
    chmod +x datagram-cli-x86_64-linux

    echo -e "${GREEN}Запускаємо ноду у screen-сесії 'datagram_node'...${NC}"
    screen -dmS datagram_node bash -c "./datagram-cli-x86_64-linux run -- -key $WALLET"

    echo -e "${GREEN}✅ Встановлення завершено.${NC}"
    echo -e "${GREEN}➡️ Щоб переглянути лог: screen -r datagram_node${NC}"
    echo -e "${GREEN}➡️ Для виходу з screen: Ctrl+A, потім D${NC}"
    ;;
    
  2)
    echo -e "${GREEN}Показ логів ноди:${NC}"
    screen -r datagram_node
    ;;

  3)
    echo -e "${PINK}Починаємо оновлення вузла...${NC}"
    cd ~/datagram || exit
    wget -q https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux -O datagram-cli-x86_64-linux
    chmod +x datagram-cli-x86_64-linux
    screen -S datagram_node -X quit
    screen -dmS datagram_node bash -c "./datagram-cli-x86_64-linux run -- -key $WALLET"
    echo -e "${GREEN}✅ Оновлено та перезапущено.${NC}"
    ;;

  4)
    echo -e "${RED}Видаляємо вузол...${NC}"
    screen -S datagram_node -X quit
    rm -rf ~/datagram
    echo -e "${GREEN}✅ Вузол видалено.${NC}"
    ;;

  *)
    echo -e "${RED}Невідома опція.${NC}"
    ;;
esac
