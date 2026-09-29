#!/bin/bash
# Huawei MACHD-WXX9 (Conexant CX11880): the internal speaker follows the
# headphone pin 0x16's DAC selection, which the driver points at the muted
# headphone DAC 0x10.
#   Speakers:   0x16 -> speaker DAC 0x11, speaker EAPD on, GPIO default (disabled)
#   Headphones: 0x16 -> headphone DAC 0x10, speaker EAPD off, GPIO1 driven low
#               (GPIO1 low enables the headphone output on this board)
# Re-applied in a loop because codec runtime-PM resume restores the driver's cached state.

EXPECTED_VENDOR=0x14f11f86
EXPECTED_SUBSYSTEM=0x1e83323f

for tool in hda-verb amixer; do
    command -v "$tool" >/dev/null || { echo "$tool not found (install alsa-tools and alsa-utils)"; exit 0; }
done

card=$(readlink /proc/asound/sofhdadsp) || { echo "sof-hda-dsp card not found"; exit 1; }
n=${card#card}
dev=/dev/snd/hwC${n}D0
codec=/proc/asound/$card/codec#0

vendor=$(awk '/^Vendor Id:/{print $3}' "$codec")
subsystem=$(awk '/^Subsystem Id:/{print $3}' "$codec")

# Exit 0 on a hardware mismatch so systemd does not keep restarting the service.
if [ "$vendor" != "$EXPECTED_VENDOR" ]; then
    echo "Unsupported codec vendor $vendor (expected $EXPECTED_VENDOR). Not touching the codec."
    exit 0
fi
if [ "$subsystem" != "$EXPECTED_SUBSYSTEM" ] && [ "${ALLOW_ANY_SUBSYSTEM:-0}" != 1 ]; then
    echo "Untested subsystem $subsystem (expected $EXPECTED_SUBSYSTEM). Set ALLOW_ANY_SUBSYSTEM=1 in /etc/default/huawei-speaker-fix to override."
    exit 0
fi

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
