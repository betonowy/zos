; Creates base floppy image with bootloader
%include "config.s"

org INITIAL_ADDRESS
bits 16

; FAT12 header and jump bootloader
    jmp short entry
    nop

bpb_oem:                    db "ZOSFLOPP"
bpb_bytes_per_sector:       dw SECTOR_SIZE
bpb_sectors_per_cluster:    db SECTORS_PER_CLUSTER
bpb_reserved_sectors:       dw BOOTLOADER_SECTORS
bpb_fat_count:              db FAT_COUNT
bpb_dir_entries_count:      dw 0x70
bpb_total_sectors:          dw SECTOR_COUNT
bpb_media_descriptor_type:  db MEDIA_DESCRIPTOR
bpb_sectors_per_fat:        dw SECTORS_PER_FAT
bpb_sectors_per_track:      dw SECTORS_PER_TRACK
bpb_heads:                  dw HEADS
bpb_hidden_sectors:         dd 0
bpb_fat32_total_sectors:    dd 0
ebpb_physical_drive_number: db 0
ebpb_reserved:              db 0
ebpb_signature:             db 0x29
ebpb_volume_id:             dd 0x19860927
ebpb_volume_label:          db "ZOSBOOTDISK"
ebpb_file_system_type:      db "FAT12   "

%include "bootsector.s"

; Fill with zeros up until the end of boot sector
times SECTOR_SIZE - 4 - ($ - $$) db 0
dw 0x0000 ; Legacy physical drive number
dw 0xaa55 ; FAT boot sector signature

%include "extended_boot_16.s"

bits 32
%include "extended_boot_32.s"

; Fill with zeros up to the boot sector end
times SECTOR_SIZE * BOOTLOADER_SECTORS - ($ - $$) db 0
; FAT12 cluster table start (FAT ID + End of chain indicator)
db MEDIA_DESCRIPTOR, 0xff, 0xff
; Fill with zeros up to the start of root directory region
times SECTOR_SIZE * (BOOTLOADER_SECTORS + FAT_COUNT * SECTORS_PER_FAT) - ($ - $$) db 0
; Volume label in root directory
db "ZOSBOOTDISK" ; 8.3 name
db 0x08          ; Volume label attribute
db 0x00          ; Reserved
dw 0x1234        ; creation time bits (24h)
dw 0x0D3B        ; creation time bits (ymd)
dw 0x0D3B        ; access time bits (ymd)
dw 0x0000        ; access rights mask
dw 0x1234        ; modification time bits (24h)
dw 0x0D3B        ; modification time bits (ymd)
dw 0             ; start of file (cluster)
dd 0             ; file size in bytes
; fill the rest of image space with zeros
times SECTOR_COUNT*SECTOR_SIZE-($-$$) db 0
