const std = @import("std");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");

pub const MovePhaseDetector = struct {
    player_1_state: PlayerState = .{},
    player_2_state: PlayerState = .{},

    const Self = @This();
    pub const PlayerState = struct {
        phase: ?model.MovePhase = null,
        first_active_frame: ?u32 = null,
        last_active_frame: ?u32 = null,
        connected_frame: ?u32 = null,
    };

    pub fn detect(self: *Self, frame: *model.Frame) void {
        detectSide(&self.player_1_state, &frame.players[0], &frame.players[1]);
        detectSide(&self.player_2_state, &frame.players[1], &frame.players[0]);
    }

    fn detectSide(state: *PlayerState, player: *model.Player, other_player: *model.Player) void {
        const current_frame = player.move_frame orelse {
            state.* = .{};
            return;
        };
        const attack_type = player.attack_type orelse {
            state.* = .{};
            return;
        };
        const can_move = player.can_move orelse {
            state.* = .{};
            return;
        };
        if (current_frame == 1) {
            if (attack_type == .not_attack) {
                if (can_move) {
                    state.* = .{ .phase = .neutral };
                } else {
                    state.* = .{ .phase = .recovery };
                }
            } else {
                state.* = .{ .phase = .start_up };
            }
        }
        if (state.phase) |phase| {
            switch (phase) {
                .neutral => if (!can_move) {
                    state.phase = .recovery;
                },
                .start_up => if (player.hit_lines.len > 0) {
                    state.phase = .active;
                    state.first_active_frame = current_frame;
                },
                .active => if (player.hit_lines.len == 0) {
                    state.phase = .recovery;
                    state.last_active_frame = current_frame -| 1;
                } else if (state.connected_frame != null) {
                    state.phase = .active_recovery;
                },
                .active_recovery => if (player.hit_lines.len == 0) {
                    state.phase = .recovery;
                    state.last_active_frame = current_frame -| 1;
                },
                .recovery => if (can_move) {
                    state.phase = .neutral;
                },
            }
        }
        if (state.phase == .active and other_player.hit_outcome != null and other_player.hit_outcome != .none) {
            state.connected_frame = current_frame;
        }
        player.move_phase = state.phase;
        player.move_first_active_frame = state.first_active_frame;
        player.move_last_active_frame = state.last_active_frame;
        player.move_connected_frame = state.connected_frame;
    }
};

const testing = std.testing;

