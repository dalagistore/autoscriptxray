#!/bin/bash

# DLGST XRAY PANEL
# UI refresh only: menu actions and existing commands are preserved.

# ================= COLOR =================
PANEL_VERSION="v2.1.1"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"
LOG="/var/log/xray/access.log"

# ================= UI HELPERS =================

loading() {
    local text="$1"
    echo -ne "${CYAN}  ➜ ${text}${NC}"
    for i in {1..3}; do
        echo -ne "."
        sleep 0.35
    done
    echo ""
}

type_text() {
    local delay="${2:-0.02}"
    while IFS= read -r -n1 char; do
        printf "%s" "$char"
        sleep "$delay"
    done
    echo
}

line() {
    local color="$1"
    printf "${color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

section() {
    local title="$1"
    local color="$2"
    echo
    printf "${color}┌─ %-56s┐${NC}\n" "$title"
}

section_end() {
    local color="$1"
    printf "${color}└──────────────────────────────────────────────────────────┘${NC}\n"
}

status_label() {
    if [[ "$1" == "active" ]]; then
        printf "${GREEN}● ONLINE${NC}"
    else
        printf "${RED}● OFFLINE${NC}"
    fi
}

# ================= SYSTEM INFO =================

IP=$(curl -s ipv4.icanhazip.com)
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")

ISP=$(curl -s --max-time 3 ipinfo.io/org | cut -d " " -f2-)
[[ -z "$ISP" ]] && ISP="Unknown"

UPTIME=$(uptime -p | sed 's/up //')
TIME=$(date "+%d-%m-%Y %H:%M:%S")

OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4"%"}')

RAM=$(free -m | awk 'NR==2{printf "%sMB / %sMB",$3,$2}')

DISK=$(df -h / | awk 'NR==2{print $3 "/" $2}')

# ================= NETWORK =================

IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

MONTH_NAME=$(date +"%Y-%m")

TODAY=$(vnstat -i "$IFACE" 2>/dev/null | awk '/today/ {print $8" "$9}')
YESTERDAY=$(vnstat -i "$IFACE" 2>/dev/null | awk '/yesterday/ {print $8" "$9}')
MONTH=$(vnstat -i "$IFACE" 2>/dev/null | awk -v m="$MONTH_NAME" '$1 ~ m {print $8" "$9}')
TOTAL_BW=$(vnstat --oneline 2>/dev/null | cut -d';' -f15)

[[ -z "$TODAY" ]] && TODAY="0 B"
[[ -z "$YESTERDAY" ]] && YESTERDAY="0 B"
[[ -z "$MONTH" ]] && MONTH="0 B"
[[ -z "$TOTAL_BW" ]] && TOTAL_BW="0 B"

# ================= STATUS =================

XRAY=$(systemctl is-active xray 2>/dev/null)
NGINX=$(systemctl is-active nginx 2>/dev/null)
WG=$(systemctl is-active wg-quick@wg0 2>/dev/null)
ZIVPN=$(systemctl is-active zivpn 2>/dev/null)
UDPCUSTOM=$(systemctl is-active udp-custom 2>/dev/null)
DROPBEARWS=$(systemctl is-active dropbear-ws 2>/dev/null)
STUNNELWS=$(systemctl is-active stunnel-ws 2>/dev/null)
DROPBEAR=$(systemctl is-active dropbear 2>/dev/null)

# ================= USER COUNT =================

VMESS=$(jq '[.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients[]] | length' "$CONFIG" 2>/dev/null)
VLESS=$(jq '[.inbounds[] | select(.tag=="vless-ws-tls").settings.clients[]] | length' "$CONFIG" 2>/dev/null)
TROJAN=$(jq '[.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients[]] | length' "$CONFIG" 2>/dev/null)
SSWS=$(jq '[.inbounds[] | select(.tag=="ssws-ws-tls").settings.clients[]] | length' "$CONFIG" 2>/dev/null)

