#!/bin/bash

# =========================================================
# SSH + WEBSOCKET + UDPGW INSTALLER
# autoscriptxray - by dlgst
# =========================================================

set -o pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEPS_VERSION="deps-v2"
RELEASE_URL="https://github.com/dalagistore/autoscriptxray/releases/download/${DEPS_VERSION}"

# =========================================================
# BASE DIRECTORY
# =========================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Mendukung eksekusi dari direktori mana pun.
cd "$BASE_DIR" || {
    echo -e "${RED}[ERROR] Gagal masuk direktori project: $BASE_DIR${NC}"
    exit 1
}

# =========================================================
# HELPER
# =========================================================

fail() {
    echo -e "${RED}[ERROR] $*${NC}"
    exit 1
}

info() {
    echo -e "${GREEN}[INFO] $*${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $*${NC}"
}

require_file() {
    [[ -f "$1" ]] || fail "File tidak ditemukan: $1"
}

require_dir() {
    [[ -d "$1" ]] || fail "Direktori tidak ditemukan: $1"
}

check_service() {
    local svc="$1"

    if ! systemctl is-active --quiet "$svc"; then
        echo -e "${RED}[ERROR] Service $svc gagal berjalan.${NC}"
        systemctl --no-pager -l status "$svc" || true
        return 1
    fi

    echo -e "${GREEN}[ACTIVE] $svc${NC}"
    return 0
}

# =========================================================
# ROOT CHECK
# =========================================================

if [[ "$EUID" -ne 0 ]]; then
    fail "Jalankan script sebagai root."
fi

clear

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   INSTALL SSH + WEBSOCKET + UDPGW${NC}"
echo -e "${GREEN}============================================${NC}"
echo
echo "Project directory: $BASE_DIR"
sleep 1

# =========================================================
# REQUIRED FILES
# =========================================================

require_file "$BASE_DIR/config/udp-custom.json"
require_file "$BASE_DIR/ssh/m-ssh"
require_file "$BASE_DIR/ssh/addssh.sh"
require_file "$BASE_DIR/ssh/account-info.sh"
require_dir "$BASE_DIR/internal/go"
require_dir "$BASE_DIR/internal/go/dropbear-ws"
require_dir "$BASE_DIR/internal/go/stunnel-ws"
require_file "$BASE_DIR/internal/go/dropbear-ws.service"
require_file "$BASE_DIR/internal/go/stunnel-ws.service"
require_file "$BASE_DIR/sshws/udpgw.service"
require_file "$BASE_DIR/sshws/udp-custom.service"

# issue.net tidak wajib.
if [[ -f "$BASE_DIR/config/issue.net" ]]; then
    cp "$BASE_DIR/config/issue.net" /etc/issue.net ||
        fail "Gagal menyalin issue.net"

    chmod 644 /etc/issue.net
    info "Banner SSH berhasil dipasang."
else
    warn "issue.net tidak tersedia. Instalasi dilanjutkan tanpa banner."
fi

# =========================================================
# INSTALL DEPENDENCIES
# =========================================================

echo
info "Memperbarui daftar paket..."

apt-get update || fail "apt-get update gagal."

echo
info "Memasang dependensi..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server \
    stunnel4 \
    curl \
    wget \
    python3 \
    screen \
    git \
    golang-go \
    libtomcrypt1 \
    libtommath1 \
    ca-certificates \
    jq \
    || fail "Gagal memasang dependensi."

mkdir -p /usr/local/bin

# =========================================================
# INSTALL DROPBEAR
# =========================================================

echo
info "Menginstal Dropbear..."

systemctl stop dropbear 2>/dev/null || true

DEBIAN_FRONTEND=noninteractive apt-get purge -y \
    dropbear \
    dropbear-bin >/dev/null 2>&1 || true

rm -f /usr/sbin/dropbear
rm -f /usr/bin/dbclient
rm -f /usr/bin/dropbearkey

cd /tmp || fail "Tidak bisa masuk ke /tmp."

rm -f dropbear-bin.deb dropbear.deb

wget -qO dropbear-bin.deb \
    "${RELEASE_URL}/dropbear-bin_2019.78-2build1_amd64.deb" ||
    fail "Gagal mengunduh dropbear-bin."

wget -qO dropbear.deb \
    "${RELEASE_URL}/dropbear_2019.78-2build1_all.deb" ||
    fail "Gagal mengunduh paket Dropbear."

dpkg -i dropbear-bin.deb dropbear.deb ||
    fail "Instalasi paket Dropbear gagal."

command -v dropbear >/dev/null 2>&1 ||
    fail "Binary Dropbear tidak ditemukan."

