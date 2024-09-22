const std = @import("std");
const x86 = @import("x86");

const log = std.log.scoped(.paging);

const page_dir: *x86.paging.DirectoryEntryArray = @ptrFromInt(0xa000);
const page_table: *x86.paging.TableEntryArray = @ptrFromInt(0xb000);

pub fn init(table: []const x86.segment.InterruptDescriptor) void {
    @memset(std.mem.asBytes(page_dir), 0);
    @memset(std.mem.asBytes(page_table), 0);

    // Identity map the first megabyte
    {
        page_dir.entries[0].present = true;
        page_dir.entries[0].write_access = true;
        page_dir.entries[0].supervisor = false;
        page_dir.entries[0].accessed = true;
        page_dir.entries[0].dirty = true;
        page_dir.entries[0].setAddress(page_table);

        for (page_table.entries[0..256], 0..) |*entry, i| {
            entry.present = true;
            entry.write_access = true;
            entry.supervisor = false;
            entry.accessed = true;
            entry.dirty = true;
            entry.b31_12 = @intCast(i);
        }
    }

    var cr2 = x86.register.CR2.load();
    cr2.page_fault_linear_address = table[0x0e].logical().offset;
    cr2.store();

    var cr3 = x86.register.CR3.load();
    cr3.pdbr = x86.paging.DirectoryBaseRegister.init(page_dir);
    cr3.store();

    var cr0 = x86.register.CR0.load();
    cr0.paging = true;
    cr0.store();

    x86.raw.flushJmp(@src());
}