[[ -z "$VMESS" ]] && VMESS=0
[[ -z "$VLESS" ]] && VLESS=0
[[ -z "$TROJAN" ]] && TROJAN=0
[[ -z "$SSWS" ]] && SSWS=0

ZIVPN_USER=$(grep -vc '^$' /etc/zivpn/users.db 2>/dev/null)
[[ -z "$ZIVPN_USER" ]] && ZIVPN_USER=0

SSH_USER=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)
TOTAL=$((VMESS + VLESS + TROJAN + SSWS + ZIVPN_USER + SSH_USER))

ONLINE=$(tail -n 500 "$LOG" 2>/dev/null |
    grep -Eo 'tcp:[0-9]+.[0-9]+.[0-9]+.[0-9]+' |
    cut -d':' -f2 | sort -u | wc -l)

# ================= INIT =================

clear
echo
echo -ne "${RED}"
printf "⚡ Loading DLGST XRAY PANEL ⚡" | type_text
echo -e "${NC}"
loading "Loading system modules"
loading "Checking services"
loading "Reading traffic database"
echo
echo -e "${GREEN}  ✔ System ready!${NC}"
sleep 1
clear

# ================= HEADER =================

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                    ⚡ DLGST XRAY PANEL ⚡                 ${CYAN}║${NC}"
printf "${CYAN}║${WHITE}                     Version %-8s                       ${CYAN}║${NC}\n" "$PANEL_VERSION"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

# ================= SYSTEM INFO =================

section "SYSTEM INFORMATION" "$YELLOW"
printf "${YELLOW}│${NC}  ${WHITE}IP VPS       ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$IP"
printf "${YELLOW}│${NC}  ${WHITE}DOMAIN       ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$DOMAIN"
printf "${YELLOW}│${NC}  ${WHITE}ISP          ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$ISP"
printf "${YELLOW}│${NC}  ${WHITE}OPERATING OS ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$OS"
printf "${YELLOW}│${NC}  ${WHITE}UPTIME       ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$UPTIME"
printf "${YELLOW}│${NC}  ${WHITE}CPU USAGE    ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$CPU"
printf "${YELLOW}│${NC}  ${WHITE}RAM USAGE    ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$RAM"
printf "${YELLOW}│${NC}  ${WHITE}DISK USAGE   ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$DISK"
printf "${YELLOW}│${NC}  ${WHITE}SERVER TIME  ${NC}: %-42.42s ${YELLOW}│${NC}\n" "$TIME"
section_end "$YELLOW"

# ================= BANDWIDTH =================

section "NETWORK BANDWIDTH" "$CYAN"
printf "${CYAN}│${NC}  ${WHITE}TODAY      ${NC}: %-18.18s ${WHITE}YESTERDAY ${NC}: %-18.18s ${CYAN}│${NC}\n" "$TODAY" "$YESTERDAY"
printf "${CYAN}│${NC}  ${WHITE}THIS MONTH ${NC}: %-18.18s ${WHITE}TOTAL     ${NC}: %-18.18s ${CYAN}│${NC}\n" "$MONTH" "$TOTAL_BW"
section_end "$CYAN"

# ================= USER STATS =================

section "USER STATISTICS" "$CYAN"
printf "${CYAN}│${NC}  ${WHITE}VMESS  ${NC}: %-5s  ${WHITE}VLESS ${NC}: %-5s  ${WHITE}TROJAN ${NC}: %-5s ${CYAN}│${NC}\n" "$VMESS" "$VLESS" "$TROJAN"
printf "${CYAN}│${NC}  ${WHITE}SSWS   ${NC}: %-5s  ${WHITE}SSH   ${NC}: %-5s  ${WHITE}ZIVPN  ${NC}: %-5s ${CYAN}│${NC}\n" "$SSWS" "$SSH_USER" "$ZIVPN_USER"
printf "${CYAN}│${NC}  ${WHITE}TOTAL USERS ${NC}: %-8s  ${WHITE}ONLINE IP ${NC}: %-8s ${CYAN}│${NC}\n" "$TOTAL" "$ONLINE"
section_end "$CYAN"

