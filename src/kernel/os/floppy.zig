const std = @import("std");
const cmos = @import("cmos.zig");
const dma = @import("dma.zig");
const timer = @import("timer.zig");
const x86 = @import("x86");

var drive_info: cmos.FdInfo = .{};
var dma_mem: []u8 = &.{};
var state: State = .idle;
var current_request: ?Request = null;
var state_change_tp: usize = 0;
var irq_flag = false;

const log = std.log.scoped(.floppy);

const State = enum {
    dead,
    check_disk,
    spinup,
    reading,
    reading_wait_for_irq,
    writing,
    idle,
};

const Request = union(enum) {
    read_lba: usize,
    write_lba: usize,
};

pub fn init(p_dma_mem: []u8) void {
    drive_info = cmos.getFdInfo();
    log.debug("fd0: {s}", .{drive_info.fd0.str()});
    log.debug("fd1: {s}", .{drive_info.fd1.str()});

    x86.ass.outb(Registers.data_fifo.toU16(), Commands.version.toU8());
    msrWaitRqm();
    log.debug("Version: 0x{x}", .{x86.ass.inb(Registers.data_fifo.toU16())});

    dma.singleChannelMask(.{ .channel = 2, .state = true });
    dma.setupMemory(2, @intCast(@intFromPtr(p_dma_mem.ptr)), @intCast(p_dma_mem.len));
    dma.singleChannelMask(.{ .channel = 2, .state = false });

    log.debug("Setup DMA mem: 0x{x}, 0x{x}", .{ @intFromPtr(p_dma_mem.ptr), p_dma_mem.len });

    dma_mem = p_dma_mem;
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
    head: u1,
    sector: u8,
};

pub fn chsFromLba(lba: usize, info: cmos.FdInfo.Type) CHS {
    const layout = info.toLayout() orelse unreachable;
    return .{
        .cylinder = @intCast(lba / (2 * layout.sectors_per_track)),
        .head = @intCast((lba / layout.sectors_per_track) % 2),
        .sector = @intCast((lba % layout.sectors_per_track) + 1),
    };
}

pub fn lbaFromChs(in: CHS, info: cmos.FdInfo.Type) usize {
    const layout = info.toLayout() orelse unreachable;
    return (@as(usize, in.cylinder * layout.heads + in.head) * layout.sectors_per_track) + in.sector - 1;
}

pub fn request(req: Request) !void {
    if (current_request != null) return error.Busy;
    current_request = req;
    handle();
}

comptime {
    @setEvalBranchQuota(20000);
    for (0..2880) |i| {
        const t = cmos.FdInfo.Type.fd_3_5_1440kib;
        std.debug.assert(lbaFromChs(chsFromLba(i, t), t) == i);
    }

    const chs = chsFromLba(0, cmos.FdInfo.Type.fd_3_5_1440kib);
    std.debug.assert(chs.cylinder == 0 and chs.head == 0 and chs.sector == 1);
}

const Registers = enum(u16) {
    status_a = 0x3f0, // ro
    status_b = 0x3f1, // ro
    digital_output = 0x3f2,
    tape_drive = 0x3f3,
    main_status_datarate_select = 0x3f4, // ro/wo
    data_fifo = 0x3f5,
    digital_input_conf_control = 0x3f7, // ro/wo

    pub fn toU16(self: @This()) u16 {
        return @intFromEnum(self);
    }
};

const Commands = enum(u8) {
    read_track = 2, // generates IRQ6
    specify = 3, // * set drive parameters
    sense_drive_status = 4,
    write_data = 5, // * write to the disk
    read_data = 6, // * read from the disk
    recalibrate = 7, // * seek to cylinder 0
    sense_interrupt = 8, // * ack IRQ6, get status of last command
    write_deleted_data = 9,
    read_id = 10, // generates IRQ6
    read_deleted_data = 12,
    format_track = 13, // *
    dumpreg = 14,
    seek = 15, // * seek both heads to cylinder X
    version = 16, // * used during initialization, once
    scan_equal = 17,
    perpendicular_mode = 18, // * used during initialization, once, maybe
    configure = 19, // * set controller parameters
    lock = 20, // * protect controller params from a reset
    verify = 22,
    scan_low_or_equal = 25,
    scan_high_or_equal = 29,

    pub fn toU8(self: @This()) u8 {
        return @intFromEnum(self);
    }
};

const CommandMode = enum(u8) {
    mfm = 0x40,

    pub fn toU8(self: @This()) u8 {
        return @intFromEnum(self);
    }
};

const ST0 = packed struct {
    err: u5,
    rs: u1,
    post_reset: u2,

    pub fn fromU8(value: u8) @This() {
        return @bitCast(value);
    }

    pub fn isOk(self: @This()) bool {
        return self.err == 0;
    }
};

