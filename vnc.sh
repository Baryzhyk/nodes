#!/bin/bash
set -e

# ==== 0. Генерація паролю ====
VNC_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)

echo "[*] Updating system..."
apt update -y && apt upgrade -y

echo "[*] Installing desktop environment + clipboard tools..."
apt install -y xfce4 xfce4-goodies autocutsel xclip curl wget git \
    software-properties-common dbus-x11 libglu1-mesa gnupg libegl1-mesa

echo "[*] Downloading & Installing VirtualGL..."
VGL_VER="3.1"
wget -q https://github.com/VirtualGL/virtualgl/releases/download/${VGL_VER}/virtualgl_${VGL_VER}_amd64.deb
dpkg -i virtualgl_${VGL_VER}_amd64.deb || apt install -f -y

echo "[*] Downloading & Installing TurboVNC..."
TURBO_VER="3.1.1"
wget -q https://github.com/TurboVNC/turbovnc/releases/download/${TURBO_VER}/turbovnc_${TURBO_VER}_amd64.deb
dpkg -i turbovnc_${TURBO_VER}_amd64.deb || apt install -f -y

echo "[*] Configuring VirtualGL..."
/opt/VirtualGL/bin/vglserver_config -config +s +f -t </dev/null

echo "[*] Creating VNC startup script..."
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
export XDG_CURRENT_DESKTOP="XFCE"

# Clipboard sync
autocutsel -fork
autocutsel -selection PRIMARY -fork
xfce4-clipman &

# Fix mouse/keyboard grab in Minecraft
xset r rate 200 40
setxkbmap us

exec startxfce4
EOF
chmod +x ~/.vnc/xstartup
touch ~/.Xresources

echo "[*] Setting VNC password automatically..."
mkdir -p ~/.vnc
echo "$VNC_PASS" | /opt/TurboVNC/bin/vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo "[*] Starting VNC server..."
/opt/TurboVNC/bin/vncserver -kill :1 || true
/opt/TurboVNC/bin/vncserver :1 -geometry 1920x1080 -depth 24

# GPU check
if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null; then
    echo "[OK] GPU detected."
else
    echo "[WARN] GPU not detected or drivers missing."
fi

IP=$(hostname -I | awk '{print $1}')
echo "===================================="
echo "VNC is running!"
echo "Connect to: ${IP}:5901"
echo "Password:   ${VNC_PASS}"
echo "===================================="
