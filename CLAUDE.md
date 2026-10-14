# omarchy-stream: handoff for Claude Code on the Omarchy host

You are running on the real Omarchy (Arch + Hyprland 0.56, Wayland) host `platanvejomarchy`
with an RTX 3070 and three monitors, left to right: DP-3 1920x1080@144, DP-1 3440x1440@100,
HDMI-A-2 1920x1080@144. The client is a Mac running Moonlight over Tailscale (host 100.83.83.58).
Sunshine runs as **apollo.service** (/usr/bin/sunshine, sunshine-git), not `sunshine`.
Full host facts and what was verified: HARDWARE-NOTES.md.

## Goal
Parsec-quality hosting with Sunshine + Moonlight: all three monitors sharp, 60 fps
smooth mouse, stable connection from the office. The user tried v1
(github.com/Arnarsson/omarchy-remote-dashboard) and found it poor; this folder is v2.

## Root causes found in v1 (all treated as important by the user)
1. Moonlight scaled the 5760x1080 desktop to 1920x1080 at 10 Mbps -> blurry. Stream native size, HEVC, 40-60 Mbps.
2. 30 fps and `minimum_fps_target = 15` -> laggy cursor. Use 60 fps.
3. `nvenc_realtime_hags`, `nvenc_latency_over_power` are Windows-only; `nvidia-settings` vsync is X11-only. Dead settings.
4. Tailscale likely relayed via DERP from office Wi-Fi. "Error -1" was "fixed" by disabling Wi-Fi; likely cause is two default routes with equal metric.
5. Capture method never set. Use `capture = kms` + `setcap cap_sys_admin+p` on the real sunshine binary.

## What's here
- `omarchy-stream` (Python stdlib): `doctor`, `monitors`, `multi setup|up|down`, `serve` (dashboard, localhost + Tailscale IP, token in ~/.config/omarchy-stream/token).
- `install.sh`: shows plan, asks, backs up (`*.bak.<ts>`, never overwritten), idempotent.
- `systemd/`: `sunshine@.service` (one instance per monitor), dashboard unit.
- `mac/omarchy-connect`: Moonlight launcher for the Mac (all / multi / check).
- `config/sunshine.conf`: baseline.
- `omarchy-stream hook connect|disconnect` (via Sunshine `global_prep_cmd`): VRR off while streaming, restore + lock on disconnect.
- `omarchy-stream virtual WxH@HZ,SCALE|off` + `POST /api/virtual/...`: headless Hyprland output, Sunshine instance with `capture = wlr` on port 48989. `omarchy-connect virtual` sizes it to the Mac.
- `omarchy-connect` measures the Tailscale path and scales bitrate (100/70/40/25%).
- Plug and play: `omarchy-stream mac` prints a one-liner; `GET /mac/setup` serves a Mac installer with
  client.env filled in; `POST /api/pair/<port>/<pin>` and `/api/multi/up|down`; `install.sh -y`.
  Moonlight's `pair --pin` CLI is unverified on the Mac (a fallback reads the PIN from its output).
- Mac app: `mac/app/` (Info.plist + launcher) is assembled by `/mac/setup` into Omarchy Remote.app with
  omarchy-connect in Resources. Unsigned; installed via curl, so it isn't quarantined. Untested on a real Mac.
- `tests/run.sh`: 132 stubbed checks. Run after every change.

## Verified on hardware (2026-10-14, before any stream)
install.sh (unit/binary/port detection, idempotent reruns, one backup), doctor all green,
KMS capture + nvenc in Sunshine's log, dashboard on 127.0.0.1 and 100.83.83.58 port 8110 with
token auth (not on the LAN IP), `hyprctl output create headless` works, KMS index order =
DRM connector-id order (modetest), and `multi setup` writes the matching output_name.
Later the same day: virtual display end-to-end on the host (eval mode fix, wlr captures
OS-VIRTUAL at 2560x1664), `multi up` via API (each instance on its own CRTC, confirmed by
Sunshine's "Final KMS display_names" line), `multi down` restores apollo, and the pairing
endpoint authenticates against the real Sunshine /api/pin. Mac setup one-liner served live.
Still needs a real stream: hooks firing, encoder under load, wlr capture of OS-VIRTUAL, Mac side.

## Verified off-device
Only off-device, with stubbed sunshine/hyprctl/tailscale/systemctl/Moonlight and the
dashboard in headless Chromium. Installer reruns, backups, decline path, doctor checks,
multi configs, stream switching and auth all passed. Nothing has run on real hardware.

## Your next steps
1. Read README.md, then run `./install.sh` with the user (it needs sudo once).
2. Run `omarchy-stream doctor`; fix every ✘ (routing metric, DERP path, uinput).
3. Have the user stream once, rerun doctor, confirm encoder is nvenc not software.
4. Unverified on hardware, check these:
   - ~~KMS `output_name` index order~~ done: connector-id order (DP-1 0, HDMI-A-2 1, DP-3 2); confirm the picture in each window.
   - Sunshine accepting the config-path argument in `sunshine@.service` on this version.
   - Hooks actually fire on this Sunshine version (watch `hyprctl getoption misc:vrr` during a stream).
   - Virtual display: `hyprctl output create headless` works on this Hyprland, and Sunshine's wlr capture selects OS-VIRTUAL by name (if not, it may need an index).
   - `fec_percentage`/bitrate tuning against Moonlight's stats overlay (Ctrl+Alt+Shift+S).
5. If the user wants it on GitHub: commit into their repo (Arnarsson/omarchy-remote-dashboard) on a new branch; ask before pushing.

Report results honestly: say what was verified on hardware and what wasn't.
