const std = @import("std");
const imgui = @import("imgui");
const dll = @import("../dll.zig");
const components = @import("root.zig");
const game = @import("../game/root.zig");

pub const MainWindow = struct {
    logs_window: components.LogsWindow = .{},
    is_logs_window_open: bool = false,
    is_game_memory_window_open: bool = false,

    const Self = @This();

    pub fn draw(self: *Self, open: ?*bool, game_memory: *const game.Memory) void {
        if (self.is_logs_window_open) {
            self.logs_window.draw(&self.is_logs_window_open, dll.buffer_logger);
        }
        if (self.is_game_memory_window_open) {
            components.drawGameMemoryWindow(&self.is_game_memory_window_open, game_memory);
        }
        const render_content = imgui.igBegin("Irony", open, imgui.ImGuiWindowFlags_HorizontalScrollbar);
        defer imgui.igEnd();
        if (!render_content) {
            return;
        }
        if (imgui.igButton("Open Logs", .{})) {
            self.is_logs_window_open = true;
        }
        if (imgui.igButton("Open Game Memory", .{})) {
            self.is_game_memory_window_open = true;
        }
    }
};
