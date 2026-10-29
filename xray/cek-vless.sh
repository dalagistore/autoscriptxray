#!/bin/bash

CONFIG="/etc/xray/config.json"
DB="/etc/xray/vless.db"
LOG="/var/log/xray/access.log"

clear
echo "=============================================="
echo "       DLGST XRAY PANEL - CEK LOGIN VLESS"
echo "=============================================="
echo "Waktu : $(date '+%d-%m-%Y %H:%M:%S')"
echo "Aktivitas yang diperiksa: 10 menit terakhir"
echo

for file in "$CONFIG" "$DB" "$LOG"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File tidak ditemukan: $file"
        read -r -p "Tekan Enter untuk kembali..."
        exit 1
    fi
done

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq belum terpasang."
    read -r -p "Tekan Enter untuk kembali..."
    exit 1
fi

printf '%-20s %-15s %-22s\n' "USERNAME" "STATUS" "EXPIRY"
echo "------------------------------------------------------------"

now=$(date +%s)
found=0

while read -r username expiry uuid; do
    [[ -z "$username" || -z "$uuid" ]] && continue

    if ! jq -e --arg uuid "$uuid" '
        any(
            .inbounds[]
            | select(
                .tag == "vless-ws-tls" or
                .tag == "vless-ws-nontls" or
                .tag == "vless-grpc"
            )
            | .settings.clients[]?;
            .id == $uuid
        )
    ' "$CONFIG" >/dev/null 2>&1; then
        continue
    fi

    found=1
    status="TIDAK AKTIF"

    if awk -v user="$username" -v now="$now" '
        /accepted/ && /email:/ {
            ts = substr($0, 1, 19)
            gsub("/", " ", ts)
            event_time = mktime(ts)
            if (event_time > 0 && now - event_time >= 0 &&
                now - event_time <= 600 && $0 ~ ("email: " user "$")) {
                found=1
            }
        }
        END { exit !found }
    ' "$LOG"; then
        status="ADA AKTIVITAS"
    fi

    today=$(date +%F)
    if [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] &&
       [[ "$expiry" < "$today" ]]; then
        status="EXPIRED"
    fi

    printf '%-20s %-15s %-22s\n' "$username" "$status" "$expiry"
done < "$DB"

if [[ "$found" -eq 0 ]]; then
    echo "Belum ada akun VLESS yang cocok dengan database dan config."
fi

echo
echo "Keterangan:"
echo "ADA AKTIVITAS = ada koneksi tercatat dalam 10 menit terakhir."
echo "TIDAK AKTIF   = tidak ditemukan koneksi pada periode tersebut."
echo "EXPIRED       = tanggal masa berlaku sudah lewat."
echo
echo "Catatan: ini bukan pemeriksaan sesi online secara real-time."
read -r -p "Tekan Enter untuk kembali..."
