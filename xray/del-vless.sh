#!/bin/bash
set -u
CONFIG="/etc/xray/config.json"
DB="/etc/xray/vless.db"
TAGS='["vless-ws-tls","vless-ws-nontls","vless-grpc"]'
BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
pause_back(){ echo; read -rp "Tekan Enter untuk kembali ke menu VLESS..."; }
clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "                HAPUS AKUN VLESS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ $EUID -ne 0 ]]; then echo "Jalankan skrip sebagai root."; pause_back; exit 1; fi
if [[ ! -f "$CONFIG" || ! -f "$DB" ]]; then echo "Konfigurasi atau database VLESS tidak ditemukan."; pause_back; exit 1; fi
if ! jq empty "$CONFIG" >/dev/null 2>&1; then echo "config.json tidak valid. Tidak ada perubahan."; pause_back; exit 1; fi
echo
printf '%-20s %-12s\n' "USERNAME" "EXPIRED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
awk 'NF >= 3 {printf "%-20s %-12s\n",$1,$2}' "$DB"
echo
read -rp "Masukkan username yang ingin dihapus: " user
if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then echo "Format username tidak valid."; pause_back; exit 1; fi
mapfile -t rows < <(awk -v u="$user" '$1 == u {print $1, $2, $3}' "$DB")
if [[ ${#rows[@]} -ne 1 ]]; then echo "Username tidak ditemukan atau tercatat lebih dari sekali."; pause_back; exit 1; fi
read -r dbuser expiry uuid <<< "${rows[0]}"
if [[ ! "$uuid" =~ ^[a-fA-F0-9-]{36}$ ]]; then echo "UUID database tidak valid."; pause_back; exit 1; fi
if ! jq -e --arg uuid "$uuid" --argjson tags "$TAGS" '[.inbounds[] | select(.tag as $t | $tags | index($t)) | .settings.clients[]? | select(.id==$uuid)] | length > 0' "$CONFIG" >/dev/null 2>&1; then
    echo "UUID tidak ditemukan di inbound VLESS. Database tidak diubah."; pause_back; exit 1
fi
echo
echo "Username : $dbuser"; echo "Expired  : $expiry"; echo "UUID     : $uuid"; echo
read -rp "Yakin ingin menghapus akun ini? Ketik HAPUS untuk melanjutkan: " confirm
if [[ "$confirm" != "HAPUS" ]]; then echo "Penghapusan dibatalkan."; pause_back; exit 0; fi
stamp=$(date +%Y%m%d-%H%M%S)
backup_config="${CONFIG}.bak.${stamp}"; backup_db="${DB}.bak.${stamp}"
if ! cp -a "$CONFIG" "$backup_config" || ! cp -a "$DB" "$backup_db"; then echo "Gagal membuat backup."; pause_back; exit 1; fi
tmp_config=$(mktemp --suffix=.json); tmp_db=$(mktemp)
trap 'rm -f "$tmp_config" "$tmp_db"' EXIT
if ! jq --arg uuid "$uuid" --argjson tags "$TAGS" '.inbounds |= map(if (.tag as $t | $tags | index($t)) then .settings.clients=[.settings.clients[]? | select(.id!=$uuid)] else . end)' "$CONFIG" > "$tmp_config"; then echo "Gagal memproses konfigurasi."; pause_back; exit 1; fi
if ! jq empty "$tmp_config" >/dev/null 2>&1 || ! xray -test -config "$tmp_config"; then echo "Validasi Xray gagal. Konfigurasi asli tetap dipakai."; pause_back; exit 1; fi
if ! awk -v u="$user" '$1 != u' "$DB" > "$tmp_db"; then echo "Gagal menyiapkan database."; pause_back; exit 1; fi
if ! cat "$tmp_config" > "$CONFIG"; then cp -a "$backup_config" "$CONFIG"; echo "Gagal menerapkan konfigurasi."; pause_back; exit 1; fi
if ! systemctl restart xray || ! systemctl is-active --quiet xray; then
    echo "Xray gagal aktif. Memulihkan konfigurasi."
    cp -a "$backup_config" "$CONFIG"; systemctl restart xray; pause_back; exit 1
fi
if ! cat "$tmp_db" > "$DB"; then
    echo "Gagal memperbarui database. Memulihkan backup."
    cp -a "$backup_config" "$CONFIG"; cp -a "$backup_db" "$DB"; systemctl restart xray; pause_back; exit 1
fi
echo; echo -e "${GREEN}Akun VLESS berhasil dihapus.${NC}"
echo "Username        : $user"; echo "Backup config   : $backup_config"; echo "Backup database: $backup_db"
echo "Status Xray     : $(systemctl is-active xray)"
pause_back
