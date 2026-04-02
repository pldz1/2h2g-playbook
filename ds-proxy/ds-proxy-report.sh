#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  ds-proxy Health & Memory Report
#  Usage: bash ds-proxy-report.sh
#         bash ds-proxy-report.sh --watch   (repeat every 30s)
# ═══════════════════════════════════════════════════════════════

CONTAINER="ds-proxy"
WATCH_MODE=false
WATCH_INTERVAL=30

[[ "$1" == "--watch" ]] && WATCH_MODE=true

# ── Auto-detect if sudo is needed for docker ─────────────────
DOCKER="docker"
if ! docker info &>/dev/null 2>&1; then
  if sudo docker info &>/dev/null 2>&1; then
    DOCKER="sudo docker"
  else
    echo -e "${RED}✗ Cannot connect to Docker daemon (tried with and without sudo)${RESET}"
    exit 1
  fi
fi

# ── Colors ────────────────────────────────────────────────────
RED=$'\033[0;31m'; YELLOW=$'\033[1;33m'; GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

# ── Thresholds ────────────────────────────────────────────────
WARN_RSS_MB=200
CRIT_RSS_MB=400
WARN_FD=1000
CRIT_FD=3000
WARN_TIMEWAIT=500
CRIT_TIMEWAIT=2000

status_color() {
  local val=$1 warn=$2 crit=$3
  if   (( val >= crit )); then echo -e "${RED}${val}${RESET}"
  elif (( val >= warn )); then echo -e "${YELLOW}${val}${RESET}"
  else                         echo -e "${GREEN}${val}${RESET}"
  fi
}

