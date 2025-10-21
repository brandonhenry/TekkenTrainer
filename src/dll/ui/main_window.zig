const std = @import("std");
const imgui = @import("imgui");
const dll = @import("../../dll.zig");
const sdk = @import("../../sdk/root.zig");
const core = @import("../core/root.zig");
const game = @import("../game/root.zig");
const model = @import("../model/root.zig");
const ui = @import("root.zig");

pub const MainWindow = struct {
    is_first_draw: bool = true,
    is_open: bool = false,
    settings_window: ui.SettingsWindow = .{},
    logs_window: ui.LogsWindow = .{},
    game_memory_window: ui.GameMemoryWindow = .{},
    frame_window: ui.FrameWindow = .{},
    quadrant_layout: ui.QuadrantLayout = .{},
    view: ui.View = .{},
    controls: ui.Controls(.{}) = .{},
    controls_height: f32 = 0,
    is_exit_confirm_open: bool = false,

    const Self = @This();
    const QuadrantContext = struct {
        self: *Self,
        settings: *const model.Settings,
        frame: ?*const model.Frame,
    };

    pub fn processFrame(self: *Self, settings: *const model.Settings, frame: *const model.Frame) void {
        self.view.processFrame(settings, frame);
    }

    pub fn update(self: *Self, delta_time: f32) void {
        self.view.update(delta_time);
    }

    pub fn draw(
        self: *Self,
        base_dir: *const sdk.fs.BaseDir,
        settings: *model.Settings,
        game_memory: *const game.Memory,
        controller: *core.Controller,
    ) void {
        self.handleFirstDraw();
        self.handleOpenKey();
        self.controls.handleKeybinds(controller);
        if (!self.is_open) {
            return;
        }
        self.drawSecondaryWindows(base_dir, settings, game_memory, controller);
        const render_content = imgui.igBegin("Irony", &self.is_open, imgui.ImGuiWindowFlags_MenuBar);
        defer imgui.igEnd();
        if (!render_content) {
            return;
        }
        self.drawMenuBar();
        if (imgui.igBeginChild_Str("views", .{ .x = 0, .y = -self.controls_height }, 0, 0)) {
            const context = QuadrantContext{
                .self = self,
                .settings = settings,
                .frame = controller.getCurrentFrame(),
            };
            self.quadrant_layout.draw(context, &.{
                .top_left = .{ .id = "front", .content = drawFrontView, .window_flags = imgui.ImGuiWindowFlags_NoMove },
                .top_right = .{ .id = "side", .content = drawSideView, .window_flags = imgui.ImGuiWindowFlags_NoMove },
                .bottom_left = .{ .id = "top", .content = drawTopView, .window_flags = imgui.ImGuiWindowFlags_NoMove },
                .bottom_right = .{ .id = "details", .content = drawDetails },
            });
        }
        imgui.igEndChild();
        if (imgui.igBeginChild_Str("controls", .{ .x = 0, .y = 0 }, 0, 0)) {
            const controls_start_y = imgui.igGetCursorPosY();
            self.controls.draw(controller);
            self.controls_height = imgui.igGetCursorPosY() - controls_start_y;
        }
        imgui.igEndChild();
    }

    fn handleFirstDraw(self: *Self) void {
        if (!self.is_first_draw) {
            return;
        }
        sdk.ui.toasts.send(.success, null, "Irony initialized. Press [Tab] to open the Irony window.", .{});
        self.is_first_draw = false;
    }

    fn handleOpenKey(self: *Self) void {
        if (imgui.igIsKeyPressed_Bool(imgui.ImGuiKey_Tab, false)) {
            self.is_open = !self.is_open;
        }
    }

    fn drawSecondaryWindows(
        self: *Self,
        base_dir: *const sdk.fs.BaseDir,
        settings: *model.Settings,
        game_memory: *const game.Memory,
        controller: *const core.Controller,
    ) void {
        self.settings_window.draw(base_dir, settings);
        self.logs_window.draw(dll.buffer_logger);
        self.game_memory_window.draw(game_memory);
        self.frame_window.draw(controller.getCurrentFrame());
    }

    fn drawMenuBar(self: *Self) void {
        if (!imgui.igBeginMenuBar()) {
            return;
        }
        defer imgui.igEndMenuBar();

        var exit_irony_clicked = false;
        if (imgui.igBeginMenu("File", true)) {
            defer imgui.igEndMenu();
            if (imgui.igMenuItem_Bool("New", null, false, true)) {
                // TODO implement
            }
            if (imgui.igMenuItem_Bool("Open", null, false, true)) {
                // TODO implement
            }
            if (imgui.igMenuItem_Bool("Save", null, false, true)) {
                // TODO implement
            }
            if (imgui.igMenuItem_Bool("Save As", null, false, true)) {
                // TODO implement
            }
            imgui.igSeparator();
            if (imgui.igMenuItem_Bool("Close Window", null, false, true)) {
                self.is_open = false;
                sdk.ui.toasts.send(.default, null, "Main window closed. Press [Tab] to open it again.", .{});
            }
            exit_irony_clicked = imgui.igMenuItem_Bool("Exit Irony", null, false, true);
        }

        if (exit_irony_clicked) {
            self.is_exit_confirm_open = true;
            imgui.igOpenPopup_Str("Exit Irony?", 0);
        }
        if (imgui.igBeginPopupModal("Exit Irony?", &self.is_exit_confirm_open, imgui.ImGuiWindowFlags_AlwaysAutoResize)) {
            defer imgui.igEndPopup();
            imgui.igText("Are you sure you want to exit from Irony?");
            imgui.igText("This will remove Irony from the game process.");
            imgui.igText("Any recorded data that is not saved will be lost.");
            imgui.igSeparator();
            if (imgui.igButton("Exit", .{})) {
                dll.selfEject();
                imgui.igCloseCurrentPopup();
            }
            imgui.igSameLine(0, -1);
            imgui.igSetItemDefaultFocus();
            if (imgui.igButton("Cancel", .{})) {
                imgui.igCloseCurrentPopup();
            }
        }

        if (imgui.igBeginMenu("Camera", true)) {
            defer imgui.igEndMenu();
            self.view.camera.drawMenuBar();
        }

        if (imgui.igMenuItem_Bool(ui.SettingsWindow.name, null, false, true)) {
            self.settings_window.is_open = !self.settings_window.is_open;
            if (self.settings_window.is_open) {
                imgui.igSetWindowFocus_Str(ui.SettingsWindow.name);
            }
        }

        if (imgui.igBeginMenu("Help", true)) {
            defer imgui.igEndMenu();
            if (imgui.igMenuItem_Bool(ui.LogsWindow.name, null, false, true)) {
                self.logs_window.is_open = true;
                imgui.igSetWindowFocus_Str(ui.LogsWindow.name);
            }
            if (imgui.igMenuItem_Bool(ui.GameMemoryWindow.name, null, false, true)) {
                self.game_memory_window.is_open = true;
                imgui.igSetWindowFocus_Str(ui.GameMemoryWindow.name);
            }
            if (imgui.igMenuItem_Bool(ui.FrameWindow.name, null, false, true)) {
                self.frame_window.is_open = true;
                imgui.igSetWindowFocus_Str(ui.FrameWindow.name);
            }
        }
    }

    fn drawFrontView(context: QuadrantContext) void {
        const frame = context.frame orelse return;
        context.self.view.draw(context.settings, frame, .front);
    }

    fn drawSideView(context: QuadrantContext) void {
        const frame = context.frame orelse return;
        context.self.view.draw(context.settings, frame, .side);
    }

    fn drawTopView(context: QuadrantContext) void {
        const frame = context.frame orelse return;
        context.self.view.draw(context.settings, frame, .top);
    }

    fn drawDetails(context: QuadrantContext) void {
        const frame = context.frame orelse return;
        ui.drawDetails(frame, context.settings.misc.details_columns);
    }
};
