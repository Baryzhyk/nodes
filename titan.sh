#!/bin/bash

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/Baryzhyk/nodes/refs/heads/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"
download_node() {
  if [ -d "$HOME/.titanedge" ]; then
    echo "Папка .titanedge уже существует. Удалите ноду и установите заново. Выход..."
    return 0
  fi

  sudo apt install lsof

  ports=(1234 55702 48710)

  for port in "${ports[@]}"; do
    if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
      echo "Ошибка: Порт $port занят. Программа не сможет выполниться."
      exit 1
    fi
  done

  echo -e "Все порты свободны! Сейчас начнется установка...\n"

  echo 'Начинаю установку...'

  cd $HOME

  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl -y

  if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
  else
    echo "Docker уже установлен. Пропускаем"
  fi

  if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  else
    echo "Docker-Compose уже установлен. Пропускаем"
  fi

  echo 'Необходимые зависимости были установлены. Запустите ноду 2 пунктом.'
}

launch_node() {
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
    docker stop "$container_id"
    docker rm "$container_id"
  done

  while true; do
    echo -en "Введите ваш HASH:${NC} "
    read HASH
    if [ ! -z "$HASH" ]; then
        break
    fi
    echo 'HASH не может быть пустым.'
  done

  docker run --network=host -d -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge
  sleep 10

  docker run --rm -it -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge bind --hash=$HASH https://api-test1.container1.titannet.io/api/v2/device/binding
  
  echo -e "Нода была запущена."
}

update_sysctl_config() {
    local CONFIG_VALUES="
net.core.rmem_max=26214400
net.core.rmem_default=26214400
net.core.wmem_max=26214400
net.core.wmem_default=26214400
"
    local SYSCTL_CONF="/etc/sysctl.conf"

    echo "Делаем резерв для sysctl.conf.bak..."
    sudo cp "$SYSCTL_CONF" "$SYSCTL_CONF.bak"

    echo "Обновляем sysctl.conf с новой конфигурацией..."
    echo "$CONFIG_VALUES" | sudo tee -a "$SYSCTL_CONF" > /dev/null

    echo "Применяем новые настройки..."
    sudo sysctl -p

    echo "Настройки обновились."

    if command -v setenforce &> /dev/null; then
        echo "Убираем SELinux..."
        sudo setenforce 0
    else
        echo "SELinux не установлен."
    fi
}

many_node() {
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
    docker stop "$container_id"
    docker rm "$container_id"
  done

  echo -e "Введите ваш HASH:"
  read -p "> " id

  update_sysctl_config

  storage_gb=50
  start_port=1235
  container_count=5

  public_ips=$(curl -s https://api.ipify.org)

  if [ -z "$public_ips" ]; then
    echo -e "Не смог получить IP адрес."
    exit 1
  fi

  docker pull nezha123/titan-edge

  current_port=$start_port
  for ip in $public_ips; do
      echo -e "Устанавливаем ноду на АЙПИ $ip"
  
      for ((i=1; i<=container_count; i++)); do
          storage_path="$HOME/titan_storage_${ip}_${i}"
  
          sudo mkdir -p "$storage_path"
          sudo chmod -R 777 "$storage_path"
  
          container_id=$(docker run -d --restart always -v "$storage_path:$HOME/.titanedge/storage" --name "titan_${ip}_${i}" --net=host nezha123/titan-edge)
  
          echo -e "Нода titan_${ip}_${i} запустилась с ID контейнером $container_id"
  
          sleep 30
  
          docker exec $container_id bash -c "\
              sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' $HOME/.titanedge/config.toml && \
              sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' $HOME/.titanedge/config.toml && \
              echo 'Хранилище titan_${ip}_${i} поставлена на $storage_gb GB, Порт поставлен на $current_port'"
  
          docker restart $container_id

          docker exec $container_id bash -c "\
              titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
          echo -e "Нода titan_${ip}_${i} была установлена."
  
          current_port=$((current_port + 1))
      done
  done
}

docker_logs() {
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
    docker logs "$container_id"
  done
}

restart_node() {
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
    docker restart "$container_id"
  done
  echo 'Нода была перезагружена.'
}

stop_node() {
  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
    docker stop "$container_id"
  done
  echo 'Нода была остановлена.'
}

delete_node() {
  read -p 'Если вы уверены удалить ноду, напишите любой символ (CTRL+C чтобы выйти): ' checkjust

  docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
    docker stop "$container_id"
    docker rm "$container_id"
  done

  sudo rm -r $HOME/.titanedge

  echo 'Нода была удалена.'
}

exit_from_script() {
  exit 0
}

while true; do
    channel_logo
    sleep 2
    echo -e "\n\nМеню:"
    echo "1. 🛠️ Установить ноду"
    echo "2. 🚀 Запустить ноду"
    echo "3. 📜 Проверить логи"
    echo "4. ✅ Поставить 5 нод"
    echo "5. 🔄 Перезагрузить ноду"
    echo "6. ⛔ Остановить ноду"
    echo "7. 🗑️ Удалить ноду"
    echo -e "8. ❌ Выйти из скрипта\n"
    read -p "Выберите пункт меню: " choice

    case $choice in
      1)
        download_node
        ;;
      2)
        launch_node
        ;;
      3)
        docker_logs
        ;;
      4)
        many_node
        ;;
      5)
        restart_node
        ;;
      6)
        stop_node
        ;;
      7)
        delete_node
        ;;
      8)
        exit_from_script
        ;;
      *)
        echo "Неверный пункт. Пожалуйста, выберите правильную цифру в меню."
        ;;
    esac
  done