run_report() {
  clear
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}  ds-proxy Health Report  —  $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════${RESET}"

  # ── Check container is running ───────────────────────────────
  if ! $DOCKER inspect "$CONTAINER" &>/dev/null; then
    echo -e "${RED}✗ Container '$CONTAINER' not found${RESET}"
    return 1
  fi

  STATUS=$($DOCKER inspect --format '{{.State.Status}}' "$CONTAINER")
  if [[ "$STATUS" != "running" ]]; then
    echo -e "${RED}✗ Container is $STATUS (not running)${RESET}"
    return 1
  fi
  echo -e "\n${BOLD}● Container:${RESET} ${GREEN}running${RESET}"

  # ── Memory ───────────────────────────────────────────────────
  echo -e "\n${BOLD}${CYAN}─── Memory ────────────────────────────────────${RESET}"

  VM=$(docker exec "$CONTAINER" cat /proc/1/status 2>/dev/null)
  RSS_KB=$(echo "$VM" | awk '/VmRSS/{print $2}')
  PEAK_KB=$(echo "$VM" | awk '/VmPeak/{print $2}')
  SWAP_KB=$(echo "$VM" | awk '/VmSwap/{print $2}')
  RSS_MB=$(( RSS_KB / 1024 ))
  PEAK_MB=$(( PEAK_KB / 1024 ))
  SWAP_MB=$(( SWAP_KB / 1024 ))

  echo -e "  RSS (actual RAM used) : $(status_color $RSS_MB $WARN_RSS_MB $CRIT_RSS_MB) MB"
  echo -e "  Peak RSS ever         : ${PEAK_MB} MB"
  echo -e "  Swap used             : $(status_color $SWAP_MB 50 200) MB"

  # docker stats snapshot
  STATS=$(docker stats "$CONTAINER" --no-stream --format "{{.MemUsage}} | {{.MemPerc}} | {{.CPUPerc}}")
  echo -e "  Docker reported       : ${STATS}"

  # smaps_rollup breakdown
  SMAPS=$(docker exec "$CONTAINER" cat /proc/1/smaps_rollup 2>/dev/null)
  ANON_KB=$(echo "$SMAPS"  | awk '/^Anonymous/{print $2}')
  FILE_KB=$(echo "$SMAPS"  | awk '/^Pss_File/{print $2}')
  ANON_MB=$(( ANON_KB / 1024 ))
  FILE_MB=$(( FILE_KB / 1024 ))
  echo -e "  Anonymous (heap/stack): ${ANON_MB} MB"
  echo -e "  File-backed (code/lib): ${FILE_MB} MB"

  # host free memory
  echo -e "\n${BOLD}  Host memory:${RESET}"
  free -m | awk '
    /^Mem/  { printf "  RAM  — used: %dMB  free: %dMB  available: %dMB\n", $3,$4,$7 }
    /^Swap/ { printf "  Swap — used: %dMB  free: %dMB\n", $3,$4 }
  '

  # ── File Descriptors ─────────────────────────────────────────
  echo -e "\n${BOLD}${CYAN}─── File Descriptors ──────────────────────────${RESET}"
  FD_COUNT=$(docker exec "$CONTAINER" ls /proc/1/fd 2>/dev/null | wc -l)
  echo -e "  Open FDs : $(status_color $FD_COUNT $WARN_FD $CRIT_FD)"

  # ── TCP Connections ──────────────────────────────────────────
  echo -e "\n${BOLD}${CYAN}─── TCP Connections ───────────────────────────${RESET}"

  TCP=$(docker exec "$CONTAINER" cat /proc/net/tcp 2>/dev/null)
  TOTAL_TCP=$(echo "$TCP" | tail -n +2 | wc -l)

  declare -A STATE_NAME
  STATE_NAME[01]="ESTABLISHED" STATE_NAME[02]="SYN_SENT"
  STATE_NAME[03]="SYN_RECV"   STATE_NAME[04]="FIN_WAIT1"
  STATE_NAME[05]="FIN_WAIT2"  STATE_NAME[06]="TIME_WAIT"
  STATE_NAME[07]="CLOSE"      STATE_NAME[08]="CLOSE_WAIT"
  STATE_NAME[09]="LAST_ACK"   STATE_NAME[0A]="LISTEN"
  STATE_NAME[0B]="CLOSING"

  echo -e "  Total TCP entries : ${TOTAL_TCP}"
  echo ""

  while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    code=$(echo "$line"  | awk '{print $2}')
    code_upper="${code^^}"
    name="${STATE_NAME[$code_upper]:-UNKNOWN($code)}"

    # highlight bad states
    colored_name="$name"
    case "$code_upper" in
      06) colored_name="${YELLOW}${name}${RESET}" ;;  # TIME_WAIT
      08) colored_name="${RED}${name}${RESET}" ;;     # CLOSE_WAIT (leak!)
      02) colored_name="${YELLOW}${name}${RESET}" ;;  # SYN_SENT
    esac

    printf "  %5s  %s\n" "$count" "$colored_name"
  done < <(echo "$TCP" | awk 'NR>1{print $4}' | sort | uniq -c | sort -rn)

  # TIME_WAIT specific warning
  TW=$(echo "$TCP" | awk 'NR>1{print $4}' | grep -c "^06$" || true)
  CW=$(echo "$TCP" | awk 'NR>1{print $4}' | grep -c "^08$" || true)

  echo ""
  echo -e "  TIME_WAIT  : $(status_color $TW $WARN_TIMEWAIT $CRIT_TIMEWAIT)  (ideal: < 500)"
  if (( CW > 50 )); then
    echo -e "  CLOSE_WAIT : ${RED}${CW}${RESET}  ← ${RED}LEAK DETECTED — connections not being closed${RESET}"
  else
    echo -e "  CLOSE_WAIT : ${GREEN}${CW}${RESET}  (ok)"
  fi

  # ── Top Remote IPs ───────────────────────────────────────────
  echo -e "\n${BOLD}${CYAN}─── Top Upstream Connections ──────────────────${RESET}"
  echo "$TCP" | awk 'NR>1{print $3}' | sort | uniq -c | sort -rn | head -8 | \
  while read count hex; do
    [[ "$hex" == "rem_address" || "$hex" == "00000000:0000" ]] && continue
    ip_hex=${hex%:*}
    port_hex=${hex#*:}
    # convert hex IP (little-endian) to dotted decimal
    ip=$(printf '%d.%d.%d.%d\n' \
      0x${ip_hex:6:2} 0x${ip_hex:4:2} 0x${ip_hex:2:2} 0x${ip_hex:0:2})
    port=$(( 16#$port_hex ))
    printf "  %5s conns  →  %s:%s\n" "$count" "$ip" "$port"
  done

  # ── Kernel TCP sysctl ────────────────────────────────────────
  echo -e "\n${BOLD}${CYAN}─── Kernel TCP Settings ───────────────────────${RESET}"
  for key in \
    net.ipv4.tcp_fin_timeout \
    net.ipv4.tcp_tw_reuse \
    net.ipv4.tcp_keepalive_time \
    net.ipv4.tcp_keepalive_intvl \
    net.ipv4.tcp_keepalive_probes; do
    val=$(docker exec "$CONTAINER" sysctl -n "$key" 2>/dev/null || sysctl -n "$key" 2>/dev/null || echo "n/a")
    printf "  %-40s %s\n" "$key" "$val"
  done

  # ── Overall Health ───────────────────────────────────────────
  echo -e "\n${BOLD}${CYAN}─── Overall Health ────────────────────────────${RESET}"
  ISSUES=0

  (( RSS_MB  >= CRIT_RSS_MB  )) && { echo -e "  ${RED}✗ Memory critical: ${RSS_MB}MB${RESET}"; (( ISSUES++ )); }
  (( RSS_MB  >= WARN_RSS_MB && RSS_MB < CRIT_RSS_MB )) && { echo -e "  ${YELLOW}⚠ Memory elevated: ${RSS_MB}MB${RESET}"; (( ISSUES++ )); }
  (( FD_COUNT >= CRIT_FD    )) && { echo -e "  ${RED}✗ FD count critical: ${FD_COUNT}${RESET}"; (( ISSUES++ )); }
  (( FD_COUNT >= WARN_FD && FD_COUNT < CRIT_FD )) && { echo -e "  ${YELLOW}⚠ FD count elevated: ${FD_COUNT}${RESET}"; (( ISSUES++ )); }
  (( TW      >= CRIT_TIMEWAIT )) && { echo -e "  ${RED}✗ TIME_WAIT critical: ${TW}${RESET}"; (( ISSUES++ )); }
  (( TW      >= WARN_TIMEWAIT && TW < CRIT_TIMEWAIT )) && { echo -e "  ${YELLOW}⚠ TIME_WAIT elevated: ${TW}${RESET}"; (( ISSUES++ )); }
  (( CW      > 50 ))  && { echo -e "  ${RED}✗ CLOSE_WAIT leak: ${CW} connections${RESET}"; (( ISSUES++ )); }
  (( SWAP_MB > 100 )) && { echo -e "  ${YELLOW}⚠ Swap in use: ${SWAP_MB}MB${RESET}"; (( ISSUES++ )); }

  if (( ISSUES == 0 )); then
    echo -e "  ${GREEN}✓ All checks passed — proxy looks healthy${RESET}"
  fi

  echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════${RESET}"
  $WATCH_MODE && echo -e "  Refreshing every ${WATCH_INTERVAL}s — Ctrl+C to stop"
}

# ── Run once or watch loop ────────────────────────────────────
if $WATCH_MODE; then
  while true; do
    run_report
    sleep "$WATCH_INTERVAL"
  done
else
  run_report
fi
