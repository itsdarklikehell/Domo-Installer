#!/usr/bin/env bash
#
# homelab-stacks.sh — health/reachability checker voor de homelab media- en AI-stacks.
#
# Dit is een optionele module voor Domo-Installer. Hij kan op zichzelf draaien
# (sudo bash homelab-stacks.sh) of gesourced worden door Domo-Installer.sh
# (dan roep je check_homelab_stacks aan vanuit het menu).
#
# De endpoints komen uit de Heimdall-dashboardregistratie van de thuisvloot
# (192.168.178.197:7990). Ze zijn hier hardcoded zodat het script ook zonder
# netwerktoegang tot Heimdall werkt; pas ze aan als de vloot verhuist.
#
# Gebruik:
#   bash homelab-stacks.sh              # leesbaar overzicht (media + AI)
#   bash homelab-stacks.sh --json       # machine-readable JSON-array
#   bash homelab-stacks.sh --media      # alleen media-stack
#   bash homelab-stacks.sh --ai         # alleen AI-stack
#
set -euo pipefail

# ---- stackdefinities (naam|groep|url) ------------------------------------
# Groepen: media | ai
HOMELAB_STACKS=(
  "Readarr|media|http://192.168.178.120:8787"
  "Prowlarr|media|http://192.168.178.117:9696"
  "Transmission|media|http://192.168.178.118:9091"
  "Jellyfin|media|http://192.168.178.99:8096"
  "MusicBrainz|media|http://192.168.178.113:5000"
  "AudioMuse-AI|media|http://192.168.178.127"
  "SuggestArr|media|http://192.168.178.123"
  "Maintainerr|media|http://192.168.178.125"
  "OpenWebUI|ai|http://192.168.178.104"
  "Ollama|ai|http://192.168.178.62:11434"
  "Whisper STT|ai|http://192.168.178.22:8081"
  "stt-whisper|ai|http://192.168.178.114"
  "nl-tts|ai|http://192.168.178.112"
  "LM Studio|ai|http://192.168.178.62:1234"
)

# ---- kleuren ----------------------------------------------------------------
if [[ -t 1 ]]; then
  C_NC='\e[0m'; C_GREEN='\e[0;32m'; C_RED='\e[0;31m'; C_BOLD='\e[1m'
else
  C_NC=''; C_GREEN=''; C_RED=''; C_BOLD=''
fi

# ---- één endpoint proberen --------------------------------------------------
# Argumenten: <naam> <url>
# Prints niets; zet globale variabelen HL_NAME HL_URL HL_CODE HL_MS HL_OK
probe_endpoint() {
  local name="$1" url="$2"
  local out code ms
  out="$(curl -s -o /dev/null -w '%{http_code} %{time_total}' --max-time 4 "$url" 2>/dev/null)" || true
  code="${out%% *}"
  ms="${out##* }"
  if [[ -z "$code" || "$code" == "000" ]]; then
    code="---"
    ms="0.000"
    HL_OK=0
  else
    HL_OK=1
  fi
  HL_NAME="$name"; HL_URL="$url"; HL_CODE="$code"; HL_MS="$ms"
}

# ---- formattering ----------------------------------------------------------
fmt_line() {
  local mark status
  if [[ "$HL_OK" -eq 1 ]]; then
    mark="${C_GREEN}✓${C_NC}"; status="${C_GREEN}UP${C_NC}  (HTTP ${HL_CODE}, ${HL_MS}s)"
  else
    mark="${C_RED}✗${C_NC}"; status="${C_RED}DOWN${C_NC} (geen verbinding)"
  fi
  printf "  %s %-14s %-42s %b\n" "$mark" "$HL_NAME" "$HL_URL" "$status"
}

json_line() {
  local state http
  [[ "$HL_OK" -eq 1 ]] && state="up" || state="down"
  if [[ "$HL_OK" -eq 1 ]]; then
    http="$HL_CODE"
  else
    # Ongeldige JSON-getallen (zoals "---") worden null.
    http="null"
  fi
  printf '    {"name":"%s","group":"%s","url":"%s","state":"%s","http":%s,"seconds":%s}' \
    "$HL_NAME" "$1" "$HL_URL" "$state" "$http" "$HL_MS"
}

# ---- hoofdloop --------------------------------------------------------------
# check_homelab_stacks [media|ai|all]
check_homelab_stacks() {
  local filter="${1:-all}"
  local first=1
  local json=0
  [[ "${HL_JSON:-0}" == "1" ]] && json=1

  for entry in "${HOMELAB_STACKS[@]}"; do
    local name="${entry%%|*}"
    local rest="${entry#*|}"
    local group="${rest%%|*}"
    local url="${rest##*|}"
    [[ "$filter" != "all" && "$filter" != "$group" ]] && continue

    probe_endpoint "$name" "$url"

    if [[ "$json" -eq 1 ]]; then
      if [[ "$first" -eq 1 ]]; then first=0; else printf ','; fi
      printf '\n'
      json_line "$group"
    else
      if [[ "$first" -eq 1 ]]; then
        printf "\n  ${C_BOLD}Homelab stacks — %s${C_NC}\n" "$filter"
        first=0
      fi
      fmt_line
    fi
  done

  if [[ "$json" -eq 1 ]]; then
    printf '\n  ]\n}\n'
  fi
  return 0
}

# ---- CLI-entrypoint --------------------------------------------------------
homelab_cli() {
  local mode="all" json=0
  for arg in "$@"; do
    case "$arg" in
      --media) mode="media" ;;
      --ai)    mode="ai" ;;
      --json)  json=1 ;;
      -h|--help)
        echo "Gebruik: $0 [--media|--ai] [--json]"; return 0 ;;
      *) echo "Onbekende optie: $arg" >&2; return 1 ;;
    esac
  done

  if [[ "$json" -eq 1 ]]; then
    HL_JSON=1
    printf '{\n  "generated": "%s",\n  "stacks": [' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    check_homelab_stacks "$mode"
  else
    check_homelab_stacks "$mode"
  fi
}

# Alleen de CLI draaien wanneer dit script direct wordt aangeroepen
# (niet wanneer het gesourced wordt door Domo-Installer.sh).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  homelab_cli "$@"
fi
