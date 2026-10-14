#!/usr/bin/env bash
# Host installer for omarchy-stream. Shows the plan, asks once, backs up anything it changes.
# Safe to rerun. Does not install Sunshine or Tailscale for you (it tells you how).
set -euo pipefail
cd "$(dirname "$0")"

APP=~/.local/share/omarchy-stream
BIN=~/.local/bin/omarchy-stream
UNITS=~/.config/systemd/user
SUNCONF=~/.config/sunshine/sunshine.conf
# The main Sunshine may run under another unit name (e.g. apollo) and from a binary that
# isn't first on PATH. Prefer whatever unit is running; SUNSHINE_UNIT / SUNSHINE override.
if [[ -z ${SUNSHINE_UNIT:-} ]]; then
  SUNSHINE_UNIT=sunshine
  for u in sunshine apollo app-dev.lizardbyte.app.Sunshine; do
    [[ $(systemctl --user is-active "$u" 2>/dev/null) == active ]] && { SUNSHINE_UNIT=$u; break; }
  done
fi
if [[ -z ${SUNSHINE:-} ]]; then
  pid=$(systemctl --user show -p MainPID --value "$SUNSHINE_UNIT" 2>/dev/null || true)
  [[ -n $pid && $pid != 0 ]] && SUNSHINE=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
  [[ -n ${SUNSHINE:-} ]] || SUNSHINE=$(command -v sunshine || true)
fi
[[ -n $SUNSHINE ]] || { echo "Sunshine not found. Install it first: yay -S sunshine"; exit 1; }
SUNREAL=$(readlink -f "$SUNSHINE")
# Reruns keep the configured port; it is busy only because our own dashboard holds it.
CUR=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("dashboard_port",""))' \
      ~/.config/omarchy-stream/config.json 2>/dev/null || true)
PORT=${DASHBOARD_PORT:-${CUR:-8080}}
if ! [[ $PORT == "$CUR" && $(systemctl --user is-active omarchy-stream-dashboard 2>/dev/null) == active ]]; then
  while ss -Hltn "sport = :$PORT" 2>/dev/null | grep -q .; do PORT=$((PORT+10)); done
fi

echo "Sunshine: $SUNREAL (unit: $SUNSHINE_UNIT.service). Dashboard port: $PORT"
echo "omarchy-stream will:"
echo "  1. copy the app to $APP and link $BIN"
echo "  2. install user units: sunshine@.service, omarchy-stream-dashboard.service"
if [[ -f $SUNCONF ]]; then
  echo "  3. back up $SUNCONF, set capture=kms, remove Windows-only/low-fps keys (your other settings stay)"
else
  echo "  3. create $SUNCONF from config/sunshine.conf"
fi
getcap "$SUNREAL" 2>/dev/null | grep -q cap_sys_admin \
  || echo "  4. sudo setcap cap_sys_admin+p $SUNREAL   (KMS capture)"
echo "  5. register session hooks in sunshine.conf (VRR off and stream keys while streaming; optional lock on disconnect;"
echo "     toggle in ~/.config/omarchy-stream/config.json). Skipped if you already have a global_prep_cmd."
echo "  5b. add one line to hyprland.lua (backed up) so the virtual screen's size survives config reloads"
echo "  6. enable the dashboard and stop running disable-wifi.sh if it is in Hyprland autostart (it is commented out, not deleted)"
echo "  7. restart $SUNSHINE_UNIT.service so the new settings apply (drops any stream in progress)"
if [[ ${1:-} == -y ]]; then echo "Proceeding (-y)."
else read -rp "Proceed? [y/N] " ok; [[ $ok == [yY] ]] || exit 1; fi

ts=$(date +%Y%m%d-%H%M%S-%N)
mkdir -p "$APP/dashboard" "$APP/mac" "$UNITS" ~/.local/bin
install -m755 omarchy-stream "$APP/"
install -m644 dashboard/index.html "$APP/dashboard/"
install -m755 mac/omarchy-connect "$APP/mac/"
mkdir -p "$APP/mac/app"
install -m755 mac/app/omarchy-remote "$APP/mac/app/"
install -m644 mac/app/Info.plist "$APP/mac/app/"
ln -sf "$APP/omarchy-stream" "$BIN"

sed "s|@SUNSHINE@|$SUNSHINE|" systemd/sunshine@.service > "$UNITS/sunshine@.service"
install -m644 systemd/omarchy-stream-dashboard.service "$UNITS/"

