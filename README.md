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

### Can't connect from Mac
1. Check Tailscale is running on both machines: `tailscale status`
2. Check Sunshine is running: `systemctl --user status sunshine`
3. Check firewall: `sudo ufw status`
4. Test API: `curl http://100.73.206.17:8080/api/ping`

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
