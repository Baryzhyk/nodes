#!/bin/bash

# Функція для завантаження та відображення логотипу
channel_logo() {
  bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)
  echo -e "\n\nПідпишись на найкращий крипто-канал @bogatiy_sybil [💸]\n"
}

# Функція для встановлення ноди
install_node() {
  echo -e "Розпочинаємо встановлення ноди...\n"

  if [ -d "$HOME/.titanedge" ]; then
    echo -e "Папка .titanedge вже існує. Видаліть ноду та встановіть знову."
    return 0
  fi

  sudo apt update -y && sudo apt upgrade -y
  sudo apt install -y nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl lsof

  ports=(1234 55702 48710)
  for port in "${ports[@]}"; do
    if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
      echo -e "Помилка: порт $port зайнятий. Установка неможлива."
      exit 1
    fi
  done

  echo -e "Всі порти вільні! Продовжуємо...\n"

  if ! command -v docker &> /dev/null; then
    echo -e "⬇Встановлення Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
  else
    echo -e "Docker вже встановлено."
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo -e "⬇Встановлення Docker-Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  else
    echo -e "Docker-Compose вже встановлено."
  fi

  echo -e "Всі залежності встановлено. Запустіть ноду через меню.\n"
}

# Функція для запуску ноди
launch_node() {
  echo -e "Запуск ноди...\n"

  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker stop
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker rm

  echo -e "Введіть ваш HASH:"
  read HASH

  docker run --network=host -d -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge
  sleep 10

  docker run --rm -it -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge bind --hash=$HASH https://api-test1.container1.titannet.io/api/v2/device/binding
  
  echo -e "Нода успішно запущена!\n"
}

# Функція для перегляду логів
view_logs() {
  echo -e "Перегляд логів ноди...\n"
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker logs
}

# Функція для перезапуску ноди
restart_node() {
  echo -e "Перезапуск ноди...\n"
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker restart
  echo -e "Нода успішно перезапущена!\n"
}

# Функція для видалення ноди
remove_node() {
  echo -e "🗑 Видалення ноди...\n"

  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker stop
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker rm

  sudo rm -rf $HOME/.titanedge

  echo -e "Ноду успішно видалено!\n"
}

# Головне меню
while true; do
  channel_logo
  CHOICE=$(whiptail --title "Меню керування нодою" \
    --menu "Оберіть дію:" 15 60 6 \
    "1" "Встановити ноду" \
    "2" "Запустити ноду" \
    "3" "Переглянути логи" \
    "4" "Перезапустити ноду" \
    "5" "Видалити ноду" \
    "6" "Вийти з скрипта" \
    3>&1 1>&2 2>&3)

  case $CHOICE in
    1)
      install_node
      ;;
    2)
      launch_node
      ;;
    3)
      view_logs
      ;;
    4)
      restart_node
      ;;
    5)
      remove_node
      ;;
    6)
      echo -e "Вихід з програми.\n"
      exit 0
      ;;
    *)
      echo -e "Невірний вибір. Спробуйте ще раз.\n"
      ;;
  esac
done
