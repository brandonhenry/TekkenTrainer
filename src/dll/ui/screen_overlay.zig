const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("root.zig");

const half_horizontal_fov: f32 = 0.5 * std.math.degreesToRadians(62.0);
const half_vertical_fov: f32 = std.math.atan((9.0 / 16.0) * std.math.tan(half_horizontal_fov));

pub fn drawScreenOverlay(
    overlay: *ui.FrameDataOverlay,
    settings: *const model.Settings,
    frame: *const model.Frame,
) void {
    if (!settings.frame_data_overlay.screen_overlay_enabled) return;
    const camera = frame.camera orelse return;

    const display_size = imgui.igGetIO_Nil().*.DisplaySize;
    if (display_size.x <= 0 or display_size.y <= 0) return;

    const aspect_ratio = display_size.x / display_size.y;
    // vertical_tan = horizontal_tan / aspect_ratio
    const vertical_fov = 2.0 * std.math.atan(std.math.tan(half_horizontal_fov) / aspect_ratio);

    // Projection matrix
    const projection = sdk.math.Mat4.fromPerspective(vertical_fov, aspect_ratio, 10.0, 100000.0);

    // Basis vectors for camera (Tekken X-Forward, Y-Left, Z-Up)
    // Following ingame_camera.zig rotation order: Yaw(Z) -> Pitch(Y) -> Roll(Z)
    const fwd = sdk.math.Vec3.fromArray(.{ 1, 0, 0 })
        .rotateZ(camera.yaw)
        .rotateY(camera.pitch)
        .rotateZ(camera.roll);

    const up = sdk.math.Vec3.fromArray(.{ 0, 0, 1 })
        .rotateZ(camera.yaw)
        .rotateY(camera.pitch)
        .rotateZ(camera.roll);

    const target = camera.position.add(fwd);
    const view = sdk.math.Mat4.fromLookAt(camera.position, target, up);

    // Coordinate system correction: Map from NDC (-1 to 1) to screen (0 to width, 0 to height).
    const ndc_to_screen = sdk.math.Mat4.fromArray(.{
        .{ 0.5 * display_size.x, 0.0, 0.0, 0.0 },
        .{ 0.0, -0.5 * display_size.y, 0.0, 0.0 }, // Flip Y
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.5 * display_size.x, 0.5 * display_size.y, 0.0, 1.0 },
    });

    // V' = V * View * Projection * NDC
    const matrix = view.multiply(projection).multiply(ndc_to_screen);

    overlay.draw(
        &settings.frame_data_overlay,
        frame,
        matrix,
        imgui.igGetForegroundDrawList_Nil(),
    );
}
