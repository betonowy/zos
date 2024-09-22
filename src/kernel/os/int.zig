const std = @import("std");
const builtin = @import("builtin");

const x86 = @import("x86");
const teleprompter = @import("teleprompter.zig");
const keyboard = @import("keyboard.zig");
const floppy = @import("floppy.zig");
const timer = @import("timer.zig");
const os = @import("root.zig");

const port_pic_master_cmd = 0x20;
const port_pic_master_data = 0x21;
const port_pic_slave_cmd = 0xa0;
const port_pic_slave_data = 0xa1;

const ICW1_ICW4 = 0x01;
const ICW1_SINGLE = 0x02;
const ICW1_INTERVAL4 = 0x04;
const ICW1_LEVEL = 0x08;
const ICW1_INIT = 0x10;

const ICW4_8086 = 0x01;
const ICW4_AUTO = 0x02;
const ICW4_BUF_SLAVE = 0x08;
const ICW4_BUF_MASTER = 0x0C;
const ICW4_SFNM = 0x10;

const PIC_READ_IRR = 0x0a;
const PIC_READ_ISR = 0x0b;

pub fn init(table: []volatile x86.segment.InterruptDescriptor) void {
    initDefaults(table, gate(.interrupt, nullHandler));

    initRoutines(table, &.{
        // CPU exceptions
        .{ .index = 0x00, .routine = gate(.trap, divisionError) },
        .{ .index = 0x01, .routine = gate(.trap, debugTrap) },
        .{ .index = 0x02, .routine = gate(.interrupt, nonMaskableInterrupt) },
        .{ .index = 0x03, .routine = gate(.trap, breakpoint) },
        .{ .index = 0x04, .routine = gate(.trap, overflow) },
        .{ .index = 0x05, .routine = gate(.trap, boundRangeExceeded) },
        .{ .index = 0x06, .routine = gate(.trap, invalidOpcode) },
        .{ .index = 0x07, .routine = gate(.trap, coprocessorUnavailable) },
        .{ .index = 0x08, .routine = gate(.trap_with_err, doubleFault) },
        .{ .index = 0x09, .routine = gate(.trap, coprocessorSegmentOverrun) },
        .{ .index = 0x0a, .routine = gate(.trap_with_err, invalidTss) },
        .{ .index = 0x0b, .routine = gate(.trap_with_err, segmentNotPresent) },
        .{ .index = 0x0c, .routine = gate(.trap_with_err, stackSegmentFault) },
        .{ .index = 0x0d, .routine = gate(.trap_with_err, generalProtectionFault) },
        .{ .index = 0x0e, .routine = gate(.trap_with_err, pageFault) },
        .{ .index = 0x10, .routine = gate(.trap, floatingPointException) },
        // IRQ handlers
        .{ .index = 0x20, .routine = gate(.interrupt, isrTimer) },
        .{ .index = 0x21, .routine = gate(.interrupt, isrKeyboardController) },
        .{ .index = 0x26, .routine = gate(.interrupt, isrFloppy) },
        // TODO software interrupts
    });

    const mm = x86.raw.inb(port_pic_master_data);
    const ms = x86.raw.inb(port_pic_slave_data);

    // initialization sequence
    x86.raw.outb(port_pic_master_cmd, ICW1_INIT | ICW1_ICW4);
    x86.raw.outb(port_pic_slave_cmd, ICW1_INIT | ICW1_ICW4);

    // vector offsets
    x86.raw.outb(port_pic_master_data, 0x20);
    x86.raw.outb(port_pic_slave_data, 0x28);

    // master/slave
    x86.raw.outb(port_pic_master_data, 0x4);
    x86.raw.outb(port_pic_slave_data, 0x2);

    // 8086 mode
    x86.raw.outb(port_pic_master_data, ICW4_8086);
    x86.raw.outb(port_pic_slave_data, ICW4_8086);

    // restore masks
    x86.raw.outb(port_pic_master_data, mm);
    x86.raw.outb(port_pic_slave_data, ms);

    x86.raw.lidt(x86.segment.DescriptorRegister.init(@intFromPtr(table.ptr), @intCast(table.len)));
}

const GateType = enum { interrupt, trap, trap_with_err, task };

fn DestinationType(comptime gate_type: GateType) type {
    return switch (gate_type) {
        .trap_with_err => fn (u32) void,
        else => fn () void,
    };
}

