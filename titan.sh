#!/bin/bash

# Функція для відображення логотипу
channel_logo() {
  echo -e '\033[0;31m'
  echo -e '┌┐ ┌─┐┌─┐┌─┐┌┬┐┬┬ ┬  ┌─┐┬ ┬┌┐ ┬┬  '
  echo -e '├┴┐│ ││ ┬├─┤ │ │└┬┘  └─┐└┬┘├┴┐││  '
  echo -e '└─┘└─┘└─┘┴ ┴ ┴ ┴ ┴   └─┘ ┴ └─┘┴┴─┘'
  echo -e '\e[0m'
  echo -e "\n\nПідпишись на найкращий канал у крипті @bogatiy_sybil [💸]"
}

# Функція для встановлення ноди
install_node() {
  echo -e "${BLUE}Розпочинаємо встановлення ноди...${NC}"
  
  if [ -d "$HOME/.titanedge" ]; then
    echo -e "${RED}Папка .titanedge вже існує. Видаліть ноду та встановіть знову.${NC}"
    return 0
  fi

  sudo apt update -y && sudo apt upgrade -y
  sudo apt install -y nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl lsof

  ports=(1234 55702 48710)
  for port in "${ports[@]}"; do
    if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
      echo -e "${RED}Помилка: порт $port зайнятий. Установка не можлива.${NC}"
      exit 1
    fi
  done

  echo -e "${GREEN}Всі порти вільні! Продовжуємо...${NC}"
  
  if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Встановлення Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
  else
    echo -e "${GREEN}Docker вже встановлено.${NC}"
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Встановлення Docker-Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  else
    echo -e "${GREEN}Docker-Compose вже встановлено.${NC}"
  fi

  echo -e "${CYAN}Необхідні залежності встановлені. Запустіть ноду через меню.${NC}"
}

# Функція для запуску ноди
launch_node() {
  echo -e "${BLUE}Запуск ноди...${NC}"
  
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker stop
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker rm

  echo -e "${YELLOW}Введіть ваш HASH:${NC}"
  read HASH

  docker run --network=host -d -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge
  sleep 10

  docker run --rm -it -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge bind --hash=$HASH https://api-test1.container1.titannet.io/api/v2/device/binding
  
  echo -e "${GREEN}Нода успішно запущена!${NC}"
}

# Функція для видалення ноди
remove_node() {
  echo -e "${BLUE}Видалення ноди...${NC}"

  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker stop
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker rm

  sudo rm -rf $HOME/.titanedge

  echo -e "${GREEN}Ноду успішно видалено!${NC}"
}

# Функція для перегляду логів
view_logs() {
  echo -e "${BLUE}Перегляд логів ноди...${NC}"
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker logs
}

# Функція для перезапуску ноди
restart_node() {
  echo -e "${BLUE}Перезапуск ноди...${NC}"
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker restart
  echo -e "${GREEN}Нода успішно перезапущена!${NC}"
}

# Функція для зупинки ноди
stop_node() {
  echo -e "${BLUE}Зупинка ноди...${NC}"
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | xargs -r docker stop
  echo -e "${GREEN}Нода зупинена!${NC}"
}

# Головне меню
while true; do
  channel_logo
  CHOICE=$(whiptail --title "Меню дій" \
    --menu "Оберіть дію:" 15 60 6 \
    "1" "🛠 Встановити ноду" \
    "2" "🚀 Запустити ноду" \
    "3" "📜 Переглянути логи" \
    "4" "🔄 Перезапустити ноду" \
    "5" "⛔ Зупинити ноду" \
    "6" "🗑 Видалити ноду" \
    "7" "❌ Вихід" \
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
      stop_node
      ;;
    6)
      remove_node
      ;;
    7)
      echo -e "${CYAN}Вихід з програми.${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Невірний вибір. Спробуйте ще раз.${NC}"
      ;;
  esac
done
