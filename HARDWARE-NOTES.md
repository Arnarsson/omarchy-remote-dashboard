# Hardware notes: platanvejomarchy (2026-10-14)

Actual host facts. The v3 handoff assumed different ones.

| Thing | Handoff assumed | Actual |
|---|---|---|
| Monitors | 3x 1920x1080 (HDMI-A-2, DP-2, DP-1) | DP-3 1920x1080@144 (x=-1933,y=168), DP-1 3440x1440@100 (x=0), HDMI-A-2 1920x1080@144 (x=3456,y=199). Bounding box 7309x1440 |
| GPU | NVIDIA | RTX 3070 (GA104), nvenc found in sunshine.log |
| Tailscale IP | 100.73.206.17 | 100.83.83.58 (platanvejomarchy) |
| Default routes | equal metric (Error -1) | eno2 metric 100, wlo1 metric 600: already fine |
| Sunshine unit | `sunshine` | **apollo.service** (enabled, running /usr/bin/sunshine, sunshine-git 2026.1006). sunshine.service exists but is disabled/inactive |
| Sunshine binary | `command -v sunshine` | PATH resolves /usr/local/bin/sunshine -> stale May "dirty" build. Real one is /usr/bin/sunshine |
| Port 8080 | free | taken on 127.0.0.1 by clickclack |
| VRR | on | misc:vrr = 0 already |
| sunshine.conf | - | stock + upnp=disabled, min_log_level=verbose (log.2 was 165 MB), csrf_allowed_origins |
| Watchdog | - | sunshine-tailscale-watchdog.timer restarts apollo.service on tailscaled flaps |

## Bugs v3 would hit here
1. install.sh setcaps the stale /usr/local/bin build and points sunshine@.service at it.
2. install.sh `systemctl --user restart sunshine` would start a 2nd Sunshine next to apollo (port clash).
3. CLI/dashboard track unit `sunshine`, so the status and the all-monitors stream are wrong.
4. Dashboard on 8080 collides with clickclack on 127.0.0.1.

## Design concern (unverified)
Sunshine on Linux captures one output per instance (KMS/wlr `output_name`). There is no
combined-desktop capture, so "all monitors, one window" at 7309x1440 probably streams a
single monitor. Check on a real stream.

## Fixed in this session (tests: 69/69, 11 new)
- install.sh detects the running unit (sunshine|apollo|lizardbyte) and the binary from its
  MainPID (/proc/PID/exe); SUNSHINE_UNIT / SUNSHINE / DASHBOARD_PORT override. Writes
  sunshine_unit, sunshine_bin, dashboard_port into config.json (merged, toggles kept).
- Dashboard port scans 8080, 8090, ... for a free one. Here 8080 (clickclack), 8090 and 8100 are busy, so it picks 8110.
- CLI: doctor/status/API/multi use config's unit; doctor adds a `sunshine-unit` check.
- install restarts the detected unit (and the dashboard on reruns).

## Verified on hardware before install
- /usr/bin/sunshine already has cap_sys_admin,cap_sys_nice=p, so no sudo is needed.
- /dev/uinput is root:input 660 and sven is in `input`.
- `hyprctl output create headless NAME` works on Hyprland 0.56.2 (appeared at x=5376 at 1920x1080 and removed cleanly).
- Current capture before install: wlr ("Screencasting with Wayland's protocol"), not KMS.
- hypridle lock_cmd = omarchy-system-lock, so `loginctl lock-session` should lock.

## Open issues (not fixed)
- Mac `multi` uses one MONITOR_RES for all instances; DP-1 here is 3440x1440.
- Mac defaults DESKTOP_RES=5760x1080 and HOST=omarchy. Set HOST=platanvejomarchy (or 100.83.83.58).

## Installed and verified (2026-10-14 09:47+)
- install.sh ran 5 times: rc=0 each, 1 backup (sunshine.conf.bak.20261014-094503-*), hook registered once.
  sunshine.conf diff: +capture=kms, +nvenc_preset=1, +global_prep_cmd (hooks). Nothing removed.
