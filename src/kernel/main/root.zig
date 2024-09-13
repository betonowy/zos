const std = @import("std");

const os = @import("os");
const x86 = @import("x86");

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
    a20_is_on: bool,
};

export fn main(params: *const KernelParams) linksection(".text.entry") noreturn {
    @setAlignStack(4);

    os.tele.init(.clear);

    std.log.info(
        "Conventional memory: {} KiB, Extended: {} KiB, A20: {}",
        .{ params.conv_mem, params.ext_mem, params.a20_is_on },
    );

    os.int.setup(idt[0..]);

    os.halt();
}

const idt: *allowzero [0x80]x86.IDT = @ptrFromInt(0x0);
