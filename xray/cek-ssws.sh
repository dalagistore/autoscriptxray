#!/bin/bash
set -euo pipefail
source /etc/autoscriptvpn/xray/account-common.sh ssws
require_files
printf '\n=== DLGST SSWS - CEK ===\n'
LOG=/var/log/xray/access.log
[[ -f "$LOG" ]] || { echo "Log tidak ditemukan: $LOG"; exit 1; }
printf '%-22s %-15s %-15s\n' USERNAME EXPIRY AKTIVITAS
now=$(date +%s)
while read -r user expiry secret rest; do
  [[ -n "$user" && -n "${secret:-}" ]] || continue
  if ! user_exists "$user"; then continue; fi
  state='TIDAK ADA'
  if awk -v u="$user" -v now="$now" -v tags="$TYPE" '
    /accepted/ && /email: / {
      split(substr($0,1,19),a,/[/ :]/)
      t=mktime(a[1]" "a[2]" "a[3]" "a[4]" "a[5]" "a[6])
      if(t<=now && t>=now-600 && index($0,"email: "u)>0 && $0 ~ ("email: "u"$") && index($0,"["tags"-")>0) found=1
    }
    END {exit !found}
  ' "$LOG"; then state='ADA AKTIVITAS'; fi
  [[ "$expiry" < "$(date +%F)" ]] && state='EXPIRED'
  printf '%-22s %-15s %-15s\n' "$user" "$expiry" "$state"
done < "$DB"
echo 'Aktivitas 10 menit terakhir; BUKAN sesi online real-time.'
echo 'IP 127.0.0.1 bukan IP asli pelanggan.'
wait_back
