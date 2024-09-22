const std = @import("std");
const x86 = @import("root.zig");

pub const DescriptorRegister = extern struct {
    size_in_bytes_minus_one: u16,
    offset: u32 align(2),

    pub fn init(offset: u32, entries: u16) @This() {
        return .{ .size_in_bytes_minus_one = entries * 8 - 1, .offset = offset };
    }

    pub fn len(self: @This()) u16 {
        return (self.size_in_bytes_minus_one + 1) / 8;
    }
};

pub const Descriptor = packed struct {
    limit_0_16: u16,
    base_0_24: u24,
    spec: Specialization,
    limit_16_20: u4,
    flags: Flags,
    base_24_32: u8,

    pub const Specialization = packed union {
        pub const System = packed struct {
            variant: enum(u4) { tss_16 = 0x1, ldt = 0x2, tss_16_busy = 0x3, tss_32 = 0x9, tss_32_busy = 0xb },
            always_false: bool = false,
            privilege: u2,
            present: bool = true,
        };

        pub const Code = packed struct {
            accessed: bool = true,
            readable: bool,
            conforming: enum(u1) { exact, less_equal },
            executable: bool = true,
            always_true: bool = true,
            privilege: u2,
            present: bool = true,
        };

        pub const Data = packed struct {
            accessed: bool = true,
            writable: bool,
            direction: enum(u1) { up, down },
            executable: bool = false,
            always_true: bool = true,
            privilege: u2,
            present: bool = true,
        };

        system: System,
        code: Code,
        data: Data,

        pub fn check(self: @This()) enum { system, code, data } {
            if (self.system.always_false) return .system;
            return if (self.code.executable) .code else .data;
        }
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
        spec: Specialization,
        flags: Flags,

        pub fn toX86(self: @This()) Descriptor {
            return init(self);
        }
    };

    pub fn init(in: Logical) @This() {
        return .{
            .limit_0_16 = @truncate(in.limit),
            .limit_16_20 = @intCast(in.limit >> 16),
            .base_0_24 = @truncate(in.base),
            .base_24_32 = @intCast(in.base >> 24),
            .spec = in.spec,
            .flags = in.flags,
        };
    }

    pub fn logical(self: @This()) Logical {
        return .{
            .limit = self.limit_0_16 | @as(u20, self.limit_16_20) << 16,
            .base = self.base_0_24 | @as(u32, self.base_24_32) << 24,
            .spec = self.spec,
            .flags = self.flags,
        };
    }
};

pub const InterruptDescriptor = packed struct {
    offset_0_16: u16,
    segment_selector: u16,
    _reserved_32_40: u8 = 0,
    gate: Gate,
    _reserved_44_45: u1 = 0,
    privilege: u2,
    present: bool = true,
    offset_16_32: u16,

    pub const Gate = enum(u4) {
        null = 0,
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

        pub fn toX86(self: @This()) InterruptDescriptor {
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

    pub const empty = std.mem.zeroes(@This());
};

comptime {
    std.debug.assert(@sizeOf(DescriptorRegister) == 6);
    std.debug.assert(@bitSizeOf(DescriptorRegister) == 48);
    std.debug.assert(@sizeOf(Descriptor) == 8);
    std.debug.assert(@bitSizeOf(Descriptor) == 64);
    std.debug.assert(@sizeOf(InterruptDescriptor) == 8);
    std.debug.assert(@bitSizeOf(InterruptDescriptor) == 64);

    {
        const gdt = Descriptor.init(.{
            .spec = .{ .data = .{
                .direction = .down,
                .privilege = 0,
                .writable = true,
            } },
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
    {
        const idt = InterruptDescriptor.init(.{
            .offset = 0x21371337,
            .segment_selector = 0xf9ec,
            .gate = .task,
            .privilege = 1,
        });

        const idt_logical = idt.logical();
        const idt_again = idt_logical.toX86();

        std.debug.assert(std.mem.eql(u8, std.mem.asBytes(&idt), std.mem.asBytes(&idt_again)));
    }
}

pub const TaskState = extern struct {
    back_link: u16 align(4) = undefined,
    esp_0: u32 = undefined,
    ss_0: u16 align(4) = undefined,
    esp_1: u32 = undefined,
    ss_1: u16 align(4) = undefined,
    esp_2: u32 = undefined,
    ss_2: u16 align(4) = undefined,
    cr3: x86.register.CR3 = undefined,
    eip: u32 = undefined,
    eflags: u32 = undefined,
    eax: u32 = undefined,
    ecx: u32 = undefined,
    edx: u32 = undefined,
    ebx: u32 = undefined,
    esp: u32 = undefined,
    ebp: u32 = undefined,
    esi: u32 = undefined,
    edi: u32 = undefined,
    es: u16 align(4) = undefined,
    cs: u16 align(4) = undefined,
    ss: u16 align(4) = undefined,
    ds: u16 align(4) = undefined,
    fs: u16 align(4) = undefined,
    gs: u16 align(4) = undefined,
    ldt: u16 align(4) = undefined,
    t: bool align(2) = undefined,
    io_map_base: u16 = undefined,
};

comptime {
    std.debug.assert(@sizeOf(TaskState) == 0x68);
}
