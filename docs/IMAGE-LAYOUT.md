# Release 1.0 Image Layouts

## Original 48 MB Image

### Whole Device

| Property | Value |
| --- | ---: |
| Image size | 48,103,424 bytes |
| Logical sector size | 512 bytes |
| Total sectors | 93,952 |
| Reported BIOS geometry | 734 cylinders, 4 heads, 32 sectors/track |

### Partition And Filesystems

The MBR contains one active type-81 MINIX partition:

| Item | Start sector | Sectors | Bytes |
| --- | ---: | ---: | ---: |
| Type-81 container | 32 | 81,920 | 41,943,040 |
| Root filesystem | 32 | 2,880 | 1,474,560 |
| `/usr` filesystem | 2,912 | 79,040 | 40,468,480 |

MINIX mounts:

```text
root=/dev/hd1
usr=/dev/hd1b
```

## Compact 32 MB Image

The compact image contains the same Release 1.0 system and retains the root
filesystem unchanged. Its `/usr` filesystem is shortened only after confirming
that every allocated zone lies below the new endpoint.

### Whole Device

| Property | Value |
| --- | ---: |
| Image size | 31,981,568 bytes |
| Logical sector size | 512 bytes |
| Total sectors | 62,464 |
| Image geometry | 488 cylinders, 4 heads, 32 sectors/track |

### Partition And Filesystems

| Item | Start sector | Sectors | Bytes |
| --- | ---: | ---: | ---: |
| Type-81 container | 32 | 61,440 | 31,457,280 |
| Root filesystem | 32 | 2,880 | 1,474,560 |
| `/usr` filesystem | 2,912 | 58,560 | 29,982,720 |

The compact `/usr` filesystem has 29,280 1 KiB blocks. Release 1.0 data ends
at zone 20,407, leaving approximately 8.7 MiB free on `/usr`. Both filesystems
pass `fsck.minix`, and the image has booted successfully on a real HP 200LX
when written to a 48 MB CF card. A physical 32 MB card has not yet been tested.

The loader passes `/dev/hd1` as the root device. Startup then reads `/etc/fstab`
and mounts the second MINIX subpartition as `/usr`.

## Release Preparation

Before the Release 1.0 images were hashed:

- both filesystems passed `fsck.minix`;
- transient `utmp`, `wtmp`, and `lastlog` state was reset;
- `/etc/hostname.file` was set to `HP200LX`;
- `/etc/issue` was set to
  `MINIX Release 2.0 Version 2 - HP 200LX kernel`;
- root's prompt was set to `HP200LX# `;
- `/usr/local/bin/volts` was installed executable.

Resetting accounting state prevents an unnecessary recovery check on the first
boot. Future unclean shutdowns still trigger the normal MINIX filesystem check.

## Writing An Image

The image is a whole-device image. Writing it destroys the existing target
card contents. On a Unix-like host, a typical command is:

```sh
sudo dd if=IMAGE.img of=/dev/sdX bs=1M conv=fsync
```

Replace `/dev/sdX` with the complete CF device. Do not append a partition
number. Compare the full-device SHA-256 with the release checksum afterward.

The original image has been hardware-validated on both 48 MB and 256 MB CF
cards. The compact image has been hardware-validated on a 48 MB CF card and
fits media at least 31,981,568 bytes in size. A larger card retains unused
capacity after either image; the release does not resize its MINIX partition
or filesystems automatically.
