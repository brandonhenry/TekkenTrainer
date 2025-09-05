const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

pub const ViewDirection = enum {
    front,
    side,
    top,
};

pub const View = struct {
    frame: model.Frame = .{},
    camera: ui.Camera = .{},
    hurt_cylinders: ui.HurtCylinders = .{},
    hit_lines: ui.HitLines = .{},

    const Self = @This();

    pub fn processFrame(self: *Self, frame: *const model.Frame) void {
        self.hurt_cylinders.processFrame(frame);
        self.hit_lines.processFrame(frame);
        self.frame = frame.*;
    }

    pub fn update(self: *Self, delta_time: f32) void {
        self.hurt_cylinders.update(delta_time);
        self.hit_lines.update(delta_time);
    }

    pub fn draw(self: *Self, direction: ViewDirection) void {
        self.camera.updateWindowState(direction);
        const matrix = self.camera.calculateMatrix(&self.frame, direction) orelse return;
        const inverse_matrix = matrix.inverse() orelse sdk.math.Mat4.identity;

        ui.drawCollisionSpheres(&self.frame, matrix, inverse_matrix);
        self.hurt_cylinders.draw(&self.frame, direction, matrix, inverse_matrix);
        ui.drawFloor(&self.frame, direction, matrix);
        ui.drawForwardDirections(&self.frame, direction, matrix);
        ui.drawSkeletons(&self.frame, matrix);
        self.hit_lines.draw(&self.frame, matrix);
    }
};