# ================= SERVICE STATUS =================

section "SERVICE STATUS" "$BLUE"
printf "${BLUE}│${NC}  ${WHITE}XRAY       ${NC}: %-20b ${WHITE}NGINX       ${NC}: %-20b ${BLUE}│${NC}\n" "$(status_label "$XRAY")" "$(status_label "$NGINX")"
printf "${BLUE}│${NC}  ${WHITE}DROPBEAR   ${NC}: %-20b ${WHITE}WIREGUARD   ${NC}: %-20b ${BLUE}│${NC}\n" "$(status_label "$DROPBEAR")" "$(status_label "$WG")"
printf "${BLUE}│${NC}  ${WHITE}UDP CUSTOM ${NC}: %-20b ${WHITE}UDP ZIVPN   ${NC}: %-20b ${BLUE}│${NC}\n" "$(status_label "$UDPCUSTOM")" "$(status_label "$ZIVPN")"
printf "${BLUE}│${NC}  ${WHITE}SSH WS     ${NC}: %-20b ${WHITE}SSL WS      ${NC}: %-20b ${BLUE}│${NC}\n" "$(status_label "$DROPBEARWS")" "$(status_label "$STUNNELWS")"
section_end "$BLUE"

# ================= MAIN MENU =================

section "MAIN MENU" "$RED"
printf "${RED}│${NC}  [1]  ${WHITE}SSH ACCOUNT${NC}                 [8]  ${WHITE}TOOLS${NC}                  ${RED}│${NC}\n"
printf "${RED}│${NC}  [2]  ${WHITE}VMESS${NC}                       [9]  ${WHITE}STATUS${NC}                 ${RED}│${NC}\n"
printf "${RED}│${NC}  [3]  ${WHITE}VLESS${NC}                       [10] ${WHITE}CLEAR RAM${NC}              ${RED}│${NC}\n"
printf "${RED}│${NC}  [4]  ${WHITE}TROJAN${NC}                      [11] ${WHITE}REBOOT VPS${NC}             ${RED}│${NC}\n"
printf "${RED}│${NC}  [5]  ${WHITE}SHADOWSOCKS WS${NC}              [12] ${WHITE}UNINSTALL${NC}              ${RED}│${NC}\n"
printf "${RED}│${NC}  [6]  ${WHITE}WIREGUARD${NC}                   [13] ${WHITE}UDP CUSTOM${NC}             ${RED}│${NC}\n"
printf "${RED}│${NC}  [7]  ${WHITE}UDP ZIVPN${NC}                   [X]  ${WHITE}EXIT${NC}                   ${RED}│${NC}\n"
section_end "$RED"

# ================= LICENSE =================

section "LICENSE INFORMATION" "$GREEN"
printf "${GREEN}│${NC}  ${WHITE}LICENSE      ${NC}: %-43s ${GREEN}│${NC}\n" "DLGST-ULTIMATE-2026"
printf "${GREEN}│${NC}  ${WHITE}LICENSE TYPE ${NC}: %-43s ${GREEN}│${NC}\n" "Lifetime Premium"
section_end "$GREEN"

echo
read -rp "$(echo -e "${YELLOW}  Select menu [1-13/X] : ${NC}")" menu

case $menu in
1) m-ssh ;;
2) m-vmess ;;
3) m-vless ;;
4) m-trojan ;;
5) m-ssws ;;
6) m-wg ;;
7) m-zivpn ;;
8) tools-menu ;;
9) running ;;
10) clearcache ;;
11) reboot ;;
12) bash /root/uninstall.sh ;;
13) systemctl status udp-custom ;;
x|X) exit ;;
*)
    echo -e "${RED}  ❌ Invalid menu!${NC}"
    sleep 1
    exec "$0"
    ;;
esac
