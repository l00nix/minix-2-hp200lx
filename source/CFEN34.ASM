; CFEN34.ASM - HP 200LX SunDisk CF primary IDE enabler before ELKS boot
; Assemble:
;   nasm -f bin CFEN34.ASM -o CFEN34.COM

org 100h

BASE    equ 01f0h
ALTSTAT equ 03f6h
CORVAL  equ 042h

start:
        push cs
        pop ds
        push cs
        pop es
        cld

        mov dx, msg_title
        call puts_z

        call cardbios_read_cis
        mov dx, msg_cis
        call puts_z
        mov ax, [cis_flags]
        call hex_word
        call crlf_out

        call ss_set_socket
        mov dx, msg_socket
        call puts_z
        mov ax, [sock_ax]
        call hex_word
        mov dx, msg_flags
        call puts_z
        mov ax, [sock_flags]
        call hex_word
        call crlf_out

        call ss_set_windows
        mov dx, msg_win1
        call puts_z
        mov ax, [win1_ax]
        call hex_word
        mov dx, msg_flags
        call puts_z
        mov ax, [win1_flags]
        call hex_word
        call crlf_out

        mov dx, msg_win2
        call puts_z
        mov ax, [win2_ax]
        call hex_word
        mov dx, msg_flags
        call puts_z
        mov ax, [win2_flags]
        call hex_word
        call crlf_out

        call write_cor_fcsr
        mov dx, msg_cor
        call puts_z
        mov ax, [cor_wr_ax]
        call hex_word
        mov dx, msg_flags
        call puts_z
        mov ax, [cor_wr_flags]
        call hex_word
        mov dx, msg_read
        call puts_z
        mov al, [cor_read]
        call hex_byte
        call crlf_out

        mov dx, msg_fcsr
        call puts_z
        mov al, [fcsr_before]
        call hex_byte
        mov dx, msg_arrow
        call puts_z
        mov al, [fcsr_after]
        call hex_byte
        call crlf_out

        call ata_status_line

        mov dx, msg_done
        call puts_z
        mov ax, 4c00h
        int 21h

cardbios_read_cis:
        mov bx, rw_pkt
        mov byte [bx+1], 8
        mov word [bx+6], 256
        mov word [bx+8], 0
        mov word [bx+10], 0
        mov word [bx+12], cis_buf
        mov word [bx+14], cs
        mov ax, 0b000h
        int 1ah
        pushf
        push cs
        pop ds
        pop word [cis_flags]
        mov [cis_ax], ax
        ret

ss_set_socket:
        mov ax, 8e00h
        mov bx, 8001h
        mov cx, 0111h
        xor dx, dx
        xor si, si
        mov di, 8000h
        int 1ah
        pushf
        push cs
        pop ds
        pop word [sock_flags]
        mov [sock_ax], ax
        ret

ss_set_windows:
        mov ax, 8900h
        mov bx, 0901h
        mov cx, 8
        mov dx, 0501h
        mov si, BASE
        xor di, di
        int 1ah
        pushf
        push cs
        pop ds
        pop word [win1_flags]
        mov [win1_ax], ax

        mov ax, 8900h
        mov bx, 0a01h
        mov cx, 2
        mov dx, 0501h
        mov si, ALTSTAT
        xor di, di
        int 1ah
        pushf
        push cs
        pop ds
        pop word [win2_flags]
        mov [win2_ax], ax
        ret

