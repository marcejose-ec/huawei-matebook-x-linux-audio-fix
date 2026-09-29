#!/bin/bash
# Huawei MACHD-WXX9 (Conexant CX11880): the internal speaker follows the
# headphone pin 0x16's DAC selection, which the driver points at the muted
# headphone DAC 0x10.
#   Speakers:   0x16 -> speaker DAC 0x11, speaker EAPD on, GPIO default (disabled)
#   Headphones: 0x16 -> headphone DAC 0x10, speaker EAPD off, GPIO1 driven low
#               (GPIO1 low enables the headphone output on this board)
# Re-applied in a loop because codec runtime-PM resume restores the driver's cached state.

card=$(readlink /proc/asound/sofhdadsp) || exit 1
n=${card#card}
dev=/dev/snd/hwC${n}D0
V() { hda-verb "$dev" "$@" >/dev/null 2>&1; }

while true; do
    if amixer -c "$n" cget iface=CARD,name='Headphone Jack' 2>/dev/null | grep -q 'values=on'; then
        V 0x16 0x701 0x0000
        V 0x17 0x70C 0x0000
        V 0x01 0x716 0x2
        V 0x01 0x717 0x2
        V 0x01 0x715 0x0
    else
        V 0x16 0x701 0x0001
        V 0x17 0x70C 0x0002
        V 0x01 0x716 0x0
        V 0x01 0x717 0x0
        V 0x01 0x715 0x0
    fi
    sleep 0.5
done
