# Keyboard Shortcuts Quick Reference

Complete guide to all keyboard shortcuts for Omarchy remote desktop streaming.

---

## 🎮 Moonlight Streaming Control

### Essential Controls
| Shortcut | Action |
|----------|--------|
| **`Ctrl + Alt + Shift + Z`** | **Release/Capture Mouse & Keyboard** (Most important!) |
| `Ctrl + Alt + Shift + Q` | Quit streaming session |
| `Ctrl + Alt + Shift + X` | Toggle fullscreen/windowed mode |
| `Ctrl + Alt + Shift + D` | Minimize Moonlight window |

### Display & Performance
| Shortcut | Action |
|----------|--------|
| `Ctrl + Alt + Shift + S` | Show performance stats overlay |
| `Ctrl + Alt + Shift + M` | Toggle mouse mode |
| `Ctrl + Alt + Shift + C` | Toggle cursor display |
| `Ctrl + Alt + Shift + L` | Lock mouse pointer to video area |

### Clipboard
| Shortcut | Action |
|----------|--------|
| `Ctrl + Alt + Shift + V` | Paste clipboard from Mac to Linux |

---

## 🖥️ Omarchy Window Management (While Streaming)

### Move Window to Monitor
Use these to move windows between your 3 monitors:

| Shortcut | Action |
|----------|--------|
| `Ctrl + 1` | Move window to **Left Monitor** (HDMI-A-2) |
| `Ctrl + 2` | Move window to **Middle Monitor** (DP-2) |
| `Ctrl + 3` | Move window to **Right Monitor** (DP-1) |
| `Ctrl + Shift + Left` | Move window to left monitor |
| `Ctrl + Shift + Right` | Move window to right monitor |

### Focus Monitor (Cursor Only)
| Shortcut | Action |
|----------|--------|
| `Ctrl + Alt + 1` | Move cursor to Left Monitor |
| `Ctrl + Alt + 2` | Move cursor to Middle Monitor |
| `Ctrl + Alt + 3` | Move cursor to Right Monitor |

---

## 🗂️ Omarchy Virtual Desktops/Workspaces

### Switch Workspaces
| Shortcut | Action |
|----------|--------|
| `Super + 1` | Switch to Desktop 1 |
| `Super + 2` | Switch to Desktop 2 |
| `Super + 3` | Switch to Desktop 3 |
| `Super + Left Arrow` | Previous Desktop |
| `Super + Right Arrow` | Next Desktop |

### Move Windows Between Desktops
| Shortcut | Action |
|----------|--------|
| `Ctrl + Shift + 1` | Move window to Desktop 1 (and follow) |
| `Ctrl + Shift + 2` | Move window to Desktop 2 (and follow) |
| `Ctrl + Shift + 3` | Move window to Desktop 3 (and follow) |

---

## 🍎 Mac Desktop Switching (While Streaming)

To switch Mac desktops while streaming:

1. **Release control**: Press `Ctrl + Alt + Shift + Z`
2. **Switch desktops**: Use `Ctrl + Left/Right Arrow` or 3-finger swipe
3. **Recapture**: Press `Ctrl + Alt + Shift + Z` again

---

## 📋 Clipboard Usage

### Mac → Linux (Omarchy)
1. Copy on Mac: `Cmd + C`
2. In Moonlight: Press `Ctrl + Alt + Shift + V`
3. Text is pasted on Omarchy!

### Linux → Mac
Not directly supported. Workarounds:
- Use cloud clipboard (Google Keep, Dropbox)
- SSH: `ssh 100.73.206.17 "cat file.txt" | pbcopy`

---

## 🌐 Dashboard Web UI Shortcuts

When viewing the dashboard at `http://localhost:8080`:

| Shortcut | Action |
|----------|--------|
| `Ctrl + S` | Open Sunshine web dashboard |
| `Ctrl + R` | Restart Sunshine service |

---

## 🚀 Raycast Commands (On Mac)

Quick commands in Raycast (`Cmd + Space`):

| Command | Description |
|---------|-------------|
| `connect` | Launch Moonlight to Omarchy |
| `omarchy status` | View system stats (CPU, Memory, GPU) |
| `control sunshine` | Start/Stop/Restart Sunshine |
| `switch-desktop 2` | Switch Mac to desktop 2 |
| `switch-workspace 1` | Switch Omarchy to workspace 1 |

---

## 💡 Common Workflows

### Switching Between Mac and Streaming
1. `Ctrl + Alt + Shift + Z` - Release mouse/keyboard
2. Do work on Mac (switch apps, desktops, etc.)
3. `Ctrl + Alt + Shift + Z` - Recapture to continue streaming

### Moving Window to Different Monitor
1. Click on the window you want to move
2. `Ctrl + 2` - Moves window to middle monitor
3. `Ctrl + 1` or `Ctrl + 3` - Move to left or right

### Quick Disconnect & Reconnect
1. `Ctrl + Alt + Shift + Q` - Quit streaming
2. Use Raycast `connect` command - Quick reconnect

### View Performance Issues
1. `Ctrl + Alt + Shift + S` - Show stats overlay
2. Check encode/decode/network latency
3. Adjust settings based on bottleneck

---

## 🔑 Most Important Shortcuts to Remember

1. **`Ctrl + Alt + Shift + Z`** - Release/Capture (use this constantly!)
2. **`Ctrl + Alt + Shift + Q`** - Quit streaming
3. **`Ctrl + 1/2/3`** - Move window to specific monitor
4. **`Ctrl + Alt + Shift + V`** - Paste from Mac to Linux
5. **`Ctrl + Alt + Shift + S`** - Performance stats

---

## 📝 Notes

- **Super key** = Windows key / Command key (depending on keyboard)
- All `Ctrl + Alt + Shift` shortcuts are Moonlight-specific
- Mac shortcuts only work when mouse/keyboard is released (`Ctrl + Alt + Shift + Z`)
- Monitor shortcuts (Ctrl + 1/2/3) work while streaming

---

## 🆘 Help

For troubleshooting and more info:
- Full README: [README.md](README.md)
- Troubleshooting: See README troubleshooting section
- Dashboard: `http://localhost:8080`
- Raycast Extension: [raycast-omarchy-remote](https://github.com/Arnarsson/raycast-omarchy-remote)
