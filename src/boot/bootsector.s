%include "config.s"

entry:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, INITIAL_ADDRESS
    ; append more code to the memory, we'll need it anyway
    mov ax, 1
    mov bx, INITIAL_ADDRESS + SECTOR_SIZE
    mov cl, BOOTLOADER_SECTORS - 1
    call read_lba_to_mem
    ; find KERNEL.ELF in root directory
    mov si, kernel_filename
    call find_file_root_dir_entry
    ; load file into memory
    mov di, ELF_LOAD_START
    mov si, ax
    call load_entry_to_mem
    mov si, ELF_LOAD_START
    call verify_elf_signature
    jmp extended_boot_16

; params: [lba:    ax]
;         [mem: es:bx]
;         [len:    cl]
read_lba_to_mem:
    push 3 ; num of allowed retries
.load_retry:
    mov si, cx
    div byte [bpb_sectors_per_track]
    mov cl, ah
    inc cl
    xor ah, ah
    div byte [bpb_heads]
    mov dh, ah
    mov ch, al
    mov dl, 0
    mov ax, si
    mov ah, 0x02
    int 0x13
    jnc .success
    pop ax
    dec ax
    or ax, ax
    push ax
    jnz .load_retry
    mov si, msg_load_error
    call print
    jmp halt
.success:
    pop ax
    ret

; params: [name8.3: si]
; return: [cluster: ax]
find_file_root_dir_entry:
    xor ax, ax
    add ax, [bpb_reserved_sectors]
    xor cx, cx
    mov cl, [bpb_fat_count]
.accumulate_fat_sectors:
    add ax, [bpb_sectors_per_fat]
    dec cl
    jnz .accumulate_fat_sectors
    mov bx, SCRATCH_BUFFER
    mov cl, 1
    call read_lba_to_mem
    mov si, SCRATCH_BUFFER
    xor bx, bx
.compare_filename:
    mov di, kernel_filename
    mov cx, 8 + 3
    call compare_mem
    or ax, ax
    jnz .success
    inc bx
    mov ax, 32
    mul bx
    add ax, SCRATCH_BUFFER
    mov si, ax
    mov cx, [si]
    or cx, cx
    jnz .compare_filename
    mov si, msg_kernel_not_found
    call print
    jmp halt
.success:
    mov ax, 32
    mul bx
    add ax, SCRATCH_BUFFER
    ret

; params: [dest:  di]
;         [entry: si]
load_entry_to_mem:
    mov ax, [si + 0x1c]
    add ax, di
    push ax
    mov ax, [si + 0x1a]
    push bp
    push di ; [bp + 2] memory destination
    push ax ; [bp + 0] cluster to be read
    mov bp, sp
    jmp .read_cluster
.load_cluster_table: ; [cluster: [bp]]]
    mov ax, [bp]
    shr ax, 10
    add ax, [bpb_reserved_sectors]
    mov bx, SCRATCH_BUFFER
    mov cl, 3
    call read_lba_to_mem
    mov si, [bp]
    and si, 0x03ff
    mov dx, si
    shl si, 1
    add si, dx
    shr si, 1
    mov ax, [si + SCRATCH_BUFFER]
    and dx, 1 ; if not zero -> starts with half byte
    jnz .read_odd_cluster_num
    shl ax, 4
.read_odd_cluster_num:
    shr ax, 4
    mov [bp], ax
    cmp ax, 0x0ff8
    ja .load_finished
.read_cluster:
    mov ax, [bpb_dir_entries_count]
    shr ax, 4
    add ax, [bpb_reserved_sectors]
    xor ch, ch
    mov cl, [bpb_fat_count]
.accumulate_fat_sectors:
    add ax, [bpb_sectors_per_fat]
    dec cl
    jnz .accumulate_fat_sectors
    add ax, [bp]
    sub ax, 2
    mov bx, [bp + 2]
    mov cl, 1
    call read_lba_to_mem
    add word [bp + 2], SECTOR_SIZE
    jmp .load_cluster_table
.load_finished:
    pop ax
    pop di
    pop bp
    pop di
    ret

; params: [str: si]
verify_elf_signature:
    mov di, elf_signature
    mov cx, 4
    call compare_mem
    or al, al
    jnz .success
    mov si, msg_kernel_invalid
    call print
    jmp halt
.success:
    ret

; params: [str_a: si]
;         [str_b: di]
;         [count: cx]
; return: [equal: ax]
compare_mem:
    xor ax, ax
    cmpsb
    jne .end_ne
    dec cx
    jnz compare_mem
    inc ax
.end_ne:
    ret

; params: [newline: dl]
; params: [string:  si]
print:
    lodsb
    or al, al
    jz .end
    mov ah, 0x0e
    xor bh, bh
    int 0x10
    jmp print
.end:
    or dl, dl
    jz .no_newline
    mov si, msg_newline
    xor dl, dl
    jmp print
.no_newline:
    ret

; harakiri
halt:
    hlt
    jmp halt

elf_signature: db 0x7f, 'ELF'
kernel_filename: db 'KERNEL  ELF'
msg_kernel_not_found: db 'Kernel not found', 0
msg_load_error: db 'Disk load failed', 0
msg_kernel_invalid: db 'Kernel has an invalid ELF signature', 0
msg_newline: db 0x0d, 0x0a, 0
