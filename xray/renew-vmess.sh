#!/bin/bash
set -euo pipefail
source /etc/autoscriptvpn/xray/account-common.sh vmess
require_files
printf '\n=== DLGST VMESS - RENEW ===\n'
awk '{print " - " $1 " (" $2 ")"}' "$DB"
read -r -p 'Username diperpanjang: ' user
[[ "$user" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'Username tidak valid'; exit 1; }
row=$(get_db "$user")
[[ -n "$row" ]] && user_exists "$user" || { echo 'Akun tidak ditemukan di database/config'; exit 1; }
read -r -p 'Tambah hari (1-3650): ' days
[[ "$days" =~ ^[0-9]+$ ]] && ((10#$days >= 1 && 10#$days <= 3650)) || { echo 'Jumlah hari tidak valid'; exit 1; }
read -r _ expiry _ <<< "$row"
today=$(date +%F)
base="$today"
[[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$expiry" > "$today" ]] && base="$expiry"
new_exp=$(date -d "$base + $((10#$days)) days" +%F)
cp -p "$DB" "$DB.bak.$(date +%Y%m%d%H%M%S)"
tmpdb=$(mktemp)
awk -v u="$user" -v exp="$new_exp" 'BEGIN{OFS=" "} $1==u {$2=exp} {print}' "$DB" > "$tmpdb"
cat "$tmpdb" > "$DB"; rm -f "$tmpdb"
echo "Akun $user diperpanjang sampai $new_exp (database)."
echo 'Catatan: tanggal expiry belum otomatis memutus koneksi Xray.'
wait_back
