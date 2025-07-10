const std = @import("std");
const math = @import("../math/root.zig");
const game = @import("../game/root.zig");

pub const Frame = struct {
    players: [2]Player = .{ .{}, .{} },
    left_player_id: PlayerId = .player_1,
    main_player_id: PlayerId = .player_1,

    const Self = @This();

    pub fn getPlayerById(self: *const Self, id: PlayerId) *const Player {
        switch (id) {
            .player_1 => return &self.players[0],
            .player_2 => return &self.players[1],
        }
    }

    pub fn getPlayerBySide(self: *const Self, side: PlayerSide) *const Player {
        return switch (side) {
            .left => return self.getPlayerById(self.left_player_id),
            .right => return self.getPlayerById(self.left_player_id.getOther()),
        };
    }

    pub fn getPlayerByRole(self: *const Self, role: PlayerRole) *const Player {
        return switch (role) {
            .main => return self.getPlayerById(self.main_player_id),
            .secondary => return self.getPlayerById(self.main_player_id.getOther()),
        };
    }
};

pub const PlayerId = enum {
    player_1,
    player_2,

    const Self = @This();

    pub fn getOther(self: Self) Self {
        switch (self) {
            .player_1 => return .player_2,
            .player_2 => return .player_1,
        }
    }
};

pub const PlayerSide = enum {
    left,
    right,

    const Self = @This();

    pub fn getOther(self: Self) Self {
        switch (self) {
            .left => return .right,
            .right => return .left,
        }
    }
};

pub const PlayerRole = enum {
    main,
    secondary,

    const Self = @This();

    pub fn getOther(self: Self) Self {
        switch (self) {
            .main => return .secondary,
            .secondary => return .main,
        }
    }
};

pub const Player = struct {
    position: ?math.Vec3 = null,
    skeleton_lines_buffer: [max_skeleton_lines]math.LineSegment3 = undefined,
    skeleton_lines_len: usize = 0,
    hurt_cylinders_buffer: [max_hurt_cylinders]HurtCylinder = undefined,
    hurt_cylinders_len: usize = 0,
    collision_spheres_buffer: [max_collision_spheres]math.Sphere = undefined,
    collision_spheres_len: usize = 0,
    hit_lines_buffer: [max_hit_lines]HitLine = undefined,
    hit_lines_len: usize = 0,

    const Self = @This();
    pub const max_skeleton_lines = 15;
    pub const max_hurt_cylinders = game.HurtCylinders.len;
    pub const max_collision_spheres = game.CollisionSpheres.len;
    pub const max_hit_lines = @typeInfo(game.HitLines).array.len * 2;

    pub fn getSkeletonLines(self: *const Self) []const math.LineSegment3 {
        return self.skeleton_lines_buffer[0..self.skeleton_lines_len];
    }

    pub fn getHurtCylinders(self: *const Self) []const HurtCylinder {
        return self.hurt_cylinders_buffer[0..self.hurt_cylinders_len];
    }

    pub fn getGetCollisionSpheres(self: *const Self) []const math.Sphere {
        return self.collision_spheres_buffer[0..self.collision_spheres_len];
    }

    pub fn getHitLines(self: *const Self) []const HitLine {
        return self.hit_lines_buffer[0..self.hit_lines_len];
    }
};

pub const HurtCylinder = struct {
    cylinder: math.Cylinder,
    intersects: bool,
};

pub const HitLine = struct {
    line: math.LineSegment3,
    intersects: bool,
};

const testing = std.testing;

test "Frame.getPlayerById should return correct player" {
    const frame = Frame{};
    try testing.expectEqual(&frame.players[0], frame.getPlayerById(.player_1));
    try testing.expectEqual(&frame.players[1], frame.getPlayerById(.player_2));
}

test "Frame.getPlayerBySide should return correct player" {
    const frame_1 = Frame{ .left_player_id = .player_1 };
    const frame_2 = Frame{ .left_player_id = .player_2 };
    try testing.expectEqual(&frame_1.players[0], frame_1.getPlayerBySide(.left));
    try testing.expectEqual(&frame_1.players[1], frame_1.getPlayerBySide(.right));
    try testing.expectEqual(&frame_2.players[1], frame_2.getPlayerBySide(.left));
    try testing.expectEqual(&frame_2.players[0], frame_2.getPlayerBySide(.right));
}

