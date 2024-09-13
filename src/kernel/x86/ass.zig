const std = @import("std");
const x86 = @import("root.zig");

/// Halt execution
pub inline fn halt() void {
    asm volatile ("hlt");
}

/// Write byte to port
pub inline fn outb(port: u16, value: u8) void {
    _ = asm volatile ("outb %al, %dx"
        : [ret] "={eax}" (-> usize),
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

/// Read byte from port
pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %dx"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

/// Software interrupt
pub inline fn int(index: comptime_int) void {
    asm volatile (std.fmt.comptimePrint("int $0x{x}", .{index}));
}

/// Enable interrupts
pub inline fn sti() void {
    asm volatile ("sti");
}

/// Disable interrupts
pub inline fn cli() void {
    asm volatile ("cli");
}

/// Load interrupt descriptor table register
pub inline fn lidt(idtr: x86.IDTR) void {
    _ = asm volatile ("lidt (%eax)"
        : [ret] "={eax}" (-> usize),
        : [idtr] "{eax}" (&idtr),
    );
}

/// Load global descriptor table register
pub inline fn lgdt(gdtr: x86.GDTR) void {
    _ = asm volatile ("lgdt (%eax)"
        : [ret] "={eax}" (-> usize),
        : [gdtr] "{eax}" (&gdtr),
    );
}
