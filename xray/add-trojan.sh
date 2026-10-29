#!/bin/bash

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m        Add Trojan Account       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# ambil domain
domain=$(cat /etc/xray/domain)

# public nginx port
tls="443"
grpc="443"

# input user
read -rp "Username : " user
read -rp "Expired (days): " masaaktif

[[ "$user" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'ERROR: Username tidak valid'; exit 1; }
[[ "$masaaktif" =~ ^[0-9]+$ ]] && ((10#$masaaktif >= 1 && 10#$masaaktif <= 3650)) || { echo 'ERROR: Masa aktif harus 1-3650 hari'; exit 1; }
uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# validasi config lama
if ! jq empty /etc/xray/config.json >/dev/null 2>&1; then
    echo ""
    echo "ERROR: config.json invalid!"
    exit 1
fi

# cek duplicate user
CLIENT_EXISTS=$(jq -r '.inbounds[].settings.clients[]?.email' /etc/xray/config.json | grep -w "$user" | wc -l)

if [[ ${CLIENT_EXISTS} -gt 0 ]]; then
    echo ""
    echo "ERROR: User already exists!"
    exit 1
fi

# Cek duplikasi database
if [[ -f /etc/xray/trojan.db ]] && awk -v u="$user" '$1==u {found=1} END{exit !found}' /etc/xray/trojan.db; then
 echo 'ERROR: Username sudah ada di database'; exit 1
fi
# Pastikan semua inbound target tersedia
expected=2
actual=$(jq '[.inbounds[] | select(.tag == "trojan-ws-tls" or .tag == "trojan-ws-nontls" or .tag == "trojan-grpc")] | length' /etc/xray/config.json)
[[ "$actual" -eq "$expected" ]] || { echo "ERROR: inbound trojan tidak lengkap ($actual/$expected)"; exit 1; }
# backup config
cp /etc/xray/config.json /etc/xray/config.json.bak

# temp file
tmpfile=$(mktemp --suffix=.json)

# inject user ke config
if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients) +=
[{"password":$uuid,"email":$user}] |

(.inbounds[] | select(.tag=="trojan-grpc").settings.clients) +=
[{"password":$uuid,"email":$user}]
' /etc/xray/config.json > "$tmpfile"; then

    echo ""
    echo "ERROR: Failed inject config!"
    rm -f "$tmpfile"
    exit 1

fi

# cek file kosong
if [[ ! -s "$tmpfile" ]]; then
    echo ""
    echo "ERROR: Config generated empty!"
    rm -f "$tmpfile"
    exit 1
fi

# validasi json
if ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo ""
    echo "ERROR: Invalid JSON!"
    rm -f "$tmpfile"
    exit 1
fi

# replace config
cat "$tmpfile" > /etc/xray/config.json
rm -f "$tmpfile"

# test config xray
if ! xray -test -config /etc/xray/config.json >/dev/null 2>&1; then

    echo ""
    echo "ERROR: Xray config failed!"
    echo "Restoring backup config..."

    cp /etc/xray/config.json.bak /etc/xray/config.json

    exit 1

fi

# restart xray
systemctl restart xray

# cek status xray
if ! systemctl is-active --quiet xray; then

    echo ""
    echo "ERROR: Xray failed start!"
    echo "Restoring backup config..."

    cp /etc/xray/config.json.bak /etc/xray/config.json

    systemctl restart xray

    exit 1

fi

# simpan database user
echo "${user} ${exp} ${uuid}" >> /etc/xray/trojan.db

# generate trojan link ws
trojanlink1="trojan://${uuid}@${domain}:${tls}?path=%2Ftrojan-ws&security=tls&type=ws&host=${domain}&sni=${domain}#${user}"

# generate trojan grpc
trojanlink2="trojan://${uuid}@${domain}:${grpc}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"

clear

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m       XRAY Trojan ACCOUNT       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "Wildcard       : (bug.com).${domain}"
echo -e "Port TLS       : ${tls}"
echo -e "Port gRPC      : ${grpc}"
echo -e "Password       : ${uuid}"
echo -e "Network        : ws / grpc"
echo -e "Path           : /trojan-ws"
echo -e "ServiceName    : trojan-grpc"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link TLS       :"
echo -e "${trojanlink1}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link gRPC      :"
echo -e "${trojanlink2}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Expired On     : ${exp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

echo ""
echo "Database User  : /etc/xray/trojan.db"
echo ""

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."

m-trojan