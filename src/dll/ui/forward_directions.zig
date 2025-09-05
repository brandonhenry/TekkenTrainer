const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

const color = sdk.math.Vec4.fromArray(.{ 1.0, 0.0, 1.0, 1.0 });
const length = 100.0;
const thickness = 1.0;

pub fn drawForwardDirections(frame: *const model.Frame, direction: ui.ViewDirection, matrix: sdk.math.Mat4) void {
    if (direction != .top) {
        return;
    }
    for (&frame.players) |*player| {
        const position = player.position orelse continue;
        const rotation = player.rotation orelse continue;
        const delta = sdk.math.Vec3.plus_x.scale(length).rotateZ(rotation);
        const line = sdk.math.LineSegment3{
            .point_1 = position,
            .point_2 = position.add(delta),
        };
        ui.drawLine(line, color, thickness, matrix);
    }
}
