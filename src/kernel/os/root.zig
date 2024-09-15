const std = @import("std");
const builtin = @import("builtin");
const x86 = @import("x86");

pub const io = @import("io.zig");
pub const system = @import("system.zig");
pub const tele = @import("teleprompter.zig");
pub const int = @import("int.zig");
pub const kb = @import("keyboard.zig");
pub const cmos = @import("cmos.zig");
pub const floppy = @import("floppy.zig");
pub const dma = @import("dma.zig");
pub const timer = @import("timer.zig");

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    @setCold(true);

    tele.current_color.bg = tele.Color.Bits.black_lo;
    tele.current_color.fg = tele.Color.Bits.red_lo;

    const stdout = io.getStdOut().writer();

    _ = tele.charPrint(.{ .char = '\n', .color = undefined });
    for (0..80) |_| _ = tele.charPrint(.{ .char = '=', .color = tele.current_color });
    stdout.print("KERNEL PANIC: {s}\n", .{msg}) catch {};
    stdout.print("return address: 0x{x}\n", .{ret_addr orelse @returnAddress()}) catch {};
    for (0..80) |_| _ = tele.charPrint(.{ .char = '=', .color = tele.current_color });
    tele.disableCursor();
    tele.enableCursor();

    halt();
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    const stderr = io.getStdErr().writer();
    nosuspend stderr.print(fmt, args) catch return;
}

pub inline fn halt() noreturn {
    @setCold(true);
    while (true) x86.ass.halt();
}
