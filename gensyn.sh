#!/bin/bash

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

# Вибір дії користувачем
CHOICE=$(whiptail --title "Меню дій" \
    --menu "Оберіть дію:" 18 60 7 \
    "1" "Встановити ноду" \
    "2" "Запустити ноду" \
    "3" "Перейти до screen ноди" \
    "4" "Показати дані користувача" \
    "5" "Перевірити встановлені моделі" \
    "6" "Оновити ноду" \
    "7" "Видалити ноду" \
    3>&1 1>&2 2>&3)

# Обробка вибору користувача
case $CHOICE in
    1)
        echo "Ви обрали: Встановити ноду"
        download_node
        ;;
    2)
        echo "Ви обрали: Запустити ноду"
        launch_node
        ;;
    3)
        echo "Ви обрали: Перейти до screen ноди"
        go_to_screen
        ;;
    4)
        echo "Ви обрали: Показати дані користувача"
        userdata
        ;;
    5)
        echo "Ви обрали: Перевірити встановлені моделі"
        update_node
        ;;
    6)
        echo "Ви обрали: Оновити ноду"
        # Додайте сюди код для оновлення ноди
        ;;
    7)
        echo "Ви обрали: Видалити ноду"
        delete_node
        ;;
    *)
        echo "Скасовано."
        ;;
esac

download_node() {
  echo 'Встановлення ноди.'

  cd $HOME

  sudo apt install lsof

  ports=(4040 3000 42763)

  for port in "${ports[@]}"; do
    if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
      echo "Помилка: Порт $port зайнятий. Програма не зможе виконатись."
      exit 1
    fi
  done

  echo -e "Усі порти вільні! Зараз почнеться установка...\n"

  if [ -d "$HOME/rl-swarm" ]; then
    PID=$(netstat -tulnp | grep :3000 | awk '{print $7}' | cut -d'/' -f1)
    sudo kill $PID
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
  sudo apt install -y git curl wget build-essential python3 python3-venv python3-pip screen yarn net-tools

  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt install -y nodejs
  sudo apt update
  curl -sSL https://raw.githubusercontent.com/zunxbt/installation/main/node.sh | bash

  git clone https://github.com/zunxbt/rl-swarm.git
  cd rl-swarm

  python3 -m venv .venv
  source .venv/bin/activate

  pip install --upgrade pip

  echo "На вашому сервері встановлено тільки CPU? (якщо не знаєте, натисніть Y) (Y/N)"
  read answer

  if [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
    echo "Налаштовуємо PyTorch для використання тільки CPU..."
    export PYTORCH_ENABLE_MPS_FALLBACK=1
    export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
    sed -i 's/torch\.device("mps" if torch\.backends\.mps\.is_available() else "cpu")/torch.device("cpu")/g' hivemind_exp/trainer/hivemind_grpo_trainer.py
    echo "Команди виконано."
  else
    echo "Пропускаємо налаштування, залишаємо як є."
  fi

  if screen -list | grep -q "gensynnode"; then
    screen -ls | grep gensynnode | cut -d. -f1 | awk '{print $1}' | xargs kill
  fi

  echo 'Слідуйте далі гайду.'
}

launch_node() {
  cd $HOME

  cd rl-swarm
  source .venv/bin/activate

  if screen -list | grep -q "gensynnode"; then
    screen -ls | grep gensynnode | cut -d. -f1 | awk '{print $1}' | xargs kill
  fi

  screen -S gensynnode -d -m bash -c "trap '' INT; bash run_rl_swarm.sh 2>&1 | tee $HOME/rl-swarm/gensynnode.log"
}

watch_logs() {
  echo "Перегляд логів (Ctrl+C для повернення в меню)..."
  trap 'echo -e "\nПовернення в меню..."; return' SIGINT
  tail -n 100 -f $HOME/rl-swarm/gensynnode.log
}

go_to_screen() {
  echo 'ВИХІД З ЛОГІВ ЧЕРЕЗ CTRL+A + D'
  sleep 2

  screen -r gensynnode
}

open_local_server() {
  npm install -g localtunnel

  SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.co/ip || dig +short myip.opendns.com @resolver1.opendns.com)

  echo "IP-адреса вашого сервера: $SERVER_IP. Це правильний IP? (y/n)"
  read -r CONFIRM
  
  if [[ $CONFIRM == "y" ]]; then
      echo "IP підтверджено: $SERVER_IP"
  else
      echo "Введіть ваш IP-адресу:"
      read -r SERVER_IP
      echo "Ви ввели IP: $SERVER_IP"
  fi

  ssh -L 3000:localhost:3000 root@${SERVER_IP}
  lt --port 3000
}

userdata() {
  cd $HOME
  cat ~/rl-swarm/modal-login/temp-data/userData.json
}

userapikey() {
  cd $HOME
  cat ~/rl-swarm/modal-login/temp-data/userApiKey.json
}

update_node() {
  cd $HOME
  cd ~/rl-swarm
  git fetch origin
  git reset --hard origin/main
  git pull origin main

  echo 'Нода була оновлена.'
}

stop_node() {
  if screen -list | grep -q "gensynnode"; then
    screen -ls | grep gensynnode | cut -d. -f1 | awk '{print $1}' | xargs kill
  fi

  PID=$(netstat -tulnp | grep :3000 | awk '{print $7}' | cut -d'/' -f1)
  sudo kill $PID

  echo 'Нода була зупинена.'
}

delete_node() {
  cd $HOME

  if screen -list | grep -q "gensynnode"; then
    screen -ls | grep gensynnode | cut -d. -f1 | awk '{print $1}' | xargs kill
  fi

  PID=$(netstat -tulnp | grep :3000 | awk '{print $7}' | cut -d'/' -f1)
  sudo kill $PID
  sudo rm -rf rl-swarm/

  echo 'Нода була видалена.'
}

exit_from_script() {
  exit 0
}