fn gate(comptime gate_type: GateType, comptime dest: DestinationType(gate_type)) *const fn () callconv(.Naked) void {
    const proxy_symbol_name = std.fmt.comptimePrint("{s}_{s}", .{ @tagName(gate_type), @src().fn_name });

    const gate_setup = comptime switch (gate_type) {
        .trap_with_err => struct {
            fn trampoline() callconv(.Naked) void {
                // TODO must actually pop the error from the stack at the end
                asm volatile (std.fmt.comptimePrint(
                        \\ pusha
                        \\ cld
                        \\ push 32(%esp)
                        \\ call {s}
                        \\ pop %eax
                        \\ pop %eax
                        \\ popa
                        \\ iret
                    , .{proxy_symbol_name}));

                @export(proxy, .{ .name = proxy_symbol_name });
            }

            fn proxy(err: u32) callconv(.C) void {
                @call(.always_inline, dest, .{err});
            }
        },
        else => struct {
            fn trampoline() callconv(.Naked) void {
                asm volatile (std.fmt.comptimePrint(
                        \\ pusha
                        \\ cld
                        \\ call {s}
                        \\ popa
                        \\ iret
                    , .{proxy_symbol_name}));

                @export(proxy, .{ .name = proxy_symbol_name });
            }

            fn proxy() callconv(.C) void {
                @call(.always_inline, dest, .{});
            }
        },
    };

    return &gate_setup.trampoline;
}

const SetupRoutinesParam = struct { index: u8, routine: *const fn () callconv(.Naked) void };

fn initDefaults(table: []volatile x86.segment.InterruptDescriptor, routine: *const fn () callconv(.Naked) void) void {
    @memset(table, x86.segment.InterruptDescriptor.init(.{
        .gate = .int_32,
        .privilege = 0,
        .segment_selector = 0x8,
        .offset = @intFromPtr(routine),
    }));
}

fn initRoutines(table: []volatile x86.segment.InterruptDescriptor, params: []const SetupRoutinesParam) void {
    for (params) |param| table[param.index] = x86.segment.InterruptDescriptor.init(.{
        .gate = .int_32,
        .privilege = 0,
        .segment_selector = 0x8,
        .offset = @intFromPtr(param.routine),
    });
}

fn getPicIrqReg(cmd: u8) u16 {
    x86.raw.outb(port_pic_slave_cmd, cmd);
    x86.raw.outb(port_pic_master_cmd, cmd);
    return (@as(u16, x86.raw.inb(port_pic_slave_cmd)) << 8) | x86.raw.inb(port_pic_master_cmd);
}

fn getPicIrr() u16 {
    return getPicIrqReg(PIC_READ_IRR);
}

fn getPicIsr() u16 {
    return getPicIrqReg(PIC_READ_ISR);
}

fn irqHandled(comptime id: enum { master, slave }) void {
    switch (id) {
        .master => x86.raw.outb(port_pic_master_cmd, 0x20),
        .slave => {
            x86.raw.outb(port_pic_master_cmd, 0x20);
            x86.raw.outb(port_pic_slave_cmd, 0x20);
        },
    }
}

fn nullHandler() void {
    const isr = getPicIsr();
    if (isr & 0xff00 != 0) x86.raw.outb(port_pic_slave_cmd, 0x20);
    if (isr != 0) x86.raw.outb(port_pic_master_cmd, 0x20);
}

fn isrTimer() void {
    timer.count();
    teleprompter.cycleHealthIndicator();
    irqHandled(.master);
}

fn isrKeyboardController() void {
    keyboard.pushIrqData(x86.raw.inb(0x60));
    irqHandled(.master);
}

fn isrFloppy() void {
    floppy.irqEntry();
    irqHandled(.master);
}

fn divisionError() void {
    @panic("Divide error");
}

fn debugTrap() void {
    @panic("Debug exception");
}

fn nonMaskableInterrupt() void {
    @panic("NMI");
}

fn breakpoint() void {
    @panic("Breakpoint");
}

fn overflow() void {
    @panic("Overflow");
}

fn boundRangeExceeded() void {
    @panic("Bounds");
}

fn invalidOpcode() void {
    @panic("Invalid opcode");
}

fn coprocessorUnavailable() void {
    @panic("Coprocessor unavailable");
}

fn doubleFault(_: u32) void { // error always zero
    @panic("Double fault");
}

fn coprocessorSegmentOverrun() void {
    @panic("Coprocessor segment overrun");
}

fn invalidTss(_: u32) void {
    @panic("Invalid TSS");
}

fn segmentNotPresent(_: u32) void {
    @panic("Segment not present");
}

fn stackSegmentFault(_: u32) void {
    @panic("Stack exception");
}

fn generalProtectionFault(err: u32) void {
    std.log.err("error: {}", .{err});
    @panic("General protection exception");
}

fn pageFault(_: u32) void {
    @panic("Page fault");
}

fn floatingPointException() void {
    @panic("Coprocessor error");
}
