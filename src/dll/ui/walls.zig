const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

pub fn drawWalls(
    frame: *const model.Frame,
    direction: ui.ViewDirection,
    matrix: sdk.math.Mat4,
) void {
    if (direction != .top) {
        return;
    }
    const color = sdk.math.Vec4.fromArray(.{ 0, 1, 0, 1 });
    const thickness = 1;
    const floor_z = frame.floor_z orelse 0;
    const walls: []const model.Wall = frame.walls.asSlice();
    for (walls) |*wall| {
        const half_size = wall.half_size;
        const rotation = wall.rotation;
        const angle_1 = std.math.atan2(half_size.y(), half_size.x()) + rotation;
        const angle_2 = std.math.atan2(half_size.y(), -half_size.x()) + rotation;
        const angle_3 = std.math.atan2(-half_size.y(), -half_size.x()) + rotation;
        const angle_4 = std.math.atan2(-half_size.y(), half_size.x()) + rotation;
        const direction_1 = sdk.math.Vec2.plus_x.rotateZ(angle_1);
        const direction_2 = sdk.math.Vec2.plus_x.rotateZ(angle_2);
        const direction_3 = sdk.math.Vec2.plus_x.rotateZ(angle_3);
        const direction_4 = sdk.math.Vec2.plus_x.rotateZ(angle_4);
        const center = wall.center;
        const half_diagonal = half_size.length();
        const point_1 = center.add(direction_1.scale(half_diagonal)).extend(floor_z);
        const point_2 = center.add(direction_2.scale(half_diagonal)).extend(floor_z);
        const point_3 = center.add(direction_3.scale(half_diagonal)).extend(floor_z);
        const point_4 = center.add(direction_4.scale(half_diagonal)).extend(floor_z);
        const line_1 = sdk.math.LineSegment3{ .point_1 = point_1, .point_2 = point_2 };
        const line_2 = sdk.math.LineSegment3{ .point_1 = point_2, .point_2 = point_3 };
        const line_3 = sdk.math.LineSegment3{ .point_1 = point_3, .point_2 = point_4 };
        const line_4 = sdk.math.LineSegment3{ .point_1 = point_4, .point_2 = point_1 };
        ui.drawLine(line_1, color, thickness, matrix);
        ui.drawLine(line_2, color, thickness, matrix);
        ui.drawLine(line_3, color, thickness, matrix);
        ui.drawLine(line_4, color, thickness, matrix);
    }
}
