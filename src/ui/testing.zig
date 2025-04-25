const std = @import("std");
const imgui = @import("imgui");
const testing = std.testing;

test "hello world imgui test engine" {
    const engine = imgui.teCreateContext();
    defer imgui.teDestroyContext(engine);

    const ig_context = imgui.igCreateContext(null);
    defer imgui.igDestroyContext(ig_context);

    const test_io = imgui.teGetIO(engine);
    test_io.*.ConfigVerboseLevel = imgui.ImGuiTestVerboseLevel_Info;
    test_io.*.ConfigVerboseLevelOnError = imgui.ImGuiTestVerboseLevel_Debug;

    const hello_world_test = imgui.teRegisterTest(engine, "category", "test", null, 0);
    hello_world_test.*.GuiFunc = struct {
        var b = false;
        fn call(ctx: [*c]imgui.ImGuiTestContext) callconv(.c) void {
            _ = ctx;
            _ = imgui.igBegin("Test Window", null, imgui.ImGuiWindowFlags_NoSavedSettings);
            imgui.igText("Hello, automation world");
            _ = imgui.igButton("Click Me", .{});
            if (imgui.igTreeNode_Str("Node")) {
                _ = imgui.igCheckbox("Checkbox", &b);
                imgui.igTreePop();
            }
            imgui.igEnd();
        }
    }.call;
    hello_world_test.*.TestFunc = struct {
        fn call(ctx: [*c]imgui.ImGuiTestContext) callconv(.c) void {
            imgui.ImGuiTestContext_SetRef1(ctx, path("Test Window"));
            imgui.ImGuiTestContext_ItemClick(ctx, path("Click Me"), 0, 0);
            imgui.ImGuiTestContext_ItemOpen(ctx, path("Node"), 0);
            imgui.ImGuiTestContext_ItemCheck(ctx, path("Node/Checkbox"), 0);
            imgui.ImGuiTestContext_ItemUncheck(ctx, path("Node/Checkbox"), 0);
        }
        fn path(p: [:0]const u8) imgui.ImGuiTestRef {
            return .{ .ID = 0, .Path = p };
        }
    }.call;

    imgui.teStart(engine, ig_context);
    defer imgui.teStop(engine);

    const io = imgui.igGetIO();
    io.*.IniFilename = null;

    var pixels: [*c]u8 = undefined;
    var width: c_int = undefined;
    var height: c_int = undefined;
    var bytes_per_pixel: c_int = undefined;
    _ = imgui.ImFontAtlas_GetTexDataAsRGBA32(io.*.Fonts, &pixels, &width, &height, &bytes_per_pixel);

    imgui.teQueueTest(engine, hello_world_test, 0);
    while (!imgui.teIsTestQueueEmpty(engine)) {
        io.*.DisplaySize = .{ .x = 1280, .y = 720 };
        io.*.DeltaTime = 1.0 / 60.00;

        imgui.igNewFrame();
        imgui.igRender();
        imgui.tePostSwap(engine);
    }

    var list: imgui.ImVector_ImGuiTestPtr = undefined;
    imgui.teGetTestList(engine, &list);
    for (0..@intCast(list.Size)) |i| {
        const current_test = list.Data[i].*;
        try testing.expectEqual(imgui.ImGuiTestStatus_Success, current_test.Output.Status);
    }
}
