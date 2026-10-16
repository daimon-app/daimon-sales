#!/system/bin/sh
# GALAXY_LOCAL_AI on-device worker.
# Runs as the adb shell user inside /data/local/tmp/daimon-llm (mode 700). Uses only the local
# llama-server on 127.0.0.1 with a per-start random API key; never opens a network connection
# off the device, so it works with Wi-Fi and mobile data off.
# Usage: galaxy_worker.sh once|unload|heartbeat
#   once      process every inbox/<id>.request.json once (loads the model on demand)
#   unload    stop the local model server
#   heartbeat refresh state/heartbeat and state/resource only
# Resource guard thresholds can be tightened (never loosened) by env for tests:
#   GUARD_THERMAL_STATUS (default 2), GUARD_BATTERY_TEMP_C10 (400 = 40.0C),
#   GUARD_MIN_BATTERY_LEVEL (30, applies only when not powered), GUARD_MIN_MEM_KB (1572864 = 1.5 GiB)

D=/data/local/tmp/daimon-llm
PORT=8090
TH_MAX=${GUARD_THERMAL_STATUS:-2};        [ "$TH_MAX" -gt 2 ] && TH_MAX=2
BT_MAX=${GUARD_BATTERY_TEMP_C10:-400};    [ "$BT_MAX" -gt 400 ] && BT_MAX=400
LV_MIN=${GUARD_MIN_BATTERY_LEVEL:-30};    [ "$LV_MIN" -lt 30 ] && LV_MIN=30
MEM_MIN=${GUARD_MIN_MEM_KB:-1572864};     [ "$MEM_MIN" -lt 1572864 ] && MEM_MIN=1572864

mkdir -p "$D/inbox" "$D/outbox" "$D/state"
chmod 700 "$D"

now() { date +%Y-%m-%dT%H:%M:%S%z; }

read_resource() {
  b=$(dumpsys battery)
  BT=$(echo "$b" | sed -n 's/^ *temperature: *\([0-9]*\).*/\1/p' | head -n 1)
  LV=$(echo "$b" | sed -n 's/^ *level: *\([0-9]*\).*/\1/p' | head -n 1)
  PW=$(echo "$b" | grep -cE '(AC|USB|Wireless) powered: true')
  TH=$(dumpsys thermalservice | sed -n 's/^Thermal Status: *\([0-9]*\).*/\1/p' | head -n 1)
  MEM=$(sed -n 's/^MemAvailable: *\([0-9]*\).*/\1/p' /proc/meminfo)
  echo "thermal_status=${TH:-} battery_temp_c10=${BT:-} battery_level=${LV:-} powered=${PW:-0} mem_available_kb=${MEM:-}" > "$D/state/resource"
}

guard_reason() {
  read_resource
  [ "${TH:-0}" -ge "$TH_MAX" ] && { echo THERMAL; return; }
  [ "${BT:-0}" -ge "$BT_MAX" ] && { echo BATTERY_TEMP; return; }
  [ "${PW:-0}" -eq 0 ] && [ "${LV:-100}" -lt "$LV_MIN" ] && { echo BATTERY_LOW; return; }
  [ "${MEM:-0}" -lt "$MEM_MIN" ] && { echo MEMORY; return; }
}

server_up() {
  [ -f "$D/state/key" ] || return 1
  curl -s -m 3 "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q '"ok"'
}

unload() {
  pkill -f "$D/bin/llama-server" 2>/dev/null
  rm -f "$D/state/key"
}

ensure_server() {
  server_up && return 0
  unload
  head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$D/state/key"
  chmod 600 "$D/state/key"
  LD_LIBRARY_PATH="$D/bin" nohup "$D/bin/llama-server" -m "$D/model.gguf" --host 127.0.0.1 --port "$PORT" \
    -t 6 -c 2048 -np 1 --no-webui --api-key "$(cat "$D/state/key")" > "$D/state/server.log" 2>&1 < /dev/null &
  i=0
  while [ $i -lt 240 ]; do
    server_up && return 0
    sleep 0.5; i=$((i + 1))
  done
  return 1
}

write_status() { # id status reason started
  read_resource
  {
    echo "task_id=$1"
    echo "status=$2"
    echo "reason=$3"
    echo "started_at=$4"
    echo "finished_at=$(now)"
    echo "model_sha256=$(cat "$D/state/model.sha256" 2>/dev/null)"
    cat "$D/state/resource"
  } > "$D/outbox/$1.status.tmp"
  mv "$D/outbox/$1.status.tmp" "$D/outbox/$1.status"
  echo "$(now) task=$1 status=$2 reason=$3" >> "$D/state/events.log"
}

heartbeat() {
  read_resource
  if server_up; then s=LOADED; else s=UNLOADED; fi
  echo "at=$(now) model_state=$s $(cat "$D/state/resource")" > "$D/state/heartbeat"
}

SECRET_PATTERN='password|passwd|passphrase|パスワード|暗証|token|cookie|secret|api[_-]?key|private[ _-]?key|BEGIN [A-Z ]*PRIVATE|one[- ]time|otp|mfa|2fa|認証コード|credential'

process_once() {
  for req in "$D"/inbox/*.request.json; do
    [ -f "$req" ] || continue
    id=$(basename "$req" .request.json)
    if [ -f "$D/outbox/$id.status" ]; then rm -f "$req" "$D/inbox/$id.prompt.txt"; continue; fi
    started=$(now)
    if grep -qiE "$SECRET_PATTERN" "$D/inbox/$id.prompt.txt" 2>/dev/null; then
      write_status "$id" ESCALATE SECRET_REFUSED "$started"
    else
      reason=$(guard_reason)
      if [ -n "$reason" ]; then
        unload
        write_status "$id" ESCALATE "RESOURCE_GUARD_$reason" "$started"
      elif ! ensure_server; then
        write_status "$id" ESCALATE SERVER_START_FAILED "$started"
      elif curl -s -m 180 -H "Authorization: Bearer $(cat "$D/state/key")" -H 'Content-Type: application/json' \
             --data-binary @"$req" "http://127.0.0.1:$PORT/v1/chat/completions" -o "$D/outbox/$id.response.json"; then
        write_status "$id" COMPLETED "" "$started"
      else
        write_status "$id" ESCALATE LOCAL_INFERENCE_FAILED "$started"
      fi
    fi
    rm -f "$req" "$D/inbox/$id.prompt.txt"
  done
  heartbeat
}

case "$1" in
  once) process_once ;;
  unload) unload; heartbeat ;;
  heartbeat) heartbeat ;;
  *) echo "usage: galaxy_worker.sh once|unload|heartbeat" >&2; exit 2 ;;
esac
