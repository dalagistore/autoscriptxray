#!/bin/bash
set -u
DB="/etc/xray/vless.db"
BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "             PERPANJANG AKUN VLESS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ ! -f "$DB" ]]; then echo "Database VLESS tidak ditemukan."; read -rp "Tekan Enter..."; exit 1; fi
echo
printf '%-20s %-12s\n' "USERNAME" "EXPIRED"
awk 'NF >= 3 {printf "%-20s %-12s\n",$1,$2}' "$DB"
echo
read -rp "Username yang diperpanjang: " user
if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then echo "Format username tidak valid."; read -rp "Tekan Enter..."; exit 1; fi
mapfile -t rows < <(awk -v u="$user" '$1 == u {print $1, $2, $3}' "$DB")
if [[ ${#rows[@]} -ne 1 ]]; then echo -e "${RED}Username tidak ditemukan atau duplikat.${NC}"; read -rp "Tekan Enter..."; exit 1; fi
read -r dbuser oldexp uuid <<< "${rows[0]}"
read -rp "Tambahkan masa aktif (hari): " days
if [[ ! "$days" =~ ^[0-9]+$ ]] || (( days < 1 || days > 3650 )); then echo "Masukkan angka 1 sampai 3650."; read -rp "Tekan Enter..."; exit 1; fi
today=$(date +%F); base="$today"
if date -d "$oldexp" +%F >/dev/null 2>&1 && [[ "$oldexp" > "$today" ]]; then base="$oldexp"; fi
newexp=$(date -d "$base + $days days" +%F) || exit 1
backup="${DB}.bak.$(date +%Y%m%d-%H%M%S)"; tmp=$(mktemp)
if ! cp -a "$DB" "$backup"; then rm -f "$tmp"; echo "Gagal membuat backup."; exit 1; fi
if ! awk -v u="$user" -v e="$newexp" '$1==u {$2=e; found=1} {print} END {if (!found) exit 1}' "$DB" > "$tmp"; then rm -f "$tmp"; echo "Gagal memperbarui database."; exit 1; fi
if ! cat "$tmp" > "$DB"; then cp -a "$backup" "$DB"; rm -f "$tmp"; echo "Gagal menyimpan database. Backup dipulihkan."; exit 1; fi
rm -f "$tmp"
echo; echo -e "${GREEN}Tanggal database berhasil diperbarui.${NC}"
echo "Username     : $user"; echo "Expired lama : $oldexp"; echo "Expired baru : $newexp"; echo "UUID         : $uuid"; echo "Backup       : $backup"
echo; echo "Catatan: tanggal database saja tidak otomatis memblokir UUID di Xray."
read -rp "Tekan Enter untuk kembali..."
