const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello world.\n", .{});
}

test "hello test" {
    try std.testing.expectEqual(123, 123);
}
