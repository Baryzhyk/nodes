#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Завантаження логотипу
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
        printf "\r${GREEN}Завантажуємо меню${NC}   "
        sleep 0.3
    done
    echo ""
}

# Дії
download_node() {
  echo 'Починаю встановлення вузла...'
  cd $HOME
  sudo apt install lsof -y

  ports=(4001)
  for port in "${ports[@]}"; do
    if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
      echo "Помилка: Порт $port зайнятий. Програма не зможе виконатись."
      exit 1
    fi
  done

  sudo apt-get update -y && sudo apt-get upgrade -y
  sudo apt install -y wget make tar screen nano unzip lz4 gcc git jq

  if screen -list | grep -q "drianode"; then
    screen -ls | grep drianode | cut -d. -f1 | awk '{print $1}' | xargs kill
  fi

  if [ -d "$HOME/.dria" ]; then
    dkn-compute-launcher uninstall
    sudo rm -rf .dria/
  fi

  curl -fsSL https://ollama.com/install.sh | sh
  curl -fsSL https://dria.co/launcher | bash

  source ~/.bashrc
  clear
  echo ' Введіть команду screen -S dria'
  echo 'Після цього запустіть вузол'
}

launch_node() {
  dkn-compute-launcher start
}

settings_node() {
  dkn-compute-launcher settings
}

node_points() {
  dkn-compute-launcher points
}

models_check() {
  dkn-compute-launcher info
}

delete_node() {
  dkn-compute-launcher uninstall
  if screen -list | grep -q "dria"; then
    screen -ls | grep dria | cut -d. -f1 | awk '{print $1}' | xargs kill
  fi
}

# Запуск
animate_loading

CHOICE=$(whiptail --title "Меню дій" \
    --menu "Оберіть дію:" 18 60 7 \
    "1" "Встановити ноду" \
    "2" "Запустити вузол" \
    "3" "Налаштування вузла" \
    "4" "Перевірити очки вузла" \
    "5" "Перевірити встановлені моделі" \
    "6" "Видалити вузол" \
    "7" "Вийти з програми" \
    3>&1 1>&2 2>&3)

case $CHOICE in
  1) download_node ;;
  2) launch_node ;;
  3) settings_node ;;
  4) node_points ;;
  5) models_check ;;
  6) delete_node ;;
  7) exit 0 ;;
  *) echo "Невірний вибір." ;;
esac
