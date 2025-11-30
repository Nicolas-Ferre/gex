const std = @import("std");

pub fn main() void {
    std.debug.print("Command not yet implemented\n", .{});
}

test {
    _ = @import("compiler/reading.zig");
}
