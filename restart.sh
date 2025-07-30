#!/bin/bash

echo "🛠 Встановлення watchdog для RL Swarm..."

INSTALL_DIR="/root/rl-swarm"
WATCHDOG_SCRIPT="$INSTALL_DIR/watchdog.sh"
SERVICE_FILE="/etc/systemd/system/gensynnode.service"

read -p "❓ Бажаєте увімкнути сповіщення в Telegram? (y/N): " ENABLE_TELEGRAM

if [[ "$ENABLE_TELEGRAM" =~ ^[Yy]$ ]]; then
    read -p "🔑 Введіть ваш Telegram BOT TOKEN: " BOT_TOKEN
    read -p "👤 Введіть ваш Telegram CHAT ID: " CHAT_ID
else
    BOT_TOKEN=""
    CHAT_ID=""
fi

echo "📄 Створюємо watchdog.sh..."

cat > "$WATCHDOG_SCRIPT" <<'EOF'
#!/bin/bash

LOG_FILE="/root/rl-swarm/gensynnode.log"
PROJECT_DIR="/root/rl-swarm"

# Перевіряємо журнал на типові помилки
check_for_error() {
    grep -qE "Resource temporarily unavailable|Connection refused|BlockingIOError: \[Errno 11\]|EOFError: Ran out of input|Traceback \(most recent call last\)" "$LOG_FILE"
}

# Перевіряємо, чи процес не працює
check_process() {
    ! screen -list | grep -q "gensynnode"
}

