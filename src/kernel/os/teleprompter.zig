const std = @import("std");
const x86 = @import("x86");

const column_count = 80;
const row_count = 25;

var column: u8 = 0;
var row: u8 = 0;

pub var current_color = Color{
    .fg = Color.Bits.white_lo,
    .bg = Color.Bits.black_lo,
};

pub const Color = packed struct {
    pub const Bits = packed struct {
        b: u1,
        g: u1,
        r: u1,
        h: u1,

        pub const black_lo = @This(){ .b = 0, .g = 0, .r = 0, .h = 0 };
        pub const black_hi = @This(){ .b = 0, .g = 0, .r = 0, .h = 1 };
        pub const red_lo = @This(){ .b = 0, .g = 0, .r = 1, .h = 0 };
        pub const red_hi = @This(){ .b = 0, .g = 0, .r = 1, .h = 1 };
        pub const green_lo = @This(){ .b = 0, .g = 1, .r = 0, .h = 0 };
        pub const green_hi = @This(){ .b = 0, .g = 1, .r = 0, .h = 1 };
        pub const blue_lo = @This(){ .b = 1, .g = 0, .r = 0, .h = 0 };
        pub const blue_hi = @This(){ .b = 1, .g = 0, .r = 0, .h = 1 };
        pub const yellow_lo = @This(){ .b = 0, .g = 1, .r = 1, .h = 0 };
        pub const yellow_hi = @This(){ .b = 0, .g = 1, .r = 1, .h = 1 };
        pub const cyan_lo = @This(){ .b = 1, .g = 1, .r = 0, .h = 0 };
        pub const cyan_hi = @This(){ .b = 1, .g = 1, .r = 0, .h = 1 };
        pub const magenta_lo = @This(){ .b = 0, .g = 1, .r = 1, .h = 0 };
        pub const magenta_hi = @This(){ .b = 0, .g = 1, .r = 1, .h = 1 };
        pub const white_lo = @This(){ .b = 1, .g = 1, .r = 1, .h = 0 };
        pub const white_hi = @This(){ .b = 1, .g = 1, .r = 1, .h = 1 };
    };

    fg: Bits,
    bg: Bits,
};

const BufferType = struct {
    char: u8,
    color: Color,
};

const text_memory: *[row_count][column_count]BufferType = @ptrFromInt(0xb8000);

pub const InitMode = enum {
    quick,
    clear,
    fancy,
};

pub fn init(mode: InitMode) void {
    switch (mode) {
        .quick => initQuick(),
        .clear => initClear(),
        .fancy => initFancy(),
    }
}

fn initQuick() void {
    column = 0;
    row = 0;
    updateCursorPosition();
}

fn initClear() void {
    initQuick();

    @memset(
        @as([*]BufferType, @ptrCast(text_memory))[0 .. row_count * column_count],
        .{ .char = 0, .color = .{ .fg = current_color.fg, .bg = current_color.bg } },
    );
}

fn initFancy() void {
    initQuick();
}

pub fn enableCursor() void {
    const cursor_start = 1;
    const cursor_end = 2;

    x86.ass.outb(0x3d4, 0x0a);
    x86.ass.outb(0x3d5, (x86.ass.inb(0x3d5) & 0xc0) | cursor_start);
    x86.ass.outb(0x3d4, 0x0b);
    x86.ass.outb(0x3d5, (x86.ass.inb(0x3d5) & 0xe0) | cursor_end);

    updateCursorPosition();
}

pub fn disableCursor() void {
    x86.ass.outb(0x3d4, 0x0a);
    x86.ass.outb(0x3d5, 0x20);
}

fn scrollLine() void {
    for (text_memory[0 .. text_memory.len - 1], text_memory[1..]) |*dst, src| {
        dst.* = src;
    }

    for (text_memory[text_memory.len - 1][0..]) |*dst| {
        dst.* = std.mem.zeroes(@TypeOf(dst.*));
    }

    row -= 1;
}

fn needsScroll() bool {
    return row >= row_count;
}

fn updateCursorPosition() void {
    const position = @as(u16, column) + @as(u16, row) * column_count;

    x86.ass.outb(0x3d4, 0x0f);
    x86.ass.outb(0x3d5, @intCast(position & 0xff));
    x86.ass.outb(0x3d4, 0x0e);
    x86.ass.outb(0x3d5, @intCast((position >> 8) & 0xff));
}

pub fn charPrint(data: BufferType) void {
    switch (data.char) {
        '\r' => column = 0,
        '\n' => {
            column = 0;
            row += 1;
        },
        else => {
            text_memory[row][column] = data;

            column += 1;

            if (column >= column_count) {
                column = 0;
                row += 1;
            }
        },
    }

    if (needsScroll()) scrollLine();
    updateCursorPosition();
}

pub fn colorWriteFg(buffer: []const u8, fg: Color.Bits) usize {
    return colorWrite(buffer, .{ .fg = fg, .bg = current_color.bg });
}

pub fn colorWrite(buffer: []const u8, color: Color) usize {
    for (buffer) |char| charPrint(.{
        .char = char,
        .color = color,
    });

    return buffer.len;
}

pub fn stderrWrite(buffer: []const u8) usize {
    return colorWrite(buffer, .{
        .fg = Color.Bits.red_hi,
        .bg = current_color.bg,
    });
}

pub fn stdoutWrite(buffer: []const u8) usize {
    return colorWrite(buffer, .{
        .fg = current_color.fg,
        .bg = current_color.bg,
    });
}
