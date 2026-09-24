# Release 1.0

Release 1.0 is the first reproducible HP 200LX MINIX 2.0.2 build in this
project with a persistent native MINIX filesystem on PCMCIA/CF.

## Highlights

- Boots Mack's HP-compatible MINIX kernel through a DOS real-mode loader.
- Reuses Richard Dubs's PCMCIA and BIOS INT 13 disk bridge.
- Adds the CF initialization and validation sequence proven during ELKS work.
- Mounts native persistent root and `/usr` filesystems from PCMCIA/CF.
- Boots the original image on tested 48 MB and 256 MB CF cards.
- Adds a hardware-tested compact image that fits media at least 31,981,568
  bytes in size and leaves approximately 8.7 MiB free on `/usr`.
- Supports a double-speed-modified HP 200LX when `DSPEED /R` is used before
  booting MINIX to unload the DOS flicker workaround and recover its memory.
- Includes a working HP 200LX keyboard and tested display-zoom combination.
- Includes Mack's `volts` utility.
- Uses hostname and prompt `HP200LX`.
- Starts without a spurious first-boot filesystem check.

## Release Assets

- `HP200LX-MINIX-2.0.2-native-1.0.img`
- `HP200LX-MINIX-2.0.2-native-1.0-32MB.img`
- `MNXBOOT-Release-1.0.zip`
- SHA-256 checksum files for all assets

## Known Issues

- ON/OFF resume may hang after the unit is powered back on.
- Not every PCMCIA/CF card and adapter combination has been tested.
- The compact image was validated on a 48 MB CF card, not yet on a physical
  32 MB card.
- PCMCIA networking is not included.
