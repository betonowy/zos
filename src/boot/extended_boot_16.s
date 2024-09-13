%include "config.s"
%include "structs.s"

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

; KiB of low memory available
bios_data_conv_mem: dw 0
bios_data_ext_mem_0x88: dw 0
bios_data_a20_state: db 0

CODE_SEG equ gdt_code_descriptor - gdt_start
DATA_SEG equ gdt_data_descriptor - gdt_start

extended_boot_16:
    call get_bios_data
    cli
    call process_elf_file
    lgdt [gdt_descriptor]
    mov eax, cr0
    or al, 1
    mov cr0, eax
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    jmp 0x08:extended_boot_32

process_elf_file:
; Some values are actually 32-bit,
; but this assumes that they never
; exceed 16-bit register capacity.
struc .stack_data
    .stack_prg_hdr      resd 1
    .stack_ph_offset    resw 1
    .stack_ph_entsize   resw 1
    .stack_ph_num       resw 1
    .stack_ph_current   resw 1
endstruc
    enter .stack_data_size, 0
    mov si, ELF_LOAD_START
    xor cx, cx
    mov [bp - .stack_data_size + .stack_ph_current], cx
    mov ax, [si + ElfHdr.phnum]
    mov [bp - .stack_data_size + .stack_ph_num], ax
    mov ax, [si + ElfHdr.phentsize]
    mov [bp - .stack_data_size + .stack_ph_entsize], ax
    mov ax, [si + ElfHdr.phoff]
    add ax, ELF_LOAD_START
    mov [bp - .stack_data_size + .stack_ph_offset], ax
.load_program_headers:
    mov si, [bp - .stack_data_size + .stack_ph_offset]
    mov cx, [bp - .stack_data_size + .stack_ph_current]
    mov ax, [bp - .stack_data_size + .stack_ph_entsize]
    mov dx, [bp - .stack_data_size + .stack_ph_num]
    cmp cx, dx
    jae .finish_program_headers
    mul cx
    add si, ax
    mov ax, [si + ElfPrgHdr.offset]
    mov cx, [si + ElfPrgHdr.filesz]
    mov di, [si + ElfPrgHdr.paddr]
    add ax, ELF_LOAD_START
    mov si, ax
    rep movsb
    inc word [bp - .stack_data_size + .stack_ph_current]
    jmp .load_program_headers
.finish_program_headers:
    leave
    ret

get_bios_data:
    clc
    int 0x12
    jnc .success_conv_mem
    mov ax, 64
.success_conv_mem:
    mov [bios_data_conv_mem], ax
    mov ah, 0x88
    clc
    int 0x15
    jnc .success_ext_mem
    mov ax, 0
    jmp .failed_a20 ; no ext mem, no point enabling a20
.success_ext_mem:
    mov [bios_data_ext_mem_0x88], ax
    mov byte [bios_data_a20_state], 1
    call is_a20_on
    jc .success_a20
    call enable_a20_bios
    call is_a20_on
    jc .success_a20
    call enable_a20_kb
    call is_a20_on
    jc .success_a20
.failed_a20:
    mov byte [bios_data_a20_state], 0
.success_a20:
    ret

is_a20_on:
    cli
    pushad
    xor ax, ax
    mov ds, ax
    not ax
    mov es, ax
    mov si, 0x7dfe + 0x00
    mov di, 0x7dfe + 0x10
    mov al, [ds:si]
    mov dl, al
    not dl
    mov [es:di], dl
    cmp al, [ds:si]
    je .a20_on
    xor ax, ax
    mov es, ax
    popad
    sti
    clc
    ret
.a20_on:
    xor ax, ax
    mov es, ax
    popad
    sti
    stc
    ret

enable_a20_bios:
    mov ax, 0x2401
    int 0x15
    ret

enable_a20_kb:
    push ax
    call .enable_a20_wait_1
    mov al, 0xad
    out 0x64, al
    call .enable_a20_wait_1
    mov al, 0xd0
    out 0x64, al
    call .enable_a20_wait_2
    in al, 0x60
    push eax
    call .enable_a20_wait_1
    mov al, 0xd1
    out 0x64, al
    call .enable_a20_wait_1
    pop eax
    or al, 2
    out 0x60, al
    call .enable_a20_wait_1
    mov al, 0xae
    out 0x64, al
    call .enable_a20_wait_1
    pop ax
    ret

.enable_a20_wait_1:
    in al, 0x64
    test al, 2
    jnz .enable_a20_wait_1
    ret

.enable_a20_wait_2:
    in al, 0x64
    test al, 1
    jnz .enable_a20_wait_2
    ret
