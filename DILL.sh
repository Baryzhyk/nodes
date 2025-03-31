#!/bin/bash

# Перевірка наявності необхідних утиліт, встановлення якщо відсутні
if ! command -v figlet &> /dev/null; then
    echo "figlet не знайдено. Встановлюємо..."
    sudo apt update && sudo apt install -y figlet
fi

if ! command -v whiptail &> /dev/null; then
    echo "whiptail не знайдено. Встановлюємо..."
    sudo apt update && sudo apt install -y whiptail
fi

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

# Вивід меню
CHOICE=$(whiptail --title "Меню дій" \
    --menu "Оберіть дію:" 15 60 5 \
    "1" "Встановити ноду" \
    "2" "Перевірити роботу ноди" \
    "3" "Показати публічний ключ" \
    "4" "Зупинити ноду" \
    "5" "Перезапустити ноду" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1)
        echo -e "${GREEN}Встановлення ноди...${NC}"
        sudo apt update && sudo apt install -y curl
        curl -sO https://raw.githubusercontent.com/DillLabs/launch-dill-node/main/dill.sh && chmod +x dill.sh && ./dill.sh
        ;;

    2)
        echo -e "${GREEN}Перевірка роботи ноди...${NC}"
        cd ~/dill && ./health_check.sh -v
        ;;

    3)
        echo -e "${GREEN}Ваш публічний ключ:${NC}"
        cd ~/dill && ./show_pubkey.sh
        ;;

    4)
        echo -e "${GREEN}Зупинка ноди...${NC}"
        cd ~/dill && ./stop_dill_node.sh
        ;;

    5)
        echo -e "${GREEN}Перезапуск ноди...${NC}"
        cd ~/dill && ./start_dill_node.sh
        ;;

    *)
        echo -e "${RED}Невірний вибір. Завершення програми.${NC}"
        ;;
esac
