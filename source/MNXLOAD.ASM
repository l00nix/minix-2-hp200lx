bits 16
cpu 186
org 100h

; MNXLOAD 0.1 / MNXGO 0.1
; The default build is the reversible HP 200LX memory-layout test.  Define
; HANDOFF to build MNXGO, which uses the same validated loader and then enters
; Mack's MINIX kernel with a boot-monitor-compatible real-mode stack.

%define READ_SIZE           128
%ifdef NATIVE
%define EXPECTED_RECORDS    752
%else
%define EXPECTED_RECORDS    756
%endif
%define EXPECTED_COMPONENTS 4

%define A_NAME              0
%define A_MAGIC0            64
%define A_MAGIC1            65
%define A_FLAGS             66
%define A_CPU               67
%define A_HDRLEN            68
%define A_TEXT              72
%define A_DATA              76
%define A_BSS               80
%define A_ENTRY             84
%define A_TOTAL             88

%define EXEC_SIZE           32
%define EXEC_SYMS           28

%define ALLOC_PARAS         02e00h
%ifdef NATIVE
%define KERNEL_DATA_PARA    00900h
%define MM_BASE_PARA        00f40h
%define MM_DATA_PARA        01230h
%define FS_BASE_PARA        015c0h
%define FS_DATA_PARA        01c70h
%define INIT_BASE_PARA      02b00h
%define AOUT_PARA           02d70h
%define INT13_SERVICE_SEG   09000h
%else
%define KERNEL_DATA_PARA    00910h
%define MM_BASE_PARA        00f50h
%define MM_DATA_PARA        01240h
%define FS_BASE_PARA        015d0h
%define FS_DATA_PARA        01c80h
%define INIT_BASE_PARA      02b10h
%define AOUT_PARA           02d80h
%endif

start:
    cld
    push cs
    pop ds
    push cs
    pop es

    ; DOS gives a COM program a stack near offset FFFEh.  Move it into the
    ; portion of the PSP block we retain before shrinking that block.
    cli
    mov ax, cs
    mov ss, ax
    mov sp, program_end
    sti

    mov si, msg_banner
    call puts

    ; A COM program initially owns all remaining conventional memory.  Keep
    ; only this program and its private stack so DOS can satisfy AH=48h.
    mov bx, program_end
    add bx, 15
    mov cl, 4
    shr bx, cl
    mov ah, 4ah
    int 21h
    jc resize_error

%ifdef HANDOFF
    ; Ask DOS for the largest available conventional-memory block.  MINIX's
    ; memory map begins at the aligned runtime image and extends to its end.
    mov bx, 0ffffh
    mov ah, 48h
    int 21h
    jnc alloc_unexpected
    mov [largest_block], bx
    mov [alloc_paras], bx
%else
    mov bx, ALLOC_PARAS
%endif
    mov ah, 48h
    int 21h
    jc alloc_error
    mov [alloc_seg], ax

    ; MINIX uses 256-byte clicks, so align the runtime base to 16 paragraphs.
    add ax, 000fh
    and ax, 0fff0h
    mov [load_seg], ax

%ifdef HANDOFF
    mov bx, ax
    sub bx, [alloc_seg]
    mov ax, [alloc_paras]
    sub ax, bx
    mov [arena_paras], ax
%ifdef NATIVE
    ; Dubs' INT13 service occupies 9000:0000.  DOS does not own that memory,
    ; so its largest-block result can include it.  Keep MINIX strictly below
    ; the service even if the allocated DOS block extends farther upward.
    mov ax, [load_seg]
    cmp ax, INT13_SERVICE_SEG
    jae capacity_error
    mov ax, INT13_SERVICE_SEG
    sub ax, [load_seg]
    cmp [arena_paras], ax
    jbe .arena_capped
    mov [arena_paras], ax
.arena_capped:
    mov ax, [arena_paras]
%endif
    cmp ax, ALLOC_PARAS
    jae .arena_ok
    jmp capacity_error
.arena_ok:
%endif

    mov si, msg_reading
    call puts

    mov dx, buffer
    mov ah, 1ah
    int 21h
    push cs
    pop ds

    mov dx, minix_fcb
    mov ah, 0fh
    int 21h
    push cs
    pop ds
    or al, al
    jz .open_ok
    jmp open_error
