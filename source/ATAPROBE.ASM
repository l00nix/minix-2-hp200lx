bits 16
org 100h

ATA_DATA        equ 01F0h
ATA_ERROR       equ 01F1h
ATA_SECCOUNT    equ 01F2h
ATA_SECTOR      equ 01F3h
ATA_CYLLOW      equ 01F4h
ATA_CYLHIGH     equ 01F5h
ATA_DRIVE       equ 01F6h
ATA_STATUS      equ 01F7h
ATA_CONTROL     equ 03F6h
ATA_CMD_READ    equ 020h
ATA_CMD_IDENT   equ 0ECh

start:
    push cs
    pop ds
    push cs
    pop es
    cld

    call parse_mode
    jc usage_exit

    mov dx, banner
    call print_string
    mov dx, initial_msg
    call print_string
    call print_regs

    call identify_device
    jc done

    mov al, [mode]
    cmp al, 'C'
    je run_chs
    cmp al, 'L'
    je run_lba
    jmp done

run_chs:
    call read_chs_zero
    jmp done

run_lba:
    call read_lba_zero
    jmp done

usage_exit:
    mov dx, usage
    call print_string
    mov ax, 4C01h
    int 21h

done:
    mov dx, done_msg
    call print_string
    mov ax, 4C00h
    int 21h

parse_mode:
    mov byte [mode], 'I'
    xor ch, ch
    mov cl, [80h]
    mov si, 81h
.skip:
    jcxz .ok
    lodsb
    dec cx
    cmp al, ' '
    je .skip
    cmp al, 9
    je .skip
    and al, 0DFh
    cmp al, 'I'
    je .save
    cmp al, 'C'
    je .save
    cmp al, 'L'
    jne .bad
.save:
    mov [mode], al
.ok:
    clc
    ret
.bad:
    stc
    ret

identify_device:
    mov dx, identify_msg
    call print_string
    call wait_not_busy
    jc command_failed

    mov dx, ATA_DRIVE
    mov al, 0A0h
    out dx, al
    call wait_not_busy
    jc command_failed

    xor al, al
    mov dx, ATA_CONTROL
    out dx, al
    mov dx, ATA_ERROR
    out dx, al
    inc dx
    mov al, 1
    out dx, al
    inc dx
    xor al, al
    out dx, al
    inc dx
    out dx, al
    inc dx
    out dx, al
    mov dx, ATA_STATUS
    mov al, ATA_CMD_IDENT
    cli
    out dx, al
    sti

    call wait_drq
    jc command_failed
    call read_data_block
    mov dx, identify_ok
    call print_string
    call print_regs

    mov dx, geom_cyl
    call print_string
    mov ax, [buffer + 2]
    call print_hex_word
    mov dx, geom_heads
    call print_string
    mov ax, [buffer + 6]
    call print_hex_word
    mov dx, geom_spt
    call print_string
    mov ax, [buffer + 12]
    call print_hex_word
    call newline

    mov dx, caps_msg
    call print_string
    mov ax, [buffer + 98]
    call print_hex_word
    mov dx, lba_count_msg
    call print_string
    mov ax, [buffer + 122]
    call print_hex_word
    mov ax, [buffer + 120]
    call print_hex_word
    call newline
    clc
    ret

read_chs_zero:
    mov dx, chs_msg
    call print_string
    call wait_not_busy
    jc command_failed

    mov dx, ATA_CONTROL
    xor al, al
    out dx, al
    mov dx, ATA_ERROR
    out dx, al
    inc dx
    mov al, 1
    out dx, al
    inc dx
    out dx, al
    inc dx
    xor al, al
    out dx, al
    inc dx
    out dx, al
    inc dx
    mov al, 0A0h
    out dx, al
    call io_delay
    mov dx, ATA_STATUS
    mov al, ATA_CMD_READ
    cli
    out dx, al
    sti

    call wait_drq
    jc command_failed
    call read_data_block
    mov dx, read_ok
    call print_string
    call show_sector
    clc
    ret

read_lba_zero:
    mov dx, lba_msg
    call print_string
    call wait_not_busy
    jc command_failed

    mov dx, ATA_CONTROL
    xor al, al
    out dx, al
    mov dx, ATA_ERROR
    out dx, al
    inc dx
    mov al, 1
    out dx, al
    inc dx
    xor al, al
    out dx, al
    inc dx
    out dx, al
    inc dx
    out dx, al
    inc dx
    mov al, 0E0h
    out dx, al
    call io_delay
    mov dx, ATA_STATUS
    mov al, ATA_CMD_READ
    cli
    out dx, al
    sti

    call wait_drq
    jc command_failed
    call read_data_block
    mov dx, read_ok
    call print_string
    call show_sector
    clc
    ret

