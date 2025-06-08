const std = @import("std");
const imgui = @import("imgui");
const dll = @import("../dll.zig");
const components = @import("root.zig");
const game = @import("../game/root.zig");

pub const MainWindow = struct {
    logs_window: components.LogsWindow = .{},
    is_logs_window_open: bool = false,
    game_memory_window: components.GameMemoryWindow = .{},
    is_game_memory_window_open: bool = false,

    const Self = @This();

    pub fn draw(self: *Self, open: ?*bool, game_memory: *const game.Memory) void {
        self.drawChildWindows(game_memory);

        const render_content = imgui.igBegin("Irony", open, imgui.ImGuiWindowFlags_MenuBar);
        defer imgui.igEnd();
        if (!render_content) {
            return;
        }

        self.drawMenuBar();
    }

    fn drawChildWindows(self: *Self, game_memory: *const game.Memory) void {
        if (self.is_logs_window_open) {
            self.logs_window.draw(&self.is_logs_window_open, dll.buffer_logger);
        }
        if (self.is_game_memory_window_open) {
            self.game_memory_window.draw(&self.is_game_memory_window_open, game_memory);
        }
    }

    fn drawMenuBar(self: *Self) void {
        if (!imgui.igBeginMenuBar()) {
            return;
        }
        defer imgui.igEndMenuBar();

        if (imgui.igBeginMenu("Help", true)) {
            defer imgui.igEndMenu();
            if (imgui.igMenuItem_Bool("Logs", null, false, true)) {
                self.is_logs_window_open = true;
                imgui.igSetWindowFocus_Str(components.LogsWindow.name);
            }
            if (imgui.igMenuItem_Bool("Game Memory", null, false, true)) {
                self.is_game_memory_window_open = true;
                imgui.igSetWindowFocus_Str(components.GameMemoryWindow.name);
            }
        }
    }
};
