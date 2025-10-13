# Omarchy Remote Access Control System

Complete remote desktop streaming solution with web dashboard and Raycast extension.

## Features

### Web Dashboard (http://localhost:8080)
- **Real-time System Monitoring**: CPU, Memory, GPU usage and temperature
- **Service Status**: Live status of Tailscale, Sunshine, and WireGuard
- **Service Control**: Start, stop, restart Sunshine streaming
- **Connection Status**: See if your Mac is connected via Tailscale
- **Auto-refresh**: Updates every 5 seconds

### Raycast Extension (Mac)
- **Quick Connect**: Launch Moonlight to Omarchy with one command
- **System Status**: View all stats from Raycast
- **Remote Control**: Control Sunshine service remotely
- **Desktop Switching**: Switch Mac virtual desktops

## Installation

### On Omarchy (Linux)

Already installed and configured! Services start automatically on boot:
- Tailscale daemon
- Sunshine streaming server
- WireGuard VPN
- Remote Access Dashboard (Flask API + Web UI)

### On Mac

1. **Install Moonlight**: Download from [moonlight-stream.org](https://moonlight-stream.org)
2. **Install Tailscale**: Download from [tailscale.com/download](https://tailscale.com/download)
3. **Install Raycast Extension**:
   ```bash
   # Copy the extension folder to your Mac
   cd ~/raycast-omarchy-remote
   npm install
   npm run dev
   ```

## Usage

### Connecting from Mac

1. Make sure Tailscale is running on both machines
2. Open Moonlight
3. Add host: `100.73.206.17` (or use Raycast: `connect`)
4. Enter pairing PIN if prompted (visible in Sunshine dashboard)
5. **IMPORTANT: Select "All Monitors (5760x1080)"** to stream all 3 monitors
   - Selecting "Desktop" will only show one monitor
   - Individual monitor options (HDMI, DP-1, DP-2) stream single monitors
6. Enjoy full 3-monitor streaming!

#### Moonlight Settings for Slow Connections

If you're on a slow/unstable connection (like office wifi):

1. In Moonlight, go to **Settings**
2. Set **Bitrate**: 10 Mbps (or lower if still laggy)
3. Set **Resolution**: 1920x1080 or lower (will scale the 5760x1080 down)
4. Set **FPS**: 30 fps (configured on server)
5. Enable **Hardware Decoding** for better performance

The server is optimized for 10 Mbps with FEC (Forward Error Correction) for packet loss.

#### Mouse Capture and Desktop Switching

When streaming, Moonlight captures your mouse and keyboard. To switch Mac desktops or use Mac shortcuts:

**Key Shortcut: `Ctrl + Alt + Shift + Z`** - Toggle mouse/keyboard capture on/off

**How to switch Mac desktops while streaming:**
1. Press `Ctrl + Alt + Shift + Z` to release mouse/keyboard
2. Use `Ctrl + Left/Right Arrow` to switch Mac desktops (or swipe with 3 fingers on trackpad)
3. Press `Ctrl + Alt + Shift + Z` again to recapture for streaming

**Other useful Moonlight shortcuts:**
- `Ctrl + Alt + Shift + Q` - Quit streaming session
- `Ctrl + Alt + Shift + X` - Toggle fullscreen/windowed mode
- `Ctrl + Alt + Shift + S` - Show performance stats
- `Ctrl + Alt + Shift + M` - Toggle mouse mode
- `Ctrl + Alt + Shift + D` - Minimize stream window
- `Ctrl + Alt + Shift + V` - Paste clipboard from Mac to Linux

#### Clipboard Sync (Copy/Paste Between Mac and Linux)

Clipboard sync is built into Moonlight/Sunshine with a keyboard shortcut:

**Mac → Linux (Omarchy):**
1. Copy text on your Mac (`Cmd + C`)
2. While streaming in Moonlight, press `Ctrl + Alt + Shift + V`
3. This pastes your Mac clipboard directly on Omarchy

**Linux (Omarchy) → Mac:**
Unfortunately, clipboard sync from Linux to Mac is not fully supported. Workarounds:
- Use a cloud clipboard service (Dropbox, Google Keep, etc.)
- SSH and pipe through clipboard: `ssh omarchy "cat file.txt" | pbcopy`
- Use the Raycast extension API to send text

**Note:** Moonlight's `Ctrl + Alt + Shift + V` is the primary way to transfer clipboard from Mac to Linux during streaming.

### Web Dashboard

Access at `http://localhost:8080` on Omarchy (opens automatically on login)

**Features**:
- View system stats
- Monitor all services
- Control Sunshine (start/stop/restart)
- See Mac connection status
- Quick links to Sunshine and Tailscale admin

**Keyboard Shortcuts**:
- `Ctrl+S`: Open Sunshine dashboard
- `Ctrl+R`: Restart Sunshine

### Omarchy Monitor & Desktop Switching (Mac-like shortcuts)

Use these keyboard shortcuts on **Omarchy** while streaming:

**Move active window to specific monitor:**
- `Ctrl + 1` - Move window to **Left Monitor** (HDMI-A-2)
- `Ctrl + 2` - Move window to **Middle Monitor** (DP-2)
- `Ctrl + 3` - Move window to **Right Monitor** (DP-1)
- `Ctrl + Shift + Left/Right` - Move window to adjacent monitor

**Focus monitor (cursor only):**
- `Ctrl + Alt + 1/2/3` - Move cursor to Left/Middle/Right monitor

**Switch between virtual desktops/workspaces:**
- `Super + 1/2/3` - Switch to Desktop 1/2/3
- `Super + Left/Right Arrow` - Previous/Next Desktop

**Move windows between desktops:**
- `Ctrl + Shift + 1/2/3` - Move window to Desktop 1/2/3 (and follow)

These work like Mac's window management!

### Raycast Commands (Mac)

- `connect` - Quick connect to Omarchy
- `status` - View system status
- `control` - Control Sunshine service
- `switch-desktop [1-9|next|prev|left|right]` - Switch Mac desktops
- `switch-workspace [1-9|next|prev]` - Switch Omarchy Hyprland workspaces remotely

## API Endpoints

The Flask server exposes these REST API endpoints:

- `GET /api/status` - Get all system and service status
- `GET /api/ping` - Health check
- `POST /api/sunshine/start` - Start Sunshine
- `POST /api/sunshine/stop` - Stop Sunshine
- `POST /api/sunshine/restart` - Restart Sunshine
- `GET /api/sunshine/pin` - Get pairing PIN
- `POST /api/workspace/switch/<workspace>` - Switch Hyprland workspace (1-9, next, prev)
- `GET /api/workspace/current` - Get current active workspace

All endpoints are accessible via Tailscale network from your Mac.

## Configuration

### Dashboard Autostart
The dashboard starts automatically via Hyprland autostart:
`~/.config/hypr/autostart.conf`

### Service Management
- Tailscale: `systemctl status tailscaled`
- Sunshine: `systemctl --user status sunshine`
- WireGuard: `systemctl status wg-quick@wg0`
- Dashboard: Check process running on port 8080

### Firewall
All required ports are open:
- 47989/tcp - Sunshine streaming
- 47990/tcp - Sunshine web UI
- 48010/tcp - Sunshine RTSP
- 47998-48000/udp - Sunshine video/audio
- 8080/tcp - Dashboard API
- Tailscale network (100.64.0.0/10) - Full access

## Troubleshooting

### Error -1: Connection Terminated / Keeps Disconnecting

**Problem**: Moonlight shows "Error -1" and keeps disconnecting randomly.

**Root Cause**: Multiple active network interfaces (Ethernet + WiFi) cause packet routing conflicts.

**Solution**: Disable WiFi and use only Ethernet
```bash
# Temporarily disable WiFi
sudo ip link set wlan0 down

# Or use the provided script
~/remote-access-dashboard/disable-wifi.sh

# Restart Sunshine after changing network
systemctl --user restart sunshine
```

**Make it permanent**: Add to Hyprland autostart or create a systemd service.

**Other potential causes:**
- Network speed mismatch between host and client
- VPN interfering with local network
- Firewall blocking UDP ports 47998-48000
- High packet loss or jitter on network

### Can't connect from Mac
1. Check Tailscale is running on both machines: `tailscale status`
2. Check Sunshine is running: `systemctl --user status sunshine`
3. Check firewall: `sudo ufw status`
4. Test API: `curl http://100.73.206.17:8080/api/ping`
5. **Make sure WiFi is disabled** if you're using Ethernet

### Dashboard not opening on login
1. Check autostart: `grep "Remote Access" ~/.config/hypr/autostart.conf`
2. Check if server is running: `ss -tlnp | grep 8080`
3. Manually start: `~/remote-access-dashboard/serve.sh`

### Moonlight can't find host
1. Verify Tailscale IP: `tailscale status`
2. Check Sunshine web UI: `https://localhost:47990`
3. Try adding by IP directly: `100.73.206.17`

### Only seeing one monitor
1. In Moonlight, make sure you selected **"All Monitors (5760x1080)"** NOT "Desktop"
2. Check Sunshine config: `~/.config/sunshine/sunshine.conf` should have `width = 5760` and `height = 1080`
3. Verify all monitors are detected: `hyprctl monitors`
4. Restart Sunshine: `systemctl --user restart sunshine`

### Mouse lag / stuttering / unresponsive input

**Problem**: Mouse feels sluggish, laggy, or stutters during streaming.

**Solution**: The configuration has been optimized with low-latency settings:
```bash
# Settings already added to ~/.config/sunshine/sunshine.conf:
nvenc_preset = 1                    # Fastest encoding
nvenc_realtime_hags = enabled       # Hardware GPU scheduling
nvenc_latency_over_power = enabled  # Prioritize latency over power
minimum_fps_target = 15             # Maintain responsiveness
```

**Additional fixes:**
1. **View performance stats**: Press `Ctrl + Alt + Shift + S` during streaming to see where lag is (encode/network/decode)
2. **Check hardware decoding**: Make sure Moonlight is using hardware decode (not software)
3. **Reduce resolution**: Try 1920x1080 in Moonlight settings instead of 5760x1080
4. **Lower FEC**: If network is stable, reduce `fec_percentage` from 20 to 10 in sunshine.conf
5. **Disable vsync**: Run `nvidia-settings` and disable "sync to vblank" or set to "fast"

**If still laggy after these fixes:**
- Attach a physical mouse to the Omarchy host and test (rules out software issues)
- Test on Xorg instead of Wayland if using Wayland
- Check `nvidia-smi` to ensure GPU isn't throttling

### Stream is laggy/stuttering on slow connection
1. Lower bitrate in Moonlight settings (try 5-8 Mbps)
2. Lower resolution in Moonlight (try 1920x1080 instead of 5760x1080)
3. Reduce FPS in `~/.config/sunshine/sunshine.conf` (set `fps = 30` or `fps = 24`)
4. Increase `qp` value for more compression (try `qp = 32`)
5. Make sure hardware decoding is enabled in Moonlight
6. Check network: `ping 100.73.206.17` should show <50ms latency

## Development

### Flask API Server
```bash
cd ~/remote-access-dashboard
python3 api-server.py
```

### Raycast Extension
```bash
cd ~/raycast-omarchy-remote
npm install
npm run dev
```

## Files

- `~/remote-access-dashboard/` - Dashboard and API server
  - `api-server.py` - Flask REST API
  - `index.html` - Web dashboard
  - `serve.sh` - Startup script
- `~/raycast-omarchy-remote/` - Raycast extension
  - `src/connect.tsx` - Quick connect command
  - `src/status.tsx` - System status view
  - `src/control.tsx` - Service control
  - `src/switch-desktop.tsx` - Desktop switching
- `~/.config/hypr/autostart.conf` - Hyprland autostart config

## Tech Stack

- **Backend**: Python Flask, psutil
- **Frontend**: HTML/CSS/JavaScript
- **Mac Client**: Raycast (TypeScript/React)
- **Streaming**: Sunshine + Moonlight
- **VPN**: Tailscale, WireGuard
- **System**: Arch Linux, Hyprland

## License

MIT