.open_ok:
    mov word [record_index], 0
    mov byte [component], 0
    mov byte [map_index], 0
    mov word [map_remaining], 0

.read_record:
    mov dx, minix_fcb
    mov ah, 14h
    int 21h
    push cs
    pop ds
    cld
    mov [last_status], al
    or al, al
    jz .read_ok
    jmp size_error
.read_ok:
    call capture_header
    jc layout_error
    call map_record
    inc word [record_index]
    cmp word [record_index], EXPECTED_RECORDS
    jb .read_record

    ; The validated image must end exactly after record 755.
    mov dx, minix_fcb
    mov ah, 14h
    int 21h
    push cs
    pop ds
    cld
    mov [last_status], al
    cmp al, 1
    jne size_error
    call close_file

    cmp byte [component], EXPECTED_COMPONENTS
    jne layout_error_closed
    cmp byte [map_index], MAP_COUNT
    jne layout_error_closed
    cmp word [map_remaining], 0
    jne layout_error_closed

    call clear_runtime_gaps
    call build_aout_headers
    call verify_runtime
    jc runtime_error

    mov si, msg_complete
    call puts
    mov si, msg_base
    call puts
    mov ax, [load_seg]
    call puthex16
    call newline
    call print_layout
%ifdef HANDOFF
    call prepare_handoff
    mov si, msg_ready
    call puts
%ifndef AUTO_GO
    xor ax, ax
    int 16h
%endif
    call newline
    jmp enter_minix
%else
    mov si, msg_ok
    call puts
    mov al, 0
    jmp exit_program
%endif

resize_error:
    mov si, msg_resize_error
    call puts
    mov al, 1
    jmp fatal_no_alloc

alloc_error:
    mov [largest_block], bx
    mov si, msg_alloc_error
    call puts
    mov si, msg_largest
    call puts
    mov ax, [largest_block]
    call puthex16
    call newline
    mov al, 1
    jmp fatal_no_alloc

%ifdef HANDOFF
alloc_unexpected:
    mov [alloc_seg], ax
    mov es, ax
    mov ah, 49h
    int 21h
    mov word [alloc_seg], 0
    mov si, msg_alloc_unexpected
    call puts
    mov al, 1
    jmp fatal_no_alloc

capacity_error:
    mov si, msg_capacity_error
    call puts
    mov al, 1
    jmp exit_program
%endif

open_error:
    mov si, msg_open_error
    mov al, 1
    jmp exit_program

size_error:
    call close_file
    mov si, msg_size_error
    call puts
    mov si, msg_record
    call puts
    mov ax, [record_index]
    call puthex16
    mov si, msg_status
    call puts
    mov al, [last_status]
    call puthex8
    call newline
    mov al, 1
    jmp exit_program

layout_error:
    call close_file
layout_error_closed:
    mov si, msg_layout_error
    call puts
    mov si, msg_counts
    call puts
    mov al, [component]
    call puthex8
    mov si, msg_map
    call puts
    mov al, [map_index]
    call puthex8
    mov si, msg_remaining
    call puts
    mov ax, [map_remaining]
    call puthex16
    call newline
    mov al, 1
    jmp exit_program

runtime_error:
    mov si, msg_runtime_error
    call puts
    call print_runtime_words
    mov al, 1

exit_program:
    mov [exit_code], al
    mov ax, [alloc_seg]
    or ax, ax
    jz .no_free
    mov es, ax
    mov ah, 49h
    int 21h
.no_free:
    mov al, [exit_code]
fatal_no_alloc:
    mov ah, 4ch
    int 21h

close_file:
    push cs
    pop ds
    mov dx, minix_fcb
    mov ah, 10h
    int 21h
    push cs
    pop ds
    cld
    ret

; Capture and validate each 96-byte image header from the first record of its
; sector.  Only the 32-byte exec portion is needed by the kernel handoff.
capture_header:
    push ax
    push bx
    push cx
    push si
    push di
    xor bx, bx
    mov bl, [component]
    cmp bl, EXPECTED_COMPONENTS
    jae .not_header
    shl bx, 1
    mov ax, [header_records + bx]
    cmp ax, [record_index]
    jne .not_header

    cmp byte [buffer + A_MAGIC0], 01h
    jne .bad
    cmp byte [buffer + A_MAGIC1], 03h
    jne .bad
    cmp byte [buffer + A_HDRLEN], 20h
    jne .bad
    cmp byte [buffer + A_CPU], 04h
    jne .bad
    call validate_component_fields
    jc .bad

    mov si, [component_names + bx]
    mov di, buffer + A_NAME
