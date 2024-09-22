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
    x86.raw.sti();

    os.floppy.init(fd_dma_mem);
    os.floppy.request(.{ .read_lba = 1 }) catch {};

    while (true) {
        while (os.kb.popKeyData()) |data| {
            _ = os.tele.stdoutWrite(&.{data});
        }

        os.floppy.handle();

        x86.raw.halt();
    }
}

const idt: *allowzero [0x80]x86.segment.InterruptDescriptor = @ptrFromInt(0x0);
const fd_dma_mem: *align(4) [0x200]u8 = @ptrFromInt(0x400);
