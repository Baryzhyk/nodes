#!/bin/bash

# Перевірка на root
if [ "$EUID" -ne 0 ]; then
  echo "Будь ласка, запустіть скрипт з правами root (sudo)"
  exit 1
fi

# Завантаження логотипу
bash <(curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh)

# Кольори
GREEN="\e[32m"
NC="\e[0m"

# --- Анімація ---
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

# --- Функції дій ---
get_role_with_gswarm() {
  echo "=== [1/5] Встановлюємо залежності ==="
  apt update && apt install -y wget curl nano

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

  echo "=== [5/5] Запускаємо майстер налаштування ==="
  sleep 1
  gswarm
  echo "=== ✅ Отримання ролі завершено! ==="
}

download_node() {
  echo '🔧 Встановлення ноди...'

  cd $HOME
  apt install -y lsof

  ports=(4040 42763)
  for port in "${ports[@]}"; do
    if lsof -i :"$port" &>/dev/null; then
      echo "❌ Порт $port зайнятий."
      exit 1
    fi
  done

  echo "✅ Порти вільні, триває встановлення..."

  [ -d "$HOME/rl-swarm" ] && {
    PID=$(netstat -tulnp | grep :3000 | awk '{print $7}' | cut -d'/' -f1)
    kill "$PID" 2>/dev/null || true
    rm -rf rl-swarm/
  }

  TARGET_SWAP_GB=32
  CURRENT_SWAP_KB=$(free -k | awk '/Swap:/ {print $2}')
  CURRENT_SWAP_GB=$((CURRENT_SWAP_KB / 1024 / 1024))

  if [ "$CURRENT_SWAP_GB" -lt "$TARGET_SWAP_GB" ]; then
    swapoff -a
    sed -i '/swap/d' /etc/fstab
    fallocate -l ${TARGET_SWAP_GB}G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "vm.swappiness = 10" >> /etc/sysctl.conf
    sysctl -p
  fi

  apt update -y && apt upgrade -y
  apt install -y git curl wget build-essential python3 python3-venv python3-pip screen yarn net-tools gnupg

  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt update -y && apt install -y nodejs

  git clone https://github.com/gensyn-ai/rl-swarm
  cd rl-swarm
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements-cpu.txt
  pip install --upgrade pip

  export PYTORCH_ENABLE_MPS_FALLBACK=1
  export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
  sed -i 's/torch\.device("mps" if torch\.backends\.mps\.is_available() else "cpu")/torch.device("cpu")/g' hivemind_exp/trainer/hivemind_grpo_trainer.py

  screen -S gensynnode -X quit 2>/dev/null || true
  echo '✅ Встановлення завершено.'
}

launch_node() {
  cd $HOME/rl-swarm
  source .venv/bin/activate
  screen -S gensynnode -X quit 2>/dev/null || true
  screen -S gensynnode -d -m bash -c "trap '' INT; bash run_rl_swarm.sh 2>&1 | tee $HOME/rl-swarm/gensynnode.log"
  echo "🚀 Нода запущена у screen 'gensynnode'"
}

go_to_screen() {
  echo '📺 Щоб вийти з логів: CTRL + A, потім D'
  sleep 2
  screen -r gensynnode
}

userdata() {
  [ -f "$HOME/rl-swarm/modal-login/temp-data/userData.json" ] && cat "$HOME/rl-swarm/modal-login/temp-data/userData.json" || echo "Дані не знайдено"
}

update_node() {
  cd ~/rl-swarm
  git fetch origin
  git reset --hard origin/main
  git pull origin main
  echo '🔄 Нода оновлена.'
}

delete_node() {
  screen -S gensynnode -X quit 2>/dev/null || true
  rm -rf ~/rl-swarm
  echo "🗑️ Нода видалена."
}

check_models() {
  echo "📦 Встановлені моделі:"
  ls ~/rl-swarm/models 2>/dev/null || echo "Моделі не знайдено."
}

# --- Меню ---
animate_loading

CHOICE=$(whiptail --title "Меню дій" \
  --menu "Оберіть дію:" 20 60 10 \
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
  5) echo "Ви обрали: Перевірити встановлені моделі"; check_models ;;
  6) echo "Ви обрали: Оновити ноду"; update_node ;;
  7) echo "Ви обрали: Отримати роль"; get_role_with_gswarm ;;
  8) echo "Ви обрали: Видалити ноду"; delete_node ;;
  *) echo "❌ Скасовано." ;;
esac
