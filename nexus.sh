#!/bin/bash
set -e

# --- Кольори ---
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

# --- Відображення логотипу ---
bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)

# --- Анімація ---
animate_loading() {
    for ((i = 1; i <= 3; i++)); do
        printf "\r${GREEN}Завантажуємо меню${NC}."
        sleep 0.3
        printf "\r${GREEN}Завантажуємо меню${NC}.."
        sleep 0.3
        printf "\r${GREEN}Завантажуємо меню${NC}..."
        sleep 0.3
    done
    echo ""
}

animate_loading

# --- Перевірка whiptail ---
if ! command -v whiptail &>/dev/null; then
    echo -e "${RED}whiptail не знайдено. Встановлюємо...${NC}"
    sudo apt update && sudo apt install -y whiptail
fi

# --- Функція: Встановлення Docker ---
install_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${PINK}Docker не знайдено. Встановлюємо...${NC}"
        sudo apt update
        sudo apt install -y curl ca-certificates apt-transport-https gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
            | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo \
          "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
           https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
           $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
          | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        echo -e "${GREEN}✔ Docker встановлено${NC}"
    else
        echo -e "${GREEN}✔ Docker вже встановлено (${NC}$(docker --version)${GREEN})${NC}"
    fi
}

# --- Функція: Встановлення Docker Compose ---
install_docker_compose() {
    if ! command -v docker-compose &>/dev/null; then
        echo -e "${PINK}Docker Compose не знайдено. Встановлюємо...${NC}"
        sudo apt update && sudo apt install -y wget jq

        COMPOSE_VER=$(wget -qO- https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name")

        sudo wget -O /usr/local/bin/docker-compose \
            "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)"
        sudo chmod +x /usr/local/bin/docker-compose

        DOCKER_CLI_PLUGINS=${DOCKER_CLI_PLUGINS:-"$HOME/.docker/cli-plugins"}
        mkdir -p "$DOCKER_CLI_PLUGINS"
        curl -fsSL \
            "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" \
            -o "${DOCKER_CLI_PLUGINS}/docker-compose"
        chmod +x "${DOCKER_CLI_PLUGINS}/docker-compose"

        echo -e "${GREEN}✔ Docker Compose ${COMPOSE_VER} встановлено${NC}"
    else
        echo -e "${GREEN}✔ Docker Compose вже встановлено (${NC}$(docker-compose --version)${GREEN})${NC}"
    fi
}

# --- Функція: Встановлення вузла ---
install_node() {
    install_docker
    install_docker_compose
    sudo apt install -y screen

    docker pull nexusxyz/nexus-cli:latest

    read -p "Вставте ваш node id: " PRIVATE_KEY

    screen -S nexus -dm bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $PRIVATE_KEY"
    echo -e "${GREEN}✅ Вузол встановлено.${NC}"
    echo -e "${GREEN}➡ Для перегляду логів: screen -r nexus${NC}"
    echo -e "${GREEN}↩ Для виходу з логів: Ctrl+A, потім D${NC}"
}

# --- Функція: Перезапуск вузла ---
restart_node() {
    echo -e "${RED}♻ Перезапуск вузла...${NC}"
    screen -XS nexus quit 2>/dev/null
    docker stop nexus 2>/dev/null || true
    docker rm nexus 2>/dev/null || true

    read -p "Вставте ваш node id: " PRIVATE_KEY

    screen -S nexus -dm bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $PRIVATE_KEY"
    echo -e "${GREEN}✅ Вузол перезапущено.${NC}"
}

# --- Функція: Видалення вузла ---
delete_node() {
    echo -e "${RED}🗑 Видаляємо вузол...${NC}"
    screen -XS nexus quit 2>/dev/null
    docker stop nexus 2>/dev/null || true
    docker rm nexus 2>/dev/null || true
    docker rmi nexusxyz/nexus-cli:latest 2>/dev/null || true
    echo -e "${GREEN}✅ Вузол повністю видалено.${NC}"
}

# --- Головне меню ---
CHOICE=$(whiptail --title "Меню керування Nexus" \
  --menu "Оберіть дію:" 20 60 10 \
  "1" "Встановити ноду" \
  "2" "Переглянути логи" \
  "3" "Перезапустити ноду" \
  "4" "Видалити ноду" \
  3>&1 1>&2 2>&3)

# --- Обробка вибору ---
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Скасовано. Вихід.${NC}"
  exit 1
fi

case $CHOICE in
  1) install_node ;;
  2)
    screen -r nexus || echo -e "${RED}❌ Сесія не знайдена. Можливо вузол не запущено.${NC}"
    ;;
  3) restart_node ;;
  4) delete_node ;;
  *) echo -e "${RED}Невідома опція.${NC}" ;;
esac
