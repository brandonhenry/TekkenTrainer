const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");

pub const NavigationLayout = struct {
    navigation_width: f32 = 192,
    selected_page_index: usize = 0,

    const Self = @This();
    pub fn Page(comptime Context: type) type {
        return struct {
            name: [:0]const u8,
            content: *const fn (context: Context) void,
        };
    }

    const min_navigation_width = 64;
    const min_page_width = 64;
    const splitter_width = 8;

    pub fn draw(self: *Self, context: anytype, pages: []const Page(@TypeOf(context))) void {
        var content_size: imgui.ImVec2 = undefined;
        imgui.igGetContentRegionAvail(&content_size);
        if (imgui.igBeginChild_Str("navigation", .{ .x = self.navigation_width }, imgui.ImGuiChildFlags_Borders, 0)) {
            self.drawButtons(@TypeOf(context), pages);
        }
        imgui.igEndChild();
        imgui.igSameLine(0, 0);
        self.drawSplitter(content_size);
        imgui.igSameLine(0, 0);
        if (imgui.igBeginChild_Str("content", .{}, imgui.ImGuiChildFlags_Borders, 0)) {
            if (self.selected_page_index < pages.len) {
                pages[self.selected_page_index].content(context);
            }
        }
        imgui.igEndChild();
    }

    fn drawButtons(self: *Self, Context: type, pages: []const Page(Context)) void {
        var content_size: imgui.ImVec2 = undefined;
        imgui.igGetContentRegionAvail(&content_size);
        for (pages, 0..) |*page, index| {
            const selected = index == self.selected_page_index;
            if (selected) {
                const color = imgui.ImVec4{ .x = 0, .y = 0.4, .z = 0, .w = 1 };
                imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Button, color);
                imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_ButtonHovered, color);
                imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_ButtonActive, color);
            }
            defer if (selected) imgui.igPopStyleColor(3);
            if (imgui.igButton(page.name, .{ .x = content_size.x })) {
                self.selected_page_index = index;
            }
        }
    }

    fn drawSplitter(self: *Self, content_size: imgui.ImVec2) void {
        _ = imgui.igInvisibleButton("splitter", .{ .x = splitter_width, .y = content_size.y }, 0);
        if (imgui.igIsItemHovered(0)) {
            imgui.igSetMouseCursor(imgui.ImGuiMouseCursor_ResizeEW);
        }
        if (imgui.igIsItemActive()) {
            self.navigation_width += imgui.igGetIO_Nil().*.MouseDelta.x;
            if (self.navigation_width > content_size.x - min_page_width - splitter_width) {
                self.navigation_width = content_size.x - min_page_width - splitter_width;
            }
            if (self.navigation_width < min_navigation_width) {
                self.navigation_width = min_navigation_width;
            }
        }
    }
};

const testing = std.testing;

test "should render content of the currently selected page" {
    const Test = struct {
        var layout = NavigationLayout{};

        fn guiFunction(_: sdk.ui.TestContext) !void {
            imgui.igSetNextWindowSize(.{ .x = 400, .y = 200 }, imgui.ImGuiCond_Always);
            _ = imgui.igBegin("Window", null, 0);
            defer imgui.igEnd();
            layout.draw({}, &.{
                .{ .name = "Page 1", .content = drawPage1 },
                .{ .name = "Page 2", .content = drawPage2 },
                .{ .name = "Page 3", .content = drawPage3 },
            });
        }

        fn drawPage1(_: void) void {
            _ = imgui.igButton("Content 1", .{});
        }

        fn drawPage2(_: void) void {
            _ = imgui.igButton("Content 2", .{});
        }

        fn drawPage3(_: void) void {
            _ = imgui.igButton("Content 3", .{});
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            ctx.setRef(ctx.windowInfo("//Window/content", 0).ID);
            try ctx.expectItemExists("Content 1");

            ctx.setRef(ctx.windowInfo("//Window/navigation", 0).ID);
            ctx.itemClick("Page 2", 0, 0);
            ctx.setRef(ctx.windowInfo("//Window/content", 0).ID);
            try ctx.expectItemExists("Content 2");

            ctx.setRef(ctx.windowInfo("//Window/navigation", 0).ID);
            ctx.itemClick("Page 3", 0, 0);
            ctx.setRef(ctx.windowInfo("//Window/content", 0).ID);
            try ctx.expectItemExists("Content 3");

            ctx.setRef(ctx.windowInfo("//Window/navigation", 0).ID);
            ctx.itemClick("Page 1", 0, 0);
            ctx.setRef(ctx.windowInfo("//Window/content", 0).ID);
            try ctx.expectItemExists("Content 1");
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should pass the context to content functions" {
    const Test = struct {
        var layout = NavigationLayout{};
        var page_1_context: ?i32 = null;
        var page_2_context: ?i32 = null;
        var page_3_context: ?i32 = null;

        fn guiFunction(_: sdk.ui.TestContext) !void {
            imgui.igSetNextWindowSize(.{ .x = 400, .y = 200 }, imgui.ImGuiCond_Always);
            _ = imgui.igBegin("Window", null, 0);
            defer imgui.igEnd();
            layout.draw(@as(i32, 123), &.{
                .{ .name = "Page 1", .content = drawPage1 },
                .{ .name = "Page 2", .content = drawPage2 },
                .{ .name = "Page 3", .content = drawPage3 },
            });
        }

        fn drawPage1(context: i32) void {
            page_1_context = context;
        }

        fn drawPage2(context: i32) void {
            page_2_context = context;
        }

        fn drawPage3(context: i32) void {
            page_3_context = context;
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            ctx.setRef(ctx.windowInfo("//Window/navigation", 0).ID);
            ctx.itemClick("Page 1", 0, 0);
            try testing.expectEqual(123, page_1_context);

            ctx.setRef(ctx.windowInfo("//Window/navigation", 0).ID);
            ctx.itemClick("Page 2", 0, 0);
            try testing.expectEqual(123, page_2_context);

            ctx.setRef(ctx.windowInfo("//Window/navigation", 0).ID);
            ctx.itemClick("Page 3", 0, 0);
            try testing.expectEqual(123, page_3_context);
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}

test "should resize child windows correctly when mouse dragging the splitter" {
    const Test = struct {
        var layout = NavigationLayout{};
        var current: f32 = 0.0;

        fn guiFunction(_: sdk.ui.TestContext) !void {
            imgui.igSetNextWindowSize(.{ .x = 400, .y = 200 }, imgui.ImGuiCond_Always);
            _ = imgui.igBegin("Window", null, 0);
            defer imgui.igEnd();
            layout.draw({}, &.{
                .{ .name = "Page", .content = drawContent },
            });
        }

        fn drawContent(_: void) void {
            var size: imgui.ImVec2 = undefined;
            imgui.igGetContentRegionAvail(&size);
            current = size.x;
        }

        fn testFunction(ctx: sdk.ui.TestContext) !void {
            var last: f32 = 0;
            var delta: f32 = 0;
            ctx.setRef("Window");

            last = current;
            ctx.itemDragWithDelta("splitter", .{ .x = 10, .y = 20 });
            delta = current - last;
            try testing.expectEqual(-10, delta);

            last = current;
            ctx.itemDragWithDelta("splitter", .{ .x = -40, .y = -50 });
            delta = current - last;
            try testing.expectEqual(40, delta);
        }
    };
    const context = try sdk.ui.getTestingContext();
    try context.runTest(.{}, Test.guiFunction, Test.testFunction);
}
