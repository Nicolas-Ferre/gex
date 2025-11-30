const std = @import("std");
const config = @import("config.zig");
const fs = std.fs;
const mem = std.mem;
const math = std.math;
const testing = std.testing;
const Walker = fs.Dir.Walker;

pub const Context = struct {
    config: config.Config,
    root_path: []const u8,
    alloc: mem.Allocator,
    err_file_path: ?[]const u8 = null,

    pub fn deinit(self: @This()) void {
        if (self.err_file_path) |path| self.alloc.free(path);
    }
};

pub const Files = struct {
    files: std.ArrayList(File),

    pub fn init(ctx: *Context) Error!@This() {
        const abs_path = fs.realpathAlloc(ctx.alloc, ctx.root_path) catch {
            return error.FailedRootDirOpening;
        };
        defer ctx.alloc.free(abs_path);
        var root_dir = fs.openDirAbsolute(abs_path, .{ .iterate = true }) catch {
            return error.FailedRootDirOpening;
        };
        defer root_dir.close();
        var walker = try root_dir.walk(ctx.alloc);
        defer walker.deinit();
        return .{ .files = try File.scan(ctx, &walker) };
    }

    pub fn deinit(self: *@This(), ctx: *const Context) void {
        for (self.files.items) |*file| {
            file.deinit(ctx);
        }
        self.files.deinit(ctx.alloc);
    }
};

pub const File = struct {
    path: []const u8,
    content: ?[]const u8,

    fn scan(ctx: *Context, walker: *Walker) Error!std.ArrayList(@This()) {
        var files = try std.ArrayList(File).initCapacity(ctx.alloc, 10);
        errdefer files.deinit(ctx.alloc);
        while (walker.next() catch return error.FailedDirWalking) |entry| {
            if (@This().isFileWithExt(&entry, ctx.config.file_extension)) {
                var file = try File.init(ctx, &entry);
                errdefer file.deinit(ctx);
                try files.append(ctx.alloc, file);
            }
        }
        return files;
    }

    fn init(ctx: *Context, entry: *const Walker.Entry) Error!@This() {
        const path = try ctx.alloc.dupe(u8, entry.path);
        const max_bytes = math.maxInt(usize);
        const content = entry.dir.readFileAlloc(ctx.alloc, entry.basename, max_bytes) catch {
            ctx.err_file_path = path;
            return error.FailedFileReading;
        };
        return .{ .path = path, .content = content };
    }

    fn deinit(self: *@This(), ctx: *const Context) void {
        ctx.alloc.free(self.path);
        if (self.content) |content| ctx.alloc.free(content);
    }

    fn isFileWithExt(entry: *const Walker.Entry, ext: []const u8) bool {
        const entry_ext = fs.path.extension(entry.basename);
        return entry.kind == .file and mem.eql(u8, entry_ext, ext);
    }
};

pub const Error = error{
    OutOfMemory,
    FailedFileReading,
    FailedRootDirOpening,
    FailedDirWalking,
};

const test_config = config.Config{ .file_extension = ".ext" };

test "Read valid folder" {
    const root_path = "./testdata/reading/valid/";
    var ctx = Context{ .config = test_config, .root_path = root_path, .alloc = testing.allocator };
    defer ctx.deinit();
    var read_files = try Files.init(&ctx);
    defer read_files.deinit(&ctx);
    try testing.expectEqual(2, read_files.files.items.len);
    const files = read_files.files.items;
    try testing.expectEqualStrings("root.ext", files[0].path);
    try testing.expectEqualStrings("content of root.ext", files[0].content.?);
    try testing.expectEqualStrings("inner/inner2/inner.ext", files[1].path);
    try testing.expectEqualStrings("content of inner.ext", files[1].content.?);
}

test "Read not existing folder" {
    const root_path = "./testdata/not-existing";
    var ctx = Context{ .config = test_config, .root_path = root_path, .alloc = testing.allocator };
    defer ctx.deinit();
    try testing.expectEqual(error.FailedRootDirOpening, Files.init(&ctx));
}
