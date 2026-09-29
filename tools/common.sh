# Sourced by the tools/ scripts. Locates the SOF card and its codec, and refuses non-Conexant codecs.

card=$(readlink /proc/asound/sofhdadsp) || { echo "sof-hda-dsp sound card not found."; exit 1; }
n=${card#card}
dev=/dev/snd/hwC${n}D0
codec=/proc/asound/$card/codec#0

vendor=$(awk '/^Vendor Id:/{print $3}' "$codec")
case "$vendor" in
    0x14f1*) ;;
    *) echo "Codec vendor $vendor is not Conexant. These tests do not apply."; exit 1 ;;
esac

V() { hda-verb "$dev" "$@" >/dev/null; }
ask() { echo "$1 [y/N]"; read -r a; [[ $a == [yY]* ]]; }

need_root() {
    [ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0"; exit 1; }
    command -v hda-verb >/dev/null || { echo "hda-verb not found: sudo apt install alsa-tools"; exit 1; }
    command -v amixer >/dev/null || { echo "amixer not found: sudo apt install alsa-utils"; exit 1; }
}
