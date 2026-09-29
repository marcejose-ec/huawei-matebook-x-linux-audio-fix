#!/bin/bash
# Toggles each codec GPIO to look for an external speaker amp enable. Runtime-only.
# On the MACHD-WXX9 none of them affect the speakers; kept for other models.
. "$(dirname "$0")/common.sh"
need_root

set_gpio() { V 0x01 0x716 "$1"; V 0x01 0x717 "$1"; V 0x01 0x715 "$2"; }

systemctl stop huawei-speaker-fix.service 2>/dev/null
trap 'set_gpio 0 0; systemctl start huawei-speaker-fix.service 2>/dev/null' EXIT

echo "Unplug headphones, play music through the speakers, then press Enter."; read -r

for bit in 0 1 2 3 4; do
    m=$((1 << bit))
    set_gpio "$m" "$m"
    if ask "GPIO$bit high. Any change?"; then
        echo "RESULT: GPIO$bit (mask 0x$(printf %x $m)) affects the speakers."
        exit 0
    fi
    set_gpio 0 0
done
echo "RESULT: no GPIO affects the speakers."
