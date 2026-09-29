#!/bin/bash
# Read-only. Prints the facts needed to tell whether this fix applies to your laptop.
. "$(dirname "$0")/common.sh"

echo "=== System ==="
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name 2>/dev/null
echo
echo "=== Codec ==="
grep -E '^(Codec|Vendor Id|Subsystem Id):' "$codec"
echo
echo "=== Output pins (expect 0x16 = HP jack, 0x17 = speaker, both listing 0x10 0x11) ==="
awk '/^Node 0x1[67] /{p=1;print;next} /^Node/{p=0} p' "$codec" | grep -E '^Node|Pin Default|Connection|^     0x|EAPD 0x'
echo
echo "=== GPIO ==="
awk '/^GPIO:/{p=1;print;next} p && /^  IO\[/{print;next} {p=0}' "$codec"
echo
echo "=== Jack ==="
amixer -c "$n" cget iface=CARD,name='Headphone Jack' | tail -1
