# Rebuilding The DOS Helpers

Release 1.0 was built with NASM. Run these commands from this directory:

```text
nasm -f bin CFEN34.ASM -o ..\boot\MNXBOOT\CFEN34.COM
nasm -f bin ATAPROBE.ASM -o ..\boot\MNXBOOT\ATAPROB.COM
nasm -f bin -DHANDOFF -DNATIVE MNXLOAD.ASM -o ..\boot\MNXBOOT\MNXNAT.COM
```

The resulting files must match the hashes recorded in `..\SHA256SUMS.txt`.
`MNXNAT.COM` is the native-card variant of the DOS MINIX loader; the two
defines select the BIOS handoff and native-root path used by Release 1.0.

`dubs\PUT13.C` is Richard L. Dubs's original source for the helper that
installs the prepared INT 13 vector. Other frozen boot files are retained as
the tested historical binaries because corresponding buildable source is not
part of this repository.
