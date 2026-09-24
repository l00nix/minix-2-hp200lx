# Release 1.0

Release 1.0 is the first reproducible HP 200LX MINIX 2.0.2 build in this
project with a persistent native MINIX filesystem on PCMCIA/CF.

## Highlights

- Boots Mack's HP-compatible MINIX kernel through a DOS real-mode loader.
- Reuses Richard Dubs's PCMCIA and BIOS INT 13 disk bridge.
- Adds the CF initialization and validation sequence proven during ELKS work.
- Mounts native persistent root and `/usr` filesystems from the 48 MB CF card.
- Includes a working HP 200LX keyboard and tested display-zoom combination.
- Includes Mack's `volts` utility.
- Uses hostname and prompt `HP200LX`.
- Starts without a spurious first-boot filesystem check.

## Release Assets

- `HP200LX-MINIX-2.0.2-native-1.0.img`
- `MNXBOOT-Release-1.0.zip`
- SHA-256 checksum files for both assets

## Known Issues

- ON/OFF resume may hang after the unit is powered back on.
- Storage card compatibility beyond the tested 48 MB card is not established.
- PCMCIA networking is not included.
