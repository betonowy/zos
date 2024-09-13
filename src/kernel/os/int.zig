const std = @import("std");

const x86 = @import("x86");
const teleprompter = @import("teleprompter.zig");
const os = @import("root.zig");

pub const InstallParams = struct { segment_selector: u16, gate: x86.IDT.Gate, privilege: u2 };

pub fn setup(table: []allowzero x86.IDT) void {
    x86.ass.cli();
    for (table) |*entry| install(entry, .{ .segment_selector = 0x08, .gate = .int_32, .privilege = 0 }, .isrNull);
    x86.ass.lidt(x86.IDTR.init(@intFromPtr(table.ptr), @intCast(table.len)));
    x86.ass.sti();
}

fn install(entry: *allowzero volatile x86.IDT, cfg: InstallParams, comptime routine: @TypeOf(.tag)) void {
    const isr = struct {
        pub fn function() callconv(.Naked) void {
            asm volatile (std.fmt.comptimePrint(
                    \\pusha
                    \\cld
                    \\call {s}
                    \\popa
                    \\iret
                , .{@tagName(routine)}));
        }
    };

    entry.* = x86.IDT.init(.{
        .offset = @intFromPtr(&isr.function),
        .gate = cfg.gate,
        .privilege = cfg.privilege,
        .segment_selector = cfg.segment_selector,
    });
}

export fn isrNull() void {
    std.log.warn("Unhandled interrupt!", .{});
}
