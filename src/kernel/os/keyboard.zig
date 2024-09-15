const std = @import("std");

const KeyFifo = std.fifo.LinearFifo(u8, .{ .Static = 32 });

var ascii_fifo: KeyFifo = KeyFifo.init();
var state: State = .clear;

var shift_l_state: bool = false;
var shift_r_state: bool = false;

pub fn pushIrqData(value: u8) void {
    switch (state) {
        .clear => {
            const scan_code = ScanCodeSet1_Base.fromU8(value);

            if (scan_code.isExtended()) {
                switch (scan_code) {
                    .extended_0 => state = .extended_0,
                    .extended_1 => state = .extended_1_s0,
                    else => unreachable,
                }
                return;
            }

            switch (scan_code) {
                .d_shift_l => shift_l_state = true,
                .d_shift_right => shift_r_state = true,
                .u_shift_l => shift_l_state = false,
                .u_shift_right => shift_r_state = false,
                else => {},
            }

            if (scan_code.isDown()) {
                if (scan_code.toAscii(shift_l_state or shift_r_state)) |ascii| {
                    ascii_fifo.writeItem(ascii) catch {};
                }
            }
        },
        // TODO better support for extended codes once needed
        .extended_0 => {
            state = .clear;

            const scan_code = ScanCodeSet1_E0.fromU8(value);

            if (scan_code.isDown()) {
                if (scan_code.toAscii()) |ascii| {
                    ascii_fifo.writeItem(ascii) catch {};
                }
            }
        },
        .extended_1_s0 => {
            state = .extended_1_s1;
        },
        .extended_1_s1 => {
            state = .clear;
        },
    }
}

pub fn popKeyData() ?u8 {
    return ascii_fifo.readItem();
}

const State = enum { clear, extended_0, extended_1_s0, extended_1_s1 };

