#!/usr/bin/env bash
show_dlgst_ssh_info() {
    local user="$1" pass="$2" expiry="$3" duration="$4" kind="$5" file="$6"
    local domain="" ip="" created

    for f in /etc/xray/domain /etc/v2ray/domain /etc/autoscriptvpn/domain; do
        if [[ -s "$f" ]]; then
            domain="$(head -n1 "$f" | tr -d '[:space:]')"
            [[ -n "$domain" ]] && break
        fi
    done
    ip="$(curl -4 -fsS --max-time 3 https://api.ipify.org 2>/dev/null || true)"
    [[ -n "$ip" ]] || ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [[ -n "$ip" ]] || ip="Tidak terdeteksi"
    [[ -n "$domain" ]] || domain="$ip"
    created="$(date '+%Y-%m-%d %H:%M:%S')"

    port_active() {
        ss -H -lntu 2>/dev/null |
        awk -v p="$1" '{n=split($5,a,":"); if(a[n]==p)f=1} END{exit !f}'
    }
    port_status() { port_active "$1" && echo AKTIF || echo TIDAK AKTIF; }
    service_status() { systemctl is-active --quiet "$1" 2>/dev/null && echo RUNNING || echo TIDAK AKTIF; }

    {
        echo "================================================"
        echo "             DLGST - PREMIUM VPN"
        printf "                 SSH %s\n" "$kind"
        echo "================================================"
        echo
        echo "[ INFORMASI AKUN ]"
        printf '%-17s: %s\n' Username "$user"
        printf '%-17s: %s\n' Password "$pass"
        printf '%-17s: %s\n' "IP Server" "$ip"
        printf '%-17s: %s\n' Domain "$domain"
        printf '%-17s: %s\n' "Tanggal dibuat" "$created"
        printf '%-17s: %s\n' Kedaluwarsa "$expiry"
        printf '%-17s: %s\n' Durasi "$duration"
        echo
        echo "[ INFORMASI KONEKSI ]"
        printf '%-17s: %s (%s)\n' OpenSSH 22 "$(port_status 22)"
        printf '%-17s: %s (%s)\n' Dropbear 109,143 "$( { port_active 109 || port_active 143; } && echo AKTIF || echo TIDAK AKTIF)"
        printf '%-17s: %s (%s)\n' "Dropbear WS" 2082 "$(port_status 2082)"
        printf '%-17s: %s (%s)\n' "Stunnel WS" 2096 "$(port_status 2096)"
        printf '%-17s: %s (%s)\n' HTTP 80 "$(port_status 80)"
        printf '%-17s: %s (%s)\n' "HTTPS/Nginx" 443 "$(port_status 443)"
        printf '%-17s: %s/UDP (%s)\n' "UDP Custom" 36712 "$(port_status 36712)"
        printf '%-17s: %s/TCP (LOKAL)\n' "BadVPN UDPGW" 7300
        echo
        echo "[ FORMAT KONEKSI ]"
        echo "SSH       : $domain:22"
        echo "SSH WS    : $domain:2082@$user:$pass"
        echo "SSH WSS   : $domain:2096@$user:$pass"
        echo "UDP Custom: Port 36712/UDP"
        echo
        echo "[ STATUS LAYANAN ]"
        printf '%-17s: %s\n' SSH "$(service_status ssh)"
        printf '%-17s: %s\n' Dropbear "$(service_status dropbear)"
        printf '%-17s: %s\n' Nginx "$(service_status nginx)"
        printf '%-17s: %s\n' "UDP Custom" "$(service_status udp-custom)"
        echo
        echo "================================================"
        echo "          DLGST - PREMIUM VPN"
        echo "================================================"
    } | tee "$file"
}