- config.json: sunshine_unit=apollo, sunshine_bin=/usr/bin/sunshine, dashboard_port=8110.
- doctor: all ✔, rc=0. Sven's MacBook Air direct via 192.168.50.12:41641 (LAN).
- Sunshine log after the restart: "Screencasting with KMS", h264_nvenc + hevc_nvenc.
- Dashboard: 127.0.0.1 and 100.83.83.58 :8110 return page 200, no token 401, bad token 401, token 200. LAN IP refused.
- KMS index order (modetest -e): DP-1 -> crtc 200 (0), HDMI-A-2 -> 392 (1), DP-3 -> 584 (2) =
  connector-id order. `multi setup` now writes DP-1=0, HDMI-A-2=1, DP-3=2 (x-order would have been wrong for all 3).

## More bugs fixed
5. doctor flagged every idle tailnet peer as "relayed through DERP" (10 false ✘). It now judges Active peers only.
6. install rerun moved the dashboard port because its own dashboard held it. It now keeps the configured port.
7. multi output_name used x-order. It now uses DRM connector-id order (DRM_SYSFS overridable for tests).

## Consequence for "all monitors, one window"
apollo with KMS and no output_name captures index 0 = DP-1 (3440x1440) only. Streaming
the combined 7309x1440 desktop isn't possible with Sunshine KMS. On the Mac set
DESKTOP_RES=3440x1440 for `omarchy-connect`, or use `multi` / `virtual`.
8. Mac `multi` used one MONITOR_RES for all windows. It now takes one size per port.

## Mac client.env for this desk (~/.config/omarchy-stream/client.env on the Mac)
HOST=platanvejomarchy
DESKTOP_RES=3440x1440
MONITOR_RES="1920x1080 3440x1440 1920x1080"
MULTI_PORTS="48089 48189 48289"
TOKEN=<host: cat ~/.config/omarchy-stream/token>

## Virtual display, live test (2026-10-14 10:03)
- `omarchy-stream virtual 2560x1664@60,2`: headless output created, sunshine@virtual active on 48989.
- wlr capture DOES select OS-VIRTUAL by name: log says "[wlgrab] Selected monitor [] ... Offset 5376x0"
  (the [] is the empty description of a headless output).
- BUG 9: `hyprctl keyword monitor` fails on Hyprland 0.56 ("keyword can't work with non-legacy parsers. Use eval"),
  so the screen stayed 1920x1080. Working: `hyprctl eval 'hl.monitor({ output = "OS-VIRTUAL", mode = "2560x1664@60", position = "auto", scale = 2 })'`.
  Also, ~/.config/hypr/scripts/monitor-reload-on-hotplug.sh runs `hyprctl reload` 1 s after monitoradded, which wipes
  runtime monitor rules. So: wait, apply, verify, retry.
- `virtual off` removes the output and stops the instance cleanly.

## Pairing automation (verified host side)
- `sunshine <instance.conf> --creds USER PASS` sets that instance's web-UI login (exits, keeps pairings).
- This sunshine-git uses GET https://localhost:<port+1>/api/pin -> {"pairings":[{id,name,address}]} and
  POST {pairing_id (32 hex), pin, name}. Basic auth works, no CSRF needed without an Origin header. Wrong password gives 401.
- Plan: host stores per-instance creds; the Mac starts `moonlight pair host:port --pin N`; host polls GET and POSTs.
  Moonlight's `pair --pin` CLI is unverified (no Mac here), so fall back to prompting for the PIN Moonlight shows.

## Plug and play (2026-10-14 10:10)
- `install.sh -y` ran OK and printed the Mac one-liner.
- GET /mac/setup over the Tailscale IP served a 171-line script. Running it in a scratch HOME gave HOST=100.83.83.58,
  DESKTOP_RES=3440x1440, MONITOR_RES="1920x1080 3440x1440 1920x1080", MULTI_PORTS="48089 48189 48289", DASHBOARD_PORT=8110,
  and a client byte-identical to mac/omarchy-connect.
- POST /api/virtual/2560x1664@60,2: the screen came up at 2560x1664 (eval fix) and wlgrab captured at 2560x1664. webcreds 600.
- POST /api/pair/48989/1234 logged into the real instance API and returned "no pairing request arrived" after 20 s (expected, no Mac).
- POST /api/multi/up: three instances active, apollo stopped. CRTC per instance: DP-3=584, HDMI-A-2=392, DP-1=200, all correct.
  POST /api/multi/down: instances stopped, apollo active again, doctor rc=0.
