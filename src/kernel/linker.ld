MEMORY {
    kernel_region (wxa) : org = 0x0, l = 0x8000 - 0x1000
}

PHDRS {
    idt PT_LOAD;
    text PT_LOAD;
    rodata PT_LOAD;
    data PT_LOAD;
    bss PT_LOAD;
}

SECTIONS {
    . = SIZEOF_HEADERS;

    .text : ALIGN(4) {
        *(.text.entry)
        *(.text*)
    } > kernel_region :text

    .rodata : ALIGN(4) {
        *(.rodata*)
    } > kernel_region :data

    .data : ALIGN(4) {
        *(.data*)
    } > kernel_region :data

    .bss : ALIGN(4) {
        *(.bss*)
    } > kernel_region :bss

    /* We don't need exception handling in here, bloat! */
    /DISCARD/ : {
        *(.eh_frame*)
    }
}
