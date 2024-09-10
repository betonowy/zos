gdt_start:
    gdt_null_descriptor:
        dd 0
        dd 0
    gdt_code_descriptor:
        dw 0xffff
        dw 0
        db 0
        db 10011010b
        db 11001111b
        db 0
    gdt_data_descriptor:
        dw 0xffff
        dw 0
        db 0
        db 10010010b
        db 11001111b
        db 0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start
    dd gdt_start

CODE_SEG equ gdt_code_descriptor - gdt_start
DATA_SEG equ gdt_data_descriptor - gdt_start

; params: [ax: num]
print_ax:
    mov dx, ax
    mov cx, 16
.calculate_letter:
    sub cx, 4
    mov ax, dx
    shr ax, cl
    and al, 0x0f
    cmp al, 0x09
    ja .letter
.numeric:
    add al, '0'
    jmp .print_next
.letter:
    add al, 'a' - 0xa
.print_next:
    mov ah, 0x0e
    mov bh, 0
    int 0x10
    or cx, cx
    jnz .calculate_letter
.return:
    ret

print_debug_regstate:
    pushf
    push ax ; [bp + 14]
    push bx ; [bp + 12]
    push cx ; [bp + 10]
    push dx ; [bp + 8]
    push si ; [bp + 6]
    push di ; [bp + 4]
    push sp ; [bp + 2]
    push bp ; [bp + 0]
    mov bp, sp

    mov si, .str_ax
    mov dl, 0
    call print
    mov ax, [bp + 14]
    call print_ax

    mov si, .str_bx
    mov dl, 0
    call print
    mov ax, [bp + 12]
    call print_ax

    mov si, .str_cx
    mov dl, 0
    call print
    mov ax, [bp + 10]
    call print_ax

    mov si, .str_dx
    mov dl, 0
    call print
    mov ax, [bp + 8]
    call print_ax

    mov si, .str_si
    mov dl, 0
    call print
    mov ax, [bp + 6]
    call print_ax

    mov si, .str_di
    mov dl, 0
    call print
    mov ax, [bp + 4]
    call print_ax

    mov si, .str_sp
    mov dl, 0
    call print
    mov ax, [bp + 2]
    call print_ax

    mov si, .str_bp
    mov dl, 0
    call print
    mov ax, [bp]
    call print_ax
    mov si, msg_newline
    mov dl, 0
    call print

    pop bp
    pop sp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    ret
.str_ax: db 'ax: ', 0
.str_bx: db ' bx: ', 0
.str_cx: db ' cx: ', 0
.str_dx: db ' dx: ', 0
.str_si: db ' si: ', 0
.str_di: db ' di: ', 0
.str_sp: db ' sp: ', 0
.str_bp: db ' bp: ', 0
