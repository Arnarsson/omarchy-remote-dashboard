#!/bin/bash
# Disable WiFi on boot to prevent Error -1 disconnections
# Multiple active network interfaces cause packet routing conflicts

# Disable WiFi interface
sudo ip link set wlan0 down

echo "WiFi disabled - using Ethernet only for stable streaming"
