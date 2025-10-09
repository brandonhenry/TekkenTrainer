const std = @import("std");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

pub const HitLines = struct {
    lingering: sdk.misc.CircularBuffer(128, LingeringLine) = .{},

    const Self = @This();
    const LingeringLine = struct {
        line: sdk.math.LineSegment3,
        player_id: model.PlayerId,
        remaining_time: f32,
        attack_type: ?model.AttackType,
        inactive_or_crushed: bool,
    };

    pub fn processFrame(
        self: *Self,
        settings: *const model.PlayerSettings(model.HitLinesSettings),
        frame: *const model.Frame,
    ) void {
        for (model.PlayerId.all) |player_id| {
            const player_settings = settings.getById(frame, player_id);
            if (!player_settings.enabled) {
                continue;
            }
            const player = frame.getPlayerById(player_id);
            for (player.hit_lines.asConstSlice()) |*hit_line| {
                _ = self.lingering.addToBack(.{
                    .line = hit_line.line,
                    .player_id = player_id,
                    .remaining_time = player_settings.duration,
                    .attack_type = player.attack_type,
                    .inactive_or_crushed = hit_line.flags.is_inactive or hit_line.flags.is_crushed,
                });
            }
        }
    }

    pub fn update(self: *Self, delta_time: f32) void {
        for (0..self.lingering.len) |index| {
            const line = self.lingering.getMut(index) catch unreachable;
            line.remaining_time -= delta_time;
        }
        while (self.lingering.getFirst() catch null) |line| {
            if (line.remaining_time > 0.0) {
                break;
            }
            _ = self.lingering.removeFirst() catch unreachable;
        }
    }

    pub fn draw(
        self: *Self,
        settings: *const model.PlayerSettings(model.HitLinesSettings),
        frame: *const model.Frame,
        matrix: sdk.math.Mat4,
    ) void {
        self.drawLingering(settings, frame, matrix);
        drawRegular(settings, frame, matrix);
    }

    fn drawRegular(
        settings: *const model.PlayerSettings(model.HitLinesSettings),
        frame: *const model.Frame,
        matrix: sdk.math.Mat4,
    ) void {
        for (model.PlayerId.all) |player_id| {
            const player_settings = settings.getById(frame, player_id);
            if (!player_settings.enabled) {
                continue;
            }
            const player = frame.getPlayerById(player_id);
            for (player.hit_lines.asConstSlice()) |hit_line| {
                const line_settings = if (hit_line.flags.is_inactive or hit_line.flags.is_crushed) block: {
                    break :block &player_settings.inactive_or_crushed;
                } else block: {
                    break :block &player_settings.normal;
                };
                const line = hit_line.line;
                const color = line_settings.outline.colors.get(player.attack_type orelse .not_attack);
                const thickness = line_settings.fill.thickness + (2.0 * line_settings.outline.thickness);
                ui.drawLine(line, color, thickness, matrix);
            }
        }
        for (model.PlayerId.all) |player_id| {
            const player_settings = settings.getById(frame, player_id);
            if (!player_settings.enabled) {
                continue;
            }
            const player = frame.getPlayerById(player_id);
            for (player.hit_lines.asConstSlice()) |hit_line| {
                const line_settings = if (hit_line.flags.is_inactive or hit_line.flags.is_crushed) block: {
                    break :block &player_settings.inactive_or_crushed;
                } else block: {
                    break :block &player_settings.normal;
                };
                const line = hit_line.line;
                const color = line_settings.fill.colors.get(player.attack_type orelse .not_attack);
                const thickness = line_settings.fill.thickness;
                ui.drawLine(line, color, thickness, matrix);
            }
        }
    }

    fn drawLingering(
        self: *const Self,
        settings: *const model.PlayerSettings(model.HitLinesSettings),
        frame: *const model.Frame,
        matrix: sdk.math.Mat4,
    ) void {
        for (0..self.lingering.len) |index| {
            const hit_line = self.lingering.get(index) catch unreachable;
            const player_settings = settings.getById(frame, hit_line.player_id);
            if (!player_settings.enabled) {
                continue;
            }

            const line = hit_line.line;
            const line_settings = if (hit_line.inactive_or_crushed) block: {
                break :block &player_settings.inactive_or_crushed;
            } else block: {
                break :block &player_settings.normal;
            };

            const duration = player_settings.duration;
            const completion = 1.0 - (hit_line.remaining_time / duration);
            var color = line_settings.outline.colors.get(hit_line.attack_type orelse .not_attack);
            color.asColor().a *= 1.0 - (completion * completion * completion * completion);
            const thickness = line_settings.fill.thickness + (2.0 * line_settings.outline.thickness);

            ui.drawLine(line, color, thickness, matrix);
        }
        for (0..self.lingering.len) |index| {
            const hit_line = self.lingering.get(index) catch unreachable;
            const player_settings = settings.getById(frame, hit_line.player_id);
            if (!player_settings.enabled) {
                continue;
            }

            const line = hit_line.line;
            const line_settings = if (hit_line.inactive_or_crushed) block: {
                break :block &player_settings.inactive_or_crushed;
            } else block: {
                break :block &player_settings.normal;
            };

            const duration = player_settings.duration;
            const completion = 1.0 - (hit_line.remaining_time / duration);
            var color = line_settings.fill.colors.get(hit_line.attack_type orelse .not_attack);
            color.asColor().a *= 1.0 - (completion * completion * completion * completion);
            const thickness = line_settings.fill.thickness;

            ui.drawLine(line, color, thickness, matrix);
        }
    }
};
