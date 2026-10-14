#!/usr/bin/env bash
# Off-device test suite: stubs sunshine, hyprctl, tailscale, systemctl, ip, loginctl,
# Moonlight and macOS tools, then exercises install.sh, the CLI, the dashboard API and
# the Mac script. Real-hardware behaviour is NOT covered; see README "Not verified yet".
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'jobs -p | xargs -r kill 2>/dev/null; rm -rf "$WORK"' EXIT
STUBS=$WORK/stubs; mkdir -p "$STUBS"
export LOG=$WORK/calls.log STATE=$WORK/state; mkdir -p "$STATE"; : > "$LOG"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  \033[32m✔\033[0m %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31m✘\033[0m %s\n' "$1"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
section(){ printf '\n%s\n' "$1"; }

stub() { printf '#!/bin/sh\n%s\n' "$2" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }
stub sunshine  'echo "sunshine $*" >> "$LOG"'
stub systemctl 'echo "systemctl $*" >> "$LOG"
[ "$2" = is-active ] && { [ "$3" = "${ACTIVE_UNIT:-}" ] && echo active || echo inactive; }
[ "$2" = show ] && echo "${MAINPID:-0}"; exit 0'
stub ss        'case "$*" in *":${BUSY:-none} "*|*":${BUSY:-none}") echo "LISTEN 0 4096 127.0.0.1:$BUSY";; esac; exit 0'
stub loginctl  'echo "loginctl $*" >> "$LOG"; [ "$1" = show-user ] && echo 2; exit 0'
stub omarchy-system-lock 'echo "OMARCHY-LOCK" >> "$LOG"; [ -z "$LOCK_FAIL" ]'
stub osascript 'case "$*" in *"choose from list"*) echo "${CHOICE:-false}" ;; *) echo "OSA $*" >> "$LOG" ;; esac'
stub ifconfig  '[ "$1" = awdl0 ] && echo "awdl0: flags=8943<UP,BROADCAST,RUNNING> mtu 1500"; exit 0'
stub sudo      'echo "sudo $*" >> "$LOG"; [ "$1" = setcap ] && touch "$STATE/capped"; exit 0'
stub getcap    '[ -f "$STATE/capped" ] && echo "$1 cap_sys_admin=p"; exit 0'
stub ip        'echo "[{\"dst\":\"default\",\"dev\":\"enp5s0\",\"metric\":100},{\"dst\":\"default\",\"dev\":\"wlan0\",\"metric\":100}]"'
stub tailscale 'if [ "$1" = ping ]; then
  i=0; while [ $i -lt ${PINGS:-10} ]; do
    if [ -n "$RELAY" ]; then echo "pong from omarchy (100.73.206.17) via DERP(fra) in ${RTT:-48}ms"
    else r=${RTT:-9}; [ -n "$SPIKE" ] && [ $((i % 3)) = 2 ] && r=$SPIKE
      echo "pong from omarchy (100.73.206.17) via 85.1.2.3:41641 in ${r}ms"; fi; i=$((i+1)); done
  exit 0; fi
echo "{\"BackendState\":\"Running\",\"Self\":{\"TailscaleIPs\":[\"100.73.206.17\"]},\"Peer\":{\"a\":{\"HostName\":\"svens-macbook\",\"OS\":\"macOS\",\"Online\":true,\"Active\":true,\"TailscaleIPs\":[\"100.64.0.2\"],\"CurAddr\":\"\",\"Relay\":\"fra\"},\"b\":{\"HostName\":\"idle-box\",\"OS\":\"linux\",\"Online\":true,\"Active\":false,\"TailscaleIPs\":[\"100.64.0.3\"],\"CurAddr\":\"\",\"Relay\":\"ams\"}}}"'
stub hyprctl '
echo "hyprctl $*" >> "$LOG"
case "$1" in
  monitors) printf "[{\"name\":\"HDMI-A-2\",\"width\":1920,\"height\":1080,\"refreshRate\":60.0,\"x\":0,\"y\":0,\"scale\":1},{\"name\":\"DP-2\",\"width\":1920,\"height\":1080,\"refreshRate\":144.0,\"x\":1920,\"y\":0,\"scale\":1},{\"name\":\"DP-1\",\"width\":1920,\"height\":1080,\"refreshRate\":144.0,\"x\":3840,\"y\":0,\"scale\":1}"
            vm=$(cat "$STATE/vmode" 2>/dev/null || echo 3024x1964)
            [ -f "$STATE/virtual" ] && printf ",{\"name\":\"OS-VIRTUAL\",\"width\":${vm%%x*},\"height\":${vm##*x},\"refreshRate\":60.0,\"x\":5760,\"y\":0,\"scale\":2}"
            echo "]" ;;
  getoption) if [ "$2" = cursor:invisible ]; then echo "{\"option\":\"cursor:invisible\",\"bool\":$(cat "$STATE/cursor" 2>/dev/null || echo false)}"
             else echo "{\"option\":\"misc:vrr\",\"int\":$(cat "$STATE/vrr" 2>/dev/null || echo 2)}"; fi ;;
  keyword) if [ -n "$LUA" ]; then echo "keyword can'"'"'t work with non-legacy parsers. Use eval."; exit 0; fi
           [ "$2" = misc:vrr ] && echo "$3" > "$STATE/vrr"
           [ "$2" = cursor:invisible ] && echo "$3" > "$STATE/cursor"
           [ "$2" = monitor ] && echo "$3" | cut -d, -f2 | cut -d@ -f1 > "$STATE/vmode"; echo ok ;;
  eval) case "$2" in
          *"mode ="*) echo "$2" | sed -n "s/.*mode = \"\([0-9]*x[0-9]*\)@.*/\1/p" > "$STATE/vmode" ;;
          *"invisible ="*) echo "$2" | sed -n "s/.*invisible = \([a-z]*\).*/\1/p" > "$STATE/cursor" ;;
          *"vrr ="*) echo "$2" | sed -n "s/.*vrr = \([0-9]*\).*/\1/p" > "$STATE/vrr" ;;
        esac; echo ok ;;
  output) [ "$2" = create ] && touch "$STATE/virtual"; [ "$2" = remove ] && rm -f "$STATE/virtual"; echo ok ;;
