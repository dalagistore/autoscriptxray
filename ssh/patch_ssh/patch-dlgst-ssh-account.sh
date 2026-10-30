#!/bin/bash
set -Eeuo pipefail

SRC="/root/autoscriptxray/ssh/m-ssh"
ADD="/etc/autoscriptvpn/ssh/addssh.sh"
INST="/etc/autoscriptvpn/ssh/m-ssh"
HELPER="/etc/autoscriptvpn/ssh/account-info.sh"

BACKUP="/root/dlgst-ssh-backup-$(date +%Y%m%d-%H%M%S)"

if [[ $EUID -ne 0 ]]; then
    echo "Jalankan sebagai root!"
    exit 1
fi

if [[ ! -f "$SRC" || ! -f "$ADD" ]]; then
    echo "File sumber tidak ditemukan!"
    exit 1
fi

mkdir -p "$BACKUP"
cp -a "$SRC" "$ADD" "$BACKUP/"

echo "Membuat helper informasi akun..."

cat > "$HELPER" <<'EOF'
#!/bin/bash

show_dlgst_ssh_info() {
    local user="$1"
    local pass="$2"
    local expiry="$3"
    local duration="$4"
    local kind="$5"
    local file="$6"

    local domain=""
    local ip=""
    local created

    for f in /etc/xray/domain /etc/v2ray/domain /etc/autoscriptvpn/domain; do
        if [[ -s "$f" ]]; then
            domain=$(head -n1 "$f" | tr -d '[:space:]')
            [[ -n "$domain" ]] && break
        fi
    done

    ip=$(curl -4 -fsS --max-time 3 https://api.ipify.org 2>/dev/null || true)
    [[ -n "$ip" ]] || ip=$(hostname -I | awk '{print $1}')
    [[ -n "$domain" ]] || domain="$ip"

    created=$(date '+%Y-%m-%d %H:%M:%S')

    port_active() {
        ss -H -lntu 2>/dev/null |
        awk -v p="$1" '{
            n=split($5,a,":")
            if(a[n]==p) found=1
        }
        END {exit !found}'
    }

    port_status() {
        if port_active "$1"; then
            echo "AKTIF"
        else
            echo "TIDAK AKTIF"
        fi
    }

    service_status() {
        if systemctl is-active --quiet "$1" 2>/dev/null; then
            echo "RUNNING"
        else
            echo "TIDAK AKTIF"
        fi
    }

    {
        echo "================================================"
        echo "             DLGST - PREMIUM VPN"
        echo "                 SSH $kind"
        echo "================================================"
        echo
        echo "[ INFORMASI AKUN ]"

        printf '%-17s: %s\n' "Username" "$user"
        printf '%-17s: %s\n' "Password" "$pass"
        printf '%-17s: %s\n' "IP Server" "$ip"
        printf '%-17s: %s\n' "Domain" "$domain"
        printf '%-17s: %s\n' "Tanggal dibuat" "$created"
        printf '%-17s: %s\n' "Kedaluwarsa" "$expiry"
        printf '%-17s: %s\n' "Durasi" "$duration"

        echo
        echo "[ INFORMASI KONEKSI ]"

        printf '%-17s: %s (%s)\n' "OpenSSH" 22 "$(port_status 22)"
        printf '%-17s: %s (%s)\n' "Dropbear" "109,143" \
            "$( { port_active 109 || port_active 143; } && echo AKTIF || echo TIDAK AKTIF)"
        printf '%-17s: %s (%s)\n' "Dropbear WS" 2082 "$(port_status 2082)"
        printf '%-17s: %s (%s)\n' "Stunnel WS" 2096 "$(port_status 2096)"
        printf '%-17s: %s (%s)\n' "HTTP" 80 "$(port_status 80)"
        printf '%-17s: %s (%s)\n' "HTTPS/Nginx" 443 "$(port_status 443)"
        printf '%-17s: %s/UDP (%s)\n' "UDP Custom" 36712 "$(port_status 36712)"
        printf '%-17s: %s/TCP (LOKAL)\n' "BadVPN UDPGW" 7300

        echo
        echo "[ FORMAT KONEKSI ]"
        echo "SSH       : $domain:22"
        echo "SSH WS    : $domain:2082@$user:$pass"
        echo "SSH WSS   : $domain:2096@$user:$pass"
        echo "UDP Custom: Port 36712/UDP"
        echo
        echo "[ PAYLOAD WS ]"
        printf 'GET / HTTP/1.1[crlf]\nHost: %s[crlf]\nUpgrade: websocket[crlf]\nConnection: Upgrade[crlf]\n[crlf]\n' "$domain"

        echo
        echo "[ PAYLOAD ENHANCED ]"
        printf 'GET / HTTP/1.1[crlf]\nHost: [host][crlf]\n[crlf]\nPATCH / HTTP/1.1[crlf]\nHost: %s[crlf]\nUpgrade: websocket[crlf]\nConnection: Upgrade[crlf]\n[crlf][split]\n' "$domain"

        echo
        echo "[ STATUS LAYANAN ]"
        printf '%-17s: %s\n' "SSH" "$(service_status ssh)"
        printf '%-17s: %s\n' "Dropbear" "$(service_status dropbear)"
        printf '%-17s: %s\n' "Nginx" "$(service_status nginx)"
        printf '%-17s: %s\n' "UDP Custom" "$(service_status udp-custom)"

        echo
        echo "[ CATATAN ]"
        echo "Akun menggunakan database user Linux."
        echo "UDP Custom menggunakan port 36712/UDP."
        echo "BadVPN UDPGW port 7300 terikat ke localhost."
        echo "Dilarang melakukan DDoS, spam, carding, dan hacking."
        echo
        echo "================================================"
        echo "          DLGST - PREMIUM VPN"
        echo "================================================"

    } | tee "$file"
}
EOF

