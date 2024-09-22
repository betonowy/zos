const x86 = @import("x86");

// TODO support second 16-bit DMA controller
const port_dma_m_ch_1_start_address = 0x2;
const port_dma_m_ch_1_count = 0x3;
const port_dma_m_ch_2_start_address = 0x4;
const port_dma_m_ch_2_count = 0x5;
const port_dma_m_ch_3_start_address = 0x6;
const port_dma_m_ch_3_count = 0x7;
const port_dma_m_status = 0x8;
const port_dma_m_command = 0x8;
const port_dma_m_request = 0x9;
const port_dma_m_single_ch_mask = 0xa;
const port_dma_m_mode = 0xb;
const port_dma_m_flip_flop = 0xc;
const port_dma_m_intermediate = 0xd;
const port_dma_m_master_reset = 0xd;
const port_dma_m_mask_reset = 0xe;
const port_dma_m_multich_mask = 0xf;

const port_ch_1_page = 0x83;
const port_ch_2_page = 0x81;
const port_ch_3_page = 0x82;

pub const SingleChannelMaskPayload = packed struct {
    channel: u2,
    state: bool,

    pub fn toU3(self: @This()) u3 {
        return @bitCast(self);
    }
};

pub fn singleChannelMask(payload: SingleChannelMaskPayload) void {
    x86.raw.outb(port_dma_m_single_ch_mask, payload.toU3());
}

pub const MultiChannelMaskPayload = packed struct {
    ch_0: bool,
    ch_1: bool,
    ch_2: bool,
    ch_3: bool,

    pub fn toU4(self: @This()) u4 {
        return @bitCast(self);
    }
};

pub fn multiChannelMask(payload: MultiChannelMaskPayload) void {
    x86.raw.outb(port_dma_m_multich_mask, payload.toU4());
}

pub const SetModePayload = packed struct {
    channel: u2,
    transfer: TransferType,
    auto_reset: bool,
    order: Order,
    mode: TransferMode,

    pub const TransferType = enum(u2) {
        self_test,
        write,
        read,
    };

    pub const Order = enum(u1) {
        up,
        down,
    };

    pub const TransferMode = enum(u2) {
        on_demand,
        single,
        block,
        cascade,
    };

    pub fn toU8(self: @This()) u8 {
        return @bitCast(self);
    }
};

pub fn setMode(payload: SetModePayload) void {
    x86.raw.outb(port_dma_m_mode, payload.toU8());
}

pub fn masterReset() void {
    x86.raw.outb(port_dma_m_master_reset, undefined);
}

pub fn maskReset() void {
    x86.raw.outb(port_dma_m_mask_reset, undefined);
}

pub fn flipFlopReset() void {
    x86.raw.outb(port_dma_m_flip_flop, undefined);
}

pub const StatusPayload = packed struct {
    transfer_complete_0: u1,
    transfer_complete_1: u1,
    transfer_complete_2: u1,
    transfer_complete_3: u1,
    dma_request_0: u1,
    dma_request_1: u1,
    dma_request_2: u1,
    dma_request_3: u1,

    pub fn fromU8(value: u8) @This() {
        return @bitCast(value);
    }

    pub fn isTransferComplete(self: @This(), channel: u2) void {
        return switch (channel) {
            0 => self.transfer_complete_0,
            1 => self.transfer_complete_1,
            2 => self.transfer_complete_2,
            3 => self.transfer_complete_3,
        };
    }

    pub fn isDmaRequest(self: @This(), channel: u2) void {
        return switch (channel) {
            0 => self.dma_request_0,
            1 => self.dma_request_1,
            2 => self.dma_request_2,
            3 => self.dma_request_3,
        };
    }
};

pub fn setupMemory(channel: u2, addr: u24, len: u16) void {
    const port_addr: u16 = switch (channel) {
        else => unreachable,
        1 => port_dma_m_ch_1_start_address,
        2 => port_dma_m_ch_2_start_address,
        3 => port_dma_m_ch_3_start_address,
    };

    const port_count: u16 = switch (channel) {
        else => unreachable,
        1 => port_dma_m_ch_1_count,
        2 => port_dma_m_ch_2_count,
        3 => port_dma_m_ch_3_count,
    };

    const port_page: u16 = switch (channel) {
        else => unreachable,
        1 => port_ch_1_page,
        2 => port_ch_2_page,
        3 => port_ch_3_page,
    };

    const dma_len = len - 1;

    flipFlopReset();
    x86.raw.outb(port_addr, @truncate(addr >> 0));
    x86.raw.outb(port_addr, @truncate(addr >> 8));
    flipFlopReset();
    x86.raw.outb(port_count, @truncate(dma_len >> 0));
    x86.raw.outb(port_count, @truncate(dma_len >> 8));
    x86.raw.outb(port_page, @intCast(addr >> 16));
}
