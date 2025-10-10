const std = @import("std");
const imgui = @import("imgui");
const model = @import("../model/root.zig");
const ui = @import("root.zig");

pub const SettingsWindow = struct {
    is_open: bool = false,
    navigation_layout: ui.NavigationLayout = .{},

    const Self = @This();
    pub const name = "Settings";

    pub fn draw(self: *Self, settings: *model.Settings) void {
        if (!self.is_open) {
            return;
        }
        const render_content = imgui.igBegin(name, &self.is_open, imgui.ImGuiWindowFlags_HorizontalScrollbar);
        defer imgui.igEnd();
        if (!render_content) {
            return;
        }
        self.navigation_layout.draw(settings, &.{
            .{
                .name = "Page 1",
                .content = struct {
                    fn call(_: *model.Settings) void {
                        imgui.igText("Page 1....");
                    }
                }.call,
            },
            .{
                .name = "Page 2",
                .content = struct {
                    fn call(_: *model.Settings) void {
                        imgui.igText("Page 2....");
                    }
                }.call,
            },
            .{
                .name = "Page 3",
                .content = struct {
                    fn call(_: *model.Settings) void {
                        imgui.igText("Page 3....");
                    }
                }.call,
            },
        });
    }
};
