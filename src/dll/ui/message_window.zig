const std = @import("std");
const builtin = @import("builtin");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");

pub const MessageWindowPlacement = enum {
    top,
    center,
    bottom,
};

pub fn drawMessageWindow(
    id: [:0]const u8,
    message: [:0]const u8,
    placement: MessageWindowPlacement,
    focus: bool,
) void {
    const display_size = imgui.igGetIO_Nil().*.DisplaySize;
    var message_size: imgui.ImVec2 = undefined;
    imgui.igCalcTextSize(&message_size, message, null, false, -1.0);
    const window_size = imgui.ImVec2{
        .x = message_size.x + (2 * imgui.igGetStyle().*.WindowPadding.x + imgui.igGetStyle().*.WindowBorderSize),
        .y = message_size.y + (2 * imgui.igGetStyle().*.WindowPadding.y + imgui.igGetStyle().*.WindowBorderSize),
    };
    const window_position = imgui.ImVec2{
        .x = 0.5 * display_size.x - 0.5 * window_size.x,
        .y = switch (placement) {
            .top => 0,
            .center => 0.5 * display_size.y - 0.5 * window_size.y,
            .bottom => display_size.y - window_size.y,
        },
    };

    var window_flags = imgui.ImGuiWindowFlags_AlwaysAutoResize |
        imgui.ImGuiWindowFlags_NoDecoration |
        imgui.ImGuiWindowFlags_NoInputs |
        imgui.ImGuiWindowFlags_NoSavedSettings;
    if (!focus) {
        window_flags |= imgui.ImGuiWindowFlags_NoFocusOnAppearing;
        window_flags |= imgui.ImGuiWindowFlags_NoBringToFrontOnFocus;
    }
    imgui.igSetNextWindowPos(window_position, imgui.ImGuiCond_Always, .{});
    imgui.igSetNextWindowSize(window_size, imgui.ImGuiCond_Always);

    const is_open = imgui.igBegin(id, null, window_flags);
    defer imgui.igEnd();
    if (!is_open) {
        return;
    }

    drawText(message);
}

fn drawText(text: [:0]const u8) void {
    imgui.igText("%s", text.ptr);
    if (builtin.is_test) {
        var rect: imgui.ImRect = undefined;
        imgui.igGetItemRectMin(&rect.Min);
        imgui.igGetItemRectMax(&rect.Max);
        imgui.teItemAdd(imgui.igGetCurrentContext(), imgui.igGetID_Str(text), &rect, null);
    }
}

const testing = std.testing;

test "should draw correct message inside correct window" {
    const Test = struct {
        fn guiFunction(_: sdk.ui.TestContext) !void {
            drawMessageWindow("Message Window", "Message.", .center, false);
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            ctx.setRef("Message Window");
            try ctx.expectItemExists("Message.");
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should draw window on correct position when placement is top" {
    const Test = struct {
        fn guiFunction(_: sdk.ui.TestContext) !void {
            drawMessageWindow("Message Window", "Message.", .top, false);
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            const display_size = imgui.igGetIO_Nil().*.DisplaySize;
            const display_top_center = imgui.ImVec2{
                .x = 0.5 * display_size.x,
                .y = 0,
            };
            const window_info = ctx.windowInfo("Message Window", 0);
            const window_top_center = imgui.ImVec2{
                // I have no idea why X and Y are swapped inside RectFull.
                .x = 0.5 * (window_info.RectFull.Min.y + window_info.RectFull.Max.y),
                .y = window_info.RectFull.Min.x,
            };
            try testing.expectApproxEqAbs(display_top_center.x, window_top_center.x, 1);
            try testing.expectApproxEqAbs(display_top_center.y, window_top_center.y, 1);
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should draw window on correct position when placement is center" {
    const Test = struct {
        fn guiFunction(_: sdk.ui.TestContext) !void {
            drawMessageWindow("Message Window", "Message.", .center, false);
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            const display_size = imgui.igGetIO_Nil().*.DisplaySize;
            const display_center = imgui.ImVec2{
                .x = 0.5 * display_size.x,
                .y = 0.5 * display_size.y,
            };
            const window_info = ctx.windowInfo("Message Window", 0);
            const window_center = imgui.ImVec2{
                // I have no idea why X and Y are swapped inside RectFull.
                .x = 0.5 * (window_info.RectFull.Min.y + window_info.RectFull.Max.y),
                .y = 0.5 * (window_info.RectFull.Min.x + window_info.RectFull.Max.x),
            };
            try testing.expectApproxEqAbs(display_center.x, window_center.x, 1);
            try testing.expectApproxEqAbs(display_center.y, window_center.y, 1);
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should draw window on correct position when placement is bottom" {
    const Test = struct {
        fn guiFunction(_: sdk.ui.TestContext) !void {
            drawMessageWindow("Message Window", "Message.", .bottom, false);
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            const display_size = imgui.igGetIO_Nil().*.DisplaySize;
            const display_bottom_center = imgui.ImVec2{
                .x = 0.5 * display_size.x,
                .y = display_size.y,
            };
            const window_info = ctx.windowInfo("Message Window", 0);
            const window_bottom_center = imgui.ImVec2{
                // I have no idea why X and Y are swapped inside RectFull.
                .x = 0.5 * (window_info.RectFull.Min.y + window_info.RectFull.Max.y),
                .y = window_info.RectFull.Max.x,
            };
            try testing.expectApproxEqAbs(display_bottom_center.x, window_bottom_center.x, 1);
            try testing.expectApproxEqAbs(display_bottom_center.y, window_bottom_center.y, 1);
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should not focus the message window when focus is false" {
    const Test = struct {
        var message_window_open = false;

        fn guiFunction(_: sdk.ui.TestContext) !void {
            {
                _ = imgui.igBegin("Window", null, 0);
                defer imgui.igEnd();
                if (imgui.igButton("Button", .{})) {
                    message_window_open = true;
                }
            }
            if (message_window_open) {
                drawMessageWindow("Message Window", "Message.", .center, false);
            }
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            ctx.setRef("Window");
            ctx.itemClick("Button", imgui.ImGuiMouseButton_Left, 0);
            ctx.setRef("//$FOCUSED");
            try ctx.expectItemNotExists("Message.");
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should focus the message window when focus is true" {
    const Test = struct {
        var message_window_open = false;

        fn guiFunction(_: sdk.ui.TestContext) !void {
            {
                _ = imgui.igBegin("Window", null, 0);
                defer imgui.igEnd();
                if (imgui.igButton("Button", .{})) {
                    message_window_open = true;
                }
            }
            if (message_window_open) {
                drawMessageWindow("Message Window", "Message.", .center, true);
            }
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            ctx.setRef("Window");
            ctx.itemClick("Button", imgui.ImGuiMouseButton_Left, 0);
            ctx.setRef("//$FOCUSED");
            try ctx.expectItemExists("Message.");
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}