const ST1 = packed struct {
    _unk_0: u1,
    write_protected: bool,
    _unk_1: u2,
    too_slow: bool,
    _unk_2: u2,
    not_enough_sectors: bool,

    pub fn fromU8(value: u8) @This() {
        return @bitCast(value);
    }

    pub fn isOk(self: @This()) bool {
        return @as(u8, @bitCast(self)) == 0;
    }

    pub fn isOtherError(self: @This()) bool {
        return self._unk_0 or self._unk_1 or self._unk_2;
    }
};

const ST2 = packed struct {
    random_errors: u8,

    pub fn fromU8(value: u8) @This() {
        return @bitCast(value);
    }

    pub fn isOk(self: @This()) bool {
        return self.random_errors == 0;
    }
};

pub fn irqEntry() void {
    irq_flag = false;
}

pub fn handle() void {
    switch (state) {
        .dead => handleDead(),
        .check_disk => handleCheckDisk(),
        .spinup => handleSpinup(),
        .reading => handleReading(),
        .reading_wait_for_irq => handleReadingWaitForIrq(),
        .writing => handleWriting(),
        .idle => handleIdle(),
    }
}

fn handleDead() void {
    _ = current_request orelse return;
    transitionCheckDisk();
}

fn handleCheckDisk() void {
    _ = current_request orelse return transitionIdle();
    if (true) transitionSpinup();
}

const spinup_timeout = 5;

fn handleSpinup() void {
    const req = current_request orelse return transitionIdle();

    if (timer.diffFrom(state_change_tp) > spinup_timeout) switch (req) {
        .read_lba => transitionReading(),
        .write_lba => transtionWriting(),
    };
}

const cmd_read = struct {
    const P1 = packed struct {
        drive: u2,
        head: u1,

        pub fn toU3(self: @This()) u3 {
            return @bitCast(self);
        }
    };

    const P2 = packed struct {
        cylinder: u8,

        pub fn toU8(self: @This()) u8 {
            return @bitCast(self);
        }
    };

    const P3 = packed struct {
        head: u1,

        pub fn toU1(self: @This()) u1 {
            return @bitCast(self);
        }
    };

    const P4 = packed struct {
        sector: u8,

        pub fn toU8(self: @This()) u8 {
            return @bitCast(self);
        }
    };

    const P5 = packed struct {
        format: u8 = 2, // always 2, all floppies use 512 byte sectors

        pub fn toU8(self: @This()) u8 {
            return @bitCast(self);
        }
    };

    const P6 = packed struct {
        eot: u8,

        pub fn toU8(self: @This()) u8 {
            return @bitCast(self);
        }
    };

    const P7 = packed struct {
        gap1: u8 = 0x1b,

        pub fn toU8(self: @This()) u8 {
            return @bitCast(self);
        }
    };

    const P8 = packed struct {
        format: u8 = 0xff,

        pub fn toU8(self: @This()) u8 {
            return @bitCast(self);
        }
    };

    const R1 = ST0;
    const R2 = ST1;
    const R3 = ST2;

    const R4 = packed struct {
        end_cylinder: u8,

        pub fn fromU8(value: u8) @This() {
            return @bitCast(value);
        }
    };

    const R5 = packed struct {
        end_head: u8,

        pub fn fromU8(value: u8) @This() {
            return @bitCast(value);
        }
    };

    const R6 = packed struct {
        end_sector: u8,

        pub fn fromU8(value: u8) @This() {
            return @bitCast(value);
        }
    };

    const R7 = packed struct {
        constant: u8,

        pub fn fromU8(value: u8) @This() {
            return @bitCast(value);
        }

        pub fn isValid(self: @This()) bool {
            return self.constant == 2;
        }
    };
};

fn handleReading() void {
    const req = current_request orelse return transitionIdle();
    const chs = chsFromLba(req.read_lba, drive_info.fd0);

    irq_flag = true;

    msrWaitRqm();
    x86.ass.outb(Registers.data_fifo.toU16(), Commands.read_data.toU8() | CommandMode.mfm.toU8());
    msrWaitRqmDio(false);
    x86.ass.outb(Registers.data_fifo.toU16(), (cmd_read.P1{ .drive = 0, .head = chs.head }).toU3());
    msrWaitRqmDio(false);
    x86.ass.outb(Registers.data_fifo.toU16(), (cmd_read.P2{ .cylinder = chs.cylinder }).toU8());
    msrWaitRqmDio(false);
    x86.ass.outb(Registers.data_fifo.toU16(), (cmd_read.P3{ .head = chs.head }).toU1());
    msrWaitRqmDio(false);
    x86.ass.outb(Registers.data_fifo.toU16(), (cmd_read.P4{ .sector = chs.sector }).toU8());
    msrWaitRqmDio(false);
    x86.ass.outb(Registers.data_fifo.toU16(), (cmd_read.P5{}).toU8());
    msrWaitRqmDio(false);
    x86.ass.outb(Registers.data_fifo.toU16(), (cmd_read.P6{ .eot = drive_info.fd0.toLayout().?.sectors_per_track }).toU8());
    msrWaitRqmDio(false);
    x86.ass.outb(Registers.data_fifo.toU16(), (cmd_read.P7{}).toU8());
    msrWaitRqmDio(false);
    x86.ass.outb(Registers.data_fifo.toU16(), (cmd_read.P8{}).toU8());

    current_request = req;
    transitionReadingWaitForIrq();
}

