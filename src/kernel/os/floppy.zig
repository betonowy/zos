const std = @import("std");
const cmos = @import("cmos.zig");
const dma = @import("dma.zig");

var drive_info: cmos.FdInfo = undefined;
var dma_mem: *[0x200]u8 = undefined;

pub fn init(p_dma_mem: *[0x200]u8) void {
    drive_info = cmos.getFdInfo();
    std.log.info("fd0: {s}", .{drive_info.fd0.str()});
    std.log.info("fd1: {s}", .{drive_info.fd1.str()});

    dma.singleChannelMask(.{ .channel = 2, .state = true });
    dma.setupMemory(2, @intCast(@intFromPtr(p_dma_mem)), @intCast(p_dma_mem.len));
    dma.singleChannelMask(.{ .channel = 2, .state = false });
}

fn prepareDmaForWrite() void {
    dma.singleChannelMask(.{ .channel = 2, .state = true });
    dma.setMode(.{
        .channel = 2,
        .auto_reset = true,
        .mode = .single,
        .order = .up,
        .transfer = .write,
    });
    dma.singleChannelMask(.{ .channel = 2, .state = false });
}

fn prepareDmaForRead() void {
    dma.singleChannelMask(.{ .channel = 2, .state = true });
    dma.setMode(.{
        .channel = 2,
        .auto_reset = true,
        .mode = .single,
        .order = .up,
        .transfer = .write,
    });
    dma.singleChannelMask(.{ .channel = 2, .state = false });
}

pub const CHS = struct {
    cylinder: u8,
    head: u2,
    sector: u8,
};

pub fn chsFromLba(lba: usize, info: cmos.FdInfo.Type) CHS {
    const layout = info.toLayout() orelse unreachable;
    return .{
        .cylinder = lba / (2 * layout.sectors_per_track),
        .head = (lba / layout.sectors_per_track) % 2,
        .sector = (lba % layout.sectors_per_track) + 1,
    };
}

pub fn lbaFromChs(in: CHS, info: cmos.FdInfo.Type) usize {
    const layout = info.toLayout() orelse unreachable;
    return (@as(usize, in.cylinder * layout.heads + in.head) * layout.sectors_per_track) + in.sector - 1;
}

comptime {
    @setEvalBranchQuota(20000);
    for (0..2880) |i| {
        const t = cmos.FdInfo.Type.fd_3_5_1440kib;
        std.debug.assert(lbaFromChs(chsFromLba(i, t), t) == i);
    }
}

const registers = enum(u16) {
    status_a = 0x3f0, // ro
    status_b = 0x3f1, // ro
    digital_output = 0x3f2,
    tape_drive = 0x3f3,
    main_status = 0x3f4, // ro
    datarate_select = 0x3f4, // wo
    data_fifo = 0x3f5,
    digital_input = 0x3f7, // ro
    conf_control = 0x3f7, // wo

    pub fn toU16(self: @This()) u16 {
        return @intFromEnum(self);
    }
};

pub fn irqEntry() void {
    std.log.info("IRQ6", .{});
}
