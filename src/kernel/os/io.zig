const std = @import("std");
const tele = @import("teleprompter.zig");

pub const fd_t = enum(usize) {
    null,
    stdout,
    stderr,
    stdin,
    _,

    pub fn writer(self: @This()) std.io.AnyWriter {
        return std.io.AnyWriter{
            .context = @ptrFromInt(@intFromEnum(self)),
            .writeFn = &writeFn,
        };
    }

    fn writeFn(o: *const anyopaque, buf: []const u8) !usize {
        return write(@enumFromInt(@intFromPtr(o)), buf);
    }
};

pub const STDERR_FILENO: fd_t = .stderr;
pub const STDOUT_FILENO: fd_t = .stdout;
pub const STDIN_FILENO: fd_t = .stdin;

pub fn getStdErrHandle() fd_t {
    return STDERR_FILENO;
}

pub fn getStdOutHandle() fd_t {
    return STDOUT_FILENO;
}

pub fn getStdInHandle() fd_t {
    return STDIN_FILENO;
}

pub fn getStdOut() fd_t {
    return getStdOutHandle();
}

pub fn getStdErr() fd_t {
    return getStdErrHandle();
}

pub fn getStdIn() fd_t {
    return getStdInHandle();
}

pub fn write(descriptor: fd_t, buf: []const u8) usize {
    switch (descriptor) {
        .stderr => return tele.stderrWrite(buf),
        .stdout => return tele.stdoutWrite(buf),
        .stdin => @panic("Writing to stdin is not allowed"),
        else => @panic("Reading files not yet implemented"),
    }
}

pub const errno_t = enum(usize) {
    SUCCESS,
    INTR,
    INVAL,
    FAULT,
    AGAIN,
    BADF,
    DESTADDRREQ,
    DQUOT,
    FBIG,
    IO,
    NOSPC,
    PERM,
    PIPE,
    CONNRESET,
    BUSY,
    _,
};

pub const E = errno_t;

pub fn getErrno(_: usize) errno_t {
    return .SUCCESS;
}