test "should set move_phase, move_first_active_frame, move_last_active_frame, move_connected_frame to correct value at correct frame" {
    var frames = [_]model.Frame{
        .{ .players = .{
            .{
                .move_frame = 1,
                .attack_type = .not_attack,
                .hit_outcome = .none,
                .can_move = true,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
            .{
                .move_frame = 1,
                .attack_type = .not_attack,
                .hit_outcome = .none,
                .can_move = true,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
        } },
        .{ .players = .{
            .{
                .move_frame = 1,
                .attack_type = .mid,
                .hit_outcome = .none,
                .can_move = false,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
            .{
                .move_frame = 2,
                .attack_type = .not_attack,
                .hit_outcome = .none,
                .can_move = true,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
        } },
        .{ .players = .{
            .{
                .move_frame = 2,
                .attack_type = .mid,
                .hit_outcome = .none,
                .can_move = false,
                .hit_lines = .{ .buffer = undefined, .len = 1 },
            },
            .{
                .move_frame = 3,
                .attack_type = .not_attack,
                .hit_outcome = .none,
                .can_move = true,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
        } },
        .{ .players = .{
            .{
                .move_frame = 3,
                .attack_type = .mid,
                .hit_outcome = .none,
                .can_move = false,
                .hit_lines = .{ .buffer = undefined, .len = 2 },
            },
            .{
                .move_frame = 4,
                .attack_type = .not_attack,
                .hit_outcome = .blocked_standing,
                .can_move = true,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
        } },
        .{ .players = .{
            .{
                .move_frame = 4,
                .attack_type = .mid,
                .hit_outcome = .none,
                .can_move = false,
                .hit_lines = .{ .buffer = undefined, .len = 3 },
            },
            .{
                .move_frame = 1,
                .attack_type = .not_attack,
                .hit_outcome = .blocked_standing,
                .can_move = false,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
        } },
        .{ .players = .{
            .{
                .move_frame = 5,
                .attack_type = .mid,
                .hit_outcome = .none,
                .can_move = false,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
            .{
                .move_frame = 2,
                .attack_type = .not_attack,
                .hit_outcome = .blocked_standing,
                .can_move = false,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
        } },
        .{ .players = .{
            .{
                .move_frame = 6,
                .attack_type = .mid,
                .hit_outcome = .none,
                .can_move = false,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
            .{
                .move_frame = 1,
                .attack_type = .not_attack,
                .hit_outcome = .none,
                .can_move = true,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
        } },
        .{ .players = .{
            .{
                .move_frame = 1,
                .attack_type = .not_attack,
                .hit_outcome = .none,
                .can_move = true,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
            .{
                .move_frame = 2,
                .attack_type = .not_attack,
                .hit_outcome = .none,
                .can_move = true,
                .hit_lines = .{ .buffer = undefined, .len = 0 },
            },
        } },
    };

    var detector = MovePhaseDetector{};
    for (&frames, 0..) |*frame, index| {
        detector.detect(frame);
        switch (index) {
            1 => {
                try testing.expectEqual(.start_up, frame.players[0].move_phase);
                try testing.expectEqual(.neutral, frame.players[1].move_phase);
                try testing.expectEqual(null, frame.players[0].move_first_active_frame);
                try testing.expectEqual(null, frame.players[0].move_connected_frame);
                try testing.expectEqual(null, frame.players[0].move_last_active_frame);
            },
            2 => {
                try testing.expectEqual(.active, frame.players[0].move_phase);
                try testing.expectEqual(.neutral, frame.players[1].move_phase);
                try testing.expectEqual(2, frame.players[0].move_first_active_frame);
                try testing.expectEqual(null, frame.players[0].move_connected_frame);
                try testing.expectEqual(null, frame.players[0].move_last_active_frame);
            },
            3 => {
                try testing.expectEqual(.active, frame.players[0].move_phase);
                try testing.expectEqual(.neutral, frame.players[1].move_phase);
                try testing.expectEqual(2, frame.players[0].move_first_active_frame);
                try testing.expectEqual(3, frame.players[0].move_connected_frame);
                try testing.expectEqual(null, frame.players[0].move_last_active_frame);
            },
            4 => {
                try testing.expectEqual(.active_recovery, frame.players[0].move_phase);
                try testing.expectEqual(.recovery, frame.players[1].move_phase);
                try testing.expectEqual(2, frame.players[0].move_first_active_frame);
                try testing.expectEqual(3, frame.players[0].move_connected_frame);
                try testing.expectEqual(null, frame.players[0].move_last_active_frame);
            },
            5 => {
                try testing.expectEqual(.recovery, frame.players[0].move_phase);
                try testing.expectEqual(.recovery, frame.players[1].move_phase);
                try testing.expectEqual(2, frame.players[0].move_first_active_frame);
                try testing.expectEqual(3, frame.players[0].move_connected_frame);
                try testing.expectEqual(4, frame.players[0].move_last_active_frame);
            },
            6 => {
                try testing.expectEqual(.recovery, frame.players[0].move_phase);
                try testing.expectEqual(.neutral, frame.players[1].move_phase);
                try testing.expectEqual(2, frame.players[0].move_first_active_frame);
                try testing.expectEqual(3, frame.players[0].move_connected_frame);
                try testing.expectEqual(4, frame.players[0].move_last_active_frame);
            },
            else => {
                try testing.expectEqual(.neutral, frame.players[0].move_phase);
                try testing.expectEqual(.neutral, frame.players[1].move_phase);
                try testing.expectEqual(null, frame.players[0].move_first_active_frame);
                try testing.expectEqual(null, frame.players[0].move_connected_frame);
                try testing.expectEqual(null, frame.players[0].move_last_active_frame);
            },
        }
        try testing.expectEqual(null, frame.players[1].move_first_active_frame);
        try testing.expectEqual(null, frame.players[1].move_connected_frame);
        try testing.expectEqual(null, frame.players[1].move_last_active_frame);
    }
}
