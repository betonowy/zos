const std = @import("std");

pub const os = @import("./os.zig");

pub const std_options = std.Options{
    .logFn = logFn,
    .log_level = .debug,
};

fn logFnCommonMessageLevel(msg_level_str: []const u8, color: os.tele.Color.Bits) void {
    _ = os.tele.colorWriteFg("[", os.tele.Color.Bits.white_lo);
    _ = os.tele.colorWriteFg(msg_level_str, color);
}

fn logFnCommonScope(scope: []const u8) void {
    const default_fg = os.tele.Color.Bits.white_lo;

    if (scope.len == 0) {
        _ = os.tele.colorWriteFg("]: ", default_fg);
        return;
    }

    _ = os.tele.colorWriteFg("] (", default_fg);
    _ = os.tele.colorWriteFg(scope, os.tele.Color.Bits.cyan_lo);
    _ = os.tele.colorWriteFg("): ", default_fg);
}

fn logFn(comptime message_level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    const level_color = switch (message_level) {
        .err => os.tele.Color.Bits.red_hi,
        .warn => os.tele.Color.Bits.yellow_lo,
        .info => os.tele.Color.Bits.green_lo,
        .debug => os.tele.Color.Bits.blue_hi,
    };
    logFnCommonMessageLevel(message_level.asText(), level_color);
    logFnCommonScope(if (scope == .default) &.{} else @tagName(scope));
    os.io.getStdOut().writer().print(format ++ "\n", args) catch return;
}

const KernelParams = extern struct {
    conv_mem: u16,
    ext_mem: u16,
};

export fn main(params: *const KernelParams) linksection(".text.entry") noreturn {
    @setAlignStack(4);
    os.tele.init(.clear);
    std.log.info("Conventional memory: {} KiB, Extended: {} KiB", .{ params.conv_mem, params.ext_mem });
    os.halt();
}

export const idt: [2]os.x86.IDT linksection(".idt") = .{
    os.x86.IDT.init(.{
        .offset = 0,
        .segment_selector = 0,
        .gate = .int_32,
        .privilege = 0,
    }),
} ++ .{os.x86.IDT.empty} ** 1;
