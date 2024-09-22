const std = @import("std");
const x86 = @import("root.zig");

pub const DirectoryBaseRegister = packed struct {
    address_high: u20,

    pub fn init(ptr: *volatile DirectoryEntryArray) @This() {
        std.debug.assert(x86.paging.isAligned(ptr));
        return .{ .address_high = @intCast(@intFromPtr(ptr) >> 12) };
    }
};

pub const DirectoryEntry = packed struct {
    /// Page present. If set, page is actually in physical memory at the moment. (hint: swapping).
    present: bool,
    /// Write permission flag.
    write_access: bool,
    /// Supervisor access.
    supervisor: bool,
    /// Reserved by Intel in i386. Do not define.
    reserved_0: u2,
    /// Set if underlying memory has been accessed since the last time this flag was cleared.
    accessed: bool,
    /// Set if underlying memory has been written to since the last time this flag was cleared.
    dirty: bool,
    /// Reserved by Intel in i386. Do not define.
    reserved_1: u2,
    /// Available for systems programmer use.
    user_data: u3,
    /// High 20 bits of page table address.
    b31_12: u20,

    pub fn setAddress(self: *volatile @This(), ptr: *volatile anyopaque) void {
        std.debug.assert(x86.paging.isAligned(ptr));
        self.b31_12 = @intCast(@intFromPtr(ptr) >> 12);
    }

    pub fn table(self: @This()) *volatile TableEntryArray {
        return @ptrFromInt(@as(usize, self.b31_12) << 12);
    }
};

pub const TableEntry = packed struct {
    /// Page present. If set, page is actually in physical memory at the moment. (hint: swapping).
    present: bool,
    /// Write permission flag.
    write_access: bool,
    /// Supervisor access.
    supervisor: bool,
    /// Reserved by Intel in i386. Do not define.
    reserved_0: u2,
    /// Set if underlying memory has been accessed since the last time this flag was cleared.
    accessed: bool,
    /// Set if underlying memory has been written to since the last time this flag was cleared.
    dirty: bool,
    /// Reserved by Intel in i386. Do not define.
    reserved_1: u2,
    /// Available for systems programmer use.
    user_data: u3,
    /// High 20 bits of frame address.
    b31_12: u20,

    pub fn setAddress(self: *@This(), ptr: *anyopaque) void {
        std.debug.assert(isAligned(ptr));
        self.b31_12 = @intCast(@intFromPtr(ptr) >> 12);
    }

    pub fn frame(self: @This()) *anyopaque {
        return @ptrFromInt(@as(usize, self.b31_12) << 12);
    }
};

pub const InvalidEntry = packed struct {
    present: bool = false,
    user_data: u31 = undefined,
};

comptime {
    std.debug.assert(@bitSizeOf(DirectoryEntry) == 32);
    std.debug.assert(@bitSizeOf(TableEntry) == 32);
}

pub const DirectoryEntryArray = struct {
    entries: [1024]DirectoryEntry,

    pub fn toPDBR(self: *const @This()) DirectoryBaseRegister {
        return DirectoryBaseRegister.init(self);
    }
};

pub const TableEntryArray = struct {
    entries: [1024]TableEntry,
};

pub fn isAligned(ptr: *const volatile anyopaque) bool {
    return @as(u12, @truncate(@intFromPtr(ptr))) == 0;
}
