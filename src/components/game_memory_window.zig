const std = @import("std");
const imgui = @import("imgui");
const game = @import("../game/root.zig");
const components = @import("root.zig");

pub fn drawGameMemoryWindow(open: ?*bool, game_memory: *const game.Memory) void {
    const render_content = imgui.igBegin("Game Memory", open, imgui.ImGuiWindowFlags_HorizontalScrollbar);
    defer imgui.igEnd();
    if (!render_content) {
        return;
    }
    components.drawData("game_memory", game_memory);
}
