#!/usr/bin/env bash
set -Eeuo pipefail
BASE=/root/autoscriptxray
SRC="$BASE/ssh/m-ssh"
ADD=/etc/autoscriptvpn/ssh/addssh.sh
INST=/etc/autoscriptvpn/ssh/m-ssh
HELPER=/etc/autoscriptvpn/ssh/account-info.sh
BACKUP="/root/dlgst-ssh-backup-$(date +%Y%m%d-%H%M%S)"
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root."; exit 1; }
[[ -f "$SRC" && -f "$ADD" ]] || { echo "File sumber tidak ditemukan."; exit 1; }
mkdir -p "$BACKUP"
cp -a "$SRC" "$ADD" "$BACKUP/"
[[ ! -f "$INST" ]] || cp -a "$INST" "$BACKUP/m-ssh.installed"

cat > "$HELPER" <<'HELPER'
#!/usr/bin/env bash
show_dlgst_ssh_info() {
    local user="$1" pass="$2" expiry="$3" duration="$4" kind="$5" file="$6"
    local domain="" ip="" created
    for f in /etc/xray/domain /etc/v2ray/domain /etc/autoscriptvpn/domain; do
        if [[ -s "$f" ]]; then domain="$(head -n1 "$f" | tr -d '[:space:]')"; [[ -n "$domain" ]] && break; fi
    done
    ip="$(curl -4 -fsS --max-time 3 https://api.ipify.org 2>/dev/null || true)"
    [[ -n "$ip" ]] || ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [[ -n "$ip" ]] || ip="Tidak terdeteksi"
    [[ -n "$domain" ]] || domain="$ip"
    created="$(date '+%Y-%m-%d %H:%M:%S')"
    port_active() {
        ss -H -lntu 2>/dev/null | awk -v p="$1" '{n=split($5,a,":"); if(a[n]==p)f=1} END{exit !f}'
    }
    pstate() { port_active "$1" && echo AKTIF || echo TIDAK AKTIF; }
    sstate() {
        systemctl is-active --quiet "$1" 2>/dev/null && echo RUNNING || echo TIDAK AKTIF
    }
    {
        echo "================================================"
        echo "             DLGST - PREMIUM VPN"
        printf "                 SSH %s\n" "$kind"
        echo "================================================"
        echo
        echo "[ INFORMASI AKUN ]"
        printf '%-17s: %s\n' Username "$user"
        printf '%-17s: %s\n' Password "$pass"
        printf '%-17s: %s\n' "IP Server" "$ip"
        printf '%-17s: %s\n' Domain "$domain"
        printf '%-17s: %s\n' "Tanggal dibuat" "$created"
        printf '%-17s: %s\n' Kedaluwarsa "$expiry"
        printf '%-17s: %s\n' Durasi "$duration"
        echo
        echo "[ INFORMASI KONEKSI ]"
        printf '%-17s: %s (%s)\n' OpenSSH 22 "$(pstate 22)"
        printf '%-17s: %s (%s)\n' Dropbear 109,143 "$( { port_active 109 || port_active 143; } && echo AKTIF || echo TIDAK AKTIF)"
        printf '%-17s: %s (%s)\n' "Dropbear WS" 2082 "$(pstate 2082)"
        printf '%-17s: %s (%s)\n' "Stunnel WS" 2096 "$(pstate 2096)"
        printf '%-17s: %s (%s)\n' HTTP 80 "$(pstate 80)"
        printf '%-17s: %s (%s)\n' "HTTPS/Nginx" 443 "$(pstate 443)"
        printf '%-17s: %s/UDP (%s)\n' "UDP Custom" 36712 "$(pstate 36712)"
        printf '%-17s: %s/TCP (LOKAL)\n' "BadVPN UDPGW" 7300
        echo
        echo "[ FORMAT KONEKSI ]"
        echo "SSH biasa : $domain:22"
        echo "SSH WS    : $domain:2082@$user:$pass"
        echo "SSH WSS   : $domain:2096@$user:$pass"
        echo "UDP Custom: port 36712/UDP; format autentikasi mengikuti aplikasi client"
        echo
        echo "[ PAYLOAD WS ]"
        printf 'GET / HTTP/1.1[crlf]\nHost: %s[crlf]\nUpgrade: websocket[crlf]\nConnection: Upgrade[crlf]\n[crlf]\n' "$domain"
        echo
        echo "[ PAYLOAD ENHANCED ]"
        printf 'GET / HTTP/1.1[crlf]\nHost: [host][crlf]\n[crlf]\nPATCH / HTTP/1.1[crlf]\nHost: %s[crlf]\nUpgrade: websocket[crlf]\nConnection: Upgrade[crlf]\n[crlf][split]\n' "$domain"
        echo
        echo "[ STATUS LAYANAN ]"
        printf '%-17s: %s\n' SSH "$(sstate ssh)"
        printf '%-17s: %s\n' Dropbear "$(sstate dropbear)"
        printf '%-17s: %s\n' Nginx "$(sstate nginx)"
        printf '%-17s: %s\n' "UDP Custom" "$(sstate udp-custom)"
        echo
        echo "[ CATATAN ]"
        echo "Akun menggunakan database user Linux."
        echo "UDP Custom aktif pada port 36712/UDP; payload autentikasi tidak diasumsikan."
        echo "BadVPN UDPGW 7300 terikat ke localhost."
        echo "Dilarang melakukan DDoS, spam, carding, hacking, dan aktivitas ilegal."
        echo
        echo "================================================"
        echo "          DLGST - PREMIUM VPN"
        echo "================================================"
    } | tee "$file"
}
HELPER
chmod 700 "$HELPER"

