const teleprompter = @import("./teleprompter.zig");

pub const fd_t = union(enum) {
    null,
    stdout,
    stderr,
    stdin,
    file: u8,

    pub fn writer() void {}
};

// pub const STDERR_FILENO: fd_t = .stderr;
// pub const STDOUT_FILENO: fd_t = .stdout;
// pub const STDIN_FILENO: fd_t = .stdin;

// pub fn write(descriptor: fd_t, bytes_ptr: [*]const u8, len: usize) usize {
//     switch (descriptor) {
//         .stderr => return teleprompter.stderrWrite(bytes_ptr[0..len]),
//         .stdout => return teleprompter.stdoutWrite(bytes_ptr[0..len]),
//         .stdin => @panic("Writing to stdin is not allowed"),
//         else => @panic("Reading files not yet implemented"),
//     }
// }

// pub const errno_t = enum(usize) {
//     SUCCESS,
//     INTR,
//     INVAL,
//     FAULT,
//     AGAIN,
//     BADF,
//     DESTADDRREQ,
//     DQUOT,
//     FBIG,
//     IO,
//     NOSPC,
//     PERM,
//     PIPE,
//     CONNRESET,
//     BUSY,
//     _,
// };

// pub const E = errno_t;

// pub fn getErrno(_: usize) errno_t {
//     return .SUCCESS;
// }