DROPBEAR_VER="$(dropbear -V 2>&1 || true)"

echo "$DROPBEAR_VER"

if ! grep -q "2019.78" <<< "$DROPBEAR_VER"; then
    fail "Versi Dropbear yang terpasang tidak sesuai."
fi

# =========================================================
# DROPBEAR HOST KEYS
# =========================================================

mkdir -p /etc/dropbear

if [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]]; then
    dropbearkey -t rsa \
        -f /etc/dropbear/dropbear_rsa_host_key ||
        fail "Gagal membuat RSA host key."
fi

if [[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]]; then
    dropbearkey -t ecdsa \
        -f /etc/dropbear/dropbear_ecdsa_host_key ||
        warn "Gagal membuat ECDSA host key; periksa dukungan algoritma Dropbear."
fi

# =========================================================
# DROPBEAR BANNER CONFIG
# =========================================================

DROPBEAR_BANNER_ARGS=""

if [[ -f /etc/issue.net ]]; then
    DROPBEAR_BANNER_ARGS="-b /etc/issue.net"
fi

# =========================================================
# DROPBEAR CONFIG
# =========================================================

cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -W 65536 ${DROPBEAR_BANNER_ARGS}"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

# =========================================================
# DROPBEAR SYSTEMD SERVICE
# =========================================================

cat > /etc/systemd/system/dropbear.service <<EOF
[Unit]
Description=Dropbear SSH Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/dropbear -E -F -p 109 -p 143 -W 65536 ${DROPBEAR_BANNER_ARGS}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/dropbear.service

# =========================================================
# BUILD GO WEBSOCKET SERVICES
# =========================================================

echo
info "Membangun SSH WebSocket dan SSL WebSocket..."

command -v go >/dev/null 2>&1 ||
    fail "Go compiler tidak ditemukan."

cd "$BASE_DIR/internal/go" ||
    fail "Gagal masuk ke direktori internal/go."

go build -ldflags="-s -w" \
    -o /usr/local/bin/dropbearws \
    ./dropbear-ws ||
    fail "Build dropbear-ws gagal."

go build -ldflags="-s -w" \
    -o /usr/local/bin/stunnelws \
    ./stunnel-ws ||
    fail "Build stunnel-ws gagal."

chmod 755 /usr/local/bin/dropbearws
chmod 755 /usr/local/bin/stunnelws

# =========================================================
# INSTALL WEBSOCKET SERVICES
# =========================================================

install -m 644 \
    "$BASE_DIR/internal/go/dropbear-ws.service" \
    /etc/systemd/system/dropbear-ws.service ||
    fail "Gagal memasang dropbear-ws.service."

install -m 644 \
    "$BASE_DIR/internal/go/stunnel-ws.service" \
    /etc/systemd/system/stunnel-ws.service ||
    fail "Gagal memasang stunnel-ws.service."

# =========================================================
# INSTALL BADVPN UDPGW
# =========================================================

echo
info "Menginstal BadVPN UDPGW..."

wget -qO /usr/local/bin/badvpn-udpgw \
    "${RELEASE_URL}/badvpn-udpgw" ||
    fail "Gagal mengunduh BadVPN UDPGW."

chmod 755 /usr/local/bin/badvpn-udpgw

# =========================================================
# UDPGW SYSTEMD SERVICE
# =========================================================

install -m 644 \
    "$BASE_DIR/sshws/udpgw.service" \
    /etc/systemd/system/udpgw.service ||
    fail "Gagal memasang udpgw.service."

# =========================================================
# INSTALL UDP CUSTOM
# =========================================================

echo
info "Menginstal UDP Custom..."

wget -qO /usr/local/bin/udp-custom \
    "${RELEASE_URL}/udp-custom-linux-amd64" ||
    fail "Gagal mengunduh UDP Custom."

chmod 755 /usr/local/bin/udp-custom

mkdir -p /etc/udp-custom

install -m 644 \
    "$BASE_DIR/config/udp-custom.json" \
    /etc/udp-custom/config.json ||
    fail "Gagal memasang konfigurasi UDP Custom."

# =========================================================
# UDP CUSTOM SYSTEMD SERVICE
# =========================================================

install -m 644 \
    "$BASE_DIR/sshws/udp-custom.service" \
    /etc/systemd/system/udp-custom.service ||
    fail "Gagal memasang udp-custom.service."

# =========================================================
# INSTALL DLGST SSH ACCOUNT MANAGER
# =========================================================

echo
info "Memasang DLGST SSH Account Manager..."

mkdir -p /etc/autoscriptvpn/ssh