.name_loop:
    lodsb
    cmp al, [di]
    jne .bad
    inc di
    or al, al
    jnz .name_loop

    ; DI = saved_headers + component * 32.
    xor bx, bx
    mov bl, [component]
    mov cl, 5
    shl bx, cl
    mov di, saved_headers
    add di, bx
    mov si, buffer + A_MAGIC0
    mov cx, EXEC_SIZE / 2
    rep movsw
    inc byte [component]
.not_header:
    clc
    jmp .done
.bad:
    stc
.done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

validate_component_fields:
    push ax
    push bx
    push di
    xor bx, bx
    mov bl, [component]
    mov di, bx
    shl bx, 1
    mov al, [expected_flags + di]
    cmp al, [buffer + A_FLAGS]
    jne .bad
    mov ax, [expected_text + bx]
    cmp ax, [buffer + A_TEXT]
    jne .bad
    mov ax, [expected_data + bx]
    cmp ax, [buffer + A_DATA]
    jne .bad
    mov ax, [expected_bss + bx]
    cmp ax, [buffer + A_BSS]
    jne .bad
    mov ax, [expected_total + bx]
    cmp ax, [buffer + A_TOTAL]
    jne .bad
    cmp word [buffer + A_TEXT + 2], 0
    jne .bad
    cmp word [buffer + A_DATA + 2], 0
    jne .bad
    cmp word [buffer + A_BSS + 2], 0
    jne .bad
    cmp word [buffer + A_ENTRY], 0
    jne .bad
    cmp word [buffer + A_ENTRY + 2], 0
    jne .bad
    cmp word [buffer + A_TOTAL + 2], 0
    jne .bad
    clc
    jmp .done
.bad:
    stc
.done:
    pop di
    pop bx
    pop ax
    ret

; Copy the payload records listed in map_table into their final runtime
; addresses.  Padding records between text and data are intentionally skipped.
map_record:
    push ax
    push bx
    push cx
    push si
    push di
    push es

    cmp word [map_remaining], 0
    jne .copy
    xor bx, bx
    mov bl, [map_index]
    cmp bl, MAP_COUNT
    jae .done
    shl bx, 1
    mov si, bx
    shl bx, 1
    add bx, si                 ; map index * 6
    mov ax, [map_table + bx]
    cmp ax, [record_index]
    jne .done
    mov ax, [map_table + bx + 2]
    mov [map_remaining], ax
    mov ax, [load_seg]
    add ax, [map_table + bx + 4]
    mov [map_dest_seg], ax

.copy:
    mov ax, [map_dest_seg]
    mov es, ax
    xor di, di
    mov si, buffer
    mov cx, READ_SIZE / 2
    rep movsw
    add word [map_dest_seg], READ_SIZE / 16
    dec word [map_remaining]
    jnz .done
    inc byte [map_index]
.done:
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

clear_runtime_gaps:
    push ax
    push bx
    push cx
    push si
    push di
    push es
    mov si, zero_table
    mov bx, 4
.next:
    mov ax, [load_seg]
    add ax, [si]
    mov es, ax
    xor di, di
    mov cx, [si + 2]
    xor ax, ax
    rep stosw
    add si, 4
    dec bx
    jnz .next
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

build_aout_headers:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    xor bx, bx
.patch:
    mov ax, [load_seg]
    add ax, [component_base_para + bx]
    mov dx, ax
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov si, bx
    mov cl, 4
    shl si, cl                 ; component * 32 (bx is component * 2)
    mov [saved_headers + si + EXEC_SYMS], ax
    mov ax, dx
    mov cl, 12
    shr ax, cl
    mov [saved_headers + si + EXEC_SYMS + 2], ax
    add bx, 2
    cmp bx, EXPECTED_COMPONENTS * 2
    jb .patch

    mov ax, [load_seg]
    add ax, AOUT_PARA
    mov es, ax
    xor di, di
    mov si, saved_headers
    mov cx, (EXPECTED_COMPONENTS * EXEC_SIZE) / 2
    rep movsw

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