cat > "$ADD" <<'ADD'
#!/usr/bin/env bash
set -Eeuo pipefail
clear
source /etc/autoscriptvpn/ssh/account-info.sh
echo "=== DLGST - PREMIUM VPN | CREATE SSH ACCOUNT ==="
read -r -p "Username      : " user
[[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "Username tidak valid."; exit 1; }
id "$user" &>/dev/null && { echo "Username sudah digunakan."; exit 1; }
read -r -s -p "Password      : " pass; echo
[[ -n "$pass" ]] || { echo "Password tidak boleh kosong."; exit 1; }
read -r -p "Expired Days  : " days
[[ "$days" =~ ^[0-9]+$ ]] && (( days >= 1 && days <= 3650 )) || { echo "Masukkan 1-3650 hari."; exit 1; }
EXP="$(date -d "+$days days" +%Y-%m-%d)"
useradd -e "$EXP" -m -s /bin/bash "$user" || { echo "Gagal membuat user."; exit 1; }
if ! printf '%s:%s\n' "$user" "$pass" | chpasswd; then userdel "$user" 2>/dev/null || true; echo "Gagal mengatur password."; exit 1; fi
mkdir -p /root/accounts
FILE="/root/accounts/${user}.txt"
show_dlgst_ssh_info "$user" "$pass" "$EXP" "$days Hari" ACCOUNT "$FILE"
echo "Informasi akun tersimpan: $FILE"
ADD
chmod 700 "$ADD"

python3 - "$SRC" <<'PY'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); s=p.read_text()
anchor="ADD_SCRIPT='/etc/autoscriptvpn/ssh/addssh.sh'"
if "source /etc/autoscriptvpn/ssh/account-info.sh" not in s:
    s=s.replace(anchor,anchor+"\nsource /etc/autoscriptvpn/ssh/account-info.sh",1)
fn='''trial_ssh_account() {
    clear
    echo "=== DLGST - PREMIUM VPN | SSH TRIAL ==="
    read -r -p 'Username trial (kosong = otomatis): ' user
    [[ -n "$user" ]] || user="trial$(date +%H%M%S)"
    valid_username "$user" || { err 'Format username tidak valid.'; return; }
    account_exists "$user" && { err 'Username sudah digunakan.'; return; }
    local pass expiry file
    pass=$(make_password)
    expiry=$(date -d '+1 day' +%Y-%m-%d) || { err 'Gagal menghitung kedaluwarsa.'; return; }
    useradd -M -s /bin/false -e "$expiry" "$user" || { err 'Gagal membuat akun trial.'; return; }
    if ! printf '%s:%s\\n' "$user" "$pass" | chpasswd; then
        userdel "$user" 2>/dev/null || true
        err 'Gagal mengatur password; akun dibatalkan.'; return
    fi
    chage -E "$expiry" "$user" || warn 'Tanggal kedaluwarsa gagal diterapkan.'
    mkdir -p /root/accounts
    file="/root/accounts/${user}.txt"
    show_dlgst_ssh_info "$user" "$pass" "$expiry" "1 Hari" TRIAL "$file"
    echo "Informasi akun tersimpan: $file"
}'''
s2,n=re.subn(r'trial_ssh_account\(\) \{.*?\n\}\n(?=renew_ssh_account\(\))',fn+"\n\n",s,count=1,flags=re.S)
if n!=1: raise SystemExit("Blok trial tidak ditemukan; batal.")
p.write_text(s2)
PY

install -m 700 "$SRC" "$INST"
if [[ -f /usr/bin/m-ssh && ! -L /usr/bin/m-ssh ]]; then
    cp -a /usr/bin/m-ssh "$BACKUP/m-ssh.usr-bin"
    install -m 700 "$SRC" /usr/bin/m-ssh
fi

bash -n "$ADD"
bash -n "$SRC"
bash -n "$HELPER"
echo
echo "PATCH BERHASIL. Backup: $BACKUP"
echo "Helper: $HELPER"
echo "Silakan uji menu Trial terlebih dahulu."
