# Boot Sequence

Release 1.0 uses DOS as a small launch environment, then runs entirely from a
native MINIX PCMCIA/CF filesystem.

## Exact Sequence

`MNXBOOT.BAT` is a DOS CRLF batch file containing:

```dos
@ECHO OFF
REM HP 200LX native MINIX boot sequence
CARDIO.EXE
CFEN34.COM
ATAPROB.COM I
DEBUG < VECT13.DAT
PUT13.EXE
MNXNAT.COM
```

The card may remain inserted during a reboot to DOS. The sequence explicitly
reinitializes the PCMCIA/ATA path before MINIX starts.

![The complete DOS-to-MINIX boot sequence](media/boot-sequence.jpg)

*The DOS-side card initialization, ATA check, and `MNXNAT` handoff immediately
before entering MINIX.*

## Stage By Stage

### 1. `CARDIO.EXE`

Richard L. Dubs's HP 200LX utility asks the built-in PCMCIA services to enable
the ATA card for I/O access. This is the original bridge from the LX's normal
memory-mapped DOS card use to ATA-style I/O.

### 2. `CFEN34.COM`

This helper came from the HP 200LX ELKS bring-up. It performs the additional,
repeatable card/socket/window setup needed by the tested CF adapter, selects
the primary IDE register pair at `1F0h/3F6h`, and writes configuration option
register value `42h`.

`CARDIO` and `CFEN34` overlap conceptually, but the combined sequence is the
one proven repeatable on the release hardware.

### 3. `ATAPROB.COM I`

The read-only ATA diagnostic issues IDENTIFY DEVICE and reports status,
geometry, and LBA capacity. Mode `I` does not write the disk. Besides providing
useful diagnostics, it confirms that the card is responsive before the BIOS
bridge and MINIX take over.

### 4. `DEBUG < VECT13.DAT`

DOS DEBUG applies the prepared vector bytes at physical address `0000:004C`,
the interrupt-vector-table entry for BIOS interrupt 13h. The vector targets
`9000:0000`.

### 5. `PUT13.EXE`

Dubs's loader copies `INT13.BIN` to segment `9000h`. Together with the vector
installed in the previous step, it exposes the PCMCIA ATA card through BIOS
hard-disk services.

### 6. `MNXNAT.COM`

The Release 1.0 DOS loader:

- opens and validates the exact 96,256-byte `MINIX.SYS` image;
- checks the four MINIX components and their expected memory layout;
- reserves MINIX conventional memory below Dubs's service at segment `9000h`;
- loads kernel, memory manager, filesystem server, and init;
- supplies native boot parameters including `rootdev=769` (`/dev/hd1`);
- transfers control directly to Mack's real-mode MINIX kernel.

The kernel's BIOS disk driver then uses interrupt 13h to read the native card.
`/etc/fstab` keeps root on `/dev/hd1` and mounts `/usr` from `/dev/hd1b`.

## Difference From Dubs's Original Method

Dubs's 1998 method also enabled the card and installed the interrupt 13h
service, but then `WINI200.EXE` loaded the MINIX boot block from the card. The
boot block located the card-resident MINIX boot monitor, and the monitor loaded
the selected MINIX image. That required a correctly installed boot block,
monitor-sector extent metadata, and modified boot-monitor memory positions.

Release 1.0 does **not** execute the card's MINIX boot block or boot monitor.
DOS reads `MINIX.SYS`, and `MNXNAT.COM` performs the image layout and direct
kernel handoff. Dubs's contribution remains essential at a different layer:
his PCMCIA activation and interrupt 13h service make the native card visible to
the running kernel's BIOS disk driver.

This separation combines Mack's stable HP-specific kernel with Dubs's native
card access without depending on the unstable kernel in Dubs's original test.

## Relationship To The ELKS Method

The architecture resembles the proven HP 200LX ELKS persistent-root design:

```text
DOS -> initialize CF -> DOS loader -> OS kernel -> persistent CF root
```

The practical lessons carried over were:

- initialize the card deterministically instead of relying on prior DOS state;
- validate ATA visibility before the irreversible handoff;
- keep the DOS-side kernel loader separate from the native root filesystem;
- let the operating system mount the PCMCIA/CF filesystem persistently.

The disk access after handoff is different. ELKS uses its CF/ATA driver and
mounts `/dev/cfa1`; this MINIX release uses Dubs's BIOS interrupt 13h bridge and
the MINIX BIOS disk driver, exposing the filesystems as `/dev/hd1` and
`/dev/hd1b`.