# Надсилаємо сповіщення в Telegram
send_telegram_alert() {
    SERVER_IP=$(curl -s https://api.ipify.org)
EOF

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    cat >> "$WATCHDOG_SCRIPT" <<EOF
    BOT_TOKEN="$BOT_TOKEN"
    CHAT_ID="$CHAT_ID"
    curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" \\
        -d chat_id="\$CHAT_ID" \\
        -d text="⚠️ RL Swarm було перезапущено 🌐 IP: \$SERVER_IP 🕒 \$(date '+%Y-%m-%d %H:%M:%S')" \\
        -d parse_mode="Markdown"
EOF
else
    cat >> "$WATCHDOG_SCRIPT" <<'EOF'
    echo "[INFO] Сповіщення в Telegram вимкнені"
EOF
fi

cat >> "$WATCHDOG_SCRIPT" <<'EOF'
}

# Перезапуск процесу RL Swarm
restart_process() {
    echo "[INFO] Перезапуск gensynnode..."

    screen -XS gensynnode quit
    
   mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

echo "[INFO] Перевірка наявності важливих файлів..."

if [ ! -f "/root/rl-swarm/modal-login/temp-data/userData.json" ]; then
    echo "[WARN] /root/rl-swarm/modal-login/temp-data/userData.json не знайдено!"
fi

if [ ! -f "/root/rl-swarm/modal-login/temp-data/userApiKey.json" ]; then
    echo "[WARN] /root/rl-swarm/modal-login/temp-data/userApiKey.json не знайдено!"
fi

cd "$PROJECT_DIR" || exit
source .venv/bin/activate

echo "[INFO] Запускаємо процес у сесії screen..."
screen -S gensynnode -d -m bash -c "trap '' INT; bash run_rl_swarm.sh 2>&1 | tee /root/rl-swarm/gensynnode.log"

echo "[INFO] Процес запущено, лог: $LOG_FILE"
sleep 5

    echo "[INFO] Очікуємо завершення встановлення..."

    for i in {1..300}; do
        if tail -n 20 "$LOG_FILE" 2>/dev/null | grep -q "Done!"; then
            echo "[INFO] Встановлення завершено — знайдено повідомлення 'Done!'"
            break
        fi
        sleep 1
    done

    echo "[INFO] Очікуємо питання про Hugging Face Hub..."
    for i in {1..60}; do
        LOG_TAIL=$(tail -n 10 "$LOG_FILE" 2>/dev/null || echo "")
        if echo "$LOG_TAIL" | grep -q "\[y/N\]"; then
            echo "[INFO] Виявлено запит [y/N], відправляємо 'N'"
            screen -S gensynnode -X stuff "N$(echo -ne '\r')"
            sleep 3
            break
        fi
        sleep 1
    done

    echo "[INFO] Очікуємо запит про назву моделі..."
    FOUND_MODEL_QUESTION=false

    for i in {1..120}; do
        LOG_TAIL=$(tail -n 20 "$LOG_FILE" 2>/dev/null || echo "")
        echo "[DEBUG] Спроба $i/120, перевірка логу..."
        echo "[DEBUG] Останні 3 рядки:"
        tail -n 3 "$LOG_FILE" 2>/dev/null || echo "Немає логу"

        if echo "$LOG_TAIL" | grep -qi "enter the name of the model"; then
            echo "[INFO] Виявлено 'enter the name of the model' — натискаємо Enter"
            screen -S gensynnode -X stuff "$(echo -ne '\r')"
            FOUND_MODEL_QUESTION=true
            break
        elif echo "$LOG_TAIL" | grep -qi "huggingface repo/name format"; then
            echo "[INFO] Виявлено 'huggingface repo/name format' — натискаємо Enter"
            screen -S gensynnode -X stuff "$(echo -ne '\r')"
            FOUND_MODEL_QUESTION=true
            break
        elif echo "$LOG_TAIL" | grep -qi "press \[enter\]"; then
            echo "[INFO] Виявлено 'press [Enter]' — натискаємо Enter"
            screen -S gensynnode -X stuff "$(echo -ne '\r')"
            FOUND_MODEL_QUESTION=true
            break
        elif echo "$LOG_TAIL" | grep -qi "default model"; then
            echo "[INFO] Виявлено 'default model' — натискаємо Enter"
            screen -S gensynnode -X stuff "$(echo -ne '\r')"
            FOUND_MODEL_QUESTION=true
            break
        elif echo "$LOG_TAIL" | grep -qi "model.*:" && echo "$LOG_TAIL" | grep -v "installing\|downloading"; then
            echo "[INFO] Виявлено запит моделі — натискаємо Enter"
            screen -S gensynnode -X stuff "$(echo -ne '\r')"
            FOUND_MODEL_QUESTION=true
            break
        fi

        if [ $((i % 30)) -eq 0 ]; then
            echo "[INFO] Пройшло 30 секунд — примусове натискання Enter (спроба $((i/30)))"
            screen -S gensynnode -X stuff "$(echo -ne '\r')"
        fi

        sleep 1
    done

    if [ "$FOUND_MODEL_QUESTION" = false ]; then
        echo "[WARN] Запит про модель не знайдено, натискаємо Enter як запасний варіант"
        screen -S gensynnode -X stuff "$(echo -ne '\r')"
    fi

    send_telegram_alert
}

while true; do
    if check_for_error || check_process; then
        restart_process
    fi
    sleep 10
done
EOF

chmod +x "$WATCHDOG_SCRIPT"

echo "✅ watchdog.sh створено в $WATCHDOG_SCRIPT"

echo "📄 Створюємо systemd сервіс..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=RL Swarm Watchdog
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/bin/bash $WATCHDOG_SCRIPT
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "🔁 Перезапуск systemd та запуск сервісу..."
sudo systemctl daemon-reload
sudo systemctl enable gensynnode.service
sudo systemctl restart gensynnode.service

echo "✅ Встановлення завершено!"
echo "👉 Перевірка статусу: sudo systemctl status gensynnode.service"
echo "👉 Перегляд логів watchdog: sudo journalctl -u gensynnode.service -f"
echo "👉 Перегляд логів RL Swarm: tail -f /root/rl-swarm/gensynnode.log"

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    SERVER_IP=$(curl -s https://api.ipify.org)
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="✅ Скрипт RL Swarm встановлено 🌐 IP: $SERVER_IP 🕒 $(date '+%Y-%m-%d %H:%M:%S')" \
        -d parse_mode="Markdown"
fi