esac'
stub moonlight 'echo "MOONLIGHT $*" >> "$LOG"'
stub open      'echo "OPEN $*" >> "$LOG"'
stub system_profiler 'printf "Graphics/Displays:\n    Displays:\n        Color LCD:\n          Display Type: Built-in Liquid Retina XDR Display\n          Resolution: 3024 x 1964 Retina\n"'
export PATH=$STUBS:$PATH MOONLIGHT=$STUBS/moonlight LAUNCH_DELAY=0
export HYPRLAND_INSTANCE_SIGNATURE=test XDG_SESSION_TYPE=wayland DRM_SYSFS=$WORK/nodrm OMARCHY_SETTLE=0

new_home() { HOME=$(mktemp -d -p "$WORK"); export HOME; mkdir -p "$HOME/.config/sunshine" "$HOME/.config/hypr"; }

# --------------------------------------------------------------------------- install
section "install.sh"
new_home
printf 'nvenc_realtime_hags = enabled\nnvenc_latency_over_power = enabled\nminimum_fps_target = 15\nfec_percentage = 20\n' > "$HOME/.config/sunshine/sunshine.conf"
cp "$HOME/.config/sunshine/sunshine.conf" "$WORK/orig.conf"
printf 'exec-once = ~/remote-access-dashboard/serve.sh\nexec-once = ~/remote-access-dashboard/disable-wifi.sh\nexec-once = waybar\n' > "$HOME/.config/hypr/autostart.conf"
echo n | "$ROOT/install.sh" >/dev/null 2>&1
check "declining changes nothing" 'cmp -s "$HOME/.config/sunshine/sunshine.conf" "$WORK/orig.conf" && [ ! -d "$HOME/.local" ]'
for _ in 1 2 3; do echo y | "$ROOT/install.sh" >/dev/null 2>&1 || bad "install run failed"; done
C=$HOME/.config/sunshine/sunshine.conf
check "capture = kms set once"            '[ "$(grep -c "^capture = kms" "$C")" = 1 ]'
check "Windows-only keys removed"         '! grep -qE "nvenc_realtime_hags|nvenc_latency_over_power" "$C"'
check "low fps floor removed"             '! grep -q minimum_fps_target "$C"'
check "user setting kept"                 'grep -q "fec_percentage = 20" "$C"'
check "session hook registered once"      '[ "$(grep -c "omarchy-stream hook connect" "$C")" = 1 ]'
check "exactly one backup, == original"   '[ "$(ls "$C".bak.* | wc -l)" = 1 ] && cmp -s "$C".bak.* "$WORK/orig.conf"'
check "v1 autostart lines commented"      '[ "$(grep -c "^# disabled by omarchy-stream" "$HOME/.config/hypr/autostart.conf")" = 2 ] && grep -q "^exec-once = waybar" "$HOME/.config/hypr/autostart.conf"'
check "setcap requested once"             '[ "$(grep -c "sudo setcap" "$LOG")" = 1 ]'
check "client config defaults written"    'grep -q lock_on_disconnect "$HOME/.config/omarchy-stream/config.json"'
check "sunshine@ unit points at binary"   'grep -q "ExecStart=$STUBS/sunshine" "$HOME/.config/systemd/user/sunshine@.service"'
check "mac client shipped with the app"   '[ -x "$HOME/.local/share/omarchy-stream/mac/omarchy-connect" ]'
H1=$HOME; new_home; : > "$LOG"
"$ROOT/install.sh" -y </dev/null >/dev/null 2>&1
check "install -y needs no input"         '[ -x "$HOME/.local/bin/omarchy-stream" ]'
HOME=$H1
CLI=$HOME/.local/bin/omarchy-stream

