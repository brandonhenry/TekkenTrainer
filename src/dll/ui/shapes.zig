const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const ui = @import("../ui/root.zig");

pub fn drawLine(
    line: sdk.math.LineSegment3,
    color: sdk.math.Vec4,
    thickness: f32,
    matrix: sdk.math.Mat4,
) void {
    const draw_list = imgui.igGetWindowDrawList();
    const point_1 = line.point_1.pointTransform(matrix).swizzle("xy").toImVec();
    const point_2 = line.point_2.pointTransform(matrix).swizzle("xy").toImVec();
    const u32_color = imgui.igGetColorU32_Vec4(color.toImVec());

    imgui.ImDrawList_AddLine(draw_list, point_1, point_2, u32_color, thickness);
}

pub fn drawSphere(
    sphere: sdk.math.Sphere,
    color: sdk.math.Vec4,
    thickness: f32,
    matrix: sdk.math.Mat4,
    inverse_matrix: sdk.math.Mat4,
) void {
    const world_right = sdk.math.Vec3.plus_x.directionTransform(inverse_matrix).normalize();
    const world_up = sdk.math.Vec3.plus_y.directionTransform(inverse_matrix).normalize();

    const draw_list = imgui.igGetWindowDrawList();
    const center = sphere.center.pointTransform(matrix).swizzle("xy").toImVec();
    const radius = world_up.add(world_right).scale(sphere.radius).directionTransform(matrix).swizzle("xy").toImVec();
    const u32_color = imgui.igGetColorU32_Vec4(color.toImVec());

    imgui.ImDrawList_AddEllipse(draw_list, center, radius, u32_color, 0, 32, thickness);
}

pub fn drawCylinder(
    cylinder: sdk.math.Cylinder,
    color: sdk.math.Vec4,
    thickness: f32,
    direction: ui.ViewDirection,
    matrix: sdk.math.Mat4,
    inverse_matrix: sdk.math.Mat4,
) void {
    const world_right = sdk.math.Vec3.plus_x.directionTransform(inverse_matrix).normalize();
    const world_up = sdk.math.Vec3.plus_y.directionTransform(inverse_matrix).normalize();

    const draw_list = imgui.igGetWindowDrawList();
    const center = cylinder.center.pointTransform(matrix).swizzle("xy");
    const u32_color = imgui.igGetColorU32_Vec4(color.toImVec());

    switch (direction) {
        .front, .side => {
            const half_size = world_up.scale(cylinder.half_height)
                .add(world_right.scale(cylinder.radius))
                .directionTransform(matrix)
                .swizzle("xy");
            const min = center.subtract(half_size).toImVec();
            const max = center.add(half_size).toImVec();
            imgui.ImDrawList_AddRect(draw_list, min, max, u32_color, 0, 0, thickness);
        },
        .top => {
            const im_center = center.toImVec();
            const radius = world_up
                .add(world_right)
                .scale(cylinder.radius)
                .directionTransform(matrix)
                .swizzle("xy")
                .toImVec();
            imgui.ImDrawList_AddEllipse(draw_list, im_center, radius, u32_color, 0, 32, thickness);
        },
    }
}

pub fn drawFloor(
    floor_z: f32,
    color: sdk.math.Vec4,
    thickness: f32,
    direction: ui.ViewDirection,
    matrix: sdk.math.Mat4,
) void {
    if (direction == .top) {
        return;
    }

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
