const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");

pub fn drawLiveFrameDataHud(settings: *const model.FrameDataOverlaySettings, frame: *const model.Frame) void {
    if (!settings.live_frame_data_hud_enabled) return;

    const player = frame.getPlayerById(.player_1);
    const startup = player.getStartupFrames();
    const active = player.getActiveFrames();
    const recovery = player.getRecoveryFrames();

    const display_size = imgui.igGetIO_Nil().*.DisplaySize;
    const window_padding = imgui.ImVec2{ .x = 30, .y = 30 };
    const window_width: f32 = 320;
    const window_height: f32 = 220;
    
    const window_pos = imgui.ImVec2{
        .x = window_padding.x,
        .y = display_size.y - window_height - window_padding.y,
    };

    imgui.igSetNextWindowPos(window_pos, imgui.ImGuiCond_Always, .{});
    imgui.igSetNextWindowSize(.{ .x = window_width, .y = window_height }, imgui.ImGuiCond_Always);

    const window_flags = imgui.ImGuiWindowFlags_NoDecoration | 
                       imgui.ImGuiWindowFlags_NoInputs | 
                       imgui.ImGuiWindowFlags_NoSavedSettings |
                       imgui.ImGuiWindowFlags_NoBackground |
                       imgui.ImGuiWindowFlags_NoFocusOnAppearing |
                       imgui.ImGuiWindowFlags_NoBringToFrontOnFocus;

    if (imgui.igBegin("Live Frame Data HUD", null, window_flags)) {
        const draw_list = imgui.igGetWindowDrawList();
        const p_min = window_pos;
        const p_max = imgui.ImVec2{ .x = window_pos.x + window_width, .y = window_pos.y + window_height };
        
        // Background: Deep dark semi-transparent
        const bg_color = imgui.igGetColorU32_Vec4(.{ .x = 0.05, .y = 0.05, .z = 0.07, .w = 0.9 });
        imgui.ImDrawList_AddRectFilled(draw_list, p_min, p_max, bg_color, 15.0, 0);

        // Neon Purple Glow/Border
        const border_color = imgui.igGetColorU32_Vec4(.{ .x = 0.8, .y = 0.0, .z = 1.0, .w = 1.0 });
        imgui.ImDrawList_AddRect(draw_list, p_min, p_max, border_color, 15.0, 0, 3.0);

        // Drop shadow / Outer glow (simulated with a slightly larger rect)
        const shadow_color = imgui.igGetColorU32_Vec4(.{ .x = 0.8, .y = 0.0, .z = 1.0, .w = 0.3 });
        imgui.ImDrawList_AddRect(draw_list, .{ .x = p_min.x - 2, .y = p_min.y - 2 }, .{ .x = p_max.x + 2, .y = p_max.y + 2 }, shadow_color, 17.0, 0, 1.0);

        // Content Rendering
        imgui.igPushStyleVar_Vec2(imgui.ImGuiStyleVar_WindowPadding, .{ .x = 20, .y = 20 });
        defer imgui.igPopStyleVar(1);

        imgui.igSetCursorPos(.{ .x = 20, .y = 20 });
        
        // Header
        const header_color = imgui.ImVec4{ .x = 0.8, .y = 0.2, .z = 1.0, .w = 1.0 };
        imgui.igTextColored(header_color, "■ LIVE FRAME DATA");
        
        imgui.igDummy(.{ .x = 0, .y = 15 });
        
        drawRow("Startup:", startup.actual, .cyan);
        imgui.igDummy(.{ .x = 0, .y = 8 });
        imgui.igSeparator();
        imgui.igDummy(.{ .x = 0, .y = 8 });
        drawRow("Active:", active.actual, .cyan);
        imgui.igDummy(.{ .x = 0, .y = 8 });
        imgui.igSeparator();
        imgui.igDummy(.{ .x = 0, .y = 8 });
        drawRow("Recovery:", recovery.actual, .cyan);
    }
    imgui.igEnd();
}

fn drawRow(label: [:0]const u8, value: ?u32, color_type: enum { cyan }) void {
    // Label
    imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_Text, .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 });
    imgui.igText("%s", label.ptr);
    imgui.igPopStyleColor(1);
    
    imgui.igSameLine(0, -1);
    
    // Value Calculation
    var buffer: [32]u8 = undefined;
    const value_text = if (value) |v| 
        std.fmt.bufPrintZ(&buffer, "{d}f", .{v}) catch "---"
    else 
        "---";
    
    // Right alignment
    var text_size: imgui.ImVec2 = undefined;
    imgui.igCalcTextSize(&text_size, value_text, null, false, -1.0);
    
    const window_width = imgui.igGetWindowWidth();
    const right_padding = 25.0;
    imgui.igSetCursorPosX(window_width - text_size.x - right_padding);
    
    // Color
    const value_color = switch (color_type) {
        .cyan => imgui.ImVec4{ .x = 0.0, .y = 1.0, .z = 1.0, .w = 1.0 },
    };
    
    imgui.igTextColored(value_color, "%s", value_text.ptr);
}
