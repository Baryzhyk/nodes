#!/bin/bash

# Перевірка наявності необхідних утиліт, встановлення за необхідності
if ! command -v figlet &> /dev/null; then
    echo "figlet не знайдено. Встановлюємо..."
    sudo apt update && sudo apt install -y figlet
fi

if ! command -v whiptail &> /dev/null; then
    echo "whiptail не знайдено. Встановлюємо..."
    sudo apt update && sudo apt install -y whiptail
fi

# Визначення кольорів для зручності
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

# Завантаження та відображення логотипу
bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)

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

# Відображення меню дій
CHOICE=$(whiptail --title "Меню дій" \
    --menu "Оберіть дію:" 15 50 4 \
    "1" "Встановити ноду" \
    "2" "Перевірити статус ноди" \
    "3" "Видалити ноду" \
    "4" "Вийти з меню" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1)
        echo -e "${BLUE}Встановлюємо ноду...${NC}"

        sudo apt update && sudo apt upgrade -y
        rm -f ~/install.sh ~/update.sh ~/start.sh
        
        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/install.sh
        source ./install.sh

        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/update.sh
        source ./update.sh

        cd ~/multipleforlinux

        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/start.sh
        source ./start.sh

        echo -e "${YELLOW}Введіть ваш Account ID (унікальний ідентифікатор):${NC}"
        read IDENTIFIER
        echo -e "${YELLOW}Придумайте пароль:${NC}"
        read PIN

        multiple-cli bind --bandwidth-download 100 --identifier $IDENTIFIER --pin $PIN --storage 200 --bandwidth-upload 100

        echo -e "${PINK}-----------------------------------------------------------${NC}"
        echo -e "${YELLOW}Команда для перевірки статусу ноди:${NC}"
        echo "cd ~/multipleforlinux && ./multiple-cli status"
        echo -e "${PINK}-----------------------------------------------------------${NC}"
        echo -e "${GREEN}Встановлення завершено!${NC}"
        sleep 2
        cd ~/multipleforlinux && ./multiple-cli status
        ;;

    2)
        echo -e "${BLUE}Перевіряємо статус...${NC}"
        cd ~/multipleforlinux && ./multiple-cli status
        ;;

    3)
        echo -e "${BLUE}Видалення ноди...${NC}"
        pkill -f multiple-node
        sudo rm -rf ~/multipleforlinux
        echo -e "${GREEN}Ноду успішно видалено!${NC}"
        ;;
    
    4)
        echo -e "${CYAN}Вихід з програми.${NC}"
        exit 0
        ;;
    
    *)
        echo -e "${RED}Невірний вибір. Завершення програми.${NC}"
        ;;
esac
