const std = @import("std");
const w32 = @import("win32").everything;
const w = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn main() !void {
    _ = w32.MessageBoxW(null, w("Hello world."), w("caption"), .{});
}

test "hello test" {
    try std.testing.expectEqual(123, 123);
}
