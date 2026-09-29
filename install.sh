#!/bin/bash
# Usage: sudo ./install.sh [--force]
#   --force  install on an untested subsystem ID (same Conexant CX11880 codec required)
set -e

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0"; exit 1; }
cd "$(dirname "$0")"

force=0
[ "$1" = "--force" ] && force=1

card=$(readlink /proc/asound/sofhdadsp) || { echo "sof-hda-dsp sound card not found. This fix is for SOF-based laptops."; exit 1; }
codec=/proc/asound/$card/codec#0
vendor=$(awk '/^Vendor Id:/{print $3}' "$codec")
subsystem=$(awk '/^Subsystem Id:/{print $3}' "$codec")
echo "Codec: $(awk -F': ' '/^Codec:/{print $2}' "$codec"), vendor $vendor, subsystem $subsystem"

if [ "$vendor" != 0x14f11f86 ]; then
    echo "This is not a Conexant CX11880 codec. Aborting."
    exit 1
fi
if [ "$subsystem" != 0x1e83323f ]; then
    if [ "$force" != 1 ]; then
        echo "Subsystem $subsystem is untested. Run the scripts in tools/ to confirm the fix applies,"
        echo "then re-run with --force."
        exit 1
    fi
    echo "ALLOW_ANY_SUBSYSTEM=1" > /etc/default/huawei-speaker-fix
fi

missing=()
command -v hda-verb >/dev/null || missing+=(alsa-tools)
command -v amixer >/dev/null || missing+=(alsa-utils)
if [ ${#missing[@]} -gt 0 ]; then
    if command -v apt-get >/dev/null; then
        echo "Installing missing packages: ${missing[*]}"
        apt-get install -y "${missing[@]}"
    else
        echo "Missing packages: ${missing[*]}. Install them with your package manager and re-run."
        exit 1
    fi
fi

install -m 755 huawei-speaker-fix.sh /usr/local/bin/huawei-speaker-fix.sh
install -m 644 huawei-speaker-fix.service /etc/systemd/system/huawei-speaker-fix.service
systemctl daemon-reload
systemctl enable huawei-speaker-fix.service
systemctl restart huawei-speaker-fix.service

echo "Installed. Status: $(systemctl is-active huawei-speaker-fix.service)"
