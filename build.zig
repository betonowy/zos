const std = @import("std");

pub fn build(b: *std.Build) !void {
    const nasm = try b.findProgram(&.{"nasm"}, &.{});
    _ = try b.findProgram(&.{"mcopy"}, &.{});

    const target = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .x86,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.i386 },
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .target = target,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/kernel/main/root.zig"),
        .strip = true,
        .single_threaded = true,
    });

    const kernel_mod_x86 = b.addModule("x86", .{ .root_source_file = b.path("src/kernel/x86/root.zig") });

    const kernel_mod_os = b.addModule("os", .{ .root_source_file = b.path("src/kernel/os/root.zig") });
    kernel_mod_os.addImport("x86", kernel_mod_x86);

    kernel.root_module.addImport("os", kernel_mod_os);
    kernel.root_module.addImport("x86", kernel_mod_x86);

    kernel.setLinkerScript(b.path("src/kernel/linker.ld"));
    kernel.entry = .{ .symbol_name = "main" };
    kernel.link_z_max_page_size = 4;
    kernel.link_z_common_page_size = 4;
    kernel.stack_size = 0xe00;

    b.installArtifact(kernel);

    const bootloader = try NasmStep.create(b, nasm, "src/boot/image.s", "zig-out/bin/image.img", .{
        .include_dirs = &.{b.pathFromRoot("src/boot")},
    });
    b.default_step.dependOn(&bootloader.step);

    const mcopy_kernel = try Fat12CopyFileStep.create(b, "mcopy", "zig-out/bin/kernel.elf", "::kernel.elf", "zig-out/bin/image.img");
    mcopy_kernel.step.dependOn(&kernel.step);
    mcopy_kernel.step.dependOn(&bootloader.step);
    b.default_step.dependOn(&mcopy_kernel.step);
}

const NasmStep = struct {
    nasm: []const u8,
    opts: Options,
    input: []const u8,
    output: []const u8,
    include_dirs: [][]const u8,
    step: std.Build.Step,

    const Format = enum { bin };
    pub const Options = struct {
        format: Format = .bin,
        include_dirs: []const []const u8 = &.{},
    };

    pub fn create(b: *std.Build, nasm: []const u8, input: []const u8, output: []const u8, opts: Options) !*@This() {
        var self = try b.allocator.create(@This());

        self.step = std.Build.Step.init(.{
            .id = .custom,
            .name = "nasm",
            .owner = b,
            .makeFn = &make,
        });

        self.input = try b.allocator.dupe(u8, input);
        self.output = try b.allocator.dupe(u8, output);
        self.nasm = try b.allocator.dupe(u8, nasm);
        self.opts = opts;

        self.include_dirs = try b.allocator.dupe([]const u8, opts.include_dirs);
        for (self.include_dirs[0..]) |*dir| dir.* = try b.allocator.dupe(u8, dir.*);

        return self;
    }

    fn make(step: *std.Build.Step, opts: std.Build.Step.MakeOptions) anyerror!void {
        const self: *NasmStep = @fieldParentPtr("step", step);
        var timer = try std.time.Timer.start();
        defer self.step.result_duration_ns = timer.read();

        switch (self.opts.format) {
            .bin => try makeBin(self, opts),
        }
    }

    fn makeBin(self: *@This(), opts: std.Build.Step.MakeOptions) anyerror!void {
        const run = std.Build.Step.Run.create(self.step.owner, "nasm");
        try self.step.owner.build_root.handle.makePath(std.fs.path.dirname(self.output) orelse ".");
        run.addArgs(&.{ self.nasm, "-f", "bin", "-o", self.output });
        for (self.include_dirs) |dir| run.addArgs(&.{ "-i", dir });
        run.addArg(self.input);
        try run.step.makeFn(&run.step, opts);
        self.step.result_cached = false;
        self.step.result_peak_rss = run.step.result_peak_rss;
    }
};

const Fat12CopyFileStep = struct {
    mcopy: []const u8,
    image: []const u8,
    input: []const u8,
    dest: []const u8,

    step: std.Build.Step,

    pub fn create(b: *std.Build, mcopy: []const u8, input: []const u8, dest: []const u8, image: []const u8) !*@This() {
        var self = try b.allocator.create(@This());

        self.step = std.Build.Step.init(.{
            .id = .custom,
            .name = "mcopy",
            .owner = b,
            .makeFn = &make,
        });

        self.mcopy = try b.allocator.dupe(u8, mcopy);
        self.image = b.pathFromRoot(image);
        self.input = b.pathFromRoot(input);
        self.dest = try b.allocator.dupe(u8, dest);

        return self;
    }

    fn make(step: *std.Build.Step, opts: std.Build.Step.MakeOptions) anyerror!void {
        const self: *Fat12CopyFileStep = @fieldParentPtr("step", step);
        var timer = try std.time.Timer.start();
        defer self.step.result_duration_ns = timer.read();

        const run = std.Build.Step.Run.create(self.step.owner, "mcopy");
        run.addArgs(&.{ self.mcopy, "-i", self.image, self.input, self.dest });

        try run.step.makeFn(&run.step, opts);
        self.step.result_cached = false;
        self.step.result_peak_rss = run.step.result_peak_rss;
    }
};
