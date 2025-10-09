const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

pub fn drawCollisionSpheres(
    settings: *const model.PlayerSettings(model.CollisionSpheresSettings),
    frame: *const model.Frame,
    matrix: sdk.math.Mat4,
    inverse_matrix: sdk.math.Mat4,
) void {
    for (model.PlayerId.all) |player_id| {
        const player_settings = settings.getById(frame, player_id);
        if (!player_settings.enabled) {
            continue;
        }
        const player = frame.getPlayerById(player_id);
        const spheres: *const model.CollisionSpheres = if (player.collision_spheres) |*s| s else continue;
        for (spheres.values) |sphere| {
            ui.drawSphere(sphere, player_settings.color, player_settings.thickness, matrix, inverse_matrix);
        }
    }
}
