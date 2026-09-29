#!/bin/bash
set -e

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0"; exit 1; }
cd "$(dirname "$0")"

if ! command -v hda-verb >/dev/null; then
    echo "hda-verb not found, installing alsa-tools..."
    apt-get install -y alsa-tools
fi

[ -e /proc/asound/sofhdadsp ] || echo "Warning: sof-hda-dsp sound card not found; the service will exit until it appears."

install -m 755 huawei-speaker-fix.sh /usr/local/bin/huawei-speaker-fix.sh
install -m 644 huawei-speaker-fix.service /etc/systemd/system/huawei-speaker-fix.service
systemctl daemon-reload
systemctl enable huawei-speaker-fix.service
systemctl restart huawei-speaker-fix.service

echo "Installed. Status: $(systemctl is-active huawei-speaker-fix.service)"