write_cor_fcsr:
        mov byte [one_byte], CORVAL
        mov bx, rw_pkt
        mov byte [bx+1], 9
        mov word [bx+6], 1
        mov word [bx+8], 0100h
        mov word [bx+10], 0
        mov word [bx+12], one_byte
        mov word [bx+14], cs
        mov ax, 0b000h
        int 1ah
        pushf
        push cs
        pop ds
        pop word [cor_wr_flags]
        mov [cor_wr_ax], ax

        mov bx, rw_pkt
        mov byte [bx+1], 8
        mov word [bx+8], 0100h
        mov ax, 0b000h
        int 1ah
        pushf
        push cs
        pop ds
        pop word [cor_rd_flags]
        mov [cor_rd_ax], ax
        mov al, [one_byte]
        mov [cor_read], al

        mov bx, rw_pkt
        mov byte [bx+1], 8
        mov word [bx+8], 0101h
        mov ax, 0b000h
        int 1ah
        pushf
        push cs
        pop ds
        pop word [fcsr_rd1_flags]
        mov [fcsr_rd1_ax], ax
        mov al, [one_byte]
        mov [fcsr_before], al

        or al, 28h
        mov [one_byte], al
        mov bx, rw_pkt
        mov byte [bx+1], 9
        mov word [bx+8], 0101h
        mov ax, 0b000h
        int 1ah
        pushf
        push cs
        pop ds
        pop word [fcsr_wr_flags]
        mov [fcsr_wr_ax], ax

        mov bx, rw_pkt
        mov byte [bx+1], 8
        mov word [bx+8], 0101h
        mov ax, 0b000h
        int 1ah
        pushf
        push cs
        pop ds
        pop word [fcsr_rd2_flags]
        mov [fcsr_rd2_ax], ax
        mov al, [one_byte]
        mov [fcsr_after], al
        ret

ata_status_line:
        mov dx, msg_ata
        call puts_z
        mov dx, BASE
        mov cx, 8
.p:
        in al, dx
        call hex_byte
        mov al, ' '
        call put_ch
        inc dx
        loop .p
        mov dx, msg_alt
        call puts_z
        mov dx, ALTSTAT
        in al, dx
        call hex_byte
        call crlf_out
        ret

puts_z:
        push ax
        push bx
        push cx
        push dx
        push si
        mov si, dx
        xor cx, cx
.len:
        cmp byte [si], 0
        je .go
        inc si
        inc cx
        jmp .len
.go:
        mov bx, 1
        mov ah, 40h
        int 21h
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        ret

crlf_out:
        mov al, 13
        call put_ch
        mov al, 10
        call put_ch
        ret

hex_word:
        push ax
        mov al, ah
        call hex_byte
        pop ax
        call hex_byte
        ret

hex_byte:
        push ax
        push cx
        mov ah, al
        mov cl, 4
        shr al, cl
        call hex_nib
        mov al, ah
        and al, 0fh
        call hex_nib
        pop cx
        pop ax
        ret

hex_nib:
        and al, 0fh
        cmp al, 10
        jb .digit
        add al, 'A' - 10
        jmp short put_ch
.digit:
        add al, '0'

put_ch:
        push ax
        push bx
        push cx
        push dx
        mov [one_char], al
        mov dx, one_char
        mov cx, 1
        mov bx, 1
        mov ah, 40h
        int 21h
        pop dx
        pop cx
        pop bx
        pop ax
        ret

rw_pkt:
        db 16
        db 8
        db 1
        db 0
        dw 0
        dw 1
        dw 0100h
        dw 0
        dw one_byte
        dw 0

one_char db 0
one_byte db 0
cis_flags dw 0
cis_ax dw 0
sock_ax dw 0
sock_flags dw 0
win1_ax dw 0
win1_flags dw 0
win2_ax dw 0
win2_flags dw 0
cor_wr_ax dw 0
cor_wr_flags dw 0
cor_rd_ax dw 0
cor_rd_flags dw 0
fcsr_rd1_ax dw 0
fcsr_rd1_flags dw 0
fcsr_wr_ax dw 0
fcsr_wr_flags dw 0
fcsr_rd2_ax dw 0
fcsr_rd2_flags dw 0
cor_read db 0
fcsr_before db 0
fcsr_after db 0

msg_title db 'R3D34 CFEN primary IDE 1F0/3F6 COR=42',13,10,0
msg_cis db 'CIS flags=',0
msg_socket db 'SetSocket AX=',0
msg_win1 db 'SetWin data AX=',0
msg_win2 db 'SetWin alt AX=',0
msg_cor db 'COR AX=',0
msg_fcsr db 'FCSR ',0
msg_flags db ' FLAGS=',0
msg_read db ' read=',0
msg_arrow db ' -> ',0
msg_ata db 'ATA 1F0-1F7: ',0
msg_alt db ' 3F6=',0
msg_done db 'CFEN34 done.',13,10,0

cis_buf times 256 db 0
