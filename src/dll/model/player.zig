const std = @import("std");
const sdk = @import("../../sdk/root.zig");
const model = @import("root.zig");

pub const PlayerId = enum {
    player_1,
    player_2,

    const Self = @This();
    pub const all = [2]Self{ .player_1, .player_2 };

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
    pub const all = [2]Self{ .left, .right };

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
    pub const all = [2]Self{ .main, .secondary };

    pub fn getOther(self: Self) Self {
        switch (self) {
            .main => return .secondary,
            .secondary => return .main,
        }
    }
};

pub const Player = struct {
    character_id: ?u32 = null,
    move_id: ?u32 = null,
    move_frame: ?u32 = null,
    move_first_active_frame: ?u32 = null,
    move_last_active_frame: ?u32 = null,
    move_connected_frame: ?u32 = null,
    move_total_frames: ?u32 = null,
    move_phase: ?model.MovePhase = null,
    attack_type: ?model.AttackType = null,
    attack_damage: ?i32 = null,
    hit_outcome: ?model.HitOutcome = null,
    posture: ?model.Posture = null,
    blocking: ?model.Blocking = null,
    crushing: ?model.Crushing = null,
    can_move: ?bool = null,
    input: ?model.Input = null,
    health: ?i32 = null,
    rage: ?model.Rage = null,
    heat: ?model.Heat = null,
    position: ?sdk.math.Vec3 = null,
    rotation: ?f32 = null,
    skeleton: ?model.Skeleton = null,
    hurt_cylinders: ?model.HurtCylinders = null,
    collision_spheres: ?model.CollisionSpheres = null,
    hit_lines: model.HitLines = .{},

    const Self = @This();

    pub fn getStartupFrames(self: *const Self) model.U32ActualMinMax {
        return .{
            .actual = self.move_connected_frame,
            .min = self.move_first_active_frame,
            .max = self.move_last_active_frame,
        };
    }

    pub fn getActiveFrames(self: *const Self) model.U32ActualMax {
        const first_active_frame = self.move_first_active_frame orelse return .{
            .actual = null,
            .max = null,
        };
        const connected_or_whiffed_frame = self.move_connected_frame orelse self.move_last_active_frame;
        return .{
            .actual = if (connected_or_whiffed_frame) |frame| 1 + frame -| first_active_frame else null,
            .max = if (self.move_last_active_frame) |frame| 1 + frame -| first_active_frame else null,
        };
    }

    pub fn getRecoveryFrames(self: *const Self) model.U32ActualMinMax {
        const total = self.move_total_frames orelse return .{
            .actual = null,
            .min = null,
            .max = null,
        };
        if (self.move_phase == .recovery and self.attack_type == .not_attack) {
            return .{
                .actual = total,
                .min = total,
                .max = total,
            };
        }
        const connected_or_whiffed_frame = self.move_connected_frame orelse self.move_last_active_frame;
        return .{
            .actual = if (connected_or_whiffed_frame) |frame| total -| frame else null,
            .min = if (self.move_last_active_frame) |frame| total -| frame else null,
            .max = if (self.move_first_active_frame) |frame| total -| frame else null,
        };
    }

    pub fn getFrameAdvantage(self: *const Self, other: *const Self) model.I32ActualMinMax {
        const self_recovery = self.getRecoveryFrames();
        const other_recovery = other.getRecoveryFrames();
        return .{
            .actual = if (other_recovery.actual != null and self_recovery.actual != null) block: {
                break :block @as(i32, @intCast(other_recovery.actual.?)) -| @as(i32, @intCast(self_recovery.actual.?));
            } else null,
            .min = if (other_recovery.min != null and self_recovery.max != null) block: {
                break :block @as(i32, @intCast(other_recovery.min.?)) -| @as(i32, @intCast(self_recovery.max.?));
            } else null,
            .max = if (other_recovery.max != null and self_recovery.min != null) block: {
                break :block @as(i32, @intCast(other_recovery.max.?)) -| @as(i32, @intCast(self_recovery.min.?));
            } else null,
        };
    }
};

const testing = std.testing;

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

test "Player.getStartupFrames should return correct value" {
    try testing.expectEqual(model.U32ActualMinMax{ .actual = 2, .min = 1, .max = 3 }, (Player{
        .move_first_active_frame = 1,
        .move_connected_frame = 2,
        .move_last_active_frame = 3,
    }).getStartupFrames());
    try testing.expectEqual(model.U32ActualMinMax{ .actual = 2, .min = null, .max = 3 }, (Player{
        .move_first_active_frame = null,
        .move_connected_frame = 2,
        .move_last_active_frame = 3,
    }).getStartupFrames());
    try testing.expectEqual(model.U32ActualMinMax{ .actual = null, .min = 1, .max = 3 }, (Player{
        .move_first_active_frame = 1,
        .move_connected_frame = null,
        .move_last_active_frame = 3,
    }).getStartupFrames());
    try testing.expectEqual(model.U32ActualMinMax{ .actual = 2, .min = 1, .max = null }, (Player{
        .move_first_active_frame = 1,
        .move_connected_frame = 2,
        .move_last_active_frame = null,
    }).getStartupFrames());
}

