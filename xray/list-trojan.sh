#!/bin/bash
DB=/etc/xray/trojan.db
[[ -f "$DB" ]] || { echo 'Database tidak ada'; exit 1; }
printf '%-22s %-15s %-15s\n' USERNAME EXPIRY STATUS
while read -r user expiry secret rest; do
 [[ -n "$user" ]] || continue
 status=TERDAFTAR
 [[ "$expiry" < "$(date +%F)" ]] && status=EXPIRED
 printf '%-22s %-15s %-15s\n' "$user" "$expiry" "$status"
done < "$DB"
read -r -p 'Tekan Enter untuk kembali...' _ || true