# --------------------------------------------------------------------------- doctor
section "doctor"
echo "Found HEVC encoder: hevc_nvenc [nvenc]" > "$HOME/.config/sunshine/sunshine.log"
out=$("$CLI" doctor 2>&1); rc=$?
check "exit 1 when something fails"       '[ $rc = 1 ]'
check "flags equal-metric routes"         'grep -q "2 default routes with equal metric" <<<"$out"'
check "flags DERP relay"                  'grep -q "svens-macbook.*relayed through DERP" <<<"$out"'
check "idle peers not flagged as relayed" '! grep -q "path:idle-box" <<<"$out" && grep -q "1 online peer(s) idle" <<<"$out"'
check "sees hardware encoder"             'grep -q "hevc_nvenc \[nvenc\]" <<<"$out"'
check "sees session hooks"                'grep -q "session-hooks.*VRR off" <<<"$out"'
check "--json is valid JSON"              '{ "$CLI" doctor --json; true; } | python3 -c "import json,sys; json.load(sys.stdin)"'

# --------------------------------------------------------------------------- hooks
section "session hooks"
echo 2 > "$STATE/vrr"; : > "$LOG"
"$CLI" hook connect
check "connect turns VRR off"             '[ "$(cat "$STATE/vrr")" = 0 ]'
"$CLI" hook disconnect
check "disconnect restores VRR"           '[ "$(cat "$STATE/vrr")" = 2 ]'
check "disconnect locks via Omarchy"      'grep -q "OMARCHY-LOCK" "$LOG"'
: > "$LOG"; "$CLI" hook connect; LOCK_FAIL=1 "$CLI" hook disconnect
check "lock falls back to logind session" 'grep -q "loginctl lock-session 2$" "$LOG"'
echo false > "$STATE/cursor"; "$CLI" hook connect
check "connect hides the host cursor"     '[ "$(cat "$STATE/cursor")" = true ]'
"$CLI" hook disconnect
check "disconnect shows the cursor again" '[ "$(cat "$STATE/cursor")" = false ]'
echo true > "$STATE/cursor"; "$CLI" hook connect; "$CLI" hook disconnect
check "cursor hidden by user stays hidden" '[ "$(cat "$STATE/cursor")" = true ]'; echo false > "$STATE/cursor"
echo 2 > "$STATE/vrr"; LUA=1 "$CLI" hook connect
check "Lua Hyprland: VRR off via eval"    '[ "$(cat "$STATE/vrr")" = 0 ]'
LUA=1 "$CLI" hook disconnect
check "Lua Hyprland: VRR restored"        '[ "$(cat "$STATE/vrr")" = 2 ]'
echo '{"lock_on_disconnect": false}' > "$HOME/.config/omarchy-stream/config.json"; : > "$LOG"
"$CLI" hook connect; "$CLI" hook disconnect
check "lock can be turned off"            '! grep -qE "lock-session|OMARCHY-LOCK" "$LOG"'
echo 0 > "$STATE/vrr"; "$CLI" hook connect; "$CLI" hook disconnect
check "VRR already off stays off"         '[ "$(cat "$STATE/vrr")" = 0 ]'
mkdir -p "$WORK/run/hypr/sig123"; touch "$WORK/run/hypr/sig123/.socket.sock"
check "hook finds Hyprland from a service" 'env -u HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR=$WORK/run "$CLI" hook connect && grep -q "hyprctl getoption" "$LOG"'
check "hook never fails without Hyprland" 'env -u HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR=$WORK/none "$CLI" hook connect 2>/dev/null'

