#!/usr/bin/env python3
"""
Omarchy Remote Access API Server
Provides REST API for controlling streaming services
"""

from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
import subprocess
import psutil
import json
import os

app = Flask(__name__, static_folder='.')
CORS(app)  # Enable CORS for remote access from Mac

def run_command(cmd):
    """Run a shell command and return output"""
    try:
        # Get the current user's environment for systemctl --user commands
        env = os.environ.copy()
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5, env=env)
        return result.stdout.strip(), result.returncode
    except Exception as e:
        return str(e), 1

@app.route('/')
def index():
    """Serve the main dashboard"""
    return send_from_directory('.', 'index.html')

@app.route('/api/status')
def get_status():
    """Get status of all services"""
    # Check Tailscale
    tailscale_output, _ = run_command('tailscale status --json 2>/dev/null')
    tailscale_running = False
    tailscale_ip = "Unknown"
    mac_connected = False

    try:
        ts_data = json.loads(tailscale_output)
        tailscale_running = ts_data.get('BackendState') == 'Running'
        tailscale_ip = ts_data.get('Self', {}).get('TailscaleIPs', ['Unknown'])[0]

        # Check if Mac is connected
        for peer in ts_data.get('Peer', {}).values():
            if 'macbook' in peer.get('HostName', '').lower():
                mac_connected = peer.get('Online', False)
    except:
        pass

    # Check Sunshine
    sunshine_output, _ = run_command('systemctl --user is-active sunshine')
    sunshine_running = sunshine_output == 'active'

    # Check WireGuard
    wg_output, _ = run_command('systemctl is-active wg-quick@wg0')
    wireguard_running = wg_output == 'active'

    # Get system stats
    cpu_percent = psutil.cpu_percent(interval=0.1)
    memory = psutil.virtual_memory()

    # Get GPU info (NVIDIA)
    gpu_info = "N/A"
    gpu_temp = "N/A"
    gpu_output, gpu_code = run_command('nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits')
    if gpu_code == 0 and gpu_output:
        try:
            gpu_util, gpu_temp = gpu_output.split(',')
            gpu_info = f"{gpu_util.strip()}%"
            gpu_temp = f"{gpu_temp.strip()}°C"
        except:
            pass

    return jsonify({
        'services': {
            'tailscale': {
                'running': tailscale_running,
                'ip': tailscale_ip,
                'mac_connected': mac_connected
            },
            'sunshine': {
                'running': sunshine_running
            },
            'wireguard': {
                'running': wireguard_running
            }
        },
        'system': {
            'cpu': f"{cpu_percent}%",
            'memory': f"{memory.percent}%",
            'gpu': gpu_info,
            'gpu_temp': gpu_temp
        }
    })

@app.route('/api/sunshine/start', methods=['POST'])
def start_sunshine():
    """Start Sunshine service"""
    output, code = run_command('systemctl --user start sunshine')
    return jsonify({
        'success': code == 0,
        'message': 'Sunshine started' if code == 0 else 'Failed to start Sunshine'
    })

@app.route('/api/sunshine/stop', methods=['POST'])
def stop_sunshine():
    """Stop Sunshine service"""
    output, code = run_command('systemctl --user stop sunshine')
    return jsonify({
        'success': code == 0,
        'message': 'Sunshine stopped' if code == 0 else 'Failed to stop Sunshine'
    })

@app.route('/api/sunshine/restart', methods=['POST'])
def restart_sunshine():
    """Restart Sunshine service"""
    output, code = run_command('systemctl --user restart sunshine')
    return jsonify({
        'success': code == 0,
        'message': 'Sunshine restarted' if code == 0 else 'Failed to restart Sunshine'
    })

@app.route('/api/sunshine/pin')
def get_sunshine_pin():
    """Get Sunshine pairing PIN"""
    # Try to get PIN from Sunshine state file
    state_file = os.path.expanduser('~/.config/sunshine/sunshine_state.json')
    pin = None

    try:
        with open(state_file, 'r') as f:
            state = json.load(f)
            # PIN might be in different locations depending on Sunshine version
            pin = state.get('pin') or state.get('pair_pin')
    except:
        pass

    return jsonify({
        'pin': pin,
        'message': 'Check Sunshine web UI at https://localhost:47990' if not pin else None
    })

@app.route('/api/workspace/switch/<workspace>', methods=['POST'])
def switch_workspace(workspace):
    """Switch Hyprland workspace"""
    try:
        # Validate workspace input
        if workspace.isdigit() and 1 <= int(workspace) <= 9:
            output, code = run_command(f'hyprctl dispatch workspace {workspace}')
        elif workspace in ['next', 'previous', 'prev']:
            direction = '+1' if workspace == 'next' else '-1'
            output, code = run_command(f'hyprctl dispatch workspace {direction}')
        else:
            return jsonify({
                'success': False,
                'message': f'Invalid workspace: {workspace}. Use 1-9, next, or previous'
            }), 400

        return jsonify({
            'success': code == 0,
            'message': f'Switched to workspace {workspace}' if code == 0 else f'Failed to switch workspace: {output}'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500

@app.route('/api/workspace/current')
def get_current_workspace():
    """Get current active workspace"""
    output, code = run_command('hyprctl activeworkspace -j')
    if code == 0:
        try:
            workspace_data = json.loads(output)
            return jsonify({
                'success': True,
                'workspace': workspace_data.get('id'),
                'monitor': workspace_data.get('monitor'),
                'name': workspace_data.get('name')
            })
        except:
            pass
    return jsonify({
        'success': False,
        'message': 'Failed to get current workspace'
    }), 500

@app.route('/api/ping')
def ping():
    """Simple ping endpoint for health checks"""
    return jsonify({'status': 'ok', 'service': 'omarchy-remote-api'})

if __name__ == '__main__':
    # Run on port 8080, accessible from Tailscale network
    print("Starting Omarchy Remote Access API Server on port 8080")
    print("Dashboard: http://localhost:8080")
    print("API: http://localhost:8080/api/status")
    app.run(host='0.0.0.0', port=8080, debug=False)
