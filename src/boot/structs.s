%ifndef FILE_STRUCTS_S
%define FILE_STRUCTS_S

struc ElfHdr
    .magic      resb 4
    .class      resb 1
    .data       resb 1
    .iversion   resb 1
    .osabi      resb 1
    .abiver     resb 1
    .padding_1  resb 7

    .type       resw 1
    .machine    resw 1
    .eversion   resd 1

    .entry      resd 1
    .phoff      resd 1
    .shoff      resd 1
    .flags      resd 1

    .ehsize     resw 1
    .phentsize  resw 1
    .phnum      resw 1
    .shentsize  resw 1
    .shnum      resw 1
    .shstrndx   resw 1
endstruc

struc ElfPrgHdr
    .type       resd 1
    .offset     resd 1
    .vaddr      resd 1
    .paddr      resd 1
    .filesz     resd 1
    .memsz      resd 1
    .flags      resd 1
    .align      resd 1
endstruc

struc ElfSecHdr
    .name       resd 1
    .type       resd 1
    .flags      resd 1
    .addr       resd 1
    .offset     resd 1
    .size       resd 1
    .link       resd 1
    .info       resd 1
    .addralign  resd 1
    .entsize    resd 1
endstruc

%endif