# --------------------------------------------------------------------------- multi + virtual
section "multi-monitor and virtual display"
"$CLI" multi setup >/dev/null
I=$HOME/.config/sunshine/instances
check "one instance per physical monitor" '[ -f "$I/HDMI-A-2/sunshine.conf" ] && [ -f "$I/DP-2/sunshine.conf" ] && [ -f "$I/DP-1/sunshine.conf" ]'
check "ports left-to-right"               'grep -q "port = 48089" "$I/HDMI-A-2/sunshine.conf" && grep -q "port = 48289" "$I/DP-1/sunshine.conf"'
check "output_name falls back to x order" 'grep -q "output_name = 0" "$I/HDMI-A-2/sunshine.conf" && grep -q "output_name = 2" "$I/DP-1/sunshine.conf"'
D=$WORK/drm; mkdir -p "$D/card1-DP-1" "$D/card1-DP-2" "$D/card1-HDMI-A-2"
echo 823 > "$D/card1-DP-1/connector_id"; echo 837 > "$D/card1-DP-2/connector_id"; echo 834 > "$D/card1-HDMI-A-2/connector_id"
DRM_SYSFS=$D "$CLI" multi setup >/dev/null
check "output_name follows connector ids" 'grep -q "output_name = 0" "$I/DP-1/sunshine.conf" && grep -q "output_name = 1" "$I/HDMI-A-2/sunshine.conf" && grep -q "output_name = 2" "$I/DP-2/sunshine.conf"'
check "ports still left-to-right"         'grep -q "port = 48089" "$I/HDMI-A-2/sunshine.conf" && grep -q "port = 48289" "$I/DP-1/sunshine.conf"'
check "instances log at info, not verbose" 'grep -q "min_log_level = info" "$I/DP-2/sunshine.conf"'
check "no fps floor in instances"         '! grep -rq minimum_fps_target "$I"'
: > "$LOG"; out=$("$CLI" virtual 3024x1964@60,2)
check "virtual creates headless output"   'grep -q "hyprctl output create headless OS-VIRTUAL" "$LOG"'
check "virtual sets mode and scale"       'grep -q "OS-VIRTUAL,3024x1964@60,auto,2" "$LOG"'
check "virtual instance logs at info"     'grep -q "min_log_level = info" "$I/virtual/sunshine.conf"'
check "virtual uses wlr capture"          'grep -q "capture = wlr" "$I/virtual/sunshine.conf" && grep -q "output_name = OS-VIRTUAL" "$I/virtual/sunshine.conf"'
check "virtual starts its instance"       'grep -q "restart sunshine@virtual" "$LOG"'
check "virtual instance gets web login"   '[ "$(stat -c %a "$I/virtual/webcreds")" = 600 ] && grep -q "sunshine $I/virtual/sunshine.conf --creds omarchy" "$LOG"'
"$CLI" virtual off >/dev/null; : > "$LOG"
LUA=1 "$CLI" virtual 2560x1664@60,2 >/dev/null
check "Lua Hyprland: mode set via eval"   'grep -q "hyprctl eval hl.monitor({ output = \"OS-VIRTUAL\", mode = \"2560x1664@60\"" "$LOG" && [ "$(cat "$STATE/vmode")" = 2560x1664 ]'
"$CLI" multi setup >/dev/null
check "multi ignores the virtual output"  '[ ! -d "$I/OS-VIRTUAL" ]'
: > "$LOG"; "$CLI" multi up >/dev/null
check "multi instances get web logins"    '[ -f "$I/DP-2/webcreds" ] && [ -f "$I/HDMI-A-2/webcreds" ]'
check "multi up skips virtual instance"   '! grep -q "start sunshine@virtual" "$LOG" && grep -q "start sunshine@DP-2" "$LOG"'
check "bad virtual spec rejected"         '! "$CLI" virtual 12x >/dev/null'
"$CLI" virtual off >/dev/null
check "virtual off removes output"        'grep -q "hyprctl output remove OS-VIRTUAL" "$LOG"'

