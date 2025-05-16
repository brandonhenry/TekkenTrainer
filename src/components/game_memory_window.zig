const std = @import("std");
const imgui = @import("imgui");
const game = @import("../game/root.zig");
const components = @import("root.zig");

pub fn drawGameMemoryWindow(game_memory: *const game.Memory, open: ?*bool) void {
    const is_open = imgui.igBegin("Game Memory", open, imgui.ImGuiWindowFlags_HorizontalScrollbar);
    defer imgui.igEnd();
    if (!is_open) {
        return;
    }
    components.drawData("game_memory", game_memory);
}
