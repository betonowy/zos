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
bios_data_ext_mem_0x8a: dd 0

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
.success_ext_mem:
    mov [bios_data_ext_mem_0x88], ax
    ret
