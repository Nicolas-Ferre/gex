const std = @import("std");

pub fn main() !void {
    std.debug.print("Double of 2 is {}", .{double(2)});
}

fn double(number: i32) i32 {
    return number * 2;
}

test "dummy test" {
    try std.testing.expectEqual(double(0), 0);
    try std.testing.expectEqual(double(2), 4);
}