fn handleReadingWaitForIrq() void {
    const req = current_request orelse return transitionIdle();
    const chs = chsFromLba(req.read_lba, drive_info.fd0);

    if (irq_flag) return;

    msrWaitRqm();
    if (!cmd_read.R1.fromU8(x86.ass.inb(Registers.data_fifo.toU16())).isOk()) @panic("R1 not ok");
    msrWaitRqm();
    if (!cmd_read.R2.fromU8(x86.ass.inb(Registers.data_fifo.toU16())).isOk()) @panic("R2 not ok");
    msrWaitRqm();
    if (!cmd_read.R3.fromU8(x86.ass.inb(Registers.data_fifo.toU16())).isOk()) @panic("R3 not ok");
    msrWaitRqm();
    if (cmd_read.R4.fromU8(x86.ass.inb(Registers.data_fifo.toU16())).end_cylinder != chs.cylinder) log.debug("R4 not ok", .{});
    msrWaitRqm();
    if (cmd_read.R5.fromU8(x86.ass.inb(Registers.data_fifo.toU16())).end_head != chs.head) log.debug("R5 not ok", .{});
    msrWaitRqm();
    if (cmd_read.R6.fromU8(x86.ass.inb(Registers.data_fifo.toU16())).end_sector != chs.sector + 1) log.debug("R6 not ok", .{});
    msrWaitRqm();
    if (!cmd_read.R7.fromU8(x86.ass.inb(Registers.data_fifo.toU16())).isValid()) @panic("R7 not ok");

    log.debug("Data: {x}", .{dma_mem[0..16]});

    current_request = null;
    transitionIdle();
}

fn handleWriting() void {
    const req = current_request orelse return transitionIdle();
    _ = req; // autofix
}

const idle_timeout = 20;

fn handleIdle() void {
    const req = current_request orelse return if (timer.diffFrom(state_change_tp) > idle_timeout) transitionDead() else {};

    switch (req) {
        .read_lba => transitionReading(),
        .write_lba => transtionWriting(),
    }
}

fn transitionIdle() void {
    state = .idle;
    state_change_tp = timer.getTick();
}

fn transitionDead() void {
    state = .dead;
    state_change_tp = timer.getTick();
    log.debug("Transition: dead", .{});
    turnOffMotors();
}

fn transitionReading() void {
    state = .reading;
    state_change_tp = timer.getTick();
    log.debug("Transition: reading", .{});
}

fn transitionReadingWaitForIrq() void {
    state = .reading_wait_for_irq;
    state_change_tp = timer.getTick();
    log.debug("Transition: reading wait for irq", .{});
}

fn transtionWriting() void {
    state = .writing;
    state_change_tp = timer.getTick();
    log.debug("Transition: writing", .{});
}

fn transitionSpinup() void {
    state = .spinup;
    state_change_tp = timer.getTick();
    dorSetup(.{ .motor_0 = true, .sel_drive = 0 });
    log.debug("Transition: spinup", .{});
}

fn transitionCheckDisk() void {
    state = .check_disk;
    state_change_tp = timer.getTick();
    log.debug("Transition: check disk", .{});
}

fn turnOffMotors() void {
    dorSetup(.{ .sel_drive = 0 });
}

const DorSetup = packed struct {
    sel_drive: u2,
    reset: Reset = .normal,
    irq: bool = true,
    motor_0: bool = false,
    motor_1: bool = false,
    motor_2: bool = false,
    motor_3: bool = false,

    const Reset = enum(u1) { reset, normal };

    pub fn toU8(self: @This()) u8 {
        return @bitCast(self);
    }
};

fn dorSetup(params: DorSetup) void {
    x86.ass.outb(Registers.digital_output.toU16(), params.toU8());
}

const MainStatusRegister = packed struct {
    busy_0: bool,
    busy_1: bool,
    busy_2: bool,
    busy_3: bool,
    command_busy: bool,
    ndma: bool,
    dio: bool,
    rqm: bool,

    pub fn fromU8(value: u8) @This() {
        return @bitCast(value);
    }

    pub fn isRqmDio(self: @This(), dio: bool) bool {
        return self.rqm == true and self.dio == dio;
    }
};

fn msrWaitRqm() void {
    // log.debug("RQM", .{});
    while (MainStatusRegister.fromU8(x86.ass.inb(Registers.main_status_datarate_select.toU16())).rqm == false) {}
}

fn msrWaitRqmDio(dio: bool) void {
    // log.debug("RQMDIO", .{});
    while (MainStatusRegister.fromU8(x86.ass.inb(Registers.main_status_datarate_select.toU16())).isRqmDio(dio) == false) {}
}
