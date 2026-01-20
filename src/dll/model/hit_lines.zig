const std = @import("std");
const sdk = @import("../../sdk/root.zig");
const game = @import("../game/root.zig");

pub const HitLine = struct {
    line: sdk.math.LineSegment3,
    flags: HitLineFlags = .{},
};

pub const HitLineFlags = packed struct {
    is_inactive: bool = false,
    is_intersecting: bool = false,
    is_crushed: bool = false,
    is_power_crushed: bool = false,
    is_connected: bool = false,
    is_blocked: bool = false,
    is_normal_hitting: bool = false,
    is_counter_hitting: bool = false,
};

pub const HitLines = struct {
    buffer: [max_len]HitLine = std.mem.zeroes([max_len]HitLine),
    len: usize = 0,

    const Self = @This();

    pub const max_len = 8;

    pub fn asSlice(self: anytype) sdk.misc.SelfBasedSlice(@TypeOf(self), Self, HitLine) {
        return self.buffer[0..self.len];
    }
};

const testing = std.testing;

test "HitLines.asSlice should return correct value" {
    const line_1 = HitLine{
        .line = .{ .point_1 = .fromArray(.{ 1, 2, 3 }), .point_2 = .fromArray(.{ 4, 5, 6 }) },
    };
    const line_2 = HitLine{
        .line = .{ .point_1 = .fromArray(.{ 7, 8, 9 }), .point_2 = .fromArray(.{ 10, 11, 12 }) },
    };
    var lines = HitLines{};
    lines.buffer[0] = line_1;
    lines.buffer[1] = line_2;
    lines.len = 2;
    try testing.expectEqualSlices(HitLine, &.{ line_1, line_2 }, lines.asSlice());
}
