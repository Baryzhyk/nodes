#!/bin/bash

# Оновлюємо систему перед налаштуванням...
sudo apt update -y && sudo apt upgrade -y

# Перевірка наявності необхідних утиліт, встановлення якщо відсутні
if ! command -v figlet &> /dev/null; then
    echo "figlet не знайдено. Встановлюємо..."
    sudo apt update && sudo apt install -y figlet
fi

if ! command -v whiptail &> /dev/null; then
    echo "whiptail не знайдено. Встановлюємо..."
    sudo apt update && sudo apt install -y whiptail
fi

# Визначаємо кольори для зручності
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

install_dependencies() {
    echo -e "${GREEN}Встановлюємо необхідні пакети...${NC}"
    sudo apt update && sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip screen
}

# Відображення логотипу
wget -qO- https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh | bash

# Вивід привітального тексту за допомогою figlet
echo -e "${PINK}$(figlet -w 150 -f standard "Softs by Gentleman")${NC}"
echo -e "${PINK}$(figlet -w 150 -f standard "x WESNA")${NC}"

# Функція анімації завантаження
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

# Виклик функції анімації
animate_loading
echo ""

# Основне меню
CHOICE=$(whiptail --title "Меню дій" \
    --menu "Оберіть дію:" 15 50 6 \
    "1" "Встановлення ноди" \
    "2" "Перевірка статусу ноди" \
    "3" "Перевірка поінтів ноди" \
    "4" "Видалення ноди" \
    "5" "Оновлення ноди" \
    "6" "Вихід" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1) 
        install_node
        ;;
    2) 
        check_status
        ;;
    3) 
        check_points
        ;;
    4) 
        remove_node
        ;;
    5)
        update_node
        ;;
    6)
        echo -e "${CYAN}Вихід з програми.${NC}"
        ;;
    *)
        echo -e "${RED}Невірний вибір. Завершення програми.${NC}"
        ;;
esac
