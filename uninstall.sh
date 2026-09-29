#!/bin/bash
set -e

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0"; exit 1; }

systemctl disable --now huawei-speaker-fix.service 2>/dev/null || true
rm -f /usr/local/bin/huawei-speaker-fix.sh /etc/systemd/system/huawei-speaker-fix.service
systemctl daemon-reload

echo "Uninstalled. Reboot to return the codec to the driver's default routing."