const ScanCodeSet1_Base = enum(u8) {
    extended_0 = 0xe0,
    extended_1 = 0xe1,

    d_esc = 0x01,
    d_1 = 0x02,
    d_2 = 0x03,
    d_3 = 0x04,
    d_4 = 0x05,
    d_5 = 0x06,
    d_6 = 0x07,
    d_7 = 0x08,
    d_8 = 0x09,
    d_9 = 0x0a,
    d_0 = 0x0b,
    d_minus = 0x0c,
    d_equals = 0x0d,
    d_backspace = 0x0e,
    d_tab = 0x0f,
    d_q = 0x10,
    d_w = 0x11,
    d_e = 0x12,
    d_r = 0x13,
    d_t = 0x14,
    d_y = 0x15,
    d_u = 0x16,
    d_i = 0x17,
    d_o = 0x18,
    d_p = 0x19,
    d_bracket_l = 0x1a,
    d_bracket_r = 0x1b,
    d_enter = 0x1c,
    d_ctrl_l = 0x1d,
    d_a = 0x1e,
    d_s = 0x1f,
    d_d = 0x20,
    d_f = 0x21,
    d_g = 0x22,
    d_h = 0x23,
    d_j = 0x24,
    d_k = 0x25,
    d_l = 0x26,
    d_semicolon = 0x27,
    d_singlequote = 0x28,
    d_backtick = 0x29,
    d_shift_l = 0x2a,
    d_backslash = 0x2b,
    d_z = 0x2c,
    d_x = 0x2d,
    d_c = 0x2e,
    d_v = 0x2f,
    d_b = 0x30,
    d_n = 0x31,
    d_m = 0x32,
    d_comma = 0x33,
    d_period = 0x34,
    d_slash = 0x35,
    d_shift_right = 0x36,
    d_kp_star = 0x37,
    d_alt_l = 0x38,
    d_space = 0x39,
    d_capslock = 0x3a,
    d_f1 = 0x3b,
    d_f2 = 0x3c,
    d_f3 = 0x3d,
    d_f4 = 0x3e,
    d_f5 = 0x3f,
    d_f6 = 0x40,
    d_f7 = 0x41,
    d_f8 = 0x42,
    d_f9 = 0x43,
    d_f10 = 0x44,
    d_numlock = 0x45,
    d_scrollock = 0x46,
    d_kp_7 = 0x47,
    d_kp_8 = 0x48,
    d_kp_9 = 0x49,
    d_kp_minus = 0x4a,
    d_kp_4 = 0x4b,
    d_kp_5 = 0x4c,
    d_kp_6 = 0x4d,
    d_kp_plus = 0x4e,
    d_kp_1 = 0x4f,
    d_kp_2 = 0x50,
    d_kp_3 = 0x51,
    d_kp_0 = 0x52,
    d_kp_period = 0x53,
    d_f11 = 0x57,
    d_f12 = 0x58,

    u_esc = 0x81,
    u_1 = 0x82,
    u_2 = 0x83,
    u_3 = 0x84,
    u_4 = 0x85,
    u_5 = 0x86,
    u_6 = 0x87,
    u_7 = 0x88,
    u_8 = 0x89,
    u_9 = 0x8a,
    u_0 = 0x8b,
    u_minus = 0x8c,
    u_equals = 0x8d,
    u_backspace = 0x8e,
    u_tab = 0x8f,
    u_q = 0x90,
    u_w = 0x91,
    u_e = 0x92,
    u_r = 0x93,
    u_t = 0x94,
    u_y = 0x95,
    u_u = 0x96,
    u_i = 0x97,
    u_o = 0x98,
    u_p = 0x99,
    u_bracket_l = 0x9a,
    u_bracket_r = 0x9b,
    u_enter = 0x9c,
    u_ctrl_l = 0x9d,
    u_a = 0x9e,
    u_s = 0x9f,
    u_d = 0xa0,
    u_f = 0xa1,
    u_g = 0xa2,
    u_h = 0xa3,
    u_j = 0xa4,
    u_k = 0xa5,
    u_l = 0xa6,
    u_semicolon = 0xa7,
    u_singlequote = 0xa8,
    u_backtick = 0xa9,
    u_shift_l = 0xaa,
    u_backslash = 0xab,
    u_z = 0xac,
    u_x = 0xad,
    u_c = 0xae,
    u_v = 0xaf,
    u_b = 0xb0,
    u_n = 0xb1,
    u_m = 0xb2,
    u_comma = 0xb3,
    u_period = 0xb4,
    u_slash = 0xb5,
    u_shift_right = 0xb6,
    u_kp_star = 0xb7,
    u_alt_l = 0xb8,
    u_space = 0xb9,
    u_capslock = 0xba,
    u_f1 = 0xbb,
    u_f2 = 0xbc,
    u_f3 = 0xbd,
    u_f4 = 0xbe,
    u_f5 = 0xbf,
    u_f6 = 0xc0,
    u_f7 = 0xc1,
    u_f8 = 0xc2,
    u_f9 = 0xc3,
    u_f10 = 0xc4,
    u_numlock = 0xc5,
    u_scrollock = 0xc6,
    u_kp_7 = 0xc7,
    u_kp_8 = 0xc8,
    u_kp_9 = 0xc9,
    u_kp_minus = 0xca,
    u_kp_4 = 0xcb,
    u_kp_5 = 0xcc,
    u_kp_6 = 0xcd,
    u_kp_plus = 0xce,
    u_kp_1 = 0xcf,
    u_kp_2 = 0xd0,
    u_kp_3 = 0xd1,
    u_kp_0 = 0xd2,
    u_kp_period = 0xd3,
    u_f11 = 0xd7,
    u_f12 = 0xd8,

    pub fn fromU8(value: u8) @This() {
        return @enumFromInt(value);
    }

    pub fn toU8(self: @This()) u8 {
        return @intFromEnum(self);
    }

    pub fn isExtended(self: @This()) bool {
        return switch (self) {
            .extended_0, .extended_1 => true,
            else => false,
        };
    }

    pub fn isDown(self: @This()) bool {
        return if (@intFromEnum(self) & 0x80 != 0) false else true;
    }

    pub fn toAscii(self: @This(), shift_active: bool) ?u8 {
        return if (shift_active) switch (self) {
            else => null,
            .d_1, .u_1 => '!',
            .d_2, .u_2 => '@',
            .d_3, .u_3 => '#',
            .d_4, .u_4 => '$',
            .d_5, .u_5 => '%',
            .d_6, .u_6 => '^',
            .d_7, .u_7 => '&',
            .d_8, .u_8 => '*',
            .d_9, .u_9 => '(',
            .d_0, .u_0 => ')',
            .d_minus, .u_minus => '_',
            .d_equals, .u_equals => '+',
            .d_backspace, .u_backspace => 0x08,
            .d_tab, .u_tab => '\t',
            .d_q, .u_q => 'Q',
            .d_w, .u_w => 'W',
            .d_e, .u_e => 'E',
            .d_r, .u_r => 'R',
            .d_t, .u_t => 'T',
            .d_y, .u_y => 'Y',
            .d_u, .u_u => 'U',
            .d_i, .u_i => 'I',
            .d_o, .u_o => 'O',
            .d_p, .u_p => 'P',
            .d_bracket_l, .u_bracket_l => '{',
            .d_bracket_r, .u_bracket_r => '}',
            .d_enter, .u_enter => '\n',
            .d_a, .u_a => 'A',
            .d_s, .u_s => 'S',
            .d_d, .u_d => 'D',
            .d_f, .u_f => 'F',
            .d_g, .u_g => 'G',
            .d_h, .u_h => 'H',
            .d_j, .u_j => 'J',
            .d_k, .u_k => 'K',
            .d_l, .u_l => 'L',
            .d_semicolon, .u_semicolon => ':',
            .d_singlequote, .u_singlequote => '"',
            .d_backtick, .u_backtick => '~',
            .d_backslash, .u_backslash => '|',
            .d_z, .u_z => 'Z',
            .d_x, .u_x => 'X',
            .d_c, .u_c => 'C',
            .d_v, .u_v => 'V',
            .d_b, .u_b => 'B',
            .d_n, .u_n => 'N',
            .d_m, .u_m => 'M',
            .d_comma, .u_comma => '<',
            .d_period, .u_period => '>',
            .d_slash, .u_slash => '?',
            .d_kp_star, .u_kp_star => '*',
            .d_space, .u_space => ' ',
            .d_kp_7, .u_kp_7 => '7',
            .d_kp_8, .u_kp_8 => '8',
            .d_kp_9, .u_kp_9 => '9',
            .d_kp_minus, .u_kp_minus => '-',
            .d_kp_4, .u_kp_4 => '4',
            .d_kp_5, .u_kp_5 => '5',
            .d_kp_6, .u_kp_6 => '6',
            .d_kp_plus, .u_kp_plus => '+',
            .d_kp_1, .u_kp_1 => '1',
            .d_kp_2, .u_kp_2 => '2',
            .d_kp_3, .u_kp_3 => '3',
            .d_kp_0, .u_kp_0 => '0',
            .d_kp_period, .u_kp_period => '.',
        } else switch (self) {
            else => null,
            .d_1, .u_1 => '1',
            .d_2, .u_2 => '2',
            .d_3, .u_3 => '3',
            .d_4, .u_4 => '4',
            .d_5, .u_5 => '5',
            .d_6, .u_6 => '6',
            .d_7, .u_7 => '7',
            .d_8, .u_8 => '8',
            .d_9, .u_9 => '9',
            .d_0, .u_0 => '0',
            .d_minus, .u_minus => '-',
            .d_equals, .u_equals => '=',
            .d_backspace, .u_backspace => 0x08,
            .d_tab, .u_tab => '\t',
            .d_q, .u_q => 'q',
            .d_w, .u_w => 'w',
            .d_e, .u_e => 'e',
            .d_r, .u_r => 'r',
            .d_t, .u_t => 't',
            .d_y, .u_y => 'y',
            .d_u, .u_u => 'u',
            .d_i, .u_i => 'i',
            .d_o, .u_o => 'o',
            .d_p, .u_p => 'p',
            .d_bracket_l, .u_bracket_l => '[',
            .d_bracket_r, .u_bracket_r => ']',
            .d_enter, .u_enter => '\n',
            .d_a, .u_a => 'a',
            .d_s, .u_s => 's',
            .d_d, .u_d => 'd',
            .d_f, .u_f => 'f',
            .d_g, .u_g => 'g',
            .d_h, .u_h => 'h',
            .d_j, .u_j => 'j',
            .d_k, .u_k => 'k',
            .d_l, .u_l => 'l',
            .d_semicolon, .u_semicolon => ';',
            .d_singlequote, .u_singlequote => '\'',
            .d_backtick, .u_backtick => '`',
            .d_backslash, .u_backslash => '\\',
            .d_z, .u_z => 'z',
            .d_x, .u_x => 'x',
            .d_c, .u_c => 'c',
            .d_v, .u_v => 'v',
            .d_b, .u_b => 'b',
            .d_n, .u_n => 'n',
            .d_m, .u_m => 'm',
            .d_comma, .u_comma => ',',
            .d_period, .u_period => '.',
            .d_slash, .u_slash => '/',
            .d_kp_star, .u_kp_star => '*',
            .d_space, .u_space => ' ',
            .d_kp_7, .u_kp_7 => '7',
            .d_kp_8, .u_kp_8 => '8',
            .d_kp_9, .u_kp_9 => '9',
            .d_kp_minus, .u_kp_minus => '-',
            .d_kp_4, .u_kp_4 => '4',
            .d_kp_5, .u_kp_5 => '5',
            .d_kp_6, .u_kp_6 => '6',
            .d_kp_plus, .u_kp_plus => '+',
            .d_kp_1, .u_kp_1 => '1',
            .d_kp_2, .u_kp_2 => '2',
            .d_kp_3, .u_kp_3 => '3',
            .d_kp_0, .u_kp_0 => '0',
            .d_kp_period, .u_kp_period => '.',
        };
    }
};

