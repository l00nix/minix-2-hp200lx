/*
    Copyright (C) 1998  Richard L. Dubs

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 1, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <stdio.h>
#include <dos.h>
#include <bios.h>
#include <mem.h>

#define	FILELENGTH	2000
#define INT13		"Int13.bin"

static unsigned char buffer[FILELENGTH];
int mem_seg = 0x9000;
int mem_off = 0x0000;

FILE *fd;

void main(void)  {


	if ((fd = fopen(INT13,"rb")) == NULL) {
	  printf("fopen int13 file");
	  exit();
       }

	if (fread(buffer,sizeof(char),FILELENGTH,fd) == 0) {
	  printf("fread int13 file");
	  exit();
       }
	(void)fclose(fd);       /* close boot file */


	 /* move interrupt code into specified memory location */

	movedata(_DS, FP_OFF(buffer), mem_seg, mem_off, FILELENGTH);

}