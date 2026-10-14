# omarchy-stream 2.0

Parsec-style remote desktop from an **Omarchy (Hyprland)** PC to a **Mac**, built on
Sunshine + Moonlight over Tailscale. Click an app on the Mac and get a screen sized to the
Mac, one cursor, a synced clipboard, and sound where you want it.

2.0 replaces `omarchy-remote-dashboard` v1. It was developed and verified on a real host
(RTX 3070, Hyprland 0.56, three monitors, MacBook Air on Wi-Fi). `HARDWARE-NOTES.md` records
what was measured and every fix it led to.

## What's new in 2.0

**A real Mac app.** *Omarchy Remote* sits in the Dock: click it, pick a mode, done. No Terminal
after a one-line install. It updates itself from the PC on every launch.

**Virtual display, Parsec-style.** The PC creates an invisible screen exactly your Mac's size
(e.g. 2560×1664), streams it pixel-for-pixel, opens it on your main workspace, and removes it
when you disconnect, putting your monitors back on their usual workspaces.

**One cursor.** Moonlight captures the mouse and you drive the PC's cursor. No ghost second
pointer.

**Clipboard sync, both ways.** Text and pictures, including Raycast's clipboard history. A 30 ms
pasteboard watcher on the Mac catches even quick clipboard swaps. Connecting never overwrites
your Mac clipboard. Toggle it in the menu (on by default).

**Choose where sound plays.** This Mac, or the PC's speakers (e.g. better speakers at the
office). With PC speakers, Sunshine's copy is muted so you don't hear it twice.

**Stream keys.** While streaming: Ctrl+Option+1…5 brings a workspace to the screen you're
watching, Ctrl+Option+Q disconnects. They exist only during a session.

**Smarter connection.** It measures the path before connecting (direct vs relayed, latency
spikes, loss) and picks the bitrate, capped at 25 Mbps on Wi-Fi. AirDrop (AWDL), a common cause
of Mac Wi-Fi lag spikes, is paused while you stream and restored afterwards.

**Plug and play.** Pairing with Moonlight is automatic. The installer detects your Sunshine unit
and binary (e.g. `apollo.service`), finds a free dashboard port, and backs up everything it
touches. `doctor` checks capture, encoder, input, routing and the Tailscale path.

**Faster launch.** Path check in about a second, no fixed sleeps, screen ready in about 2 s on the PC.

**Safe when remote.** The PC never locks on disconnect by default (a locked host can strand
you). Opt in with `lock_on_disconnect`.

**Diagnostics without asking you.** Each session the Mac sends its Wi-Fi details, per-step
launch timing, Moonlight's log and the clipboard log to the PC, so problems can be diagnosed there.

## Using it (Mac)

| Menu item | What happens |
|---|---|
| Screen sized to this Mac | Invisible screen at your Mac's resolution (recommended) |
| Main monitor (ultrawide) | Streams the PC's main monitor |
| All three monitors | One Moonlight window per PC monitor |
| Check connection | Direct/relayed, latency and the bitrate it would use |
| Sound: this Mac / Omarchy speakers | Toggle where audio plays |
| Clipboard sync: On / Off | Toggle clipboard sync |

| Keys while streaming (Option = Alt) | Action |
|---|---|
| Ctrl+Option+1 … 5 | Bring that workspace to the screen you're watching |
| Ctrl+Option+Q | Disconnect |
| Ctrl+Option+Shift+Z | Release the mouse to the Mac (Moonlight) |
| Ctrl+Option+Shift+S | Stats overlay (Moonlight) |

## Install

**PC (Omarchy):**
```bash
yay -S sunshine-git                      # or sunshine
sudo systemctl enable --now tailscaled && sudo tailscale up
./install.sh -y
omarchy-stream doctor                    # everything should be green
```
`install.sh` sets KMS capture, registers the session hooks, installs the dashboard
(localhost + Tailscale IP only, token auth), and adds one guarded line to `hyprland.lua`
so the virtual screen's size survives config reloads. Backups: `*.bak.<timestamp>`.

**Mac, once:** paste the line `omarchy-stream mac` prints on the PC into Terminal:
```bash
curl -fsSL -H "Authorization: Bearer <token>" http://<tailscale-ip>:<port>/mac/setup | bash
```
It installs Omarchy Remote.app (Applications + Dock), the `omarchy-connect` command, Moonlight
via Homebrew if missing, your settings, and a one-time sudoers rule for the AirDrop pause.

## Host commands

```
omarchy-stream doctor [--json]     what's wrong and how to fix it
omarchy-stream monitors            monitors and the combined desktop
omarchy-stream virtual WxH@HZ,S    create the virtual screen (or: off)
omarchy-stream multi setup|up|down one Sunshine per monitor
omarchy-stream disconnect          end all streams
omarchy-stream mac                 print the Mac setup line
omarchy-stream serve               dashboard/API (runs as a user service)
```

Settings: `~/.config/omarchy-stream/config.json` (PC), `~/.config/omarchy-stream/client.env` (Mac).
Logs: PC `~/.config/omarchy-stream/{client-report,clipboard}.log`; Mac `~/Library/Logs/omarchy-*.log`.

## How it works

- **Capture**: KMS for physical monitors; the virtual screen is a headless Hyprland output captured
  with wlroots screencopy (GPU dmabuf path). Sunshine on Linux captures one output per instance, so
  "all monitors" means one instance (and window) per monitor, mapped by DRM connector order.
- **Hooks** (Sunshine `global_prep_cmd`): VRR off, stream-only keybindings and audio routing on
  connect; all restored on disconnect.
- **Dashboard API** (token auth): virtual screen, multi up/down, pairing, clipboard, path check,
  audio preference, Mac diagnostics, and the Mac app's self-update files.

## Tests

`tests/run.sh` runs 161 checks with stubbed system tools (Sunshine, Hyprland, Tailscale, PipeWire,
macOS tools, Moonlight): installer, doctor, hooks, virtual/multi, dashboard API, Mac client and app.

## Known limits

- The Mac app is unsigned (installed via `curl`, so Gatekeeper doesn't quarantine it).
- Raycast "Paste" can race the sync by a few milliseconds; if the previous item pastes, press Cmd+V again.
- Mac Wi-Fi still shows occasional latency spikes; a cable gives the best result.
- Upgrading from v1: `install.sh` comments out v1's `serve.sh` / `disable-wifi.sh` autostart lines.

See [KEYBOARD-SHORTCUTS.md](KEYBOARD-SHORTCUTS.md) for more Moonlight and Hyprland shortcuts.