# --------------------------------------------------------------------------- dashboard API
section "dashboard API"
PORT=$((20000 + RANDOM % 20000))
"$CLI" serve --local-only --port $PORT >/dev/null 2>&1 & SRV=$!
for _ in $(seq 20); do curl -s "localhost:$PORT/api/ping" >/dev/null && break; sleep 0.1; done
TOK=$(cat "$HOME/.config/omarchy-stream/token")
A=(-H "Authorization: Bearer $TOK")
check "page served without token"         '[ "$(curl -s -o /dev/null -w %{http_code} localhost:$PORT/)" = 200 ]'
check "API refuses missing token"         '[ "$(curl -s -o /dev/null -w %{http_code} localhost:$PORT/api/status)" = 401 ]'
check "API refuses wrong token"           '[ "$(curl -s -o /dev/null -w %{http_code} -H "Authorization: Bearer nope" localhost:$PORT/api/status)" = 401 ]'
check "status lists all streams"          'curl -s "${A[@]}" localhost:$PORT/api/status | python3 -c "import json,sys; s=json.load(sys.stdin); assert [x[\"name\"] for x in s[\"streams\"]][:4]==[\"all-monitors\",\"HDMI-A-2\",\"DP-2\",\"DP-1\"], s[\"streams\"]"'
check "unknown unit rejected"             '[ "$(curl -s -o /dev/null -w %{http_code} -X POST "${A[@]}" localhost:$PORT/api/stream/evil/start)" = 400 ]'
check "injection-shaped path rejected"    '[ "$(curl -s -o /dev/null -w %{http_code} -X POST "${A[@]}" "localhost:$PORT/api/workspace/3;rm")" = 404 ]'
: > "$LOG"; curl -s -X POST "${A[@]}" localhost:$PORT/api/stream/sunshine@DP-2/start >/dev/null
check "per-monitor start stops all-monitors" 'grep -q "systemctl --user stop sunshine$" "$LOG" && grep -q "start sunshine@DP-2" "$LOG"'
check "virtual via API"                   'curl -s -X POST "${A[@]}" localhost:$PORT/api/virtual/2560x1600@60,2 | grep -q "\"ok\": true"'
check "bad virtual via API rejected"      '[ "$(curl -s -o /dev/null -w %{http_code} -X POST "${A[@]}" "localhost:$PORT/api/virtual/1x1")" = 404 ]'
: > "$LOG"; curl -s -X POST "${A[@]}" localhost:$PORT/api/multi/up >/dev/null
check "API multi up starts instances"     'grep -q "start sunshine@DP-2" "$LOG"'
: > "$LOG"; curl -s -X POST "${A[@]}" localhost:$PORT/api/multi/down >/dev/null
check "API multi down restores main"      'grep -q "stop sunshine@DP-2" "$LOG" && grep -q "systemctl --user start sunshine$" "$LOG"'
check "mac setup needs the token"         '[ "$(curl -s -o /dev/null -w %{http_code} localhost:$PORT/mac/setup)" = 401 ]'
MH=$(mktemp -d -p "$WORK")
curl -s "${A[@]}" localhost:$PORT/mac/setup > "$WORK/macsetup.sh"
HOME=$MH PATH=$STUBS:/usr/bin:/bin bash "$WORK/macsetup.sh" > "$WORK/macsetup.out" 2>&1
ME=$MH/.config/omarchy-stream/client.env
check "mac setup installs the client"     'cmp -s "$MH/.local/bin/omarchy-connect" "$ROOT/mac/omarchy-connect" && [ -x "$MH/.local/bin/omarchy-connect" ]'
APPB="$MH/Applications/Omarchy Remote.app"
check "mac setup builds the app"          '[ -x "$APPB/Contents/MacOS/omarchy-remote" ] && cmp -s "$APPB/Contents/Resources/omarchy-connect" "$ROOT/mac/omarchy-connect" && python3 -c "import plistlib,sys; d=plistlib.load(open(sys.argv[1],\"rb\")); assert d[\"CFBundleExecutable\"]==\"omarchy-remote\"" "$APPB/Contents/Info.plist"'
check "mac setup adds AirDrop sudo rule"  'grep -q "sudo visudo -cf" "$LOG" && grep -q "sudo install -m 440 -o root -g wheel .* /etc/sudoers.d/omarchy-awdl" "$LOG"'
check "mac setup fills client.env"        'grep -q "^HOST=100.73.206.17$" "$ME" && grep -q "^TOKEN=$TOK$" "$ME" && grep -q "^DASHBOARD_PORT=$PORT$" "$ME" && grep -q "^MULTI_PORTS=\"48089 48189 48289\"$" "$ME" && [ "$(stat -c %a "$ME")" = 600 ]'
check "mac setup env is sourceable"       'bash -c "set -u; source \"$ME\"; [ \"\$MONITOR_RES\" = \"1920x1080 1920x1080 1920x1080\" ]"'
check "omarchy-stream mac prints it"      '"$CLI" mac | grep -q "curl -fsSL -H \"Authorization: Bearer $TOK\" http://100.73.206.17:.*/mac/setup | bash"'
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null

