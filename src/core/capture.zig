const std = @import("std");
const misc = @import("../misc/root.zig");
const math = @import("../math/root.zig");
const game = @import("../game/root.zig");
const memory = @import("../memory/root.zig");
const core = @import("root.zig");

pub const Capture = struct {
    previous_player_1_hit_lines: ?game.HitLines = null,
    previous_player_2_hit_lines: ?game.HitLines = null,

    const Self = @This();
    pub const GameMemory = struct {
        player_1: misc.Partial(game.Player),
        player_2: misc.Partial(game.Player),
    };

    pub fn captureFrame(self: *Self, game_memory: *const GameMemory) core.Frame {
        var player_1 = self.capturePlayer(&game_memory.player_1, .player_1);
        var player_2 = self.capturePlayer(&game_memory.player_2, .player_2);
        const cylinders_1 = player_1.hurt_cylinders_buffer[0..player_1.hurt_cylinders_len];
        const cylinders_2 = player_2.hurt_cylinders_buffer[0..player_2.hurt_cylinders_len];
        const lines_1 = player_1.hit_lines_buffer[0..player_1.hit_lines_len];
        const lines_2 = player_2.hit_lines_buffer[0..player_2.hit_lines_len];
        detectIntersections(cylinders_1, lines_2);
        detectIntersections(cylinders_2, lines_1);
        const frame = core.Frame{
            .players = .{ player_1, player_2 },
            .left_player_id = captureLeftPlayerId(game_memory),
            .main_player_id = captureMainPlayerId(game_memory),
        };
        self.updatePreviousHitLines(game_memory);
        return frame;
    }

    fn updatePreviousHitLines(self: *Self, game_memory: *const GameMemory) void {
        self.previous_player_1_hit_lines = game_memory.player_1.hit_lines;
        self.previous_player_2_hit_lines = game_memory.player_2.hit_lines;
    }

    fn captureLeftPlayerId(game_memory: *const GameMemory) core.PlayerId {
        if (game_memory.player_1.player_id) |player_id| {
            return if (player_id == 0) .player_1 else .player_2;
        }
        if (game_memory.player_2.player_id) |player_id| {
            return if (player_id == 0) .player_2 else .player_1;
        }
        return .player_1;
    }

    fn captureMainPlayerId(game_memory: *const GameMemory) core.PlayerId {
        if (game_memory.player_1.is_picked_by_main_player) |is_main| {
            return if (is_main) .player_1 else .player_2;
        }
        if (game_memory.player_2.is_picked_by_main_player) |is_main| {
            return if (is_main) .player_2 else .player_1;
        }
        return .player_1;
    }

    fn capturePlayer(self: *Self, player: *const misc.Partial(game.Player), player_id: core.PlayerId) core.Player {
        const position = capturePlayerPosition(player);
        var skeleton_lines_buffer: [core.Player.max_skeleton_lines]math.LineSegment3 = undefined;
        const skeleton_lines_len = captureSkeletonLines(&skeleton_lines_buffer, player);
        var hurt_cylinders_buffer: [core.Player.max_hurt_cylinders]core.HurtCylinder = undefined;
        const hurt_cylinders_len = captureHurtCylinders(&hurt_cylinders_buffer, player);
        var collision_spheres_buffer: [core.Player.max_collision_spheres]math.Sphere = undefined;
        const collision_spheres_len = captureCollisionSpheres(&collision_spheres_buffer, player);
        var hit_lines_buffer: [core.Player.max_hit_lines]core.HitLine = undefined;
        const hit_lines_len: usize = self.captureHitLines(&hit_lines_buffer, player, player_id);
        return .{
            .position = position,
            .skeleton_lines_buffer = skeleton_lines_buffer,
            .skeleton_lines_len = skeleton_lines_len,
            .hurt_cylinders_buffer = hurt_cylinders_buffer,
            .hurt_cylinders_len = hurt_cylinders_len,
            .collision_spheres_buffer = collision_spheres_buffer,
            .collision_spheres_len = collision_spheres_len,
            .hit_lines_buffer = hit_lines_buffer,
            .hit_lines_len = hit_lines_len,
        };
    }

    fn capturePlayerPosition(player: *const misc.Partial(game.Player)) ?math.Vec3 {
        if (player.collision_spheres) |spheres| {
            return spheres.lower_torso.convert().center;
        }
        if (player.hurt_cylinders) |cylinders| {
            return cylinders.upper_torso.convert().center;
        }
        return null;
    }

    fn captureSkeletonLines(
        buffer: *[core.Player.max_skeleton_lines]math.LineSegment3,
        player: *const misc.Partial(game.Player),
    ) usize {
        const cylinders: *const game.HurtCylinders = if (player.hurt_cylinders) |c| &c else return 0;
        const spheres: *const game.CollisionSpheres = if (player.collision_spheres) |s| &s else return 0;

        const head = cylinders.head.convert().center;
        const neck = spheres.neck.convert().center;
        const upper_torso = cylinders.upper_torso.convert().center;
        const left_shoulder = cylinders.left_shoulder.convert().center;
        const right_shoulder = cylinders.right_shoulder.convert().center;
        const left_elbow = cylinders.left_elbow.convert().center;
        const right_elbow = cylinders.right_elbow.convert().center;
        const left_hand = cylinders.left_hand.convert().center;
        const right_hand = cylinders.right_hand.convert().center;
        const lower_torso = spheres.lower_torso.convert().center;
        const left_pelvis = cylinders.left_pelvis.convert().center;
        const right_pelvis = cylinders.right_pelvis.convert().center;
        const left_knee = cylinders.left_knee.convert().center;
        const right_knee = cylinders.right_knee.convert().center;
        const left_ankle = cylinders.left_ankle.convert().center;
        const right_ankle = cylinders.right_ankle.convert().center;

        buffer[0] = .{ .point_1 = head, .point_2 = neck };
        buffer[1] = .{ .point_1 = neck, .point_2 = upper_torso };
        buffer[2] = .{ .point_1 = upper_torso, .point_2 = left_shoulder };
        buffer[3] = .{ .point_1 = upper_torso, .point_2 = right_shoulder };
        buffer[4] = .{ .point_1 = left_shoulder, .point_2 = left_elbow };
        buffer[5] = .{ .point_1 = right_shoulder, .point_2 = right_elbow };
        buffer[6] = .{ .point_1 = left_elbow, .point_2 = left_hand };
        buffer[7] = .{ .point_1 = right_elbow, .point_2 = right_hand };
        buffer[8] = .{ .point_1 = upper_torso, .point_2 = lower_torso };
        buffer[9] = .{ .point_1 = lower_torso, .point_2 = left_pelvis };
        buffer[10] = .{ .point_1 = lower_torso, .point_2 = right_pelvis };
        buffer[11] = .{ .point_1 = left_pelvis, .point_2 = left_knee };
        buffer[12] = .{ .point_1 = right_pelvis, .point_2 = right_knee };
        buffer[13] = .{ .point_1 = left_knee, .point_2 = left_ankle };
        buffer[14] = .{ .point_1 = right_knee, .point_2 = right_ankle };

        return 15;
    }

    fn captureHurtCylinders(
        buffer: *[core.Player.max_hurt_cylinders]core.HurtCylinder,
        player: *const misc.Partial(game.Player),
    ) usize {
        const cylinders: *const game.HurtCylinders = if (player.hurt_cylinders) |c| &c else return 0;
        inline for (cylinders.asConstArray(), 0..) |*raw, index| {
            const converted = raw.convert();
            const cylinder = math.Cylinder{
                .center = converted.center,
                .radius = converted.radius,
                .half_height = converted.half_height,
            };
            buffer[index] = .{ .cylinder = cylinder, .intersects = false };
        }
        return cylinders.asConstArray().len;
    }

    fn captureCollisionSpheres(
        buffer: *[core.Player.max_collision_spheres]math.Sphere,
        player: *const misc.Partial(game.Player),
    ) usize {
        const spheres: *const game.CollisionSpheres = if (player.collision_spheres) |s| &s else return 0;
        inline for (spheres.asConstArray(), 0..) |*raw, index| {
            const converted = raw.convert();
            const sphere = math.Sphere{ .center = converted.center, .radius = converted.radius };
            buffer[index] = sphere;
        }
        return spheres.asConstArray().len;
    }

    fn captureHitLines(
        self: *const Self,
        buffer: *[core.Player.max_hit_lines]core.HitLine,
        player: *const misc.Partial(game.Player),
        player_id: core.PlayerId,
    ) usize {
        const previous_lines: *const game.HitLines = switch (player_id) {
            .player_1 => &(self.previous_player_1_hit_lines orelse return 0),
            .player_2 => &(self.previous_player_2_hit_lines orelse return 0),
        };
        const current_lines: *const game.HitLines = if (player.hit_lines) |l| &l else return 0;
        var size: usize = 0;
        for (previous_lines, current_lines) |*raw_previous_line, *raw_current_line| {
            const previous_line = raw_previous_line.convert();
            const current_line = raw_current_line.convert();
            if (current_line.ignore) {
                continue;
            }
            if (std.meta.eql(previous_line.points, current_line.points)) {
                continue;
            }
            const line_1 = math.LineSegment3{
                .point_1 = current_line.points[0].position,
                .point_2 = current_line.points[1].position,
            };
            const line_2 = math.LineSegment3{
                .point_1 = current_line.points[1].position,
                .point_2 = current_line.points[2].position,
            };
            buffer[size] = .{ .line = line_1, .intersects = false };
            size += 1;
            buffer[size] = .{ .line = line_2, .intersects = false };
            size += 1;
        }
        return size;
    }

    fn detectIntersections(hurt_cylinders: []core.HurtCylinder, hit_lines: []core.HitLine) void {
        for (hurt_cylinders) |*cylinder| {
            for (hit_lines) |*line| {
                const intersects = math.checkCylinderLineSegmentIntersection(cylinder.cylinder, line.line);
                cylinder.intersects = intersects;
                line.intersects = intersects;
            }
        }
    }
};
