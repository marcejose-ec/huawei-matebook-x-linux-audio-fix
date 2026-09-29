#!/bin/bash
# Tests whether the speaker is fed by the headphone pin's DAC selection. Runtime-only; reboot resets it.
. "$(dirname "$0")/common.sh"
need_root

systemctl stop huawei-speaker-fix.service 2>/dev/null
trap 'systemctl start huawei-speaker-fix.service 2>/dev/null' EXIT

echo "Unplug headphones, play music through the speakers (no EQ/boost), then press Enter."
read -r

echo "Step 1: route headphone pin 0x16 to speaker DAC 0x11"
V 0x16 0x701 0x0001
ask "Much louder and fuller?" && echo "RESULT: speaker follows 0x16 routing. This fix applies."

echo "Step 2: enable speaker EAPD on 0x17"
V 0x17 0x70C 0x0002
ask "Any further change?" && echo "RESULT: EAPD on 0x17 matters for the speaker."

echo "If the service is not installed, undo without rebooting: sudo hda-verb $dev 0x16 0x701 0x0000"
