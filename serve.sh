#!/bin/bash
# Omarchy Remote Access Dashboard Server

cd "$(dirname "$0")"

# Kill any existing server on port 8080
pkill -f "api-server.py" 2>/dev/null
pkill -f "python.*http.server.*8080" 2>/dev/null

# Start the Flask API server
python3 api-server.py > /tmp/remote-dashboard.log 2>&1 &
SERVER_PID=$!

echo "Remote Access Dashboard running at http://localhost:8080"
echo "API Server PID: $SERVER_PID"

# Wait for server to start
sleep 2

# Open in default browser
xdg-open "http://localhost:8080" 2>/dev/null || echo "Please open http://localhost:8080 in your browser"

# Keep script running
wait $SERVER_PID
