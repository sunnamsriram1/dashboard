
#!/data/data/com.termux/files/usr/bin/env bash
# dashboard_loop_fastfetch.sh
# Termux dashboard with random ASCII separator + color (safe)
# Uses fastfetch instead of neofetch

export LANG=en_US.UTF-8
TOR_SOCKS_PORT=9050

# Colors
RED="\033[1;31m"
GREEN="\033[0;32m"
BOLDGREEN="\033[1;32m"
BOLDRED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
MAGENTA="\033[1;35m"
BLUE="\033[1;34m"
WHITE="\033[1;37m"
RESET="\033[0m"

COLORS=("$RED" "$GREEN" "$YELLOW" "$CYAN" "$MAGENTA" "$BLUE" "$WHITE")

# ASCII safe line symbols
LINE_CHARS=("-" "=" "*" "#" "+" "." "~")

HAS_PV=0
HAS_FASTFETCH=0
HAS_JQ=0
command -v pv >/dev/null 2>&1 && HAS_PV=1
command -v fastfetch >/dev/null 2>&1 && HAS_FASTFETCH=1
command -v jq >/dev/null 2>&1 && HAS_JQ=1

# Auto install fastfetch if not installed
if [[ $HAS_FASTFETCH -eq 0 ]]; then
    echo -e "${BOLDGREEN}Fastfetch not found! Installing...${RESET}"
    pkg install fastfetch -y >/dev/null 2>&1
    command -v fastfetch >/dev/null 2>&1 && HAS_FASTFETCH=1
    if [[ $HAS_FASTFETCH -eq 1 ]]; then
        echo -e "${BOLDGREEN}Fastfetch installed successfully!${RESET}"
        sleep 1
    else
        echo -e "${BOLDRED}Failed to install Fastfetch. Exiting.${RESET}"
        exit 1
    fi
fi

curl_safe() { curl -s --max-time 6 "$@" || echo ""; }
tor_curl() { curl -s --socks5-hostname "127.0.0.1:$TOR_SOCKS_PORT" --max-time 8 "$@" || echo ""; }

get_tor_status() {
    if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 "$TOR_SOCKS_PORT" >/dev/null 2>&1; then
        echo "ON"
    else
        echo "OFF"
    fi
}

print_line() {
    local width=$(tput cols 2>/dev/null || echo 80)
    local char=${LINE_CHARS[$((RANDOM % ${#LINE_CHARS[@]}))]}
    local color=${COLORS[$((RANDOM % ${#COLORS[@]}))]}
    printf "%b%${width}s%b\n" "$color" "" "$RESET" | tr ' ' "$char"
}

print_fastfetch_slow() {
    if [[ $HAS_FASTFETCH -eq 1 ]]; then
        ff_output=$(fastfetch 2>/dev/null)

        GREEN_FIELDS=("OS:" "Host:" "Kernel:" "Uptime:" "Packages:" "Shell:" "WM:" "Terminal:" "Terminal Font:" "CPU:" "GPU:" "Memory:" "Swap:" "Disk" "Locale:" "Local IP" "Battery & Temp")

        echo "$ff_output" | while IFS= read -r line; do
            matched=0
            for field in "${GREEN_FIELDS[@]}"; do
                if [[ $line == $field* ]]; then
                    field_name="${line%%:*}:"
                    value="${line#*:}"
                    # Only field name Bold Green, value stays normal (fastfetch default)
                    echo -e "${BOLDGREEN}${field_name}${RESET}${value}"
                    matched=1
                    break
                fi
            done
            if [[ $matched -eq 0 ]]; then
                echo "$line"
            fi
        done | { [[ $HAS_PV -eq 1 ]] && pv -qL 70 || cat; }
    else
        echo -e "${BOLDGREEN}=== Device Info ===${RESET}"
        echo -e "${BOLDGREEN}Packages:${RESET} $(command -v dpkg >/dev/null 2>&1 && dpkg -l 2>/dev/null | wc -l || echo N/A)"
    fi
}

dashboard_loop() {
    sleep 1
    while true; do
        clear
        user_name=$(whoami 2>/dev/null || echo "unknown")
        user_id=$(id -u 2>/dev/null || echo "?")
        host_name=$(hostname 2>/dev/null || echo "localhost")
        device_arch=$(uname -m 2>/dev/null || echo "?")

        real_ip=$(curl_safe https://ipinfo.io/ip)
        [[ -z "$real_ip" ]] && real_ip="N/A"

        if [[ $(get_tor_status) == "ON" ]]; then
            tor_ip=$(tor_curl https://ipinfo.io/ip)
            [[ -z "$tor_ip" ]] && tor_ip="N/A"
            [[ $HAS_JQ -eq 1 ]] && ipinfo=$(tor_curl https://ipinfo.io/json | jq -r '"\(.city), \(.region), \(.country) | \(.org)"') || ipinfo="N/A"
            tor_status_text="${GREEN}TOR ACTIVE${RESET}"
        else
            tor_ip="N/A"
            [[ $HAS_JQ -eq 1 ]] && ipinfo=$(curl_safe https://ipinfo.io/json | jq -r '"\(.city), \(.region), \(.country) | \(.org)"') || ipinfo="N/A"
            tor_status_text="${RED}TOR OFF${RESET}"
        fi

        [[ $(curl -s --head --max-time 3 https://google.com >/dev/null 2>&1; echo $?) -eq 0 ]] && internet_status="${BOLDGREEN}🌐 Internet: ONLINE ACTIVATED${RESET}" || internet_status="${BOLDRED}📴 Internet: OFFLINE DEACTIVATED${RESET}"

        now=$(date "+%Y-%m-%d | %I:%M:%S %p")
        printf "\n\n\n"

        print_fastfetch_slow
        printf "\n"

        print_line
        echo -e "${GREEN}🔴 LIVE DASHBOARD (Press Q to Quit)${RESET}"
        print_line

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

        print_line

        read -t 5 -n 1 key 2>/dev/null
        case "$key" in
            [Qq]) clear; exit 0 ;;
        esac
    done
}

dashboard_loop
