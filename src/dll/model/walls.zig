const std = @import("std");
const sdk = @import("../../sdk/root.zig");

pub const Wall = sdk.math.Rectangle;

pub const Walls = struct {
    buffer: [max_len]Wall = std.mem.zeroes([max_len]Wall),
    len: usize = 0,

    const Self = @This();

    pub const max_len = 64;

    pub fn asSlice(self: anytype) sdk.misc.SelfBasedSlice(@TypeOf(self), Self, Wall) {
        return self.buffer[0..self.len];
    }
};

const testing = std.testing;

test "Walls.asSlice should return correct value" {
    const wall_1 = Wall{ .center = .fromArray(.{ 1, 2 }), .half_size = .fromArray(.{ 3, 4 }), .rotation = 5 };
    const wall_2 = Wall{ .center = .fromArray(.{ 6, 7 }), .half_size = .fromArray(.{ 8, 9 }), .rotation = 10 };
    var walls = Walls{};
    walls.buffer[0] = wall_1;
    walls.buffer[1] = wall_2;
    walls.len = 2;
    try testing.expectEqualSlices(Wall, &.{ wall_1, wall_2 }, walls.asSlice());
}
