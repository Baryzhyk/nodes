#!/bin/bash

# Оновлення системи перед налаштуванням
sudo apt update -y && sudo apt upgrade -y

# Перевірка наявності необхідних утиліт, встановлення, якщо відсутні
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

# Завантаження логотипу
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
