#!/bin/bash
DB="/etc/xray/vless.db"
CONFIG="/etc/xray/config.json"
BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "                              DAFTAR AKUN VLESS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ ! -f "$DB" || ! -f "$CONFIG" ]]; then echo "Database atau konfigurasi VLESS tidak ditemukan."; read -rp "Tekan Enter..."; exit 1; fi
printf '%-18s %-38s %-13s %-18s\n' "USERNAME" "UUID" "EXPIRED" "STATUS"
echo "--------------------------------------------------------------------------------"
today=$(date +%F); total=0
while read -r user exp uuid extra; do
    [[ -z "${user:-}" || -z "${exp:-}" || -z "${uuid:-}" ]] && continue
    if ! date -d "$exp" +%F >/dev/null 2>&1; then status="TANGGAL INVALID"
    elif [[ "$exp" < "$today" ]]; then status="EXPIRED"
    else status="BELUM EXPIRED"
    fi
    if ! jq -e --arg uuid "$uuid" '[.inbounds[] | select(.tag=="vless-ws-tls" or .tag=="vless-ws-nontls" or .tag=="vless-grpc") | .settings.clients[]? | select(.id==$uuid)] | length > 0' "$CONFIG" >/dev/null 2>&1; then status="UUID TIDAK ADA"; fi
    case "$status" in "BELUM EXPIRED") color="$GREEN";; "EXPIRED") color="$RED";; *) color="$YELLOW";; esac
    printf '%-18s %-38s %-13s ' "$user" "$uuid" "$exp"
    echo -e "${color}${status}${NC}"
    total=$((total+1))
done < "$DB"
echo "--------------------------------------------------------------------------------"
echo "Total akun database: $total"
echo "Status menunjukkan tanggal dan keberadaan UUID, bukan status login."
read -rp "Tekan Enter untuk kembali..."
