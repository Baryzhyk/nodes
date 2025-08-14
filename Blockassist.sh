#!/bin/bash

# Кольори для виводу
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
GOLD='\033[38;5;220m'
NC='\033[0m' # Без кольору

echo -e "${GOLD}=== Починаємо встановлення ===${NC}"

# Оновлення системи та встановлення Firefox
echo -e "${YELLOW}Оновлюємо систему та встановлюємо Firefox...${NC}"
sudo apt update
sudo apt install firefox -y

# Створення ярлика Firefox на робочому столі
echo -e "${YELLOW}Створюємо ярлик Firefox на робочому столі...${NC}"
cp /usr/share/applications/firefox.desktop ~/Desktop/
chmod +x ~/Desktop/firefox.desktop

# Клонування репозиторію blockassist
echo -e "${YELLOW}Клонуємо репозиторій blockassist...${NC}"
cd ~
git clone https://github.com/gensyn-ai/blockassist.git
cd blockassist
./setup.sh

# Встановлення pyenv
echo -e "${YELLOW}Встановлюємо pyenv...${NC}"
curl -fsSL https://pyenv.run | bash

# Додавання pyenv у PATH
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Додавання pyenv у ~/.bashrc
echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc

# Встановлення залежностей для компіляції Python
echo -e "${YELLOW}Встановлюємо залежності для компіляції Python...${NC}"
sudo apt update
sudo apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# Встановлення додаткових утиліт
echo -e "${YELLOW}Встановлюємо додаткові утиліти...${NC}"
sudo apt install -y zip unzip wget

# Встановлення Python 3.10
echo -e "${YELLOW}Встановлюємо Python 3.10...${NC}"
pyenv install 3.10
pyenv global 3.10

# Встановлення pip-пакетів
echo -e "${YELLOW}Встановлюємо необхідні Python-пакети...${NC}"
pip install psutil readchar

# Встановлення Node.js 20
echo -e "${YELLOW}Встановлюємо Node.js 20...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Перевірка версії Node.js
echo -e "${GREEN}Версія Node.js:${NC}"
node --version

# Встановлення Java для Minecraft/Malmo
echo -e "${YELLOW}Встановлюємо Java...${NC}"
sudo apt install -y openjdk-8-jdk

# Виконуємо source ~/.bashrc автоматично
source ~/.bashrc

# Вивід фінальної команди
echo -e "${GREEN}=== Встановлення завершено! ===${NC}"
echo -e "${YELLOW}Для запуску BlockAssist використовуйте команду:${NC}"
echo -e "${GREEN}cd ~/blockassist && python run.py${NC}"
