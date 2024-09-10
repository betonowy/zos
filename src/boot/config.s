%ifndef FILE_CONFIG_S
%define FILE_CONFIG_S

; Filesystem constants
%define SECTOR_SIZE 512
%define SECTORS_PER_CLUSTER 1
%define BOOTLOADER_SECTORS 2
%define FAT_COUNT 1
%define SECTOR_COUNT 2880
%define MEDIA_DESCRIPTOR 0xf0
%define SECTORS_PER_FAT 9
%define SECTORS_PER_TRACK 18
%define HEADS 2
; Bootsector load address
%define INITIAL_ADDRESS 0x7c00
; Memory regions
%define SCRATCH_BUFFER_LEN 3
%define SCRATCH_BUFFER INITIAL_ADDRESS + SECTOR_SIZE * BOOTLOADER_SECTORS
%define ELF_LOAD_START SCRATCH_BUFFER + SECTOR_SIZE * SCRATCH_BUFFER_LEN
%define KERNEL_STACK 0x7e00
%define KERNEL_STACK_ALIGNMENT 16
%define RETURN_ADDRESS_SIZE_32 4
%define KEEP_ALIGNED_32(sz, align, param_space) \
            (sz - (sz + RETURN_ADDRESS_SIZE_32 + param_space) % align + align)

%endif

