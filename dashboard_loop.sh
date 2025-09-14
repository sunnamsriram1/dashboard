#!/data/data/com.termux/files/usr/bin/bash
# -------------------------
# Dashboard Loop with Real + Tor IP Info + Colors
# -------------------------

TOR_SOCKS_PORT=9050

# ANSI Colors
RED="\033[1;31m"
GREEN="\033[0;32m"
BOLDGREEN="\033[1;32m"
BOLDRED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Function: Check Tor status
get_tor_status() {
    if nc -z 127.0.0.1 $TOR_SOCKS_PORT >/dev/null 2>&1; then
        echo "ON"
    else
        echo "OFF"
    fi
}

# Function: Curl with Tor
tor_curl() {
    curl -s --socks5-hostname 127.0.0.1:$TOR_SOCKS_PORT "$1"
}

# Function: Dashboard loop
dashboard_loop() {
    while true; do
        clear

        # System info
        user_name=$(whoami)
        user_id=$(id -u)
        host_name=$(hostname)
        device_arch=$(uname -m)

        # Real IP
        real_ip=$(curl -s https://ipinfo.io/ip || echo "N/A")

        # Tor IP (only if tor is ON)
        if [[ $(get_tor_status) == "ON" ]]; then
            tor_ip=$(curl -s --socks5-hostname "127.0.0.1:$TOR_SOCKS_PORT" https://ipinfo.io/ip || echo "N/A")
            ipinfo=$(tor_curl "https://ipinfo.io/json" | jq -r '"\(.city), \(.region), \(.country) | \(.org)"')
            tor_status_text="${GREEN}TOR ACTIVE${RESET}"
        else
            tor_ip="N/A"
            ipinfo=$(curl -s https://ipinfo.io/json | jq -r '"\(.city), \(.region), \(.country) | \(.org)"')
            tor_status_text="${RED}TOR OFF${RESET}"
        fi

        # Internet Status
        if curl -s --head https://google.com >/dev/null 2>&1; then
            internet_status="${BOLDGREEN}🌐 Internet: ONLINE${RESET}"
        else
            internet_status="${BOLDRED}📴 Internet: OFFLINE${RESET}"
        fi

        # Current time
        now=$(date "+%Y-%m-%d | %I:%M:%S %p")

        echo -e "${YELLOW}==============================${RESET}"
        echo -e "${YELLOW} LIVE DASHBOARD (Press Q Quit) ${RESET}"
        echo -e "${YELLOW}==============================${RESET}"
        echo -e "👤 User   : ${CYAN}$user_name${RESET} (UID: $user_id)"
        echo -e "💻 Device : ${CYAN}$host_name${RESET} | Arch: $device_arch"
        echo -e "$internet_status"
        echo ""
        echo -e "🌐 Real IP : ${CYAN}$real_ip${RESET}"
        echo -e "🌐 TOR IP  : ${CYAN}$tor_ip${RESET}"
        echo -e "📌 IP Info : ${CYAN}$ipinfo${RESET}"
        echo -e "🌀 TOR Status: $tor_status_text"
        echo ""
        echo -e "⏰ Time: ${YELLOW}$now${RESET}"
        echo -e "${YELLOW}==============================${RESET}"

        # Key input (every 5 sec refresh)
        read -t 5 -n 1 key
        case "$key" in
            [Qq]) exit 0 ;;
        esac
    done
}

# Run Dashboard
dashboard_loop
