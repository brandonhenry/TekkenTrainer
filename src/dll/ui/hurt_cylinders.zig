const std = @import("std");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

pub const HurtCylinders = struct {
    connected_remaining_time: std.EnumArray(model.PlayerId, std.EnumArray(model.HurtCylinderId, f32)) = .initFill(
        .initFill(0),
    ),
    lingering: sdk.misc.CircularBuffer(32, LingeringCylinder) = .{},

    const Self = @This();
    pub const LingeringCylinder = struct {
        cylinder: sdk.math.Cylinder,
        player_id: model.PlayerId,
        remaining_time: f32,
    };

    pub fn processFrame(
        self: *Self,
        settings: *const model.PlayerSettings(model.HurtCylindersSettings),
        frame: *const model.Frame,
    ) void {
        for (model.PlayerId.all) |player_id| {
            const player_settings = settings.getById(frame, player_id);
            if (!player_settings.enabled) {
                continue;
            }
            const player = frame.getPlayerById(player_id);
            const cylinders: *const model.HurtCylinders = if (player.hurt_cylinders) |*c| c else return;
            for (&cylinders.values, 0..) |*hurt_cylinder, index| {
                if (!hurt_cylinder.flags.is_connected) {
                    continue;
                }
                const cylinder_id = model.HurtCylinders.Indexer.keyForIndex(index);
                const connected_remaining_time = self.connected_remaining_time.getPtr(player_id).getPtr(cylinder_id);
                connected_remaining_time.* = player_settings.connected.duration;
                _ = self.lingering.addToBack(.{
                    .cylinder = hurt_cylinder.cylinder,
                    .player_id = player_id,
                    .remaining_time = player_settings.lingering.duration,
                });
            }
        }
    }

    pub fn update(self: *Self, delta_time: f32) void {
        self.updateRegular(delta_time);
        self.updateLingering(delta_time);
    }

    fn updateRegular(self: *Self, delta_time: f32) void {
        for (&self.connected_remaining_time.values) |*player_cylinders| {
            for (&player_cylinders.values) |*remaining_time| {
                remaining_time.* -= delta_time;
            }
        }
    }

    fn updateLingering(self: *Self, delta_time: f32) void {
        for (0..self.lingering.len) |index| {
            const cylinder = self.lingering.getMut(index) catch unreachable;
            cylinder.remaining_time -= delta_time;
        }
        while (self.lingering.getFirst() catch null) |cylinder| {
            if (cylinder.remaining_time > 0) {
                break;
            }
            _ = self.lingering.removeFirst() catch unreachable;
        }
    }

    pub fn draw(
        self: *const Self,
        settings: *const model.PlayerSettings(model.HurtCylindersSettings),
        frame: *const model.Frame,
        direction: ui.ViewDirection,
        matrix: sdk.math.Mat4,
        inverse_matrix: sdk.math.Mat4,
    ) void {
        self.drawLingering(settings, frame, direction, matrix, inverse_matrix);
        self.drawRegular(settings, frame, direction, matrix, inverse_matrix);
    }

    fn drawRegular(
        self: *const Self,
        settings: *const model.PlayerSettings(model.HurtCylindersSettings),
        frame: *const model.Frame,
        direction: ui.ViewDirection,
        matrix: sdk.math.Mat4,
        inverse_matrix: sdk.math.Mat4,
    ) void {
        for (model.PlayerId.all) |player_id| {
            const player_settings = settings.getById(frame, player_id);
            if (!player_settings.enabled) {
                continue;
            }

            const player = frame.getPlayerById(player_id);
            const crushing = player.crushing orelse model.Crushing{};

            const ps = if (crushing.power_crushing) &player_settings.power_crushing else &player_settings.normal;
            const base_settings = if (crushing.invincibility) block: {
                break :block &ps.invincible;
            } else if (crushing.high_crushing) block: {
                break :block &ps.high_crushing;
            } else if (crushing.low_crushing) block: {
                break :block &ps.low_crushing;
            } else block: {
                break :block &ps.normal;
            };

            const cylinders: *const model.HurtCylinders = if (player.hurt_cylinders) |*c| c else continue;
            for (cylinders.values, 0..) |hurt_cylinder, index| {
                const cylinder = hurt_cylinder.cylinder;
                const cylinder_id = model.HurtCylinders.Indexer.keyForIndex(index);

                const remaining_time = self.connected_remaining_time.getPtrConst(player_id).get(cylinder_id);
                const duration = player_settings.connected.duration;
                const completion: f32 = if (hurt_cylinder.flags.is_connected) 0.0 else block: {
                    break :block std.math.clamp(1.0 - (remaining_time / duration), 0.0, 1.0);
                };
                const t = completion * completion * completion * completion;
                const color = sdk.math.Vec4.lerpElements(player_settings.connected.color, base_settings.color, t);
                const thickness = std.math.lerp(player_settings.connected.thickness, base_settings.thickness, t);

                ui.drawCylinder(cylinder, color, thickness, direction, matrix, inverse_matrix);
            }
        }
    }

    fn drawLingering(
        self: *const Self,
        settings: *const model.PlayerSettings(model.HurtCylindersSettings),
        frame: *const model.Frame,
        direction: ui.ViewDirection,
        matrix: sdk.math.Mat4,
        inverse_matrix: sdk.math.Mat4,
    ) void {
        for (0..self.lingering.len) |index| {
            const hurt_cylinder = self.lingering.get(index) catch unreachable;
            const player_settings = settings.getById(frame, hurt_cylinder.player_id);
            if (!player_settings.enabled) {
                continue;
            }
            const cylinder = hurt_cylinder.cylinder;

            const duration = player_settings.lingering.duration;
            const completion = 1.0 - (hurt_cylinder.remaining_time / duration);
            var color = player_settings.lingering.color;
            color.asColor().a *= 1.0 - (completion * completion * completion * completion);
            const thickness = player_settings.lingering.thickness;

            ui.drawCylinder(cylinder, color, thickness, direction, matrix, inverse_matrix);
        }
    }
};