const ScanCodeSet1_E0 = enum(u8) {
    d_kp_enter = 0x1c,
    d_ctrl_r = 0x1d,
    d_kp_slash = 0x35,
    d_alt_r = 0x38,
    d_home = 0x47,
    d_up = 0x48,
    d_pageup = 0x49,
    d_left = 0x4b,
    d_right = 0x4d,
    d_end = 0x4f,
    d_down = 0x50,
    d_pagedown = 0x51,
    d_insert = 0x52,
    d_delete = 0x53,
    d_gui_l = 0x5b,
    d_gui_r = 0x5c,
    d_apps = 0x5e,

    u_kp_enter = 0x9c,
    u_ctrl_r = 0x9d,
    u_kp_slash = 0xb5,
    u_alt_r = 0xb8,
    u_home = 0xc7,
    u_up = 0xc8,
    u_pageup = 0xc9,
    u_left = 0xcb,
    u_right = 0xcd,
    u_end = 0xcf,
    u_down = 0xd0,
    u_pagedown = 0xd1,
    u_insert = 0xd2,
    u_delete = 0xd3,
    u_gui_l = 0xdb,
    u_gui_r = 0xdc,
    u_apps = 0xde,

    pub fn fromU8(value: u8) @This() {
        return @enumFromInt(value);
    }

    pub fn toU8(self: @This()) u8 {
        return @intFromEnum(self);
    }

    pub fn isDown(self: @This()) bool {
        return if (@intFromEnum(self) & 0x80 != 0) false else true;
    }

    pub fn toAscii(self: @This()) ?u8 {
        return switch (self) {
            else => null,
            .d_kp_enter, .u_kp_enter => '\n',
            .d_kp_slash, .u_kp_slash => '/',
        };
    }
};
