const std = @import("std");
const builtin = @import("builtin");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

pub fn drawFloor(
    settings: *const model.FloorSettings,
    frame: *const model.Frame,
    direction: ui.ViewDirection,
    matrix: sdk.math.Mat4,
) void {
    if (!settings.enabled or direction == .top) {
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
    const point_1 = sdk.math.Vec2.fromArray(.{ screen_x, screen_y });
    const point_2 = sdk.math.Vec2.fromArray(.{ screen_x + screen_w, screen_y });
    const color_u32 = imgui.igGetColorU32_Vec4(settings.color.toImVec());

    imgui.ImDrawList_AddLine(draw_list, point_1.toImVec(), point_2.toImVec(), color_u32, settings.thickness);
    if (builtin.is_test) {
        ui.testing_shapes.append(.{ .line = .{
            .world_line = .{ .point_1 = .fromArray(.{ 0, 0, floor_z }), .point_2 = .fromArray(.{ 0, 0, floor_z }) },
            .screen_line = .{ .point_1 = point_1, .point_2 = point_2 },
            .color = settings.color,
            .thickness = settings.thickness,
        } });
    }
}

const testing = std.testing;

test "should draw line correctly when direction not top" {
    const Test = struct {
        const settings = model.FloorSettings{
            .enabled = true,
            .color = .fromArray(.{ 0.1, 0.2, 0.3, 0.4 }),
            .thickness = 1,
        };
        const frame = model.Frame{ .floor_z = 25 };
        var window_pos: sdk.math.Vec2 = undefined;
        var window_size: sdk.math.Vec2 = undefined;

        fn guiFunction(_: sdk.ui.TestContext) !void {
            ui.testing_shapes.clear();
            imgui.igSetNextWindowSize(.{ .x = 400, .y = 200 }, imgui.ImGuiCond_Always);
            _ = imgui.igBegin("Window", null, 0);
            defer imgui.igEnd();
            imgui.igGetCursorScreenPos(window_pos.asImVec());
            imgui.igGetContentRegionAvail(window_size.asImVec());
            const matrix = sdk.math.Mat4.identity
                .lookAt(.fromArray(.{ 0, 0, 50 }), .fromArray(.{ 1, 0, 50 }), .plus_z)
                .orthographic(-50, 50, -50, 50, -1000, 1000)
                .scale(window_size.scale(-0.5).extend(1))
                .translate(window_size.scale(0.5).add(window_pos).extend(0));
            drawFloor(&settings, &frame, .front, matrix);
        }

        fn testFunction(_: sdk.ui.TestContext) !void {
            const shapes = ui.testing_shapes.getAll();
            try testing.expectEqual(1, shapes.len);
            try testing.expect(shapes[0] == .line);
            const line = shapes[0].line;
            const point_1 = line.screen_line.point_1;
            const point_2 = line.screen_line.point_2;

            const expected_y = window_pos.y() + 0.75 * window_size.y();
            try testing.expectEqual(expected_y, point_1.y());
            try testing.expectEqual(expected_y, point_2.y());

            const min_expected_x = window_pos.x();
            const max_expected_x = window_pos.x() + window_size.x();
            if (point_1.x() < point_2.x()) {
                try testing.expectEqual(min_expected_x, point_1.x());
                try testing.expectEqual(max_expected_x, point_2.x());
            } else {
                try testing.expectEqual(max_expected_x, point_1.x());
                try testing.expectEqual(min_expected_x, point_2.x());
            }

            try testing.expectEqual(.{ 0.1, 0.2, 0.3, 0.4 }, line.color.array);
            try testing.expectEqual(1, line.thickness);
        }
    };
    ui.testing_shapes.begin(testing.allocator);
    defer ui.testing_shapes.end();
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should draw nothing when direction is top" {
    const Test = struct {
        const settings = model.FloorSettings{ .enabled = true };
        const frame = model.Frame{ .floor_z = 25 };

        fn guiFunction(_: sdk.ui.TestContext) !void {
            ui.testing_shapes.clear();
            _ = imgui.igBegin("Window", null, 0);
            defer imgui.igEnd();
            drawFloor(&settings, &frame, .top, .identity);
        }

        fn testFunction(_: sdk.ui.TestContext) !void {
            try testing.expectEqual(0, ui.testing_shapes.getAll().len);
        }
    };
    ui.testing_shapes.begin(testing.allocator);
    defer ui.testing_shapes.end();
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should draw nothing when disabled in settings" {
    const Test = struct {
        const settings = model.FloorSettings{ .enabled = false };
        const frame = model.Frame{ .floor_z = 25 };

        fn guiFunction(_: sdk.ui.TestContext) !void {
            ui.testing_shapes.clear();
            _ = imgui.igBegin("Window", null, 0);
            defer imgui.igEnd();
            drawFloor(&settings, &frame, .front, .identity);
        }

        fn testFunction(_: sdk.ui.TestContext) !void {
            try testing.expectEqual(0, ui.testing_shapes.getAll().len);
        }
    };
    ui.testing_shapes.begin(testing.allocator);
    defer ui.testing_shapes.end();
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}