test "Frame.getPlayerByRole should return correct player" {
    const frame_1 = Frame{ .main_player_id = .player_1 };
    const frame_2 = Frame{ .main_player_id = .player_2 };
    try testing.expectEqual(&frame_1.players[0], frame_1.getPlayerByRole(.main));
    try testing.expectEqual(&frame_1.players[1], frame_1.getPlayerByRole(.secondary));
    try testing.expectEqual(&frame_2.players[1], frame_2.getPlayerByRole(.main));
    try testing.expectEqual(&frame_2.players[0], frame_2.getPlayerByRole(.secondary));
}

test "PlayerId.getOther should return correct value" {
    try testing.expectEqual(PlayerId.player_2, PlayerId.player_1.getOther());
    try testing.expectEqual(PlayerId.player_1, PlayerId.player_2.getOther());
}

test "PlayerSide.getOther should return correct value" {
    try testing.expectEqual(PlayerSide.right, PlayerSide.left.getOther());
    try testing.expectEqual(PlayerSide.left, PlayerSide.right.getOther());
}

test "PlayerRole.getOther should return correct value" {
    try testing.expectEqual(PlayerRole.secondary, PlayerRole.main.getOther());
    try testing.expectEqual(PlayerRole.main, PlayerRole.secondary.getOther());
}

test "Player.getSkeletonLines should return correct value" {
    const line_1 = math.LineSegment3{ .point_1 = .fromArray(.{ 1, 2, 3 }), .point_2 = .fromArray(.{ 4, 5, 6 }) };
    const line_2 = math.LineSegment3{ .point_1 = .fromArray(.{ 7, 8, 9 }), .point_2 = .fromArray(.{ 10, 11, 12 }) };
    var player = Player{};
    player.skeleton_lines_buffer[0] = line_1;
    player.skeleton_lines_buffer[1] = line_2;
    player.skeleton_lines_len = 2;
    try testing.expectEqualSlices(math.LineSegment3, &.{ line_1, line_2 }, player.getSkeletonLines());
}

test "Player.getHurtCylinders should return correct value" {
    const cylinder_1 = HurtCylinder{
        .cylinder = .{ .center = .fromArray(.{ 1, 2, 3 }), .radius = 4, .half_height = 5 },
        .intersects = false,
    };
    const cylinder_2 = HurtCylinder{
        .cylinder = .{ .center = .fromArray(.{ 6, 7, 8 }), .radius = 9, .half_height = 10 },
        .intersects = true,
    };
    var player = Player{};
    player.hurt_cylinders_buffer[0] = cylinder_1;
    player.hurt_cylinders_buffer[1] = cylinder_2;
    player.hurt_cylinders_len = 2;
    try testing.expectEqualSlices(HurtCylinder, &.{ cylinder_1, cylinder_2 }, player.getHurtCylinders());
}

test "Player.getGetCollisionSpheres should return correct value" {
    const sphere_1 = math.Sphere{ .center = .fromArray(.{ 1, 2, 3 }), .radius = 4 };
    const sphere_2 = math.Sphere{ .center = .fromArray(.{ 6, 7, 8 }), .radius = 9 };
    var player = Player{};
    player.collision_spheres_buffer[0] = sphere_1;
    player.collision_spheres_buffer[1] = sphere_2;
    player.collision_spheres_len = 2;
    try testing.expectEqualSlices(math.Sphere, &.{ sphere_1, sphere_2 }, player.getGetCollisionSpheres());
}

test "Player.getHitLines should return correct value" {
    const line_1 = HitLine{
        .line = .{ .point_1 = .fromArray(.{ 1, 2, 3 }), .point_2 = .fromArray(.{ 4, 5, 6 }) },
        .intersects = false,
    };
    const line_2 = HitLine{
        .line = .{ .point_1 = .fromArray(.{ 7, 8, 9 }), .point_2 = .fromArray(.{ 10, 11, 12 }) },
        .intersects = true,
    };
    var player = Player{};
    player.hit_lines_buffer[0] = line_1;
    player.hit_lines_buffer[1] = line_2;
    player.hit_lines_len = 2;
    try testing.expectEqualSlices(HitLine, &.{ line_1, line_2 }, player.getHitLines());
}