# --------------------------------------------------------------------------- pairing
section "automatic pairing"
FP=$((20000 + RANDOM % 20000))
mkdir -p "$I/fake"; printf 'port = %s\n' $FP > "$I/fake/sunshine.conf"; echo secretpw > "$I/fake/webcreds"
python3 - $((FP + 1)) "$WORK/pinpost" <<'PY' & FAKE=$!
import http.server, json, sys
port, out = int(sys.argv[1]), sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self, code, body):
        b = json.dumps(body).encode(); self.send_response(code); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.headers.get("Authorization") != "Basic b21hcmNoeTpzZWNyZXRwdw==": return self.reply(401, {})
        self.reply(200, {"pairings": [{"id": "a" * 32, "name": "mac", "address": "100.64.0.2"}]})
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"])); open(out, "wb").write(body)
        self.reply(200, {"status": True})
http.server.HTTPServer(("127.0.0.1", port), H).serve_forever()
PY
PORT=$((20000 + RANDOM % 20000)); [ $PORT = $FP ] && PORT=$((PORT + 7))
OMARCHY_SUNSHINE_SCHEME=http "$CLI" serve --local-only --port $PORT >/dev/null 2>&1 & SRV=$!
for _ in $(seq 20); do curl -s "localhost:$PORT/api/ping" >/dev/null && curl -s "localhost:$((FP+1))" >/dev/null && break; sleep 0.1; done
code=$(curl -s -o /dev/null -w %{http_code} -X POST "${A[@]}" localhost:$PORT/api/pair/$FP/4321)
check "host submits the PIN"              '[ "$code" = 200 ] && python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d==dict(pairing_id=\"a\"*32, pin=\"4321\", name=\"Mac\"), d" "$WORK/pinpost"'
check "pair on unknown port fails"        '[ "$(curl -s -o /dev/null -w %{http_code} -X POST "${A[@]}" localhost:$PORT/api/pair/11111/4321)" = 500 ]'
kill $SRV $FAKE 2>/dev/null; wait $SRV $FAKE 2>/dev/null; rm -rf "$I/fake"

