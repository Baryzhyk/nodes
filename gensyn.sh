#!/bin/bash

# Перевірка на root
if [ "$EUID" -ne 0 ]; then
  echo "Будь ласка, запустіть скрипт з правами root (sudo)"
  exit 1
fi

# Завантаження логотипу
bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)

# Визначення кольорів
GREEN="\e[32m"
PINK="\e[35m"
RED="\e[31m"
NC="\e[0m"

# --- Функції ---
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

get_role_with_gswarm() {
    echo "=== [1/5] Встановлюємо залежності ==="
    apt update
    apt install -y wget curl nano

    echo "=== [2/5] Встановлюємо Go 1.23.10 ==="
    cd /tmp
    wget -q https://go.dev/dl/go1.23.10.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.23.10.linux-amd64.tar.gz

    if ! grep -q '/usr/local/go/bin' ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
    fi
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

    echo "Версія Go:"
    go version

    echo "=== [3/5] Встановлюємо GSwarm ==="
    go install github.com/Deep-Commit/gswarm/cmd/gswarm@latest

    echo "gswarm встановлено за шляхом: $(which gswarm)"

    echo "=== [4/5] Перевіряємо gswarm ==="
    gswarm --help || { echo 'Помилка встановлення gswarm!'; exit 2; }

    echo "=== [5/5] Запускаємо майстер налаштування (введіть параметри Telegram-бота) ==="
    sleep 1
    gswarm

    echo "=== ✅ Отримання ролі завершено! ==="
}

# (інші функції: download_node, launch_node, тощо - залишаються без змін)

# --- Основне виконання скрипта ---
animate_loading

CHOICE=$(whiptail --title "Меню дій" \
    --menu "Оберіть дію:" 20 60 8 \
    "1" "Встановити ноду" \
    "2" "Запустити/Перезапустити ноду" \
    "3" "Перейти до screen ноди" \
    "4" "Показати дані користувача" \
    "5" "Перевірити встановлені моделі" \
    "6" "Оновити ноду" \
    "7" "Отримати роль" \
    "8" "Видалити ноду" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1) echo "Ви обрали: Встановити ноду"; download_node ;;
    2) echo "Ви обрали: Запустити/Перезапустити ноду"; launch_node ;;
    3) echo "Ви обрали: Перейти до screen ноди"; go_to_screen ;;
    4) echo "Ви обрали: Показати дані користувача"; userdata ;;
    5) echo "Ви обрали: Перевірити встановлені моделі"; update_node ;;
    6) echo "Ви обрали: Оновити ноду"; update_node ;;
    7) echo "Ви обрали: Отримати роль"; get_role_with_gswarm ;;
    8) echo "Ви обрали: Видалити ноду"; delete_node ;;
    *) echo "Скасовано." ;;
esac