chmod 700 "$HELPER"

echo "Memperbarui script akun reguler..."

cat > "$ADD" <<'EOF'
#!/bin/bash
set -Eeuo pipefail

clear
source /etc/autoscriptvpn/ssh/account-info.sh

echo "================================================"
echo "             DLGST - PREMIUM VPN"
echo "              CREATE SSH ACCOUNT"
echo "================================================"

read -r -p "Username      : " user

[[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || {
    echo "Username tidak valid!"
    exit 1
}

id "$user" &>/dev/null && {
    echo "Username sudah digunakan!"
    exit 1
}

read -r -s -p "Password      : " pass
echo

[[ -n "$pass" ]] || {
    echo "Password tidak boleh kosong!"
    exit 1
}

read -r -p "Expired Days  : " days

[[ "$days" =~ ^[0-9]+$ ]] &&
(( days >= 1 && days <= 3650 )) || {
    echo "Masukkan masa aktif 1-3650 hari!"
    exit 1
}

EXP=$(date -d "+$days days" +%Y-%m-%d)

useradd -e "$EXP" -m -s /bin/bash "$user" || {
    echo "Gagal membuat akun!"
    exit 1
}

if ! printf '%s:%s\n' "$user" "$pass" | chpasswd; then
    userdel "$user" 2>/dev/null || true
    echo "Gagal mengatur password!"
    exit 1
fi

mkdir -p /root/accounts

FILE="/root/accounts/${user}.txt"

show_dlgst_ssh_info \
    "$user" "$pass" "$EXP" "$days Hari" \
    "ACCOUNT" "$FILE"

echo
echo "Informasi akun tersimpan: $FILE"
EOF

chmod 700 "$ADD"

echo "Memperbarui fungsi Trial SSH..."

python3 - "$SRC" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
s = p.read_text()

start = s.find("trial_ssh_account() {")
end = s.find("renew_ssh_account() {", start + 1)

if start < 0 or end < 0:
    raise SystemExit(
        "ERROR: Fungsi trial atau renew tidak ditemukan. "
        "File menu tidak diubah."
    )

fn = r'''trial_ssh_account() {
    clear

    echo "=== DLGST - PREMIUM VPN | SSH TRIAL ==="

    read -r -p 'Username trial (kosong = otomatis): ' user

    [[ -n "$user" ]] || user="trial$(date +%H%M%S)"

    valid_username "$user" || {
        err 'Format username tidak valid.'
        return
    }

    account_exists "$user" && {
        err 'Username sudah digunakan.'
        return
    }

    local pass expiry file

    pass=$(make_password)
    expiry=$(date -d '+1 day' +%Y-%m-%d) || {
        err 'Gagal menghitung kedaluwarsa.'
        return
    }

    useradd -M -s /bin/false -e "$expiry" "$user" || {
        err 'Gagal membuat akun trial.'
        return
    }

    if ! printf '%s:%s\n' "$user" "$pass" | chpasswd; then
        userdel "$user" 2>/dev/null || true
        err 'Gagal mengatur password.'
        return
    fi

    chage -E "$expiry" "$user" || warn 'Gagal menerapkan tanggal kedaluwarsa.'

    mkdir -p /root/accounts

    file="/root/accounts/${user}.txt"

    show_dlgst_ssh_info \
        "$user" "$pass" "$expiry" "1 Hari" \
        "TRIAL" "$file"

    echo
    echo "Informasi akun tersimpan: $file"
}

'''

s = s[:start] + fn + s[end:]

if "source /etc/autoscriptvpn/ssh/account-info.sh" not in s:
    anchor = "ADD_SCRIPT='/etc/autoscriptvpn/ssh/addssh.sh'"
    if anchor not in s:
        raise SystemExit("ERROR: ADD_SCRIPT tidak ditemukan.")
    s = s.replace(
        anchor,
        anchor + "\nsource /etc/autoscriptvpn/ssh/account-info.sh",
        1
    )

p.write_text(s)
PY

echo "Menyinkronkan menu..."

install -m 700 "$SRC" "$INST"

if [[ -f /usr/bin/m-ssh && ! -L /usr/bin/m-ssh ]]; then
    cp -a /usr/bin/m-ssh "$BACKUP/m-ssh.usr-bin"
    install -m 700 "$SRC" /usr/bin/m-ssh
fi

echo "Memeriksa syntax..."

bash -n "$ADD"
bash -n "$SRC"
bash -n "$HELPER"

echo
echo "========================================"
echo "       PATCH DLGST BERHASIL"
echo "========================================"
echo "Backup: $BACKUP"
echo "========================================"
echo
echo "Silakan uji Trial SSH terlebih dahulu."
