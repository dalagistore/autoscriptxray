#!/usr/bin/env bash
set -Eeuo pipefail
clear
source /etc/autoscriptvpn/ssh/account-info.sh
echo "=== DLGST - PREMIUM VPN | CREATE SSH ACCOUNT ==="
read -r -p "Username      : " user
[[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "Username tidak valid."; exit 1; }
id "$user" &>/dev/null && { echo "Username sudah digunakan."; exit 1; }
read -r -s -p "Password      : " pass
echo
[[ -n "$pass" ]] || { echo "Password tidak boleh kosong."; exit 1; }
read -r -p "Expired Days  : " days
[[ "$days" =~ ^[0-9]+$ ]] && (( days >= 1 && days <= 3650 )) || { echo "Masukkan 1-3650 hari."; exit 1; }
EXP="$(date -d "+$days days" +%Y-%m-%d)"
useradd -e "$EXP" -m -s /bin/bash "$user" || { echo "Gagal membuat user."; exit 1; }
if ! printf '%s:%s\n' "$user" "$pass" | chpasswd; then
    userdel "$user" 2>/dev/null || true
    echo "Gagal mengatur password."; exit 1
fi
mkdir -p /root/accounts
FILE="/root/accounts/${user}.txt"
show_dlgst_ssh_info "$user" "$pass" "$EXP" "$days Hari" ACCOUNT "$FILE"
echo "Informasi akun tersimpan: $FILE"