test "Player.getActiveFrames should return correct value" {
    try testing.expectEqual(model.U32ActualMax{ .actual = 2, .max = 3 }, (Player{
        .move_first_active_frame = 1,
        .move_connected_frame = 2,
        .move_last_active_frame = 3,
    }).getActiveFrames());
    try testing.expectEqual(model.U32ActualMax{ .actual = null, .max = null }, (Player{
        .move_first_active_frame = null,
        .move_connected_frame = 2,
        .move_last_active_frame = 3,
    }).getActiveFrames());
    try testing.expectEqual(model.U32ActualMax{ .actual = 3, .max = 3 }, (Player{
        .move_first_active_frame = 1,
        .move_connected_frame = null,
        .move_last_active_frame = 3,
    }).getActiveFrames());
    try testing.expectEqual(model.U32ActualMax{ .actual = 2, .max = null }, (Player{
        .move_first_active_frame = 1,
        .move_connected_frame = 2,
        .move_last_active_frame = null,
    }).getActiveFrames());
}

test "Player.getRecoveryFrames should return correct value" {
    try testing.expectEqual(model.U32ActualMinMax{ .actual = 3, .min = 2, .max = 4 }, (Player{
        .move_phase = .recovery,
        .attack_type = .mid,
        .move_first_active_frame = 1,
        .move_connected_frame = 2,
        .move_last_active_frame = 3,
        .move_total_frames = 5,
    }).getRecoveryFrames());
    try testing.expectEqual(model.U32ActualMinMax{ .actual = 3, .min = 2, .max = null }, (Player{
        .move_phase = .recovery,
        .attack_type = .mid,
        .move_first_active_frame = null,
        .move_connected_frame = 2,
        .move_last_active_frame = 3,
        .move_total_frames = 5,
    }).getRecoveryFrames());
    try testing.expectEqual(model.U32ActualMinMax{ .actual = 2, .min = 2, .max = 4 }, (Player{
        .move_phase = .recovery,
        .attack_type = .mid,
        .move_first_active_frame = 1,
        .move_connected_frame = null,
        .move_last_active_frame = 3,
        .move_total_frames = 5,
    }).getRecoveryFrames());
    try testing.expectEqual(model.U32ActualMinMax{ .actual = 3, .min = null, .max = 4 }, (Player{
        .move_phase = .recovery,
        .attack_type = .mid,
        .move_first_active_frame = 1,
        .move_connected_frame = 2,
        .move_last_active_frame = null,
        .move_total_frames = 5,
    }).getRecoveryFrames());
    try testing.expectEqual(model.U32ActualMinMax{ .actual = null, .min = null, .max = null }, (Player{
        .move_phase = .recovery,
        .attack_type = .mid,
        .move_first_active_frame = 1,
        .move_connected_frame = 2,
        .move_last_active_frame = 3,
        .move_total_frames = null,
    }).getRecoveryFrames());
    try testing.expectEqual(model.U32ActualMinMax{ .actual = 5, .min = 5, .max = 5 }, (Player{
        .move_phase = .recovery,
        .attack_type = .not_attack,
        .move_first_active_frame = null,
        .move_connected_frame = null,
        .move_last_active_frame = null,
        .move_total_frames = 5,
    }).getRecoveryFrames());
}

test "Player.getFrameAdvantage should return correct value" {
    const player_1 = Player{
        .move_phase = .recovery,
        .attack_type = .mid,
        .move_first_active_frame = 1,
        .move_connected_frame = 2,
        .move_last_active_frame = 3,
        .move_total_frames = 5,
    };
    const player_2 = Player{
        .move_phase = .recovery,
        .attack_type = .not_attack,
        .move_first_active_frame = null,
        .move_connected_frame = null,
        .move_last_active_frame = null,
        .move_total_frames = 5,
    };
    try testing.expectEqual(
        model.I32ActualMinMax{ .actual = 2, .min = 1, .max = 3 },
        player_1.getFrameAdvantage(&player_2),
    );
    try testing.expectEqual(
        model.I32ActualMinMax{ .actual = -2, .min = -3, .max = -1 },
        player_2.getFrameAdvantage(&player_1),
    );
}
