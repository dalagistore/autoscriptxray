#!/bin/bash
# DLGST XRAY PANEL - UI layout correction
# Menu commands and operational functions are preserved.

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
    printf "${CYAN}➜ %s${NC}" "$text"
    for i in {1..3}; do printf "."; sleep 0.25; done
    printf "\n"
}

type_text() {
    local delay="${2:-0.02}"
    while IFS= read -r -n1 char; do
        printf "%s" "$char"
        sleep "$delay"
    done
    printf "\n"
}

box_top() {
    local color="$1" title="$2"
    printf "${color}┌─ %s " "$title"
    local used=$((3 + ${#title} + 1))
    local remain=$((58 - used))
    (( remain < 0 )) && remain=0
    printf '%*s' "$remain" '' | tr ' ' '─'
    printf "┐${NC}\n"
}

box_bottom() {
    local color="$1"
    printf "${color}└"
    printf '%58s' '' | tr ' ' '─'
    printf "┘${NC}\n"
}

box_row() {
    local color="$1" text="$2"
    # Keep all rows the same visible width; truncate unusually long values.
    printf "${color}│${NC} %-58.58s ${color}│${NC}\n" "$text"
}

status_word() {
    if [[ "$1" == "active" ]]; then
        printf "${GREEN}● ONLINE${NC}"
    else
        printf "${RED}● OFFLINE${NC}"
    fi
}

# ================= SYSTEM INFO =================

IP=$(curl -s --max-time 3 ipv4.icanhazip.com)
[[ -z "$IP" ]] && IP="Unknown"
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
ISP=$(curl -s --max-time 3 ipinfo.io/org | cut -d " " -f2-)
[[ -z "$ISP" ]] && ISP="Unknown"
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "Unknown")
TIME=$(date "+%d-%m-%Y %H:%M:%S")
OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2+$4"%"}')
[[ -z "$CPU" ]] && CPU="N/A"
RAM=$(free -m | awk 'NR==2{printf "%sMB / %sMB",$3,$2}')
DISK=$(df -h / | awk 'NR==2{print $3 "/" $2}')

# ================= NETWORK =================

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
MONTH_NAME=$(date +"%Y-%m")
TODAY=$(vnstat -i "$IFACE" 2>/dev/null | awk '/today/ {print $8" "$9}')
YESTERDAY=$(vnstat -i "$IFACE" 2>/dev/null | awk '/yesterday/ {print $8" "$9}')
MONTH=$(vnstat -i "$IFACE" 2>/dev/null | awk -v m="$MONTH_NAME" '$1 ~ m {print $8" "$9}')
TOTAL_BW=$(vnstat --oneline 2>/dev/null | cut -d';' -f15)
[[ -z "$TODAY" ]] && TODAY="0 B"
[[ -z "$YESTERDAY" ]] && YESTERDAY="0 B"
[[ -z "$MONTH" ]] && MONTH="0 B"
[[ -z "$TOTAL_BW" ]] && TOTAL_BW="0 B"

# ================= SERVICE STATUS =================

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
ONLINE=$(tail -n 500 "$LOG" 2>/dev/null | grep -Eo 'tcp:[0-9]+.[0-9]+.[0-9]+.[0-9]+' | cut -d':' -f2 | sort -u | wc -l)

# ================= STARTUP =================

clear
printf "${RED}"
printf "⚡ Loading DLGST XRAY PANEL ⚡" | type_text
printf "${NC}"
loading "Loading system modules"
loading "Checking services"
loading "Reading traffic database"
printf "${GREEN}✔ System ready!${NC}\n"
sleep 1
clear

# ================= HEADER =================

printf "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}\n"
printf "${CYAN}║${WHITE}                 ⚡ DLGST XRAY PANEL ⚡                  ${CYAN}║${NC}\n"
printf "${CYAN}║${WHITE}                       Version %-8s                      ${CYAN}║${NC}\n" "$PANEL_VERSION"
printf "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

# ================= SYSTEM INFO =================

box_top "$YELLOW" "SYSTEM INFORMATION"
box_row "$YELLOW" "IP VPS       : $IP"
box_row "$YELLOW" "DOMAIN       : $DOMAIN"
box_row "$YELLOW" "ISP          : $ISP"
box_row "$YELLOW" "OPERATING OS : $OS"
box_row "$YELLOW" "UPTIME       : $UPTIME"
box_row "$YELLOW" "CPU USAGE    : $CPU"
box_row "$YELLOW" "RAM USAGE    : $RAM"
box_row "$YELLOW" "DISK USAGE   : $DISK"
box_row "$YELLOW" "SERVER TIME  : $TIME"
box_bottom "$YELLOW"

# ================= BANDWIDTH =================

box_top "$CYAN" "NETWORK BANDWIDTH"
box_row "$CYAN" "TODAY      : $TODAY          YESTERDAY : $YESTERDAY"
box_row "$CYAN" "THIS MONTH : $MONTH          TOTAL     : $TOTAL_BW"
box_bottom "$CYAN"

# ================= USER STATS =================

box_top "$CYAN" "USER STATISTICS"
box_row "$CYAN" "VMESS : $VMESS       VLESS : $VLESS       TROJAN : $TROJAN"
box_row "$CYAN" "SSWS  : $SSWS        SSH   : $SSH_USER    ZIVPN  : $ZIVPN_USER"
box_row "$CYAN" "TOTAL USERS : $TOTAL                  ONLINE IP : $ONLINE"
box_bottom "$CYAN"

# ================= SERVICE STATUS =================

box_top "$BLUE" "SERVICE STATUS"
box_row "$BLUE" "XRAY       : $( [[ "$XRAY" == active ]] && echo '● ONLINE' || echo '● OFFLINE' )"
box_row "$BLUE" "NGINX      : $( [[ "$NGINX" == active ]] && echo '● ONLINE' || echo '● OFFLINE' )"
box_row "$BLUE" "DROPBEAR   : $( [[ "$DROPBEAR" == active ]] && echo '● ONLINE' || echo '● OFFLINE' )"
box_row "$BLUE" "WIREGUARD  : $( [[ "$WG" == active ]] && echo '● ONLINE' || echo '● OFFLINE' )"
box_row "$BLUE" "UDP CUSTOM : $( [[ "$UDPCUSTOM" == active ]] && echo '● ONLINE' || echo '● OFFLINE' )"
box_row "$BLUE" "UDP ZIVPN  : $( [[ "$ZIVPN" == active ]] && echo '● ONLINE' || echo '● OFFLINE' )"
box_row "$BLUE" "SSH WS     : $( [[ "$DROPBEARWS" == active ]] && echo '● ONLINE' || echo '● OFFLINE' )"
box_row "$BLUE" "SSL WS     : $( [[ "$STUNNELWS" == active ]] && echo '● ONLINE' || echo '● OFFLINE' )"
box_bottom "$BLUE"

# ================= MAIN MENU =================

box_top "$RED" "MAIN MENU"
box_row "$RED" "[1]  SSH ACCOUNT                 [8]  TOOLS"
box_row "$RED" "[2]  VMESS                       [9]  STATUS"
box_row "$RED" "[3]  VLESS                       [10] CLEAR RAM"
box_row "$RED" "[4]  TROJAN                      [11] REBOOT VPS"
box_row "$RED" "[5]  SHADOWSOCKS WS              [12] UNINSTALL"
box_row "$RED" "[6]  WIREGUARD                   [13] UDP CUSTOM"
box_row "$RED" "[7]  UDP ZIVPN                   [X]  EXIT"
box_bottom "$RED"

# ================= LICENSE =================

box_top "$GREEN" "LICENSE INFORMATION"
box_row "$GREEN" "LICENSE      : DLGST-ULTIMATE-2026"
box_row "$GREEN" "LICENSE TYPE : Lifetime Premium"
box_bottom "$GREEN"

printf "\n${YELLOW}Select menu [1-13/X] : ${NC}"
read -r menu

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
        printf "${RED}❌ Invalid menu!${NC}\n"
        sleep 1
        exec "$0"
        ;;
esac