install -m 700 "$BASE_DIR/ssh/m-ssh" /etc/autoscriptvpn/ssh/m-ssh ||
    fail "Gagal memasang menu SSH."
install -m 700 "$BASE_DIR/ssh/addssh.sh" /etc/autoscriptvpn/ssh/addssh.sh ||
    fail "Gagal memasang addssh.sh."
install -m 700 "$BASE_DIR/ssh/account-info.sh" /etc/autoscriptvpn/ssh/account-info.sh ||
    fail "Gagal memasang account-info.sh."

install -m 700 "$BASE_DIR/ssh/m-ssh" /usr/bin/m-ssh ||
    fail "Gagal memasang shortcut menu SSH."

# =========================================================
# RELOAD SYSTEMD
# =========================================================

echo
info "Memuat ulang konfigurasi systemd..."

systemctl daemon-reload ||
    fail "systemctl daemon-reload gagal."

# =========================================================
# ENABLE AND RESTART SERVICES
# =========================================================

echo
info "Mengaktifkan layanan SSH..."

systemctl enable ssh ||
    fail "Gagal mengaktifkan layanan OpenSSH."

systemctl restart ssh ||
    fail "OpenSSH gagal dijalankan."

systemctl enable dropbear ||
    fail "Gagal mengaktifkan Dropbear."

systemctl restart dropbear ||
    fail "Dropbear gagal dijalankan."

systemctl enable dropbear-ws ||
    fail "Gagal mengaktifkan dropbear-ws."

systemctl restart dropbear-ws ||
    fail "dropbear-ws gagal dijalankan."

systemctl enable stunnel-ws ||
    fail "Gagal mengaktifkan stunnel-ws."

systemctl restart stunnel-ws ||
    fail "stunnel-ws gagal dijalankan."

systemctl enable udpgw ||
    fail "Gagal mengaktifkan udpgw."

systemctl restart udpgw ||
    fail "udpgw gagal dijalankan."

systemctl enable udp-custom ||
    fail "Gagal mengaktifkan udp-custom."

systemctl restart udp-custom ||
    fail "udp-custom gagal dijalankan."

# =========================================================
# VERIFY SERVICES
# =========================================================

echo
info "Memeriksa status layanan..."
sleep 2

SERVICE_FAILED=0

for svc in \
    ssh \
    dropbear \
    dropbear-ws \
    stunnel-ws \
    udpgw \
    udp-custom
do
    check_service "$svc" || SERVICE_FAILED=1
done

if [[ "$SERVICE_FAILED" -ne 0 ]]; then
    echo
    warn "Ada layanan yang gagal berjalan. Periksa log di atas."
    exit 1
fi

# =========================================================
# NOLOGIN WS
# =========================================================

cat > /etc/profile.d/no-login.sh <<'EOF'
#!/bin/bash

[[ "$USER" == "root" ]] && return

clear
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " SSH WS ACCOUNT ONLY"
echo " SHELL ACCESS DENIED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sleep 2

pkill -9 -u "$USER"
EOF

chmod 755 /etc/profile.d/no-login.sh

# =========================================================
# HOLD DROPBEAR PACKAGES
# =========================================================

apt-mark hold dropbear dropbear-bin >/dev/null 2>&1 || true

# =========================================================
# INSTALL LOG
# =========================================================

cat >> /root/log-install.txt <<EOF

━━━━━━━━━━━━━━━━━━━━━━
SSH PANEL
━━━━━━━━━━━━━━━━━━━━━━

OpenSSH             : 22
Dropbear            : 109, 143
SSH WebSocket       : 2082 (periksa konfigurasi service)
SSH SSL WebSocket   : 2096 (periksa konfigurasi service)
BadVPN UDPGW        : 7300 (periksa konfigurasi service)
UDP Custom          : 36712 (periksa konfigurasi)
Port UdpSSH         : 1-65535

Project Directory   : ${BASE_DIR}

━━━━━━━━━━━━━━━━━━━━━━

EOF

# =========================================================
# DONE
# =========================================================

clear

echo
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} [ OK ] SSH + WS + UDPGW BERHASIL DIPASANG${NC}"
echo -e "${GREEN}============================================${NC}"
echo

echo -e "${GREEN}[INFO] Port yang sedang LISTEN:${NC}"
ss -tulnp | grep -E ':(22|109|143|2082|2096|7300|36712)([[:space:]]|$)' || true

echo
echo -e "${GREEN}[INFO] Status layanan:${NC}"

systemctl --no-pager --type=service |
    grep -E 'dropbear|ssh|ws|udpgw|udp' || true

echo
dropbear -V 2>&1 || true

echo
echo -e "${GREEN}[ OK ] Instalasi selesai.${NC}"
echo
