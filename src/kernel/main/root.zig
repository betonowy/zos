const std = @import("std");
pub const os = @import("os"); // has to be pub to override std handlers

const x86 = @import("x86");

const log = std.log.scoped(.main);

pub const std_options = std.Options{
    .logFn = os.log.impl,
    .log_level = .debug,
};

const KernelParams = extern struct {
    conv_mem: u16,
    ext_mem: u16,
    a20_is_on: bool,
};

export fn main(params: *const KernelParams) linksection(".text.entry") noreturn {
    @setAlignStack(4);

    os.tele.init(.clear);

    log.debug(
        "Conventional memory: {} KiB, Extended: {} KiB, A20: {}",
        .{ params.conv_mem, params.ext_mem, params.a20_is_on },
    );

    os.int.init(idt[0..]);
    os.paging.init(idt[0..]);

    @memset(std.mem.asBytes(&gdt[0]), 0);

    gdt[1] = x86.segment.Descriptor.init(.{
        .base = 0,
        .limit = std.math.maxInt(u20),
        .flags = .{ .granularity = .page, .size = .bit_32 },
        .spec = .{ .code = .{
            .conforming = .exact,
            .privilege = 0,
            .readable = true,
        } },
    });

    gdt[2] = x86.segment.Descriptor.init(.{
        .base = 0,
        .limit = std.math.maxInt(u20),
        .flags = .{ .granularity = .page, .size = .bit_32 },
        .spec = .{ .data = .{
            .direction = .up,
            .privilege = 0,
            .writable = true,
        } },
    });

    gdt[3] = x86.segment.Descriptor.init(.{
        .base = @intFromPtr(&gdt[0]),
        .limit = std.math.maxInt(u20),
        .flags = .{ .granularity = .page, .size = .bit_32 },
        .spec = .{ .system = .{
            .privilege = 0,
            .variant = .ldt,
        } },
    });

    gdt[4] = x86.segment.Descriptor.init(.{
        .base = @intFromPtr(&tss),
        .limit = @sizeOf(@TypeOf(tss)),
        .flags = .{ .granularity = .page, .size = .bit_32 },
        .spec = .{ .system = .{
            .privilege = 0,
            .variant = .tss_32,
        } },
    });

    x86.raw.lgdt(x86.segment.DescriptorRegister.init(@intFromPtr(&gdt), 3));
    x86.raw.sti();

    os.floppy.init(fd_dma_mem[0..]);
    os.floppy.request(.{ .read_lba = 1 }) catch {};

    task();
}

fn task() noreturn {
    while (true) {
        while (os.kb.popKeyData()) |data| {
            _ = os.tele.stdoutWrite(&.{data});
        }

        os.floppy.handle();

        x86.raw.halt();
    }
}

export var idt: [0x80]x86.segment.InterruptDescriptor = undefined;
export var fd_dma_mem: [0x200]u8 = undefined;

export var gdt: [6]x86.segment.Descriptor align(8) = undefined;
export var tss: x86.segment.Descriptor align(8) = undefined;
