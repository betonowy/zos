# ZOS - Minimal 32-bit kernel for i386 platform

This is an educational project for exploring the possibilities of low level programming with Zig and also to learn about the building blocks of an operating system.

## Build requirements

- Zig 0.14
- NASM assembler
- mtools (mcopy) (can be replaced with zig toolchain in the future)

NASM assembler is used to generate an initial floppy image with FAT12 filesystem and bootloader code. Zig toolchain for everything else.

## How to build

`zig build`

FAT12 1440 KiB boot floppy image is then located at `zig-out/bin/image.img`

## Build config

- Can generate floppy images different than 1.44MB 3.5-inch floppy. See `src/boot/config.s`.

## High level overview of the building process

1. Generate FAT12 floppy image
    - Single NASM pass generates the binary image:
        - FAT12 header
        - Initial bootloader (16-bit)
        - Extended bootloader (16-bit)
        - Extended bootloader (32-bit)
        - Initial (empty) FAT12 cluster table
        - Volume label in root directory
        - Padding up to the floppy image size
        - Many minor intricacies for compatibility
2. Build `kernel.elf`
3. Build initial ram disk image
4. Copy files to the image