verify_runtime:
    push ax
    push es
    mov ax, [load_seg]
    mov es, ax
    cmp word [es:2], 0008h
    jne .bad
    cmp word [es:4], 00b4h
    jne .bad
    add ax, KERNEL_DATA_PARA
    mov es, ax
    cmp word [es:0], 526fh
    jne .bad
    clc
    jmp .done
.bad:
    stc
.done:
    pop es
    pop ax
    ret

print_runtime_words:
    push ax
    push es
    mov si, msg_actual
    call puts
    mov ax, [load_seg]
    mov es, ax
    mov ax, [es:2]
    call puthex16
    mov si, msg_flags
    call puts
    mov ax, [es:4]
    call puthex16
    mov si, msg_magic
    call puts
    mov ax, [load_seg]
    add ax, KERNEL_DATA_PARA
    mov es, ax
    mov ax, [es:0]
    call puthex16
    call newline
    pop es
    pop ax
    ret

print_layout:
    mov si, msg_kernel
    call puts
    mov ax, [load_seg]
    call puthex16
    mov si, msg_ds
    call puts
    mov ax, [load_seg]
    add ax, KERNEL_DATA_PARA
    call puthex16
    call newline

    mov si, msg_mm
    call puts
    mov ax, [load_seg]
    add ax, MM_BASE_PARA
    call puthex16
    mov si, msg_ds
    call puts
    mov ax, [load_seg]
    add ax, MM_DATA_PARA
    call puthex16
    call newline

    mov si, msg_fs
    call puts
    mov ax, [load_seg]
    add ax, FS_BASE_PARA
    call puthex16
    mov si, msg_ds
    call puts
    mov ax, [load_seg]
    add ax, FS_DATA_PARA
    call puthex16
    call newline

    mov si, msg_init
    call puts
    mov ax, [load_seg]
    add ax, INIT_BASE_PARA
    call puthex16
    mov si, msg_ds
    call puts
    call puthex16
    call newline
    ret

%ifdef HANDOFF
; Build the absolute a.out-header pointer and the one conventional-memory
; region passed to MINIX.  Values in the memory variable are hexadecimal
; byte addresses, matching the standard MINIX boot monitor.
prepare_handoff:
    push ax
    push bx
    push dx
    push di

    mov ax, cs
    xor dx, dx
    call paragraphs_to_bytes
    add ax, saved_headers
    adc dx, 0
    mov [aout_abs], ax
    mov [aout_abs + 2], dx

    mov ax, [load_seg]
    xor dx, dx
    call paragraphs_to_bytes
    mov di, memory_base_digits
    call write_hex32_ascii

    mov ax, [arena_paras]
    xor dx, dx
    call paragraphs_to_bytes
    mov di, memory_size_digits
    call write_hex32_ascii

    pop di
    pop dx
    pop bx
    pop ax
    ret

; DX:AX = AX paragraphs converted to a 32-bit byte count.
paragraphs_to_bytes:
    mov bx, 4
.shift:
    shl ax, 1
    rcl dx, 1
    dec bx
    jnz .shift
    ret

; Write DX:AX as eight uppercase hexadecimal digits at DS:DI.
write_hex32_ascii:
    push ax
    push bx
    mov bx, ax
    mov ax, dx
    call write_hex16_ascii
    mov ax, bx
    call write_hex16_ascii
    pop bx
    pop ax
    ret

write_hex16_ascii:
    push ax
    push bx
    push cx
    mov bx, ax
    mov cx, 4
.digit:
    rol bx, 1
    rol bx, 1
    rol bx, 1
    rol bx, 1
    mov al, bl
    and al, 0fh
    add al, '0'
    cmp al, '9'
    jbe .store
    add al, 7
.store:
    stosb
    loop .digit
    pop cx
    pop bx
    pop ax
    ret

; Point of no return.  This recreates the 16-bit MINIX boot monitor's stack:
; a.out pointer, parameter size/pointer, null monitor return, then kernel CS:IP.
enter_minix:
    cli
    mov ax, cs
    mov ss, ax
    mov sp, program_end

    push word [aout_abs + 2]
    push word [aout_abs]
    push word BOOT_PARAM_SIZE
    push word boot_params
    push word 0
    push word 0
    mov ax, [load_seg]
    push ax
    push word 0
    add ax, KERNEL_DATA_PARA
    mov ds, ax
    mov es, ax
    retf
