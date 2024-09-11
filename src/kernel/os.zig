const std = @import("std");
const builtin = @import("builtin");

pub const io = @import("os/io.zig");
pub const system = @import("os/system.zig");
pub const tele = @import("os/teleprompter.zig");
pub const x86 = @import("os/x86.zig");
pub const interrupts = @import("os/interrupts.zig");

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
    while (true) asm volatile ("hlt");
}
