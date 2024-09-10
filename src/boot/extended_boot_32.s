%include "config.s"

extended_boot_32:
struc .stack_data
    .kp_a resb 1
    .kp_b resb 1
        alignb 4
    .kp_c resd 1
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

    mov byte [ebp - .stack_data_size + .kp_a], 'a'
    mov byte [ebp - .stack_data_size + .kp_b], 'b'
    mov dword [ebp - .stack_data_size + .kp_c], 0xf

    lea eax, [ebp - .stack_data_size]
    push eax
    call [ELF_LOAD_START + ElfHdr.entry]
halt32:
    mov byte [0xb8000], 'M'
    hlt
    jmp halt32
