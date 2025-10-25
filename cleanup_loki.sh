#!/bin/bash

echo "Cleaning up Loki installation..."

# Stop and disable service
echo "Stopping Loki service..."
sudo systemctl stop loki 2>/dev/null || true
sudo systemctl disable loki 2>/dev/null || true

# Remove binary
echo "Removing Loki binary..."
sudo rm -f /usr/local/bin/loki

# Remove configuration and data
echo "Removing configuration and data..."
sudo rm -rf /etc/loki
sudo rm -rf /var/lib/loki

# Remove service file
echo "Removing systemd service..."
sudo rm -f /etc/systemd/system/loki.service
sudo systemctl daemon-reload

# Remove user
echo "Removing loki user..."
sudo userdel loki 2>/dev/null || true

# Clean up temp files
echo "Cleaning up temporary files..."
rm -rf /tmp/loki-install

echo "Loki cleanup completed!"
