#!/usr/bin/env bash
# Interactive setup: pick services, see RAM/disk needs, write .env.
#   scripts/init.sh                         interactive
#   scripts/init.sh --profiles a,b [--low-memory]   non-interactive
set -euo pipefail
source "$(dirname "$0")/lib.sh"

LOW_MEM=""; PRESET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profiles) PRESET="$2"; shift 2 ;;
    --low-memory) LOW_MEM=y; shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

[ -f .env ] || cp .env.example .env
load_env

# current selection -> "1" / "" per profile, kept in a space-separated string
selected=" $(active_profiles) "
is_on() { case "$selected" in *" $1 "*) return 0 ;; esac; return 1; }
toggle() { if is_on "$1"; then selected="${selected/ $1 / }"; else selected="$selected$1 "; fi; }

mem=$(docker_mem_mb); disk=$(free_disk_mb)

draw() {
  local i=0 p mark ram dsk tr=0 td=0
  printf '\n%sdocker-files setup%s\n' "$B" "$N"
  printf '%sDocker can use %s RAM; %s disk free.%s\n\n' "$D" "$(human_mb "$mem")" "$(human_mb "$disk")" "$N"
  printf '  %s%-3s %-4s %-14s %-44s %8s %9s%s\n' "$D" "#" "" "profile" "what you get" "RAM" "disk" "$N"
  for p in $ALL_PROFILES; do
    i=$((i+1)); ram=$(profile_field "$p" 2); dsk=$(profile_field "$p" 3)
    if is_on "$p"; then mark="${G}[x]${N}"; tr=$((tr+ram)); td=$((td+dsk)); else mark="[ ]"; fi
    printf '  %-3s %s  %-14s %-44s %8s %9s\n' "$i" "$mark" "$p" "$(profile_field "$p" 1)" "~${ram}MB" "~$(human_mb "$dsk")"
  done
  TOTAL_RAM=$tr; TOTAL_DISK=$td
  printf '\n  %sSelected: ~%s RAM, ~%s disk%s\n' "$B" "$(human_mb "$tr")" "$(human_mb "$td")" "$N"
  if [ "$mem" -gt 0 ] && [ "$tr" -gt $((mem * 70 / 100)) ]; then
    printf '  %s! That is more than 70%% of the RAM Docker has. Pick fewer, or say yes to low-memory mode.%s\n' "$Y" "$N"
  fi
  if [ "$td" -gt $((disk - 2048)) ]; then
    printf '  %s! Not enough free disk for these images (keep 2 GB spare). Run `make prune` or pick fewer.%s\n' "$R" "$N"
  fi
}

if [ -n "$PRESET" ]; then
  if [ "$PRESET" = "*" ]; then selected=" $ALL_PROFILES "; else selected=" $(echo "$PRESET" | tr ',' ' ') "; fi
  draw
else
  [ -t 0 ] || { echo "No terminal: use --profiles a,b" >&2; exit 1; }
  while :; do
    draw
    printf '\n  Toggle by number (e.g. "1 3 8"), %sa%s = all, %sn%s = none, %sEnter%s = save: ' "$C" "$N" "$C" "$N" "$C" "$N"
    read -r answer
    [ -z "$answer" ] && break
    case "$answer" in
      a) selected=" $ALL_PROFILES " ;;
      n) selected=" " ;;
      *) for n in $answer; do
           p=$(echo "$ALL_PROFILES" | tr ' ' '\n' | sed -n "${n}p" 2>/dev/null || true)
           [ -n "$p" ] && toggle "$p"
         done ;;
    esac
  done
fi

profiles=$(echo $selected | tr ' ' ',')
[ -n "$profiles" ] || { echo "Nothing selected - .env not changed."; exit 0; }
set_env COMPOSE_PROFILES "$profiles"

# Low-memory mode: suggested when Docker has < 6 GB or the pick is tight
if [ -z "$LOW_MEM" ] && [ -z "$PRESET" ]; then
  if [ "$mem" -gt 0 ] && { [ "$mem" -lt 6144 ] || [ "$TOTAL_RAM" -gt $((mem * 70 / 100)) ]; }; then
    printf '\n  Turn on low-memory mode (smaller caches and Java heaps)? [Y/n] '
    read -r a; case "$a" in n|N) ;; *) LOW_MEM=y ;; esac
  fi
fi
if [ -n "$LOW_MEM" ]; then
  set_env REDIS_MAXMEMORY 64mb
  set_env MONGO_CACHE_GB 0.1
  set_env KAFKA_HEAP 256m
  set_env ES_HEAP 256m
  set_env KIBANA_HEAP_MB 512
  set_env KEYCLOAK_HEAP 256m
  echo "  ${G}✓${N} low-memory mode on"
fi

echo "  ${G}✓${N} saved COMPOSE_PROFILES=$profiles to .env"
echo "  Next: ${B}make up${N}   then   ${B}make urls${N}"
