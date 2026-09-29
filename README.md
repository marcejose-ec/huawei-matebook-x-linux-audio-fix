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

Other Huawei MateBooks with the same codec may need the same fix. See
[Other laptops](#other-laptops) before installing on a different model.

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

### Safety checks

Before the service sends any command to the codec, it checks that:

- `hda-verb` and `amixer` are installed.
- The codec vendor ID is `0x14f11f86` (Conexant CX11880).
- The subsystem ID is `0x1e83323f`, unless you've allowed other IDs (see
  [Other laptops](#other-laptops)).

If any check fails, it logs why and exits without touching the codec.

## Requirements

- An Intel laptop using the SOF `sof-hda-dsp` sound card
- `alsa-tools` (provides `hda-verb`)
- `alsa-utils` (provides `amixer`)
- systemd

On apt-based systems, `install.sh` installs any missing packages for you. On other
distributions, install them yourself first.

## Install

```bash
sudo ./install.sh
```

The script:

1. Checks the codec vendor and subsystem IDs. It stops if they don't match.
2. Installs `alsa-tools` and `alsa-utils` if they're missing.
3. Installs `/usr/local/bin/huawei-speaker-fix.sh` and
   `/etc/systemd/system/huawei-speaker-fix.service`.
4. Enables and starts the service.

## Check that it works

1. Play audio with headphones unplugged. The speakers should be loud and full.
2. Plug headphones in. Within about half a second, sound moves to the headphones
   and the speakers go silent.
3. Unplug them. Sound returns to the speakers.
4. Reboot and repeat.

```bash
systemctl status huawei-speaker-fix.service
journalctl -u huawei-speaker-fix.service
```

## Uninstall

```bash
sudo ./uninstall.sh
```

Reboot afterwards so the codec returns to the driver's default routing.

## Other laptops

If your laptop has a Conexant CX11880 codec with a different subsystem ID, use the
tools in `tools/` to check whether the fix applies before you install it.
All of them except `codec-info.sh` need root.

| Script | What it does |
|---|---|
| `codec-info.sh` | Read-only. Prints the codec IDs, the two output pins, GPIO state and jack state. Your pin `0x16` and pin `0x17` should both list `0x10 0x11` as their connections. |
| `speaker-route-test.sh` | Routes pin `0x16` to the speaker DAC while music plays. If the speakers get much louder, this fix applies to your laptop. |
| `headphone-test.sh` | With headphones plugged in, tries three GPIO/EAPD combinations to find the one that makes the headphones play and keeps the speakers silent. |
| `gpio-test.sh` | Switches on each codec GPIO line in turn, to look for an external speaker amp. None had any effect on the MACHD-WXX9. |

Each test changes codec state only while it runs, and a reboot resets everything.
The tests pause the service while they run and restart it when they finish.

If the speaker and headphone tests give the same results as on the MACHD-WXX9,
install with:

```bash
sudo ./install.sh --force
```

This writes `ALLOW_ANY_SUBSYSTEM=1` to `/etc/default/huawei-speaker-fix`, so the
service accepts your subsystem ID. If `headphone-test.sh` reports a different
combination, edit `huawei-speaker-fix.sh` to match before installing.

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

**The service isn't running.** Check `journalctl -u huawei-speaker-fix.service`.
It exits on purpose if a safety check fails, and the log says which one.

## Upstream status

This service is a workaround. The proper fix is a quirk for this laptop in the Linux
kernel's Conexant HDA driver (`sound/pci/hda/patch_conexant.c`). The quirk would
match the codec subsystem ID `0x1e83323f` and set the same routing and GPIO in the
driver, so no userspace service would be needed.

No such quirk exists as of September 2026. If you file a report or patch with the
ALSA developers (alsa-devel mailing list) or the
[SOF project](https://github.com/thesofproject/linux/issues), attach the output of
`tools/codec-info.sh` and `alsa-info.sh`.

## License

MIT. See [LICENSE](LICENSE).

## Credits

The routing diagnosis is based on
[Smoren/huawei-ubuntu-sound-fix](https://github.com/Smoren/huawei-ubuntu-sound-fix),
written for the Huawei MateBook 14s. It showed that the speaker follows the headphone
pin's DAC selection, and how the GPIO and EAPD commands switch between outputs.
The code in this repository was written separately for this laptop. That repository
has no license, so none of its code is copied here.
