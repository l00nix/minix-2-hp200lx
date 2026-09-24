# Release 1.0 Image Layout

## Whole Device

| Property | Value |
| --- | ---: |
| Image size | 48,103,424 bytes |
| Logical sector size | 512 bytes |
| Total sectors | 93,952 |
| Reported BIOS geometry | 734 cylinders, 4 heads, 32 sectors/track |

## Partition And Filesystems

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

The loader passes `/dev/hd1` as the root device. Startup then reads `/etc/fstab`
and mounts the second MINIX subpartition as `/usr`.

## Release Preparation

Before Release 1.0 was hashed:

- both filesystems passed `fsck.minix`;
- transient `utmp`, `wtmp`, and `lastlog` state was reset;
- `/etc/hostname.file` was set to `HP200LX`;
- `/etc/issue` was set to
  `MINIX Release 2.0 Version 2 - HP 200LX kernel`;
- root's prompt was set to `HP200LX# `;
- `/usr/local/bin/volts` was installed executable.

Resetting accounting state prevents an unnecessary recovery check on the first
boot. Future unclean shutdowns still trigger the normal MINIX filesystem check.

## Writing The Image

The image is a whole-device image. Writing it destroys the existing target
card contents. On a Unix-like host, a typical command is:

```sh
sudo dd if=HP200LX-MINIX-2.0.2-native-1.0.img of=/dev/sdX bs=1M conv=fsync
```

Replace `/dev/sdX` with the complete CF device. Do not append a partition
number. Compare the full-device SHA-256 with the release checksum afterward.

Release 1.0 is hardware-validated only on the matching 48 MB card geometry.
