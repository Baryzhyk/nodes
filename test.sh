
channel_logo() {
  echo -e '\033[0;31m'
  echo -e 'sasha_postyt '
  echo -e ''
  echo -e ''
  echo -e ''
  echo -e "\n\nПодпишись на самый 4ekHyTbIu* канал в крипте @sasha_postyt [💸]"
}

download_node() {
  if [ -d "$HOME/cysic-verifier" ]; then
    echo 'Папка cysic-verifier уже существует. Установка невозможна.'
    return
  fi

  echo 'Начинаю установку ноды...'

  while true; do
    read -p "Введите адрес вашего EVM кошелька (начиная с 0x который): " EVM_WALLET
    CLEAN_WALLET="${EVM_WALLET#0x}"
    if [[ ${#CLEAN_WALLET} == 40 ]]; then
      EVM_WALLET="0x${CLEAN_WALLET}"
      break
    else
      echo "Ошибка: Неверная длина адреса. EVM адрес должен быть 40 символов (без 0x) или 42 символа (с 0x)"
    fi
  done

  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install make screen build-essential software-properties-common curl git nano jq -y

  curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_linux.sh > ~/setup_linux.sh && bash ~/setup_linux.sh $EVM_WALLET

  sudo tee /etc/systemd/system/cysic.service > /dev/null <<EOF
[Unit]
Description=Cysic Verifier
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/cysic-verifier
ExecStart=bash $HOME/cysic-verifier/start.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable cysic
  sudo systemctl start cysic

  echo 'Нода была запущена.'
}

check_logs() {
  sudo journalctl -u cysic -f -n 100 --no-hostname
}

stop_node() {
  echo 'Начинаю останавливать ноду...'

  sudo systemctl stop cysic

  echo 'Нода была остановлена.'
}

restart_node() {
  echo 'Начинаю перезапускать ноду...'

  sudo systemctl restart cysic

  echo 'Нода была перезапущена.'
}

delete_node() {
  read -p 'Если уверены удалить ноду, введите любую букву (CTRL+C чтобы выйти): ' checkjust

  echo 'Начинаю удалять ноду...'

  sudo systemctl stop cysic
  sudo systemctl disable cysic
  sudo rm /etc/systemd/system/cysic.service
  sudo systemctl daemon-reload

  sudo rm -r $HOME/cysic-verifier
  sudo rm -r $HOME/.cysic/

  echo 'Нода была удалена.'
}

exit_from_script() {
  exit 0
}

while true; do
    channel_logo
    sleep 2
    echo -e "\n\nМеню:"
    echo "1. 🚀 Установить ноду"
    echo "2. 🔑 Проверить логи (выйти CTRL+C)"
    echo "3. 🛑 Остановить ноду"
    echo "4. 🔄 Перезапустить ноду"
    echo "5. 🗑️ Удалить ноду"
    echo -e "6. 🚪 Выйти из скрипта\n"
    read -p "Выберите пункт меню: " choice

    case $choice in
      1)
        download_node
        ;;
      2)
        check_logs
        ;;
      3)
        stop_node
        ;;
      4)
        restart_node
        ;;
      5)
        delete_node
        ;;
      6)
        exit_from_script
        ;;
      *)
        echo "Неверный пункт. Пожалуйста, выберите правильную цифру в меню."
        ;;
    esac
  done
