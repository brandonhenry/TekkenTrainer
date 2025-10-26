const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

pub fn drawForwardDirections(
    settings: *const model.PlayerSettings(model.ForwardDirectionSettings),
    frame: *const model.Frame,
    direction: ui.ViewDirection,
    matrix: sdk.math.Mat4,
) void {
    if (direction != .top) {
        return;
    }
    for (model.PlayerId.all) |player_id| {
        const player_settings = settings.getById(frame, player_id);
        if (!player_settings.enabled) {
            continue;
        }
        const player = frame.getPlayerById(player_id);
        const position = player.getPosition() orelse continue;
        const rotation = player.rotation orelse continue;
        const delta = sdk.math.Vec3.plus_x.scale(player_settings.length).rotateZ(rotation);
        const line = sdk.math.LineSegment3{
            .point_1 = position,
            .point_2 = position.add(delta),
        };
        ui.drawLine(line, player_settings.color, player_settings.thickness, matrix);
    }
}