# --------------------------------------------------------------------------- non-default host
section "host where Sunshine runs as another unit (apollo)"
new_home; rm -f "$STATE/capped"; : > "$LOG"
sleep 60 & SP=$!; SPBIN=$(readlink -f /proc/$SP/exe)
for _ in 1 2; do echo y | ACTIVE_UNIT=apollo MAINPID=$SP BUSY=8080 "$ROOT/install.sh" >/dev/null 2>&1 || bad "install run failed"; done
J=$HOME/.config/omarchy-stream/config.json
jget() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$J" "$1"; }
check "detects the running unit"          '[ "$(jget sunshine_unit)" = apollo ]'
check "binary from the running process"   '[ "$(jget sunshine_bin)" = "$SPBIN" ] && grep -q "ExecStart=$SPBIN " "$HOME/.config/systemd/user/sunshine@.service"'
check "setcap targets that binary"        'grep -q "sudo setcap cap_sys_admin+p $SPBIN$" "$LOG"'
check "busy port 8080 skipped"            '[ "$(jget dashboard_port)" = 8090 ]'
check "restarts apollo, not sunshine"     'grep -q "restart apollo$" "$LOG" && ! grep -q "restart sunshine$" "$LOG"'
python3 - "$J" <<'PY'
import json, sys; c = json.load(open(sys.argv[1])); c["lock_on_disconnect"] = False; json.dump(c, open(sys.argv[1], "w"))
PY
echo y | ACTIVE_UNIT=apollo MAINPID=$SP BUSY=8080 "$ROOT/install.sh" >/dev/null 2>&1
check "rerun keeps user toggles"          '[ "$(jget lock_on_disconnect)" = False ]'
echo y | ACTIVE_UNIT=omarchy-stream-dashboard MAINPID=$SP BUSY=8090 SUNSHINE_UNIT=apollo "$ROOT/install.sh" >/dev/null 2>&1
check "rerun keeps port held by own dashboard" '[ "$(jget dashboard_port)" = 8090 ]'
kill $SP 2>/dev/null; wait $SP 2>/dev/null
CLI=$HOME/.local/bin/omarchy-stream
out=$(ACTIVE_UNIT=apollo "$CLI" doctor 2>&1)
check "doctor checks the apollo unit"     'grep -q "apollo.service is active" <<<"$out"'
"$CLI" multi setup >/dev/null; : > "$LOG"; "$CLI" multi up >/dev/null
check "multi up stops apollo"             'grep -q "systemctl --user stop apollo$" "$LOG"'
PORT=$((20000 + RANDOM % 20000))
"$CLI" serve --local-only --port $PORT >/dev/null 2>&1 & SRV=$!
for _ in $(seq 20); do curl -s "localhost:$PORT/api/ping" >/dev/null && break; sleep 0.1; done
A=(-H "Authorization: Bearer $(cat "$HOME/.config/omarchy-stream/token")")
check "status names the apollo unit"      'curl -s "${A[@]}" localhost:$PORT/api/status | grep -q "\"unit\": \"apollo\""'
check "API can restart apollo"            '[ "$(curl -s -o /dev/null -w %{http_code} -X POST "${A[@]}" localhost:$PORT/api/stream/apollo/restart)" = 200 ]'
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
PORT=$((20000 + RANDOM % 20000))
python3 - "$J" $PORT <<'PY'
import json, sys; c = json.load(open(sys.argv[1])); c["dashboard_port"] = int(sys.argv[2]); json.dump(c, open(sys.argv[1], "w"))
PY
"$CLI" serve --local-only >/dev/null 2>&1 & SRV=$!
for _ in $(seq 20); do curl -s "localhost:$PORT/api/ping" >/dev/null && break; sleep 0.1; done
check "serve defaults to configured port" 'curl -s localhost:$PORT/api/ping | grep -q ok'
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null

