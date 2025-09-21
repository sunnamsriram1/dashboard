#!/data/data/com.termux/files/usr/bin/env bash
# dashboard_loop.sh — Termux dashboard (Upgraded version)
# Features: CPU/RAM bars, Disk usage %, Net speed, Interactive menu

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

# ==== New Helper Functions ====

progress_bar() {
    local value=$1
    local total=100
    local bar_len=20
    local filled=$(( (value * bar_len) / total ))
    local empty=$(( bar_len - filled ))
    local color=$GREEN
    [[ $value -ge 70 ]] && color=$YELLOW
    [[ $value -ge 90 ]] && color=$RED
    printf "%b[%s%s]%b %d%%" "$color" "$(printf '%0.s#' $(seq 1 $filled))" "$(printf '%0.s.' $(seq 1 $empty))" "$RESET" "$value"
}

get_cpu_usage() {
    top -bn1 | grep -m1 "CPU" | awk '{print 100-$8}' 2>/dev/null || echo 0
}

get_mem_usage() {
    free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo 0
}

get_disk_usage() {
    df /data/data/com.termux/files/home | awk 'NR==2 {print $5}' | tr -d '%' || echo 0
}


# ====== Mobile-friendly Net Speed ======
get_net_speed() {
    local url="https://www.google.com/images/branding/googlelogo/2x/googlelogo_light_color_92x30dp.png"
    local tmpfile=$(mktemp)
    local start=$(date +%s%3N)   # milliseconds
    curl -o "$tmpfile" -s --max-time 5 "$url"
    local end=$(date +%s%3N)
    local elapsed_ms=$((end - start))
    [[ $elapsed_ms -eq 0 ]] && elapsed_ms=1
    local size_bytes=$(stat -c%s "$tmpfile" 2>/dev/null || echo 50000)
    rm -f "$tmpfile"

    local kbps=$(( size_bytes*1000/elapsed_ms/1024 ))
    local mbps=$(awk "BEGIN {printf \"%.2f\", $kbps/1024*8}")

    # Visual meter
    local bar_len=20
    local speed_percent=$(( kbps > 1024 ? 100 : kbps*100/1024 ))
    local filled=$(( (speed_percent * bar_len)/100 ))
    local empty=$(( bar_len - filled ))
    local color=$GREEN
    [[ $speed_percent -ge 70 ]] && color=$YELLOW
    [[ $speed_percent -ge 90 ]] && color=$RED
    local bar=$(printf "%0.s#" $(seq 1 $filled))$(printf "%0.s." $(seq 1 $empty))

    echo "${kbps} KB/s | ${mbps} Mbps [${color}${bar}${RESET}]"
}

# ==============================

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

        #now=$(date "+%Y-%m-%d | %I:%M:%S %p")
        #!/data/data/com.termux/files/usr/bin/env bash
        # Example: Current date + day-of-year display



        # ---- Time + Day-of-Year + Countdown ----
        now=$(date "+%Y-%m-%d | %I:%M:%S %p")
        day_of_year=$(date "+%j")
        day_of_week=$(date "+%A")

        CURRENT_YEAR=$(date "+%Y")
        TARGET_DATE="$CURRENT_YEAR-12-31"
        if [[ $(date -d "$TARGET_DATE" +%s) -lt $(date +%s) ]]; then                                                                                                NEXT_YEAR=$((CURRENT_YEAR + 1))
            TARGET_DATE="$NEXT_YEAR-12-31"
        fi
        target_ts=$(date -d "$TARGET_DATE" "+%s")
        current_ts=$(date "+%s")
        target_days_left=$(( (target_ts - current_ts) / 86400 ))
        printf "\n\n"

        print_fastfetch_slow
        printf "\n"
        sleep 2
        print_line
        echo -e "${GREEN}🔴 LIVE DASHBOARD (Press N=New Shell, L=Logs, C=Clear, Q=Quit)${RESET}"
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
       # echo -e "⏰ Time: ${YELLOW}$now${RESET} | Day of Year: ${GREEN}$day_of_year${RESET}"
        #echo -e "⏰ Time: ${YELLOW}$now${RESET}"
        echo -e "⏰ Time: ${YELLOW}$now${RESET} | Day-of-Year: ${CYAN}$day_of_year${RESET} | ${BOLDGREEN}$day_of_week${RESET}"
        echo -e "📅 Countdown to Dec 31: ${BOLDGREEN}$target_days_left days${RESET}"
        # ==== New Metrics ====
        cpu=$(get_cpu_usage)
        mem=$(get_mem_usage)
        disk=$(get_disk_usage)
        speed=$(get_net_speed)

        echo -ne "⚙️  CPU Usage : "; progress_bar $cpu; echo
        echo -ne "🧠 RAM Usage : "; progress_bar $mem; echo
        echo -ne "💾 Disk Usage: "; progress_bar $disk; echo
        echo -e "📡 Net Speed : ${CYAN}$speed${RESET}"

        print_line

        read -t 5 -n 1 key 2>/dev/null
        case "$key" in
            [Qq]) clear; exit 0 ;;
            [Nn]) bash ;; # new shell
            [Ll]) less +G ~/dashboard_logs/*.log 2>/dev/null || echo "No logs yet"; sleep 2 ;;
            [Cc]) rm -rf ~/../usr/tmp/* 2>/dev/null; echo "Cache Cleared!"; sleep 2 ;;
        esac
    done
}

dashboard_loop
