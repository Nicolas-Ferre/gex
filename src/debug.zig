const std = @import("std");
const Writer = std.Io.Writer;

pub fn printAsJson(value: anytype) void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    var writer = Writer.Allocating.init(gpa.allocator());
    defer writer.deinit();
    std.json.fmt(value, .{ .whitespace = .indent_2 }).format(&writer.writer) catch {
        std.debug.panic("failed to print value as JSON", .{});
    };
    std.debug.print("{s}\n", .{writer.written()});
}
