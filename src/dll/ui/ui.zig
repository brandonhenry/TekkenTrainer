const std = @import("std");
const imgui = @import("imgui");
const build_info = @import("build_info");
const dll = @import("../../dll.zig");
const sdk = @import("../../sdk/root.zig");
const core = @import("../core/root.zig");
const game = @import("../game/root.zig");
const model = @import("../model/root.zig");
const ui = @import("root.zig");

pub const Ui = struct {
    is_first_draw: bool,
    is_open: bool,
    main_window: ui.MainWindow,
    settings_window: ui.SettingsWindow,
    logs_window: ui.LogsWindow,
    game_memory_window: ui.GameMemoryWindow,
    frame_window: ui.FrameWindow,
    about_window: ui.AboutWindow(.{}),
    screen_frame_data_overlay: ui.FrameDataOverlay,
    combo_suggestion_hud: ui.ComboSuggestionHud,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        var res = Self{
            .is_first_draw = true,
            .is_open = false,
            .main_window = .{},
            .settings_window = .init(allocator),
            .logs_window = .{},
            .game_memory_window = .{},
            .frame_window = .{},
            .about_window = .{},
            .screen_frame_data_overlay = .{},
            .combo_suggestion_hud = .{},
        };
        res.combo_suggestion_hud.init(allocator);
        return res;
    }

    pub fn deinit(self: *Self) void {
        self.combo_suggestion_hud.deinit();
        self.settings_window.deinit();
    }

    pub fn processFrame(self: *Self, settings: *const model.Settings, frame: *const model.Frame) void {
        self.main_window.processFrame(settings, frame);
    }

    pub fn update(self: *Self, delta_time: f32, controller: *core.Controller) void {
        self.main_window.update(delta_time, controller);
    }

    pub fn draw(
        self: *Self,
        base_dir: *const sdk.misc.BaseDir,
        file_dialog_context: *imgui.ImGuiFileDialog,
        settings: ?*model.Settings,
        game_memory: ?*const game.Memory(build_info.game),
        controller: *core.Controller,
        latest_version: ui.LatestVersion,
        memory_usage: usize,
    ) void {
        _ = build_info;
        _ = dll;
        _ = sdk;
        _ = game;

        if (self.is_first_draw) {
            self.is_first_draw = false;

            const viewport = imgui.igGetMainViewport();
            const display_size = viewport.*.WorkSize;

            imgui.igSetNextWindowPos(
                .{ .x = 0.5 * display_size.x, .y = 0.5 * display_size.y },
                imgui.ImGuiCond_FirstUseEver,
                .{ .x = 0.5, .y = 0.5 },
            );
            imgui.igSetNextWindowSize(.{ .x = 960, .y = 640 }, imgui.ImGuiCond_FirstUseEver);

            self.is_open = true;
        }

        if (imgui.igIsKeyReleased_Nil(imgui.ImGuiKey_Tab)) {
            self.is_open = !self.is_open;
        }

        const settings_val = settings orelse return;

        if (controller.getCurrentFrame()) |frame| {
            ui.drawScreenOverlay(&self.screen_frame_data_overlay, settings_val, frame);
            ui.drawLiveFrameDataHud(&settings_val.frame_data_overlay, frame);
            self.combo_suggestion_hud.draw(frame, settings_val, base_dir);
        }

        if (self.is_open) {
            self.main_window.draw(
                self,
                base_dir,
                file_dialog_context,
                controller,
                settings_val,
                latest_version,
                memory_usage,
            );
        }

        self.settings_window.draw(base_dir, settings_val);
        self.logs_window.draw(dll.buffer_logger);
        if (game_memory) |memory| {
            self.game_memory_window.draw(build_info.game, memory);
        }
        self.frame_window.draw(controller.getCurrentFrame());
        self.about_window.draw();
    }
};
