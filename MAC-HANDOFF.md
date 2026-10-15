# Handoff: the Mac side of omarchy-stream

State as of 2026-10-15. The PC is `platanvejomarchy` (100.83.83.58), the Mac is
`svens-macbook-air-1` (100.87.86.22, macOS 26.2, user `sven`). Everything below was checked
on the real machines, not inferred.

## How to reach the Mac from the PC

Remote Login is on and the PC's key is trusted:

```bash
ssh sven@100.87.86.22        # works from the PC with no password
```

That is how the Mac side was verified; use it instead of asking the user to run things.

## What is installed on the Mac

| Thing | Where |
|---|---|
| App | `/Applications/Omarchy Remote.app` (unsigned, installed by curl so not quarantined) |
| Launcher (menu) | `…/Contents/MacOS/omarchy-remote` |
| Client (the work) | `…/Contents/Resources/omarchy-connect` |
| Settings | `~/.config/omarchy-stream/client.env` |
| Logs | `~/Library/Logs/omarchy-remote.log`, `omarchy-clipboard.log`, `omarchy-dictation.log` |
| Also present | Moonlight.app, Tailscale, **ffmpeg and sox** (both already there) |

`client.env` currently: `HOST=100.83.83.58`, `DASHBOARD_PORT=8110`, `AUDIO=host`,
`HOST_USER=sven`, `DICTATE_MIC=host`, plus `TOKEN`.

The app self-updates on every launch: the launcher pulls `/mac/omarchy-connect` and the client
pulls `/mac/app/omarchy-remote` from the PC's dashboard. So shipping a Mac-side fix means
deploying on the PC (`./install.sh -y`) and relaunching the app. `client.env` is **not**
updated that way: new keys have to be added to the file (that is how `HOST_USER` and
`DICTATE_MIC` were missing until they were added by hand).

## Menu

Screen sized to this Mac · Main monitor (ultrawide) · All three monitors · Check connection ·
Fix connection · Sound: this Mac / Omarchy speakers · Clipboard sync: On / Off ·
Dictation mic: Omarchy / this Mac.

While streaming: Ctrl+Option+1…5 workspace, Ctrl+Option+Q disconnect, Option+X (hold) dictate.

## Verified on hardware

- Streaming daily: virtual screen at the Mac's size, one cursor, clipboard both ways
  (text 37 B, PNG 77 KB), sound on the PC's speakers with Sunshine's copy muted.
- **Fix connection**, both rungs: through the dashboard ("fixed: Sunshine restarted"), and with
  `DASHBOARD_PORT` bent to 1, over ssh ("fixed over ssh … hyprland: up").
- **Dictation choreography**, both machines live: the PC's `dictate start` flipped the flag, the
  Mac's held-open poll saw it in 0.13 s, ffmpeg started, release stopped it, and the Mac
  correctly declined to upload silence.

## Not verified, and why

- **Speech → text → typed.** macOS has not granted the microphone to Omarchy Remote. Only a
  human can grant it, in the GUI, on the first hold of Option+X. A denied mic returns
  **silence, not an error** (26328 bytes at amplitude 0.000000), which is why the client now
  checks for non-zero PCM and names the System Settings panel instead of uploading.
- Everything on the PC's own microphone path works and needs none of this.

## Gotchas that cost time

- The Mac's Tailscale build has **no `ssh` subcommand**: it prints help and exits 0, which read
  as success. Use plain `ssh`; on the tailnet, tailscaled answers port 22 itself, so no key is
  needed. Prove a remote command ran by its output, not by ssh's exit code.
- The client runs under `set -euo pipefail`: a bare `x=$(ssh …)` kills it on failure. Use `|| true`.
- bash starts background jobs with **SIGINT ignored**, so `kill -INT` never reaches a recorder.
  Use SIGTERM (ffmpeg and sox finalise the WAV header on it) with an escalation to SIGKILL.
- Notifications are suppressed unless `OMARCHY_GUI` is set, which matters when testing by hand.

## PC side, in one paragraph

Repo `~/omarchy-remote-dashboard`, branch `v2` (also the copy at `~/Downloads/omarchy-stream`
is stale, do not edit it). Deployed to `~/.local/share/omarchy-stream` by `./install.sh -y`.
Units: `apollo` (Sunshine) and `omarchy-stream-dashboard`, both enabled, port 8110, token in
`~/.config/omarchy-stream/token`. `omarchy-stream doctor` is green except what it warns about.
`tests/run.sh` is 195 checks, all passing; run it before any commit.

## Open items

1. The microphone click, above.
2. The Linux MacBook (`OmarchyMacbookSven`, 100.71.13.32) is not paired with the PC yet. See
   `HANDOFF.md` for the detail: moonlight-qt 6.1.0's CLI pairing loops, so pairing has to start
   in its GUI, and the PIN can then be submitted from the laptop against `/api/pair/48189/<pin>`.
3. Autologin is on, but the disk is LUKS with the old `encrypt` hook, so a reboot still stops at
   the passphrase prompt. Switching to `sd-encrypt` (the TPM key is already enrolled) would make
   reboots unattended; it touches booting, so do it with the user present.
