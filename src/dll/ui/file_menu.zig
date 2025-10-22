const std = @import("std");
const imgui = @import("imgui");
const dll = @import("../../dll.zig");
const sdk = @import("../../sdk/root.zig");
const core = @import("../core/root.zig");

pub const FileMenu = struct {
    file_path_buffer: [sdk.os.max_file_path_length:0]u8 = [1:0]u8{0} ** sdk.os.max_file_path_length,
    file_path_len: usize = 0,
    is_file_changed: bool = false,
    is_new_confirm_open: bool = false,
    is_exit_confirm_open: bool = false,

    const Self = @This();

    pub fn draw(
        self: *Self,
        base_dir: *const sdk.fs.BaseDir,
        is_main_window_open: *bool,
        file_dialog_context: *imgui.ImGuiFileDialog,
        controller: *core.Controller,
    ) void {
        const display_size = imgui.igGetIO_Nil().*.DisplaySize;

        var new_clicked = false;
        var open_clicked = false;
        var save_as_clicked = false;
        var close_clicked = false;
        var exit_irony_clicked = false;
        if (imgui.igBeginMenu("File", true)) {
            defer imgui.igEndMenu();
            new_clicked = imgui.igMenuItem_Bool("New", null, false, true);
            open_clicked = imgui.igMenuItem_Bool("Open", null, false, true);
            save_as_clicked = imgui.igMenuItem_Bool("Save", null, false, true);
            save_as_clicked = imgui.igMenuItem_Bool("Save As", null, false, true);
            imgui.igSeparator();
            close_clicked = imgui.igMenuItem_Bool("Close Window", null, false, true);
            exit_irony_clicked = imgui.igMenuItem_Bool("Exit Irony", null, false, true);
        }

        if (new_clicked) {
            self.is_new_confirm_open = true;
            imgui.igOpenPopup_Str("New?", 0);
        }
        if (imgui.igBeginPopupModal(
            "New?",
            &self.is_new_confirm_open,
            imgui.ImGuiWindowFlags_AlwaysAutoResize,
        )) {
            defer imgui.igEndPopup();
            imgui.igText("Are you sure you want to start a new recording?");
            imgui.igText("Any recorded data that is not saved will be lost.");
            imgui.igSeparator();
            if (imgui.igButton("New", .{})) {
                controller.clear();
                sdk.ui.toasts.send(.success, null, "New recording started.", .{});
                imgui.igCloseCurrentPopup();
            }
            imgui.igSameLine(0, -1);
            imgui.igSetItemDefaultFocus();
            if (imgui.igButton("Cancel", .{})) {
                imgui.igCloseCurrentPopup();
            }
        }

        if (open_clicked) {
            var config = imgui.IGFD_FileDialog_Config_Get();
            config.path = base_dir.get();
            config.countSelectionMax = 1;
            imgui.IGFD_OpenDialog(
                file_dialog_context,
                "open_dialog",
                "Open",
                "irony recordings (*.irony){.irony}",
                config,
            );
        }
        if (imgui.IGFD_DisplayDialog(
            file_dialog_context,
            "open_dialog",
            imgui.ImGuiWindowFlags_NoCollapse,
            .{ .x = 0.5 * display_size.x, .y = 0.5 * display_size.y },
            .{ .x = 0.5 * display_size.x, .y = 0.5 * display_size.y },
        )) {
            if (imgui.IGFD_IsOk(file_dialog_context)) {
                const path_maybe = imgui.IGFD_GetFilePathName(file_dialog_context, imgui.IGFD_ResultMode_AddIfNoFileExt);
                defer std.c.free(path_maybe);
                if (path_maybe) |path| {
                    sdk.ui.toasts.send(.default, null, "TODO open file: {s}", .{path});
                }
            }
            imgui.IGFD_CloseDialog(file_dialog_context);
        }

        if (save_as_clicked) {
            var config = imgui.IGFD_FileDialog_Config_Get();
            config.path = base_dir.get();
            config.fileName = "recording.irony";
            config.countSelectionMax = 1;
            config.flags = imgui.ImGuiFileDialogFlags_ConfirmOverwrite;
            imgui.IGFD_OpenDialog(
                file_dialog_context,
                "save_as_dialog",
                "Save As",
                "irony recordings (*.irony){.irony}",
                config,
            );
        }
        if (imgui.IGFD_DisplayDialog(
            file_dialog_context,
            "save_as_dialog",
            imgui.ImGuiWindowFlags_NoCollapse,
            .{ .x = 0.5 * display_size.x, .y = 0.5 * display_size.y },
            .{ .x = 0.5 * display_size.x, .y = 0.5 * display_size.y },
        )) {
            if (imgui.IGFD_IsOk(file_dialog_context)) {
                const path_maybe = imgui.IGFD_GetFilePathName(file_dialog_context, imgui.IGFD_ResultMode_AddIfNoFileExt);
                defer std.c.free(path_maybe);
                if (path_maybe) |path| {
                    sdk.ui.toasts.send(.default, null, "TODO save file: {s}", .{path});
                }
            }
            imgui.IGFD_CloseDialog(file_dialog_context);
        }

        if (close_clicked) {
            is_main_window_open.* = false;
            sdk.ui.toasts.send(.default, null, "Main window closed. Press [Tab] to open it again.", .{});
        }

        if (exit_irony_clicked) {
            self.is_exit_confirm_open = true;
            imgui.igOpenPopup_Str("Exit Irony?", 0);
        }
        if (imgui.igBeginPopupModal(
            "Exit Irony?",
            &self.is_exit_confirm_open,
            imgui.ImGuiWindowFlags_AlwaysAutoResize,
        )) {
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
    }
};