%endif

puts:
    push ax
    push si
    cld
.next:
    lodsb
    or al, al
    jz .done
    mov dl, al
    call putc
    jmp .next
.done:
    pop si
    pop ax
    ret

putc:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    mov al, dl
    mov ah, 0eh
    xor bh, bh
    mov bl, 07h
    int 10h
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

newline:
    mov dl, 13
    call putc
    mov dl, 10
    call putc
    ret

puthex16:
    push ax
    push bx
    push cx
    mov bx, ax
    mov cx, 4
.digit:
    rol bx, 1
    rol bx, 1
    rol bx, 1
    rol bx, 1
    mov dl, bl
    and dl, 0fh
    call putnibble
    loop .digit
    pop cx
    pop bx
    pop ax
    ret

puthex8:
    push ax
    mov ah, al
    shr al, 4
    mov dl, al
    call putnibble
    mov dl, ah
    and dl, 0fh
    call putnibble
    pop ax
    ret

putnibble:
    and dl, 0fh
    add dl, '0'
    cmp dl, '9'
    jbe putc
    add dl, 7
    jmp putc

%ifdef HANDOFF
%ifdef NATIVE
msg_banner        db 'MNXNAT 0.1: HP 200LX native-card MINIX loader', 13, 10, 0





%else
%ifdef DOSDISK
msg_banner        db 'MNXBOOT 0.1: HP 200LX DOS-file MINIX loader', 13, 10, 0
%else
msg_banner        db 'MNXGO 0.1: MINIX kernel handoff probe', 13, 10, 0
%endif
%endif
%else
msg_banner        db 'MNXLOAD 0.1: MINIX memory-layout test', 13, 10, 0
%endif
msg_reading       db 'Allocating and loading MINIX.SYS...', 13, 10, 0




msg_complete      db 'Read, layout and kernel-magic checks complete', 13, 10, 0





msg_base          db 'Aligned load segment=0x', 0


msg_kernel        db 'kernel cs=0x', 0

msg_mm            db 'mm     cs=0x', 0

msg_fs            db 'fs     cs=0x', 0

msg_init          db 'init   cs=0x', 0

msg_ds            db ' ds=0x', 0
msg_ok            db 'Memory image OK: 185088 bytes; no kernel jump', 13, 10, 0





%ifdef HANDOFF
msg_ready         db 'Press a key to enter MINIX; reset is required to return', 13, 10, 0






%endif
msg_resize_error  db 'ERROR: Cannot resize loader memory block', 13, 10, 0




msg_alloc_error   db 'ERROR: Cannot allocate 188 KB runtime block', 13, 10, 0





%ifdef HANDOFF
msg_alloc_unexpected db 'ERROR: DOS reported an invalid 1 MB free block', 13, 10, 0





msg_capacity_error db 'ERROR: Available memory is too small for MINIX', 13, 10, 0





%endif
msg_largest       db 'Largest available block (paragraphs)=0x', 0




msg_open_error    db 'ERROR: Cannot open MINIX.SYS', 13, 10, 0



%ifdef NATIVE
msg_size_error    db 'ERROR: MINIX.SYS must be exactly 96256 bytes', 13, 10, 0





%else
msg_size_error    db 'ERROR: MINIX.SYS must be exactly 96768 bytes', 13, 10, 0
%endif
msg_layout_error  db 'ERROR: Invalid MINIX image layout', 13, 10, 0



msg_counts        db 'components=0x', 0

msg_map           db ' map=0x', 0
msg_remaining     db ' remaining=0x', 0

msg_runtime_error db 'ERROR: Runtime image verification failed', 13, 10, 0




msg_actual        db 'actual click=0x', 0

msg_flags         db ' flags=0x', 0

msg_magic         db ' magic=0x', 0

msg_record        db ' record=0x', 0

msg_status        db ' FCB status=0x', 0


name_kernel       db 'kernel', 0
name_mm           db 'mm', 0
name_fs           db 'fs', 0
name_init         db 'init', 0
component_names   dw name_kernel, name_mm, name_fs, name_init