# --------------------------------------------------------------------------- Mac client
section "Mac client (omarchy-connect)"
new_home; MC=$ROOT/mac/omarchy-connect
"$MC" >/dev/null
check "first run writes private config"   '[ "$(stat -c %a "$HOME/.config/omarchy-stream/client.env")" = 600 ]'
bitrate() { : > "$LOG"; env "$@" "$MC" all >/dev/null; grep -o -- "--bitrate [0-9]*" "$LOG" | grep -o "[0-9]*$"; }
check "clean direct path: full 60 Mbps"   '[ "$(bitrate RTT=9)" = 60000 ]'
check "slower path: 70%"                  '[ "$(bitrate RTT=35)" = 42000 ]'
check "10% loss: 70%"                     '[ "$(bitrate RTT=9 PINGS=9)" = 42000 ]'
check "20% loss: 40%"                     '[ "$(bitrate RTT=9 PINGS=8)" = 24000 ]'
check "very slow/lossy: 40%"              '[ "$(bitrate RTT=90)" = 24000 ]'
check "relayed: 25%"                      '[ "$(bitrate RELAY=1)" = 15000 ]'
check "Wi-Fi spikes: 40%"                 '[ "$(bitrate RTT=4 SPIKE=130)" = 24000 ]'
check "small spikes: 70%"                 '[ "$(bitrate RTT=4 SPIKE=25)" = 42000 ]'
check "Mac cursor mode + stats overlay"   'grep -q -- "--absolute-mouse --performance-overlay" "$LOG"'
check "AirDrop paused and restored"       'grep -q "sudo -n /sbin/ifconfig awdl0 down" "$LOG" && grep -q "sudo -n /sbin/ifconfig awdl0 up" "$LOG"'
check "unreachable host fails clearly"    '! PINGS=0 "$MC" all >/dev/null'
check "all-monitors native resolution"    'grep -q -- "--resolution 5760x1080" "$LOG"'
check "virtual needs a token"             '! "$MC" virtual >/dev/null'
check "multi needs a token"               '! "$MC" multi >/dev/null'
sed -i 's/^TOKEN=.*/TOKEN=t/' "$HOME/.config/omarchy-stream/client.env"
stub curl 'echo "CURL $*" >> "$LOG"'
: > "$LOG"; "$MC" multi >/dev/null
check "multi splits bitrate across 3"     '[ "$(grep -c "OPEN -n -a Moonlight" "$LOG")" = 3 ] && grep -q -- "--bitrate 20000" "$LOG"'
sed -i 's/^MONITOR_RES=.*/MONITOR_RES="1920x1080 3440x1440 1920x1080"/' "$HOME/.config/omarchy-stream/client.env"
: > "$LOG"; "$MC" multi >/dev/null
check "multi: one size per monitor"       'grep -q "48189 Desktop --resolution 3440x1440" "$LOG" && grep -q "48289 Desktop --resolution 1920x1080" "$LOG"'
: > "$LOG"; "$MC" virtual >/dev/null
check "virtual sized to Mac display"      'grep -q "api/virtual/3024x1964@60,2" "$LOG" && grep -q -- "--resolution 3024x1964" "$LOG" && grep -q "omarchy:48989" "$LOG"'
check "virtual removed after session"     'grep -q "api/virtual/off" "$LOG"'
check "virtual pairs itself once"         'grep -q "api/pair/48989/[0-9]\{4\}" "$LOG" && grep -q "MOONLIGHT pair omarchy:48989 --pin" "$LOG" && [ -f "$HOME/.config/omarchy-stream/paired.48989" ]'
: > "$LOG"; "$MC" virtual >/dev/null
check "already paired: no pairing again"  '! grep -q "api/pair" "$LOG"'
rm -f "$HOME"/.config/omarchy-stream/paired.48?89; : > "$LOG"; "$MC" multi >/dev/null
check "multi starts host streams"         'grep -q "api/multi/up" "$LOG"'
check "multi pairs every monitor stream"  '[ "$(grep -c "api/pair/48[0-2]89/" "$LOG")" = 3 ]'
section "Mac app (Omarchy Remote.app)"
L2="$APPB/Contents/MacOS/omarchy-remote"
: > "$LOG"; HOME=$MH CHOICE="Screen sized to this Mac" "$L2"
check "app: virtual choice streams"       'grep -q "api/virtual/3024x1964@60,2" "$LOG" && grep -q "MOONLIGHT stream 100.73.206.17:48989" "$LOG"'
check "app: notifications, no terminal"   'grep -q "OSA -e display notification" "$LOG" && grep -q "=== .* virtual" "$MH/Library/Logs/omarchy-remote.log"'
: > "$LOG"; HOME=$MH CHOICE="Main monitor (ultrawide)" "$L2"
check "app: main monitor choice"          'grep -q "MOONLIGHT stream 100.73.206.17 Desktop --resolution" "$LOG"'
: > "$LOG"; HOME=$MH CHOICE=false "$L2"
check "app: cancel does nothing"          '! grep -q MOONLIGHT "$LOG"'
: > "$LOG"; HOME=$MH CHOICE="Check connection" PINGS=0 "$L2"
check "app: errors shown as a dialog"     'grep -q "OSA -e display dialog .*unreachable" "$LOG"'
check "usage on bad argument"             '! "$MC" nope >/dev/null'

printf '\n%d passed, %d failed\n' $PASS $FAIL
[ $FAIL = 0 ]
