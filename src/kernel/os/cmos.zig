const x86 = @import("x86");

pub const FdInfo = packed struct {
    fd1: Type = .no_drive,
    fd0: Type = .no_drive,

    pub fn fromU8(value: u8) @This() {
        return @bitCast(value);
    }

    pub const Type = enum(u4) {
        no_drive = 0x0,
        fd_5_25_360kib = 0x1,
        fd_5_25_1200kib = 0x2,
        fd_3_5_720kib = 0x3,
        fd_3_5_1440kib = 0x4,
        fd_3_5_2880kib = 0x5,

        pub const Layout = struct {
            tracks: u8,
            heads: u2,
            sectors_per_track: u8,
            sector_len: u16 = 0x200,
        };

        pub fn toLayout(self: @This()) ?Layout {
            return switch (self) {
                .no_drive => null,
                .fd_5_25_360kib => .{ .tracks = 40, .heads = 2, .sectors_per_track = 9 },
                .fd_5_25_1200kib => .{ .tracks = 80, .heads = 2, .sectors_per_track = 15 },
                .fd_3_5_720kib => .{ .tracks = 80, .heads = 2, .sectors_per_track = 9 },
                .fd_3_5_1440kib => .{ .tracks = 80, .heads = 2, .sectors_per_track = 18 },
                .fd_3_5_2880kib => .{ .tracks = 80, .heads = 2, .sectors_per_track = 36 },
            };
        }

        pub fn str(self: @This()) []const u8 {
            return switch (self) {
                .no_drive => "None",
                .fd_5_25_360kib => "5.25, 360KiB",
                .fd_5_25_1200kib => "5.25, 1200KiB",
                .fd_3_5_720kib => "3.5, 720KiB",
                .fd_3_5_1440kib => "3.5, 1440KiB",
                .fd_3_5_2880kib => "3.5, 2880KiB",
            };
        }
    };
};

pub fn getFdInfo() FdInfo {
    setAddress(0x10);
    return FdInfo.fromU8(readRegister());
}

const port_cmos_a = 0x70;
const port_cmos_b = 0x71;

fn setAddress(address: u7) void {
    // For now this kernel never disables NMI
    // so to simplify that we never set the MSB.
    x86.ass.outb(port_cmos_a, address);
}

fn readRegister() u8 {
    return x86.ass.inb(port_cmos_b);
}
