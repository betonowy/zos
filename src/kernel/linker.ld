MEMORY {
    low_mem (wxa) : org = 0x0, l = 0x600
    kernel_region (wxa) : org = 0x600, l = 0x8000 - 0x600 - 0x1000
}

PHDRS {
    low_data PT_LOAD;
    text PT_LOAD;
    data PT_LOAD;
    bss PT_LOAD;
}

SECTIONS {
    . = SIZEOF_HEADERS;

    .low_data ALIGN(4) : {
        &(.low_data)
    } > low_mem :low_data

    .text ALIGN(4) : {
        *(.text)
    } > kernel_region :text

    .data : ALIGN(4) {
        *(.data)
    } > kernel_region :data

    .bss : ALIGN(4) {
        *(.bss)
    } > kernel_region :bss
}
