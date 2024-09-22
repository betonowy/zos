const std = @import("std");
const paging = @import("paging.zig");
const x86 = @import("root.zig");

pub const CR0 = packed struct {
    /// Switches between 32-bit protected mode and 16-bit real mode.
    protection: bool,
    /// Controls behavior of wait instruction used to coordinate a coprocessor.
    fpu_present: bool,
    /// Set if coprocessor functions are to be emulated.
    fpu_emulated: bool,
    /// Set after every task switch. Affects coprocessor instructions.
    task_switched: bool,
    /// Controls type of coprocessor being installed.
    extension_type: ExtensionType,
    /// Reserved bits, must be preserved.
    reserved: u26,
    /// Indicates whether the processor uses page tables to translate linear addresses.
    paging: bool,

    const ExtensionType = enum(u1) { i80287, i80387 };

    pub fn load() @This() {
        return asm volatile ("mov %cr0, %eax"
            : [ret] "={eax}" (-> CR0),
        );
    }

    pub fn store(self: @This()) void {
        _ = asm volatile ("mov %eax, %cr0"
            : [ret] "={eax}" (-> usize),
            : [value] "{eax}" (self),
        );
    }
};

pub const CR2 = packed struct {
    page_fault_linear_address: u32,

    pub fn load() @This() {
        return asm volatile ("mov %cr2, %eax"
            : [ret] "={eax}" (-> CR2),
        );
    }

    pub fn store(self: @This()) void {
        _ = asm volatile ("mov %eax, %cr2"
            : [ret] "={eax}" (-> usize),
            : [value] "{eax}" (self),
        );
    }

    pub fn set(self: *@This(), ptr: *anyopaque) void {
        self.page_fault_linear_address = @intCast(@intFromPtr(ptr));
    }
};

pub const CR3 = packed struct {
    reserved: u12,
    pdbr: paging.DirectoryBaseRegister,

    pub fn load() @This() {
        return asm volatile ("mov %cr3, %eax"
            : [ret] "={eax}" (-> CR3),
        );
    }

    pub fn store(self: @This()) void {
        _ = asm volatile ("mov %eax, %cr3"
            : [ret] "={eax}" (-> usize),
            : [value] "{eax}" (self),
        );
    }
};

comptime {
    std.debug.assert(@bitSizeOf(CR0) == 32);
    std.debug.assert(@bitSizeOf(CR2) == 32);
    std.debug.assert(@bitSizeOf(CR3) == 32);
}
