const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

const color = sdk.math.Vec4.fromArray(.{ 0.0, 1.0, 0.0, 1.0 });
const thickness = 1.0;

pub fn drawFloor(frame: *const model.Frame, direction: ui.ViewDirection, matrix: sdk.math.Mat4) void {
    if (direction == .top) {
        return;
    }
    const floor_z = frame.floor_z orelse return;

    var window_pos: sdk.math.Vec2 = undefined;
    imgui.igGetCursorScreenPos(window_pos.asImVec());
    var window_size: sdk.math.Vec2 = undefined;
    imgui.igGetContentRegionAvail(window_size.asImVec());

    const screen_x = window_pos.toCoords().x;
    const screen_w = window_size.toCoords().x;
    const screen_y = sdk.math.Vec3.plus_z.scale(floor_z).pointTransform(matrix).toCoords().y;

    const draw_list = imgui.igGetWindowDrawList();
    const point_1 = sdk.math.Vec2.fromArray(.{ screen_x, screen_y }).toImVec();
    const point_2 = sdk.math.Vec2.fromArray(.{ screen_x + screen_w, screen_y }).toImVec();
    const u32_color = imgui.igGetColorU32_Vec4(color.toImVec());

    imgui.ImDrawList_AddLine(draw_list, point_1, point_2, u32_color, thickness);
}
