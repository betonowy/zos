const std = @import("std");

pub const os = @import("./os.zig");

pub const std_options = std.Options{
    .logFn = logFn,
    .log_level = .debug,
};

fn logFn(comptime message_level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    const level_txt = comptime message_level.asText();

    const Color = os.tele.Color.Bits;
    const default_fg = Color.white_lo;

    const level_color = switch (message_level) {
        .err => Color.red_hi,
        .warn => Color.yellow_lo,
        .info => Color.green_lo,
        .debug => Color.blue_hi,
    };

    _ = os.tele.colorWriteFg("[", default_fg);
    _ = os.tele.colorWriteFg(level_txt, level_color);

    if (scope == .default) {
        _ = os.tele.colorWriteFg("]: ", default_fg);
    } else {
        _ = os.tele.colorWriteFg("] (", default_fg);
        _ = os.tele.colorWriteFg(@tagName(scope), Color.cyan_lo);
        _ = os.tele.colorWriteFg("): ", default_fg);
    }

    nosuspend os.io.getStdOut().writer().print(format ++ "\n", args) catch return;
}

const KernelParams = extern struct {
    a: u8,
    b: u8,
    c: u32,
};

export fn main(_: *const KernelParams) noreturn {
    @setAlignStack(4);

    os.tele.init(.clear);

    std.log.debug("This is debug!", .{});
    std.log.info("This is info!", .{});
    std.log.warn("This is warn!", .{});
    std.log.err("This is err!", .{});
    std.log.info("Let's get a few more of those", .{});
    for (0..10) |_| std.log.info("ding", .{});
    std.log.debug("might be enough for me", .{});

    @panic("Kernel finished. System halted.");
    // os.halt();
}
