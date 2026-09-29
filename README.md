# Huawei laptop speaker fix (Conexant CX11880)

Fixes quiet, tinny internal speakers on Linux, and keeps the headphone jack
working, on a Huawei laptop that uses Intel SOF audio and a Conexant CX11880 codec.

## Tested hardware

| Item | Value |
|---|---|
| Laptop | Huawei MACHD-WXX9 (board M1020) |
| CPU / audio | Intel Core i7-1165G7 (Tiger Lake), Smart Sound audio controller `8086:a0c8` |
| Codec | Conexant CX11880, vendor `0x14f11f86`, subsystem `0x1e83323f` |
| Driver | `sof-audio-pci-intel-tgl` + `skl_hda_dsp_generic` |
| OS | Linux Mint (Ubuntu 24.04 base) |

Other Huawei MateBooks with the same codec layout may need the same fix.
The node numbers below must match your codec. Check `/proc/asound/card0/codec#0`.

## Symptoms

- The internal speakers are very quiet and sound thin, even with every mixer at 100%.
- Boosting the volume in software (EasyEffects, over-amplification) distorts badly.
- Headphones sound fine.
- Windows sounds normal on the same machine.

## Cause

The codec has two DACs and two output pins:

| Node | Role |
|---|---|
| `0x10` | Headphone DAC |
| `0x11` | Speaker DAC |
| `0x16` | Headphone jack pin |
| `0x17` | Internal speaker pin |

On this board, the speaker pin `0x17` ignores its own source selection. It plays
whatever DAC the headphone pin `0x16` is connected to. The Linux driver connects
`0x16` to the headphone DAC `0x10`. When headphones are unplugged, the driver mutes
that DAC and turns it down by 20 dB. So the speakers only get a faint leftover signal.

Headphone output also needs codec GPIO1 driven low. The driver never sets this.

Firmware updates, UCM changes, mixer levels and EQ can't fix this. The signal is lost
inside the codec, after all of those stages.

## What the service does

`huawei-speaker-fix.sh` reads the `Headphone Jack` control every 0.5 s and uses
`hda-verb` to send these commands to the codec:

| Mode | `0x16` source | Speaker EAPD (`0x17`) | GPIO1 |
|---|---|---|---|
| Headphones unplugged | `0x11` (speaker DAC) | on | default (disabled) |
| Headphones plugged in | `0x10` (headphone DAC) | off | output, low |

It runs in a loop, not once at boot. Whenever the codec wakes from runtime power
saving, the driver restores its own routing, and the service has to set it again.

## Install

```bash
sudo ./install.sh
```

This installs `alsa-tools` if `hda-verb` is missing, then installs:

- `/usr/local/bin/huawei-speaker-fix.sh`
- `/etc/systemd/system/huawei-speaker-fix.service`

It then enables and starts the service.

## Check that it works

1. Play audio with headphones unplugged. The speakers should be loud and full.
2. Plug headphones in. Within about half a second, sound moves to the headphones
   and the speakers go silent.
3. Unplug them. Sound returns to the speakers.
4. Reboot and repeat.

```bash
systemctl status huawei-speaker-fix.service
```

## Uninstall

```bash
sudo ./uninstall.sh
```

Reboot afterwards so the codec returns to the driver's default routing.

## Troubleshooting

**Only a generic "Stereo" output appears, with no "Speaker + Headphones" or HDMI outputs.**
The ALSA UCM configuration failed to load. Run this:

```bash
alsaucm -c hw:0 list _verbs
```

The UCM files may have been replaced by a newer `alsa-ucm-conf` from git. If you see
`Incompatible syntax 8`, the installed `libasound2` is too old for those files.
Restore the packaged files, then restart the audio services:

```bash
sudo apt install --reinstall alsa-ucm-conf
systemctl --user restart wireplumber pipewire pipewire-pulse
```

**Headphones are silent when plugged in.** Check that the codec's auto-mute is enabled:

```bash
amixer -c 0 sset 'Auto-Mute Mode' Enabled
sudo alsactl store
```

**Sound is distorted after the fix.** Turn off any EasyEffects gain or EQ preset
that you set up to compensate for the quiet speakers. You shouldn't need it now.

## Credits

The routing diagnosis and verbs are based on
[Smoren/huawei-ubuntu-sound-fix](https://github.com/Smoren/huawei-ubuntu-sound-fix),
written for the Huawei MateBook 14s. I adapted them for this laptop.
