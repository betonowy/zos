const std = @import("std");
const tele = @import("teleprompter.zig");
const io = @import("io.zig");

fn commonMessageLevel(msg_level_str: []const u8, color: tele.Color.Bits) void {
    _ = tele.colorWriteFg("[", tele.Color.Bits.white_lo);
    _ = tele.colorWriteFg(msg_level_str, color);
}

fn commonScope(scope: []const u8) void {
    const default_fg = tele.Color.Bits.white_lo;

    if (scope.len == 0) {
        _ = tele.colorWriteFg("]: ", default_fg);
        return;
    }

    _ = tele.colorWriteFg("] (", default_fg);
    _ = tele.colorWriteFg(scope, tele.Color.Bits.cyan_lo);
    _ = tele.colorWriteFg("): ", default_fg);
}

pub fn impl(comptime message_level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    const level_color = switch (message_level) {
        .err => tele.Color.Bits.red_hi,
        .warn => tele.Color.Bits.yellow_lo,
        .info => tele.Color.Bits.green_lo,
        .debug => tele.Color.Bits.blue_hi,
    };
    commonMessageLevel(message_level.asText(), level_color);
    commonScope(if (scope == .default) &.{} else @tagName(scope));
    io.getStdOut().writer().print(format ++ "\n", args) catch return;
}