- Still unverified: Moonlight `pair --pin` on the Mac, the hooks during a real stream, and image quality.

## First real stream from the Mac (virtual, 2026-10-14 10:17-10:19). User: "very bad, slow, two mice"
Evidence:
- Hooks DO fire on this Sunshine: "Executing Do Cmd ... hook connect" and "Executing Undo Cmd ... hook disconnect".
- Mac was on the home LAN, direct (192.168.50.12:41641). Client asked 60000 kbps, Sunshine used 46988 kbps, HEVC, about 60 fps (7252 frames in about 2 min).
- 41 IDX_REQUEST_IDR_FRAME from the client, i.e. constant packet loss.
- Host to router: avg 2.6 ms (wired eno2, fine). Host to Mac: 3 ms to 133 ms in bursts (avg 43, mdev 46). Typical macOS
  Wi-Fi AWDL / power-save spikes. omarchy-connect only used the median RTT, so it chose the full bitrate.
- Instances inherit min_log_level=verbose from the main conf: a 10 MB log in 2 min, every mouse packet logged.
- Two cursors: the client sends ABSOLUTE mouse packets, so Moonlight shows the Mac cursor AND the host cursor is
  composited into the wlr capture (lagging behind on the lossy link).
- Lock did NOT happen: hypridle/hyprlock aren't installed. Omarchy now locks with `omarchy-system-lock`
  (omarchy-shell lock), so `loginctl lock-session` has no listener (rc 0, LockedHint=no).
- Latent bug: the VRR hook uses `hyprctl keyword`, which is rejected on Hyprland 0.56 (Lua). VRR was already 0 here.
- `hyprctl eval 'hl.config({ cursor = { invisible = true } })'` works (getoption cursor:invisible -> bool true), and reverting works.
- wlr capture of OS-VIRTUAL used zwp_linux_dmabuf + CUDA external memory (GPU path) and held 60 fps.
  Capture wasn't the bottleneck; the Mac's Wi-Fi was.

## Fixes after the first stream (106 tests)
- Hooks set Hyprland options with keyword, falling back to eval (VRR now works on 0.56).
- New: hide_host_cursor_while_streaming (default on). connect sets cursor:invisible=true, disconnect restores it.
  Verified live: getoption gives bool true after connect.
- Lock: omarchy-system-lock first, then `loginctl lock-session <Display session>`. Not triggered live (it would lock the desk).
- Instances force min_log_level=info.
- Mac: bitrate also drops for latency spikes (p90 - median), --absolute-mouse (Mac cursor), --performance-overlay
  (SHOW_STATS=1), and pauses awdl0 while streaming (AWDL_OFF=1, asks for sudo), restored afterwards.
- Unverified: whether Moonlight on the Mac accepts --absolute-mouse/--performance-overlay, and the AWDL effect on the spikes.
- Mac app (Omarchy Remote.app) added 2026-10-14 10:40: built from /mac/setup and dry-run here. Not yet run on the Mac.

## App test 2 (10:49-10:52): "can't use mouse on main screen, mouse doesn't work on Mac"
- Mac input arrived (hyprctl cursorpos moved inside OS-VIRTUAL, x 6316 -> 6704). The host cursor was hidden by the
  hook, and Moonlight (--absolute-mouse) showed no local cursor either, so there was no cursor anywhere. At the desk,
  the hidden cursor sat on the invisible virtual screen.
