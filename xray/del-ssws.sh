#!/bin/bash
set -euo pipefail
source /etc/autoscriptvpn/xray/account-common.sh ssws
require_files
printf '\n=== DLGST SSWS - DEL ===\n'
awk '{print " - " $1 " (" $2 ")"}' "$DB"
read -r -p 'Username yang dihapus: ' user
[[ "$user" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'Username tidak valid'; exit 1; }
row=$(get_db "$user")
[[ -n "$row" ]] || { echo 'Akun tidak ditemukan dalam database'; exit 1; }
read -r -p "Yakin hapus $user? [y/N]: " confirm
[[ "$confirm" == [yY] ]] || exit 0
backup=$(mktemp -d /tmp/dlgst-backup.XXXXXX)
cp -p "$CONFIG" "$backup/config.json"
cp -p "$DB" "$backup/account.db"
tmp=$(mktemp --suffix=.json)
trap 'rm -f "$tmp"' EXIT
jq --arg u "$user" --argjson tags "$TAGS" '(.inbounds[] | select(.tag as $t | $tags | index($t) != null) | .settings.clients) |= map(select(.email != $u))' "$CONFIG" > "$tmp"
if ! xray -test -config "$tmp" >/dev/null 2>&1; then echo 'Config baru tidak lolos tes, dibatalkan'; exit 1; fi
cat "$tmp" > "$CONFIG"
if ! systemctl restart xray || ! systemctl is-active --quiet xray; then
  cp -p "$backup/config.json" "$CONFIG"
  systemctl restart xray || true
  echo 'Restart gagal, konfigurasi dipulihkan'; exit 1
fi
tmpdb=$(mktemp)
awk -v u="$user" '$1!=u' "$DB" > "$tmpdb"
cat "$tmpdb" > "$DB"; rm -f "$tmpdb"
echo "Akun $user dihapus. Backup: $backup"
wait_back
