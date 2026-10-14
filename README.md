# omarchy-stream

Parsec-style remote hosting for **Omarchy (Hyprland)** using Sunshine + Moonlight,
tuned for a three-monitor desk streamed to a Mac over Tailscale.

v2 of `omarchy-remote-dashboard`. v1 tuned the wrong knobs; v2 fixes the causes:

| v1 problem | Cause | v2 fix |
|---|---|---|
| Blurry text with all monitors | Moonlight scaled 5760×1080 down to 1920×1080 | Stream at the **native desktop size** (`omarchy-stream monitors` prints it), HEVC/AV1, 40–60 Mbps |
| Laggy mouse | 30 fps cap and `minimum_fps_target = 15` | **60 fps**; floor removed |
| "Fixes" that did nothing | `nvenc_realtime_hags`, `nvenc_latency_over_power` are Windows-only; `nvidia-settings` vsync is X11-only | Removed; `doctor` flags them |
| Stutter | Capture method never set | `capture = kms` + `cap_sys_admin` |
| Error -1 → Wi-Fi disabled | Two default routes with equal metric | `doctor` detects it; prefer Ethernet by route metric and keep Wi-Fi on |
| Lag/drops from the office | Tailscale relaying through DERP | `doctor`, dashboard and `omarchy-connect` show direct vs relayed; fix = UPnP or UDP 41641 |
| Dashboard open to the LAN | Flask on `0.0.0.0`, CORS `*`, no auth, `shell=True` | Binds localhost + Tailscale IP only, token auth, no shell, stdlib only |

## What makes it feel like Parsec

- **Virtual display** (`omarchy-connect virtual`): the host creates a screen exactly the
  size of your Mac's display, streams it pixel-for-pixel, and removes it when you quit.
  No scaling, no black bars. Move any workspace onto it with
  `hyprctl dispatch moveworkspacetomonitor <n> OS-VIRTUAL`.
- **Session hooks**: Sunshine calls `omarchy-stream hook` on connect/disconnect. While
  you stream, Hyprland's VRR is off (it makes captured frame timing uneven); when you
  disconnect, VRR is restored. Locking on disconnect is off by default (a locked host can
  strand you when remote); set `lock_on_disconnect` in `~/.config/omarchy-stream/config.json`.
- **Adaptive bitrate**: `omarchy-connect` pings the host 10 times first and picks the
  bitrate from what it measures: full on a clean direct path, 70% when slower or with
  a little loss, 40% when slow or lossy, 25% when relayed.

## Three ways to stream your monitors

- **All monitors, one window.** `omarchy-connect` streams the full 5760×1080 desktop.
  Simple, and works on a single Mac screen (use full-screen + scroll, or an ultrawide).
- **One window per monitor.** `omarchy-stream multi setup && omarchy-stream multi up`
  runs one Sunshine per monitor; `omarchy-connect multi` opens a Moonlight window for
  each, which you put on separate Mac displays. Closest to sitting at the desk.
  Each instance pairs once. The dashboard switches between the two modes.

## Host (Omarchy)

```bash
yay -S sunshine                      # if not installed
sudo systemctl enable --now tailscaled && sudo tailscale up
./install.sh                         # shows the plan, asks (-y to skip), backs up what it touches
omarchy-stream doctor                # fix everything red before judging quality
```

`install.sh` backs up `sunshine.conf` and `hypr/autostart.conf`, sets KMS capture,
removes the dead settings, installs `sunshine@.service` for per-monitor instances and
the dashboard user service. It also comments out v1's `disable-wifi.sh` / `serve.sh`
autostart lines. Rerun it after Sunshine updates (the `setcap` doesn't survive them).

Dashboard: `http://localhost:8080` or `http://<tailscale-ip>:8080` with the token in
`~/.config/omarchy-stream/token`.

## Client (Mac): plug and play

On the host, `omarchy-stream mac` (also printed by `install.sh`) gives one line to paste
into Terminal on the Mac:

```bash
curl -fsSL -H "Authorization: Bearer <token>" http://<tailscale-ip>:<port>/mac/setup | bash
```

It installs **Omarchy Remote.app** (in Applications and the Dock), the `omarchy-connect`
command, `client.env` with this host's IP, monitor sizes, ports and token, Moonlight via
Homebrew if missing, and a one-time sudoers rule so AirDrop can be paused while streaming
(AWDL causes 100 ms Wi-Fi spikes). After that, click the app and pick a mode; no Terminal.
Status shows as notifications, errors as dialogs; log in `~/Library/Logs/omarchy-remote.log`.

From Terminal, the same modes:

```bash
omarchy-connect virtual  # a screen sized to this Mac (pixel-perfect, removed on quit)
omarchy-connect multi    # one window per monitor; the host starts the instances itself
omarchy-connect          # the main monitor (KMS index 0)
omarchy-connect check    # just test direct vs relayed
```

Extra streams pair themselves the first time: Moonlight starts the pairing and the host
submits the PIN through each instance's own Sunshine web login (`instances/*/webcreds`).
If the path is relayed, `omarchy-connect` warns and quarters the bitrate.

Note: Sunshine on Linux captures one output per instance, so "all monitors in one picture"
isn't possible with KMS. Use `multi` or `virtual` for more than the main monitor.

## Tests

`tests/run.sh` runs 131 checks with stubbed system tools (installer, doctor, hooks,
multi/virtual, dashboard API and auth, Mac script bitrate tiers). Run it after any change.

## Reading the result

Press `Ctrl+Alt+Shift+S` in Moonlight. If **network latency or drops** are high, the
path is the problem (run `doctor`). If **host processing latency** is high, check
encoder (`doctor` should show nvenc/vaapi, never software). If **decode time** is high,
lower `CODEC` to HEVC or the resolution.

## Not verified yet

Tested off-device with stubbed sunshine, hyprctl, tailscale, systemctl and Moonlight, and the dashboard in headless Chromium (no real Hyprland, GPU or Mac). Things to confirm on
real hardware: KMS monitor index order vs `hyprctl` order for `multi`, launching
several Moonlight windows with `open -n`, AV1 on your GPU/Mac pair, Sunshine's
wlr capture of the headless virtual output, and that Sunshine runs `global_prep_cmd`
hooks on your version.

See [KEYBOARD-SHORTCUTS.md](KEYBOARD-SHORTCUTS.md) for Moonlight and Hyprland shortcuts.
