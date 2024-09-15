var tick: usize = 0;

pub fn count() void {
    tick +%= 1;
}

pub fn getTick() usize {
    return tick;
}

pub fn diffFrom(tp: usize) usize {
    return tick -% tp;
}

pub fn setFreq(_: usize) void {
    @panic("setFreq unimplemented");
}