mkdir -p "$(dirname "$SUNCONF")"
if [[ -f $SUNCONF ]]; then
  if grep -qE '^\s*(nvenc_realtime_hags|nvenc_latency_over_power|minimum_fps_target)\s*=' "$SUNCONF" \
     || ! grep -qE '^\s*capture\s*=\s*kms\s*$' "$SUNCONF" \
     || ! grep -qE '^\s*nvenc_preset\s*=' "$SUNCONF"; then
  cp -n "$SUNCONF" "$SUNCONF.bak.$ts"
  sed -i -E '/^\s*(nvenc_realtime_hags|nvenc_latency_over_power|minimum_fps_target|capture)\s*=/d' "$SUNCONF"
  echo "capture = kms" >> "$SUNCONF"
  grep -qE '^\s*nvenc_preset\s*=' "$SUNCONF" || echo "nvenc_preset = 1" >> "$SUNCONF"
  fi
else
  cp config/sunshine.conf "$SUNCONF"
fi

HOOK="{\"do\":\"$APP/omarchy-stream hook connect\",\"undo\":\"$APP/omarchy-stream hook disconnect\"}"
if ! grep -qE '^\s*global_prep_cmd\s*=' "$SUNCONF"; then
  cp -n "$SUNCONF" "$SUNCONF.bak.$ts"
  echo "global_prep_cmd = [$HOOK]" >> "$SUNCONF"
elif ! grep -q 'omarchy-stream hook' "$SUNCONF"; then
  echo "note: you already have a global_prep_cmd; add this entry to it yourself: $HOOK"
fi
mkdir -p ~/.config/omarchy-stream
# Merge: keep the user's toggles, refresh what was detected above.
python3 -I - ~/.config/omarchy-stream/config.json "$SUNSHINE_UNIT" "$SUNREAL" "$PORT" <<'PY'
import json, sys
path, unit, binary, port = sys.argv[1:]
try:
    cfg = json.load(open(path))
except (OSError, ValueError):
    cfg = {"disable_vrr_while_streaming": True, "lock_on_disconnect": False}
cfg.update(sunshine_unit=unit, sunshine_bin=binary, dashboard_port=int(port))
json.dump(cfg, open(path, "w"), indent=2)
PY

getcap "$SUNREAL" 2>/dev/null | grep -q cap_sys_admin || sudo setcap cap_sys_admin+p "$SUNREAL"

# Let the virtual display's size rule survive config reloads: include omarchy-stream's rule file.
HL=~/.config/hypr/hyprland.lua; HC=~/.config/hypr/hyprland.conf
if [[ -f $HL ]] && ! grep -q 'omarchy-stream.lua' "$HL"; then
  cp -n "$HL" "$HL.bak.$ts"
  printf '\n-- omarchy-stream: virtual display size (file exists only after first use)\ndo local f = os.getenv("HOME") .. "/.config/hypr/omarchy-stream.lua"; local h = io.open(f); if h then h:close(); dofile(f) end end\n' >> "$HL"
elif [[ ! -f $HL && -f $HC ]] && ! grep -q 'omarchy-stream.conf' "$HC"; then
  cp -n "$HC" "$HC.bak.$ts"
  touch ~/.config/hypr/omarchy-stream.conf
  printf '\n# omarchy-stream: virtual display size\nsource = ~/.config/hypr/omarchy-stream.conf\n' >> "$HC"
fi

AUTO=~/.config/hypr/autostart.conf
if [[ -f $AUTO ]] && grep -qE '^[^#].*(disable-wifi|serve\.sh)' "$AUTO"; then
  cp -n "$AUTO" "$AUTO.bak.$ts"
  sed -i -E 's/^([^#].*(disable-wifi|serve\.sh).*)$/# disabled by omarchy-stream: \1/' "$AUTO"
fi

systemctl --user daemon-reload
systemctl --user enable --now omarchy-stream-dashboard.service
systemctl --user restart omarchy-stream-dashboard.service
systemctl --user restart "$SUNSHINE_UNIT" 2>/dev/null || true

echo
echo "Done. Dashboard: http://localhost:$PORT  Token: $(cat ~/.config/omarchy-stream/token 2>/dev/null || echo 'created on first start')"
echo "Next: omarchy-stream doctor"
sleep 1
echo
"$BIN" mac 2>/dev/null || true
