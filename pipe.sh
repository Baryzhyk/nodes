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

}

# Виклик функції анімації
animate_loading
echo ""

# Функція для встановлення ноди
install_node() {
    echo -e "${BLUE}Починаємо встановлення ноди...${NC}"

    # Оновлення та встановлення залежностей
    install_dependencies

    # Створення каталогу для кешу та перехід до нього
    mkdir -p ~/pipe/download_cache
    cd ~/pipe

    # Завантаження файлу pop
    wget https://dl.pipecdn.app/v0.2.8/pop

    # Робимо файл виконуваним
    chmod +x pop

    # Створення нової сесії у screen
    screen -S pipe2 -dm

    echo -e "${YELLOW}Введіть вашу публічну адресу Solana:${NC}"
    read SOLANA_PUB_KEY
    
    # Запит значення для RAM
    echo -e "${YELLOW}Введіть кількість RAM у ГБ (ціле число):${NC}"
    read RAM
    
    # Запит значення для max-disk
    echo -e "${YELLOW}Введіть кількість max-disk у ГБ (ціле число):${NC}"
    read DISK
    
    # Запуск команди з параметрами, з вказанням публічного ключа Solana, RAM і max-disk
    screen -S pipe2 -X stuff "./pop --ram $RAM --max-disk $DISK --cache-dir ~/pipe/download_cache --pubKey $SOLANA_PUB_KEY\n"
    sleep 3
    screen -S pipe2 -X stuff "e4313e9d866ee3df\n"

    echo -e "${GREEN}Процес встановлення та запуску завершено!${NC}"
}

# Функція для перевірки статусу ноди
check_status() {
    echo -e "${BLUE}Перевірка статусу ноди...${NC}"
    
    cd pipe
    ./pop --status
    cd ..
}

# Функція для перевірки поінтів ноди
check_points() {
    echo -e "${BLUE}Перевірка поінтів ноди...${NC}"

    cd pipe
    
    ./pop --points
    
    cd ..
}

update_node() {
    echo -e "${BLUE}Оновлення до версії 0.2.8...${NC}"

    # Зупинка процесу pop
    echo -e "${YELLOW}Зупиняємо службу pipe-pop...${NC}"
    ps aux | grep '[p]op' | awk '{print $2}' | xargs kill

    # Перехід до каталогу pipe
    cd ~/pipe

    # Видалення старої версії pop
    echo -e "${YELLOW}Видаляємо стару версію pop...${NC}"
    rm -f pop

    # Завантаження нової версії pop
    echo -e "${YELLOW}Завантажуємо нову версію pop...${NC}"
    wget -O pop "https://dl.pipecdn.app/v0.2.8/pop"

    # Робимо файл виконуваним
    chmod +x pop

    # Перезавантаження системних служб
    sudo systemctl daemon-reload
    # Завершуємо сесію screen з ім'ям 'pipe2', якщо вона існує
    if screen -list | grep -q "pipe2"; then
    screen -S pipe2 -X quit
    fi
    sleep 2
    
    # Перезапуск сесії screen з ім'ям 'pipe2' і запуск pop
    screen -S pipe2 -dm ./pop
    
    sleep 5
    screen -S pipe2 -X stuff "y\n"
    
    echo -e "${GREEN}Оновлення завершено!${NC}"
}

# Функція для видалення ноди
remove_node() {
    echo -e "${BLUE}Видаляємо ноду...${NC}"

     pkill -f pop

    # Завершуємо сеанс screen з ім'ям 'pipe2' і видаляємо його
    screen -S pipe2 -X quit

    # Видалення файлів ноди
    sudo rm -rf ~/pipe

    echo -e "${GREEN}Нода успішно видалена!${NC}"
}

# Головне меню
CHOICE=$(whiptail --title "Меню дій" \
    --menu "Виберіть дію:" 15 50 6 \
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
