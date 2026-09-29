#!/bin/bash
# Finds which codec setting enables headphones while keeping the speaker silent. Runtime-only.
. "$(dirname "$0")/common.sh"
need_root

systemctl stop huawei-speaker-fix.service 2>/dev/null
trap 'systemctl start huawei-speaker-fix.service 2>/dev/null' EXIT

echo "Plug in headphones, play music, then press Enter."; read -r

V 0x16 0x701 0x0000
V 0x17 0x70C 0x0000

try() {
    if ask "Headphones playing now?"; then
        ask "Speakers silent?" && echo "RESULT: $1 works" || echo "RESULT: $1, but speakers also play"
        exit 0
    fi
}

echo "Test A: GPIO1 driven low, speaker EAPD off"
V 0x01 0x716 0x2; V 0x01 0x717 0x2; V 0x01 0x715 0x0
try "A (GPIO1 low + EAPD off)"

echo "Test B: GPIO default, speaker EAPD on"
V 0x01 0x716 0x0; V 0x01 0x717 0x0; V 0x01 0x715 0x0
V 0x17 0x70C 0x0002
try "B (EAPD on)"

echo "Test C: GPIO1 low, speaker EAPD on"
V 0x01 0x716 0x2; V 0x01 0x717 0x2; V 0x01 0x715 0x0
try "C (GPIO1 low + EAPD on)"

echo "RESULT: none of A/B/C gave headphone sound"
