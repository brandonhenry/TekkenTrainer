const std = @import("std");
const imgui = @import("imgui");
const game = @import("../game/root.zig");
const components = @import("root.zig");

pub const GameMemoryWindow = struct {
    const Self = @This();
    pub const name = "Game Memory";

    pub fn draw(_: *Self, open: ?*bool, game_memory: *const game.Memory) void {
        const render_content = imgui.igBegin(name, open, imgui.ImGuiWindowFlags_HorizontalScrollbar);
        defer imgui.igEnd();
        if (!render_content) {
            return;
        }
        components.drawData("game_memory", game_memory);
    }
};
