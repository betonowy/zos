%include "config.s"

extended_boot_32:
struc .stack_data
    .kp_conv_mem resw 1
    .kp_ext_mem_0x88 resw 1
    .kp_a20_is_on resb 1
endstruc
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov esp, KERNEL_STACK - 4
    mov ebp, esp

    enter KEEP_ALIGNED_32(.stack_data_size, KERNEL_STACK_ALIGNMENT, 4), 0

    mov ax, [bios_data_conv_mem]
    mov [ebp - .stack_data_size + .kp_conv_mem], ax
    mov ax, [bios_data_ext_mem_0x88]
    mov [ebp - .stack_data_size + .kp_ext_mem_0x88], ax
    mov al, [bios_data_a20_state]
    mov [ebp - .stack_data_size + .kp_a20_is_on], al

    lea eax, [ebp - .stack_data_size]
    push eax
    call [ELF_LOAD_START + ElfHdr.entry]

halt_32:
    mov byte [0xb8000], 'H'
    hlt
    jmp halt_32
