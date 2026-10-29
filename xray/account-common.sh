#!/bin/bash
set -euo pipefail
CONFIG=/etc/xray/config.json
TYPE="${1:?protocol required}"
DB="/etc/xray/${TYPE}.db"
case "$TYPE" in
 vmess) TAGS='["vmess-ws-tls","vmess-ws-nontls","vmess-grpc"]'; FIELD=id;;
 trojan) TAGS='["trojan-ws-tls","trojan-grpc"]'; FIELD=password;;
 ssws) TAGS='["ssws-ws-tls","ssws-ws-nontls","ssws-grpc"]'; FIELD=password;;
 *) echo "Unknown protocol"; exit 1;;
esac
require_files(){ [[ -f "$CONFIG" && -f "$DB" ]] || { echo 'Config/database tidak ditemukan'; exit 1; }; jq -e . "$CONFIG" >/dev/null; }
user_exists(){ jq -e --arg u "$1" --argjson tags "$TAGS" 'any(.inbounds[] | select(.tag as $t | $tags | index($t) != null) | .settings.clients[]?; .email==$u)' "$CONFIG" >/dev/null; }
get_db(){ awk -v u="$1" '$1==u {print; exit}' "$DB"; }
wait_back(){ read -r -p 'Tekan Enter untuk kembali...' _ || true; }