%ifdef NATIVE
header_records    dw 0, 336, 448, 684
expected_flags    db 020h, 020h, 020h, 010h
expected_text     dw 08f40h, 02e80h, 06ad0h, 0180ah
expected_data     dw 0146ah, 00420h, 0079ah, 00766h
expected_bss      dw 04ebch, 032e0h, 0dd44h, 00442h
expected_total    dw 06326h, 03900h, 0e8deh, 02532h
%else
header_records    dw 0, 340, 452, 688
expected_flags    db 020h, 020h, 020h, 010h
expected_text     dw 09100h, 02e80h, 06ad0h, 0180ah
expected_data     dw 015b6h, 00420h, 0079ah, 00766h
expected_bss      dw 04dcch, 032e0h, 0dd44h, 00442h
expected_total    dw 06382h, 03900h, 0e8deh, 02532h
%endif

; source record, record count, destination paragraph
map_table:
%ifdef NATIVE
    dw 4,   287, 0000h             ; kernel text
    dw 292, 41,  KERNEL_DATA_PARA ; kernel data
    dw 340, 94,  MM_BASE_PARA     ; mm text
    dw 436, 10,  MM_DATA_PARA     ; mm data
    dw 452, 214, FS_BASE_PARA     ; fs text
    dw 668, 16,  FS_DATA_PARA     ; fs data
    dw 688, 64,  INIT_BASE_PARA   ; init common I&D
%else
    dw 4,   290, 0000h          ; kernel text
    dw 296, 44,  KERNEL_DATA_PARA ; kernel data
    dw 344, 94,  MM_BASE_PARA   ; mm text
    dw 440, 10,  MM_DATA_PARA   ; mm data
    dw 456, 214, FS_BASE_PARA   ; fs text
    dw 672, 16,  FS_DATA_PARA   ; fs data
    dw 692, 64,  INIT_BASE_PARA ; init common I&D
%endif

; The mapper advances through seven ranges, not four components.
MAP_COUNT equ ($ - map_table) / 6

; destination paragraph, word count to clear
zero_table:
%ifdef NATIVE
    dw 0a48h, 027c0h            ; kernel bss and reserved gap
    dw 1280h, 01a00h            ; mm bss and stack
    dw 1cf0h, 07080h            ; fs bss and stack
    dw 2d00h, 00300h            ; init bss and stack
%else
    dw 0a70h, 02700h            ; kernel bss
    dw 1290h, 01a00h            ; mm bss and stack
    dw 1d00h, 07080h            ; fs bss and stack
    dw 2d10h, 00300h            ; init bss and stack
%endif

component_base_para dw 0000h, MM_BASE_PARA, FS_BASE_PARA, INIT_BASE_PARA

minix_fcb         db 0, 'MINIX   ', 'SYS'

                  dw 0
                  dw READ_SIZE
                  dd 0
                  dw 0, 0
                  times 8 db 0
                  db 0
                  times 3 db 0

alloc_seg         dw 0
load_seg          dw 0
largest_block     dw 0
record_index      dw 0
map_remaining     dw 0
map_dest_seg      dw 0
component         db 0
map_index         db 0
last_status       db 0
exit_code         db 0
%ifdef HANDOFF
alloc_paras       dw 0
arena_paras       dw 0
aout_abs          dd 0
%endif
saved_headers     times EXPECTED_COMPONENTS * EXEC_SIZE db 0
buffer            times READ_SIZE db 0

%ifdef HANDOFF
boot_params:
%ifdef NATIVE
                  db 'rootdev=769', 0

                  db 'ramimagedev=769', 0

%else
%ifdef DOSDISK
                  db 'rootdev=3073', 0
                  db 'ramimagedev=3073', 0
%else
                  db 'rootdev=256', 0
                  db 'ramimagedev=256', 0
%endif
%endif
                  db 'ramsize=0', 0

                  db 'processor=186', 0

                  db 'bus=at', 0
                  db 'video=cga', 0

                  db 'chrome=mono', 0

%ifdef DOSDISK
                  db 'dosd0=A:\MINIX.MNX', 0
%endif
                  db 'memory='
memory_base_digits db '00000000'
                  db ':'
memory_size_digits db '00000000', 0
                  db 0
boot_params_end:
BOOT_PARAM_SIZE   equ boot_params_end - boot_params
%endif

stack_space       times 1024 db 0
program_end:
