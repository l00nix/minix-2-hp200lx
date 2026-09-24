# Third-Party Notices

This repository combines historical software from several sources. Inclusion
does not change the copyright or license of any component.

## MINIX 2.0.2

MINIX and its bundled userland are copyright their respective authors and
Prentice-Hall. The applicable license permits educational and research use and
qualifying distribution to third parties only when it is for educational or
research purposes and free of direct or indirect charge.

See [`licenses/MINIX-2.0.2-LICENSE.txt`](licenses/MINIX-2.0.2-LICENSE.txt).

Source archive reference:
[MINIX 2.0.2](https://web.archive.org/web/20030208003008/http://www.cs.vu.nl/pub/minix/2.0.2/).

## Richard L. Dubs Components

The boot bundle contains Dubs-derived HP 200LX PCMCIA and BIOS services,
including `CARDIO.EXE`, `INT13.BIN`, `PUT13.EXE`, and `VECT13.DAT`. The original
package's source files identify GPL version 1 or, at the recipient's option, a
later version where stated.

See [`licenses/DUBS-GNU-GPL.txt`](licenses/DUBS-GNU-GPL.txt) and
[`docs/original/DUBS-MINIX.TXT`](docs/original/DUBS-MINIX.TXT).

Original site archive:
[The Mysterious Web Page of Dr. Dubs](https://web.archive.org/web/20000919213847/http://users.erols.com/rld/).

## Mack Baggette MINIX Port And LX Utilities

`MINIX.SYS`, the MINIX filesystem image, and `volts` descend from Mack's
HP 200LX DOSMINIX work. They remain subject to their original terms and the
underlying MINIX license. They are included here for historical educational
and research use without charge.

Reference:
[Minix for the HP200LX](https://hp200lx.3peakspublishing.com/minix/index-legacy.html).

## ELKS HP 200LX Work

`CFEN34.COM` and `CFEN34.ASM` came from the HP 200LX ELKS bring-up and were used
to make CF initialization repeatable. ELKS is GPLv2; see the upstream and
downstream repositories for full notices and history.

Reference:
[ELKS Linux on the HP 200LX](https://github.com/l00nix/elks-on-hp200lx).

## Project-Specific Helpers

`MNXLOAD.ASM`/`MNXNAT.COM` and `ATAPROBE.ASM`/`ATAPROB.COM` were developed for
this integration. No separate project-wide license has yet been selected for
these files. The repository is initially private while documentation and media
are completed.
