const std = @import("std");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

const half_horizontal_fov: f32 = 0.5 * std.math.degreesToRadians(62.0);
const half_vertical_fov: f32 = std.math.atan((9.0 / 16.0) * std.math.tan(half_horizontal_fov));

pub fn drawIngameCamera(
    settings: *const model.IngameCameraSettings,
    frame: *const model.Frame,
    direction: ui.ViewDirection,
    matrix: sdk.math.Mat4,
) void {
    if (!settings.enabled or direction == .front) {
        return;
    }
    const camera = if (frame.camera) |*c| c else return;
    const edges = [4]sdk.math.Vec3{
        sdk.math.Vec3.fromArray(.{ 1, std.math.tan(half_horizontal_fov), std.math.tan(half_vertical_fov) }).normalize(),
        sdk.math.Vec3.fromArray(.{ 1, std.math.tan(half_horizontal_fov), -std.math.tan(half_vertical_fov) }).normalize(),
        sdk.math.Vec3.fromArray(.{ 1, -std.math.tan(half_horizontal_fov), std.math.tan(half_vertical_fov) }).normalize(),
        sdk.math.Vec3.fromArray(.{ 1, -std.math.tan(half_horizontal_fov), -std.math.tan(half_vertical_fov) }).normalize(),
    };
    for (edges) |edge| {
        const offset = edge.rotateZ(camera.yaw).rotateY(camera.pitch).rotateZ(camera.roll).scale(settings.length);
        const line = sdk.math.LineSegment3{ .point_1 = camera.position, .point_2 = camera.position.add(offset) };
        ui.drawLine(line, settings.color, settings.thickness, matrix);
    }
}
