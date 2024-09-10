const std = @import("std");

pub inline fn outb(port: u16, value: u8) void {
    _ = asm volatile ("outb %al, %dx"
        : [ret] "={eax}" (-> usize),
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %dx"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub const GDTR = extern struct {
    size_in_bytes: u16,
    offset: u32 align(2),

    pub fn init(offset: u32, len: u16) @This() {
        return .{ .size_in_bytes = len * @sizeOf(GDTR), .offset = offset };
    }
};

pub const GDT = packed struct {
    limit_0_16: u16,
    base_0_24: u24,
    access: Access,
    limit_16_20: u4,
    flags: Flags,
    base_24_32: u8,

    pub const Access = packed struct {
        accessed: bool = true,
        rw: bool,
        dc: packed union {
            direction: enum(u1) { up, down },
            conforming: enum(u1) { exact, less_equal },
        },
        executable: enum(u1) { code, data },
        type: enum(u1) { system_seg, code_data_seg },
        privilege: u2,
        present: bool = true,
    };

    pub const Flags = packed struct {
        _reserved: u1 = 0,
        long_mode: bool = false,
        size: enum(u1) { bit_16, bit_32 },
        granularity: enum(u1) { byte, page },
    };

    pub const Logical = struct {
        base: u32,
        limit: u20,
        access: Access,
        flags: Flags,

        pub fn toX86(self: @This()) GDT {
            return init(self);
        }
    };

    pub fn init(in: Logical) @This() {
        return .{
            .limit_0_16 = @truncate(in.limit),
            .limit_16_20 = @intCast(in.limit >> 16),
            .base_0_24 = @truncate(in.base),
            .base_24_32 = @intCast(in.base >> 24),
            .access = in.access,
            .flags = in.flags,
        };
    }

    pub fn logical(self: @This()) Logical {
        return .{
            .limit = self.limit_0_16 | @as(u20, self.limit_16_20) << 16,
            .base = self.base_0_24 | @as(u32, self.base_24_32) << 24,
            .access = self.access,
            .flags = self.flags,
        };
    }
};

pub const IDTR = extern struct {
    size_in_bytes: u16,
    offset: u32 align(2),

    pub fn init(offset: u32, len: u8) @This() {
        return .{ .size_in_bytes = len * @sizeOf(IDTR), .offset = offset };
    }
};

pub const IDT = packed struct {
    offset_0_16: u16,
    segment_selector: u16,
    _reserved_32_40: u8 = 0,
    gate: Gate,
    _reserved_44_45: u1 = 0,
    privilege: u2,
    present: bool = true,
    offset_16_32: u16,

    pub const Gate = enum(u4) {
        task = 0x5,
        int_16 = 0x6,
        trap_16 = 0x7,
        int_32 = 0xe,
        trap_32 = 0xf,
    };

    pub const Logical = struct {
        offset: u32,
        segment_selector: u16,
        gate: Gate,
        privilege: u2,

        pub fn toX86(self: @This()) IDT {
            return init(self);
        }
    };

    pub fn init(in: Logical) @This() {
        return .{
            .offset_0_16 = @truncate(in.offset),
            .offset_16_32 = @intCast(in.offset >> 16),
            .segment_selector = in.segment_selector,
            .gate = in.gate,
            .privilege = in.privilege,
        };
    }

    pub fn logical(self: @This()) Logical {
        return .{
            .offset = self.offset_0_16 | @as(u32, self.offset_16_32) << 16,
            .segment_selector = self.segment_selector,
            .gate = self.gate,
            .privilege = self.privilege,
        };
    }
};

comptime {
    std.debug.assert(@sizeOf(GDTR) == 6);
    std.debug.assert(@bitSizeOf(GDTR) == 48);
    std.debug.assert(@sizeOf(GDT) == 8);
    std.debug.assert(@bitSizeOf(GDT) == 64);

    const gdt = GDT.init(.{
        .access = .{
            .dc = .{ .conforming = .exact },
            .executable = .code,
            .privilege = 0,
            .rw = true,
            .type = .code_data_seg,
        },
        .flags = .{
            .granularity = .page,
            .size = .bit_32,
        },
        .base = 0x21371337,
        .limit = 0x42069,
    });

    const gdt_logical = gdt.logical();
    const gdt_again = gdt_logical.toX86();

    std.debug.assert(std.mem.eql(u8, std.mem.asBytes(&gdt), std.mem.asBytes(&gdt_again)));
}

comptime {
    std.debug.assert(@sizeOf(IDTR) == 6);
    std.debug.assert(@bitSizeOf(IDTR) == 48);
    std.debug.assert(@sizeOf(IDT) == 8);
    std.debug.assert(@bitSizeOf(IDT) == 64);

    const idt = IDT.init(.{
        .offset = 0x21371337,
        .segment_selector = 0xf9ec,
        .gate = .task,
        .privilege = 1,
    });

    const idt_logical = idt.logical();
    const idt_again = idt_logical.toX86();

    std.debug.assert(std.mem.eql(u8, std.mem.asBytes(&idt), std.mem.asBytes(&idt_again)));
}
