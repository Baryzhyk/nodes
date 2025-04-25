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

download_node() {
    echo 'Встановлення ноди.'

    cd $HOME

    sudo apt install -y lsof

    ports=(4040 42763)

    for port in "${ports[@]}"; do
        if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
            echo "Помилка: Порт $port зайнятий. Програма не зможе виконатись."
            exit 1
        fi
    done

    echo -e "Усі порти вільні! Зараз почнеться установка...\n"

    if [ -d "$HOME/rl-swarm" ]; then
        PID=$(netstat -tulnp | grep :3000 | awk '{print $7}' | cut -d'/' -f1)
        sudo kill $PID 2>/dev/null
        sudo rm -rf rl-swarm/
    fi

    TARGET_SWAP_GB=32
    CURRENT_SWAP_KB=$(free -k | awk '/Swap:/ {print $2}')
    CURRENT_SWAP_GB=$((CURRENT_SWAP_KB / 1024 / 1024))

    echo "Поточний розмір Swap: ${CURRENT_SWAP_GB}GB"
    if [ "$CURRENT_SWAP_GB" -lt "$TARGET_SWAP_GB" ]; then
        swapoff -a
        sed -i '/swap/d' /etc/fstab
        SWAPFILE=/swapfile
        fallocate -l ${TARGET_SWAP_GB}G $SWAPFILE
        chmod 600 $SWAPFILE
        mkswap $SWAPFILE
        swapon $SWAPFILE
        echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
        echo "vm.swappiness = 10" >> /etc/sysctl.conf
        sysctl -p
        echo "Swap був встановлений на ${TARGET_SWAP_GB}GB"
    fi

    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y git curl wget build-essential python3 python3-venv python3-pip screen yarn net-tools gnupg

    # Додавання репозиторіїв Yarn і Node.js
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

    sudo apt update -y
    sudo apt install -y nodejs

    curl -sSL https://raw.githubusercontent.com/zunxbt/installation/main/node.sh | bash

    git clone https://github.com/zunxbt/rl-swarm.git
    cd rl-swarm

    python3 -m venv .venv
    source .venv/bin/activate

    pip install --upgrade pip

        export PYTORCH_ENABLE_MPS_FALLBACK=1
        export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
        sed -i 's/torch\.device("mps" if torch\.backends\.mps\.is_available() else "cpu")/torch.device("cpu")/g' hivemind_exp/trainer/hivemind_grpo_trainer.py
      
    if screen -list | grep -q "gensynnode"; then
        screen -ls | grep gensynnode | cut -d. -f1 | awk '{print $1}' | xargs kill
    fi
    echo 'Встановлення завершено'
}

launch_node() {
    cd $HOME/rl-swarm
    source .venv/bin/activate

    if screen -list | grep -q "gensynnode"; then
        screen -ls | grep gensynnode | cut -d. -f1 | awk '{print $1}' | xargs kill
    fi

    screen -S gensynnode -d -m bash -c "trap '' INT; bash run_rl_swarm.sh 2>&1 | tee $HOME/rl-swarm/gensynnode.log"
}

go_to_screen() {
    echo 'ВИХІД З ЛОГІВ ЧЕРЕЗ CTRL+A + D'
    sleep 2
    screen -r gensynnode
}

userdata() {
    cd $HOME
    cat ~/rl-swarm/modal-login/temp-data/userData.json
}

update_node() {
    cd ~/rl-swarm
    git fetch origin
    git reset --hard origin/main
    git pull origin main
    echo 'Нода була оновлена.'
}

delete_node() {
    cd $HOME

    if screen -list | grep -q "gensynnode"; then
        screen -ls | grep gensynnode | cut -d. -f1 | awk '{print $1}' | xargs kill
    fi

    sudo rm -rf rl-swarm/
    echo "Нода видалена."
}

# --- Основне виконання скрипта ---
animate_loading

CHOICE=$(whiptail --title "Меню дій" \
    --menu "Оберіть дію:" 18 60 7 \
    "1" "Встановити ноду" \
    "2" "Запустити/Перезапустити ноду" \
    "3" "Перейти до screen ноди" \
    "4" "Показати дані користувача" \
    "5" "Перевірити встановлені моделі" \
    "6" "Оновити ноду" \
    "7" "Видалити ноду" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1) echo "Ви обрали: Встановити ноду"; download_node ;;
    2) echo "Ви обрали: Запустити/Перезапустити ноду"; launch_node ;;
    3) echo "Ви обрали: Перейти до screen ноди"; go_to_screen ;;
    4) echo "Ви обрали: Показати дані користувача"; userdata ;;
    5) echo "Ви обрали: Перевірити встановлені моделі"; update_node ;;
    6) echo "Ви обрали: Оновити ноду"; update_node ;;
    7) echo "Ви обрали: Видалити ноду"; delete_node ;;
    *) echo "Скасовано." ;;
esac