command_failed:
    cmp byte [failure_kind], 2
    je .ata_error
    mov dx, timeout_msg
    call print_string
    jmp .show
.ata_error:
    mov dx, ata_error_msg
    call print_string
.show:
    call print_regs
    stc
    ret

; Wait for BSY to clear. The nested count is finite even if the card wedges.
wait_not_busy:
    mov byte [failure_kind], 1
    mov bx, 16
.outer:
    mov cx, 0FFFFh
.poll:
    mov dx, ATA_STATUS
    in al, dx
    test al, 080h
    jz .ready
    loop .poll
    dec bx
    jnz .outer
    stc
    ret
.ready:
    clc
    ret

; Wait for BSY=0 and DRQ=1, stopping immediately if ERR is asserted.
wait_drq:
    mov byte [failure_kind], 1
    mov bx, 16
.outer:
    mov cx, 0FFFFh
.poll:
    mov dx, ATA_STATUS
    in al, dx
    test al, 080h
    jnz .next
    test al, 001h
    jnz .error
    test al, 008h
    jnz .ready
.next:
    loop .poll
    dec bx
    jnz .outer
    stc
    ret
.error:
    mov byte [failure_kind], 2
    stc
    ret
.ready:
    clc
    ret

io_delay:
    push cx
    push dx
    mov cx, 32
.loop:
    mov dx, ATA_STATUS
    in al, dx
    loop .loop
    pop dx
    pop cx
    ret

read_data_block:
    mov dx, ATA_DATA
    mov di, buffer
    mov cx, 512
.loop:
    in al, dx
    stosb
    loop .loop
    ret

show_sector:
    call print_regs
    mov dx, first_msg
    call print_string
    mov si, buffer
    mov cx, 16
.bytes:
    lodsb
    call print_hex_byte
    mov dl, ' '
    call print_char
    loop .bytes
    call newline
    mov dx, signature_msg
    call print_string
    mov ax, [buffer + 510]
    call print_hex_word
    call newline
    ret

print_regs:
    mov dx, status_msg
    call print_string
    mov dx, ATA_STATUS
    in al, dx
    call print_hex_byte
    mov dx, error_msg
    call print_string
    mov dx, ATA_ERROR
    in al, dx
    call print_hex_byte
    call newline
    ret

print_string:
    push ax
    mov ah, 09h
    int 21h
    pop ax
    ret

print_char:
    push ax
    mov ah, 02h
    int 21h
    pop ax
    ret

newline:
    push dx
    mov dl, 13
    call print_char
    mov dl, 10
    call print_char
    pop dx
    ret

print_hex_word:
    push ax
    mov al, ah
    call print_hex_byte
    pop ax
    call print_hex_byte
    ret

print_hex_byte:
    push ax
    push bx
    push cx
    mov bl, al
    mov cl, 4
    shr al, cl
    call print_nibble
    mov al, bl
    and al, 0Fh
    call print_nibble
    pop cx
    pop bx
    pop ax
    ret

print_nibble:
    and al, 0Fh
    add al, '0'
    cmp al, '9'
    jbe .emit
    add al, 7
.emit:
    push dx
    mov dl, al
    call print_char
    pop dx
    ret

mode             db 'I'
failure_kind     db 0
banner           db 13,10,'ATAPROBE 1.1 - HP 200LX 8-bit ATA diagnostic',13,10
                 db 'No disk write commands are issued.',13,10,'$'
usage            db 13,10,'Usage: ATAPROB I  identify only',13,10
                 db '       ATAPROB C  identify, then CHS sector 0 read',13,10
                 db '       ATAPROB L  identify, then LBA sector 0 read',13,10,'$'
initial_msg      db 'Initial registers: $'
identify_msg     db 13,10,'IDENTIFY DEVICE ...',13,10,'$'
identify_ok      db 'IDENTIFY completed. $'
geom_cyl         db 'Geometry hex: cylinders=$'
geom_heads       db ' heads=$'
geom_spt         db ' sectors=$'
caps_msg         db 'Capabilities word 49=$'
lba_count_msg    db ' LBA sectors=$'
chs_msg          db 13,10,'CHS READ: C=0 H=0 S=1 ...',13,10,'$'
lba_msg          db 13,10,'LBA READ: sector 0 ...',13,10,'$'
read_ok          db 'READ completed.',13,10,'$'
timeout_msg      db 'TIMEOUT: device did not reach the required state.',13,10,'$'
ata_error_msg    db 'ATA ERROR was asserted.',13,10,'$'
status_msg       db 'status=$'
error_msg        db ' error=$'
first_msg        db 'First 16 bytes: $'
signature_msg    db 'Bytes 510-511: $'
done_msg         db 13,10,'Diagnostic finished; the card was not written.',13,10,'$'

buffer times 512 db 0
