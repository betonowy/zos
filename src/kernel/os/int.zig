const std = @import("std");
const builtin = @import("builtin");

const x86 = @import("x86");
const teleprompter = @import("teleprompter.zig");
const keyboard = @import("keyboard.zig");
const floppy = @import("floppy.zig");
const os = @import("root.zig");

pub const InstallParams = struct { segment_selector: u16, gate: x86.IDT.Gate, privilege: u2 };

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

pub fn setup(table: []allowzero volatile x86.IDT) void {
    for (table) |*entry| entry.* = x86.IDT.init(.{ .gate = .int_32, .privilege = 0, .segment_selector = 0x8, .offset = @intFromPtr(&isrNull) });

    table[0x21] = x86.IDT.init(.{ .gate = .int_32, .privilege = 0, .segment_selector = 0x8, .offset = @intFromPtr(&isrKeyboardController) });
    table[0x26] = x86.IDT.init(.{ .gate = .int_32, .privilege = 0, .segment_selector = 0x8, .offset = @intFromPtr(&isrFloppy) });

    const mm = x86.ass.inb(port_pic_master_data);
    const ms = x86.ass.inb(port_pic_slave_data);

    // initialization sequence
    x86.ass.outb(port_pic_master_cmd, ICW1_INIT | ICW1_ICW4);
    x86.ass.outb(port_pic_slave_cmd, ICW1_INIT | ICW1_ICW4);

    // vector offsets
    x86.ass.outb(port_pic_master_data, 0x20);
    x86.ass.outb(port_pic_slave_data, 0x28);

    // master/slave
    x86.ass.outb(port_pic_master_data, 0x4);
    x86.ass.outb(port_pic_slave_data, 0x2);

    // 8086 mode
    x86.ass.outb(port_pic_master_data, ICW4_8086);
    x86.ass.outb(port_pic_slave_data, ICW4_8086);

    // restore masks
    x86.ass.outb(port_pic_master_data, mm);
    x86.ass.outb(port_pic_slave_data, ms);

    x86.ass.lidt(x86.IDTR.init(@intFromPtr(table.ptr), @intCast(table.len)));
}

fn getPicIrqReg(cmd: u8) u16 {
    x86.ass.outb(port_pic_slave_cmd, cmd);
    x86.ass.outb(port_pic_master_cmd, cmd);
    return (@as(u16, x86.ass.inb(port_pic_slave_cmd)) << 8) | x86.ass.inb(port_pic_master_cmd);
}

fn getPicIrr() u16 {
    return getPicIrqReg(PIC_READ_IRR);
}

fn getPicIsr() u16 {
    return getPicIrqReg(PIC_READ_ISR);
}

fn irqHandled(comptime id: enum { master, slave }) void {
    switch (id) {
        .master => x86.ass.outb(port_pic_master_cmd, 0x20),
        .slave => {
            x86.ass.outb(port_pic_master_cmd, 0x20);
            x86.ass.outb(port_pic_slave_cmd, 0x20);
        },
    }
}

fn isrNull() callconv(.Interrupt) void {
    const isr = getPicIsr();
    if (isr != 0) x86.ass.outb(port_pic_master_cmd, 0x20);
    if (isr & 0xff00 != 0) x86.ass.outb(port_pic_slave_cmd, 0x20);
}

fn isrKeyboardController() callconv(.Interrupt) void {
    keyboard.pushIrqData(x86.ass.inb(0x60));
    irqHandled(.master);
}

fn isrFloppy() callconv(.Interrupt) void {
    floppy.irqEntry();
    irqHandled(.master);
}