- The virtual screen showed an empty workspace (4); all windows stay on the physical monitors.
Fixes: hide_host_cursor default false, Moonlight --no-absolute-mouse (capture: exactly one, the host's cursor),
stream-only keys via hl.bind/eval (Ctrl+Alt+1..5 = focus workspace N on the current monitor, Ctrl+Alt+Q = disconnect),
virtual opens on workspace 1, and the app self-updates omarchy-connect from GET /mac/omarchy-connect.
Verified live: the 6 binds appear/disappear in `hyprctl binds`. `hl.dispatch(hl.dsp.focus({workspace, on_current_monitor=true}))`
brought ws 9 to the focused monitor. Not verified: /api/apps/close ending a live session.
Lock after disconnect: LockedHint stays "no" even though omarchy-system-lock ran? Unknown, so ask the user whether the desk was locked.

## Lock verified on hardware (from the 10:52 disconnect)
omarchy-shell journal: 10:52:16.82 "lock-requested", 10:52:17.39 "secure=true" (locked); 10:52:23 PAM
"Authenticated successfully", then "unlocked" (a password was typed at the desk). `omarchy-shell lock status` / `isLocked`
can be queried. Race found: the hook ran while `virtual off` was already stopping sunshine@virtual (it won by 1.7 s).
`virtual off` now waits for session.json to disappear (the hook finished) before stopping the instance.

## Session 3 (11:09, virtual): "much better, just one mouse, still some bandwidth issues, laggy with audio"
- One cursor confirmed by the user. Ctrl+Option+N switching was used (OS-VIRTUAL showed ws 2, physical monitors reshuffled).
- Host to Mac pings during the stream still spike: 2-3 ms baseline with bursts of 131/108/86/62 ms. Mac Wi-Fi side.
Changes: on Wi-Fi the bitrate ceiling is 25 Mbps (WIFI_MAX_BITRATE_KBPS); the Mac POSTs diagnostics (path, awdl state, PHY/channel/
signal/noise/tx rate) to /api/report -> ~/.config/omarchy-stream/client-report.log; AUDIO=mac|host with the app asking
each connect (--audio-on-host); `virtual off` restores the physical monitors' workspaces (layout.json).
- 11:15 user: lock on disconnect is a 'death sentence' when remote. Now lock_on_disconnect defaults to false (and is set false on this host). Layout restore verified after the 11:15 disconnect (DP-1 1, DP-3 2, HDMI-A-2 3).

## Session 4 (11:22): audio on host verified, launch about 50 s
- Audio: Sunshine didn't switch the default sink (no "Setting default sink"); pactl default = analog output.
- First Mac report: 802.11ax ch36 80 MHz, -37/-91 dBm, 1080 Mbps, awdl0 DOWN (pause worked), rtt 4 ms, p90 80 ms, so it chose 10 Mbps.
  Signal and AWDL ruled out; idle spikes are maybe power-save/scanning. User: "much better".
- Launch timeline (host): API about 11:21:58, instance up 11:22:02.2, Moonlight connected 11:22:12.5. The other ~35 s were on the Mac
  (dialogs, 10 sequential `tailscale ping`s, Moonlight start, fixed 2 s sleep).
Changes: measure = 1 tailscale ping (path) + `ping -c 10 -i 0.1` (about 1 s); the host polls (mode applied, port listening)
instead of fixed sleeps; Mac's sleep 2 removed; the report includes a step timing line ("timing: start= measured= screen_ready= moonlight=").

## Clipboard sync (11:40). Request: "copy paste from Raycast clipboard, pics and text, on by default but optional"
- Host: GET /api/clipboard[?have=sha1] (200 body or 304/204), POST (text or image/png -> wl-copy). Verified with real
  wl-clipboard: text in/out, 304 on the same hash, a 1x1 PNG round-trips identically; the user's clipboard was restored afterwards.
- Mac: clip_sync loop while streaming (text every 0.15 s via pbpaste|cksum, PNG every 0.45 s via `clipboard info` +
  osascript «class PNGf» + xxd, host->Mac every 0.6 s). CLIPBOARD=1 default; the app menu toggles it.
- The launcher now self-updates via the client (atomic mv); GET /mac/app/omarchy-remote.
- Bug caught by tests: under set -e, `kill $clip` on an exited loop aborted before AirDrop was restored.
- Known race: Raycast "Paste" copies then sends Cmd+V at once; the sync can lag by up to 0.15 s, so the first paste may be the
  previous item. Unverified on the Mac (osascript image paths, xxd).

## Session 5 (11:44): "still a little slow, and what happened to the screen?" (screenshot: huge 16:9 UI)
- OS-VIRTUAL was 1920x1080 scale 2 (logical 960x540). Event trace: any mode change triggers a `configreloaded` about 1 s later
  (omarchy-hyprland-monitor-watch and monitor-reload-on-hotplug.sh), which drops runtime `eval` monitor rules, so the mode can never stick at runtime.
  FIX: install.sh appends a guarded dofile of ~/.config/hypr/omarchy-stream.lua to hyprland.lua (backup kept); `virtual`
  writes the size rule there and runs `hyprctl reload` before creating the output. Verified live twice: 2560x1664@1
  held for 6 s through reloads, create about 2.0 s, off about 1.6 s, layout restored exactly, no configerrors.
- Restore ran before workspaces migrated (DP-1 was left on an empty ws 5). Now it waits for configreloaded and re-checks up to 3 times.
- Mac timing report: start=2s measured=10s screen_ready=14s moonlight=16s, and Moonlight connected at +45 s (Sunshine ready at +10 s).
  The measure was slow because of the Mac Tailscale CLI, so the host now answers /api/path. Moonlight's ~29 s is unexplained; the app now sends Moonlight's log after each session.
- 11:55 user: "clipboard no work". Likely cause: clip_sync ran under the script's `set -e`; the first failed push
  (`[[ ]] && push` with push returning curl's failure) or a failing `$(osascript ...)` ended the loop silently for the
  whole session (shown with a minimal repro: dies at tick 1). Fix: `set +e +o pipefail` inside the loop, push always
  returns 0, Mac log ~/Library/Logs/omarchy-clipboard.log (sent to the host after each session), and the host log
  ~/.config/omarchy-stream/clipboard.log. Tests: multi tests isolated (stray clip loops polluted the suite), strays pkill'd on exit.

## Session 6 (12:24): audio doubled, clipboard pasted the wrong item, still slow to launch
- Audio: with --audio-on-host this Sunshine plays locally AND records the real sink's monitor ("sunshine-record",
  Opus 512 kbps) and streams it, so the user heard Spotify on both. Fix: the Mac POSTs /api/audio/{host|mac}; the connect hook
  spawns `audio-apply`, which mutes/unmutes Sunshine's pactl source-output (host speakers untouched).
- Clipboard: host log showed only "Linux->Mac 1320 bytes" at 12:24:04. Connecting copied the Linux clipboard (an OAuth URL)
  onto the Mac. Bug: initial state was pulled instead of just noted. No Mac->Linux transfer at all, presumably because Raycast
  swaps the clipboard faster than 0.15 s polling. Fix: a long-running JXA watcher on NSPasteboard.changeCount (30 ms) grabs
  text/PNG immediately; startup only records the host hash.
- Timing: start=16s measured=18s screen_ready=21s moonlight=21s; Moonlight connected about 6 s later (was 29 s).
  16 s before measuring = two dialogs + updates, so the sound choice moved into the menu (OMARCHY_MENU_AUDIO).
- Moonlight logs to /tmp/Moonlight-*.log ("Redirecting log output to ..."); send_log now tails that file.
- 12:41 session: user confirms clipboard works for text and images. Screen 2560x1664@1, Sunshine capture muted with host audio, Moonlight connected 2 s after launch. click->measure was 43 s (menu time vs update unknown; now reported as menu_shown/chosen).

## 2026-10-14 (late) — remote access audit + Fix connection

Audited every route back into the PC (host platanvejomarchy, 100.83.83.58):
sshd active on :22, Tailscale Running with RunSSH=true, linger=yes,
sleep/suspend/hibernate masked with IdleAction=ignore, omarchy-stream-dashboard.service
and apollo.service both enabled at boot. One gap: no TTY1 autologin, so a reboot leaves
the PC at a login prompt with no session to stream. Left as a doctor warning on purpose:
autologin hands the desktop to anyone sitting at the PC.

Tailscale SSH authorization checked in the netmap: the Mac (svens-macbook-air-1,
100.87.86.22) is an allowed principal with sshUsers {'*': '='}, so `tailscale ssh
sven@100.83.83.58` works from the Mac with no key and no password. That is the
second rung under the dashboard for "Fix connection".

`omarchy-stream rescue` verified live: 0.37 s, apollo + dashboard active, hyprland up.
`POST /api/rescue` verified live on :8110 -> {"ok": true, "unit": "apollo",
"state": "active", "hyprland": true}, and the dashboard stayed up to answer (it only
restarts Sunshine; the CLI restarts both).
Verified in a bare non-interactive environment (what SSH gives you) that ~/.local/bin is
not on PATH, so the remote command falls back to the full path under
~/.local/share/omarchy-stream.

Test suite: the host's mise shim for python3 refuses to run once the tests move HOME
("config files not trusted"), which failed 30+ checks that had nothing to do with the
change. tests/run.sh now puts /usr/bin ahead of the caller's PATH. 176 checks, 3 clean runs.

Not verified on hardware: the SSH rung from the Mac itself (cannot be driven from here;
covered by stubs and by the netmap authorization check above).

## 2026-10-14 (late) — dictation from either microphone

Moonlight owns the keyboard while streaming, so Option+X always reaches the PC, never macOS.
The PC therefore drives dictation: `omarchy-stream dictate start|stop` is bound to Option+X
press/release for the session. With mic=host it calls voxtype directly (unchanged); with
mic=mac it only flips ~/.config/omarchy-stream/dictate.state, which the Mac is watching on a
held-open GET /api/dictate (25 s, 50 ms granularity). The Mac records while the key is down and
POSTs the WAV; the PC transcribes with voxtype and types it with wtype.

Verified live on the host:
- POST /api/dictate/mic/mac -> {"ok": true, "mic": "mac"}; `dictate start` writes "rec".
- Long poll: answered 0.13 s after the key press (1.63 s against a 1.5 s delay), and a poll
  with nothing happening returns after its full 25 s. voxtype left idle, not stuck recording.
- POST /api/dictate with a 32 KB 220 Hz tone: voxtype ran (5.3 s), recognised nothing, logged
  "nothing recognised", typed nothing, {"ok": false}. The whole upload path works.
- voxtype prints the transcript on its stderr INFO line, not stdout, which `run()` was dropping;
  transcribe_and_type now reads both streams.

Two bugs the stubs caught, both real:
- bash starts background jobs with SIGINT ignored, so `kill -INT` never reached the recorder:
  the loop then waited forever and dictation died for the rest of the session. Now SIGTERM
  (ffmpeg and sox both finalise the WAV header on it), with a 2 s escalation to SIGKILL.
- the recorder's temp path needed a .wav extension for ffmpeg to pick the WAV muxer.

Not verified on hardware: speech -> text -> wtype (no TTS here to synthesise speech, and typing
into the live session is intrusive), and the entire Mac half (recorder, mic permission, upload).
Needs `brew install sox` (or ffmpeg) on the Mac, and macOS will ask for Microphone permission.

## 2026-10-14 (night) — the Mac half, verified on the Mac

The MacBook Air has Remote Login on, so the Mac side could finally be driven from the PC
(ssh sven@100.87.86.22, key auth, macOS 26.2). ffmpeg and sox were already installed there,
so the "brew install sox" step was never needed. client.env predated the new keys and got
HOST_USER=sven and DICTATE_MIC=host; the app's bundled client and launcher were refreshed
from /mac/* on the PC.

Verified Mac -> PC, for real:
- "Fix connection", rung 1: `omarchy-connect rescue` -> "fixed: Sunshine restarted (dashboard
  answered)".
- rung 2: with DASHBOARD_PORT bent to 1, -> "dashboard did not answer, going in over SSH ...
  fixed over ssh: dashboard: active / apollo: active / hyprland: up". Config restored after.
- Dictation choreography, both machines live: the Mac's held-open poll returned "rec" when
  `dictate start` ran on the PC, it started ffmpeg, the next poll returned "idle" on release,
  it stopped the recorder and correctly declined to upload.

Three real bugs this access exposed, all fixed:
- `tailscale ssh` does not exist in the Mac's Tailscale build: it printed help and exited 0,
  which the rescue read as success. Plain ssh is enough (tailscaled answers port 22 on the
  tailnet), and success is now proven by rescue's own "hyprland:" line, not by ssh's exit code.
- the bare `ssh_out=$(ssh ...)` assignment killed the client through set -e on a failed ssh,
  so it never printed "could not reach the PC".
- a microphone macOS has not granted returns SILENCE, not an error: 26328 bytes at amplitude
  0.000000. The Mac now checks for non-zero PCM and names the System Settings panel to allow,
  instead of uploading silence and reporting "nothing recognised".

Doctor's autologin check reads AUTOLOGIN_DIR when set, so the suite stops depending on this
machine's /etc (it went green here once autologin was actually enabled).

Still needs a human, once: the macOS Microphone prompt on the first hold of Option+X, and
with it the proof that real speech comes out as typed text.
