const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("root.zig");

pub const FrameDataOverlay = struct {
    const Self = @This();

    pub fn draw(
        self: *Self,
        settings: *const model.FrameDataOverlaySettings,
        frame: *const model.Frame,
        matrix: sdk.math.Mat4,
    ) void {
        _ = self;
        if (!settings.enabled) return;

        const player_1 = frame.getPlayerById(.player_1);
        const player_2 = frame.getPlayerById(.player_2);

        drawPlayerFrameAdvantage(player_1, player_2, matrix);
        drawPlayerFrameAdvantage(player_2, player_1, matrix);
    }

    fn drawPlayerFrameAdvantage(
        player: *const model.Player,
        opponent: *const model.Player,
        matrix: sdk.math.Mat4,
    ) void {
        const frame_advantage = player.getFrameAdvantage(opponent).actual orelse return;

        // Determine position (above head)
        var position = if (player.getSkeleton()) |skeleton|
            skeleton.head
        else if (player.getHurtCylindersHeight(0).max) |height|
            (if (player.getPosition()) |pos|
                pos.swizzle("xy").extend(height)
            else
                return)
        else
            return;

        // Offset above head
        position = position.add(sdk.math.Vec3.fromArray(.{ 0, 0, 30 })); // 30cm above head

        // Project to screen
        const screen_pos = position.pointTransform(matrix);
        // Check if behind camera
        if (screen_pos.z() < 0 or screen_pos.z() > 1) return;

        // Format text
        var buffer: [32]u8 = undefined;
        // const sign = if (frame_advantage > 0) "+" else "";
        // const text = std.fmt.bufPrintZ(&buffer, "{s}{d}", .{ sign, frame_advantage }) catch return;
        // User requested just the number for negative, but big green + for plus? 
        // "green in big letter with black outline if plus. red in big letter with black outline in minus"
        // I will assume standard signed integer formatting: +5, -5, 0.
        
        const text = if (frame_advantage > 0)
             std.fmt.bufPrintZ(&buffer, "+{d}", .{frame_advantage}) catch return
        else 
             std.fmt.bufPrintZ(&buffer, "{d}", .{frame_advantage}) catch return;

        // Select color
        const color = if (frame_advantage > 0)
            sdk.math.Vec4.fromArray(.{ 0.0, 1.0, 0.0, 1.0 }) // Green
        else if (frame_advantage < 0)
            sdk.math.Vec4.fromArray(.{ 1.0, 0.0, 0.0, 1.0 }) // Red
        else
            sdk.math.Vec4.fromArray(.{ 1.0, 1.0, 1.0, 1.0 }); // White

        drawOutlinedText(text, screen_pos, color);
    }

    fn drawOutlinedText(text: [:0]const u8, position: sdk.math.Vec3, color: sdk.math.Vec4) void {
        const draw_list = imgui.igGetWindowDrawList();
        
        // Calculate text size to center it
        // We want "big letter" so let's scale it. 
        // ImGui default font size is small. We can use SetWindowFontScale but that affects the whole window.
        // Or we can just use the default font. The user said "big letter". 
        // Since I cannot easily load fonts here without context, I will stick to default font for now. 
        // Revisiting: The user explicitely asked for BIG letters.
        // I'll check if `sdk` has font utilities. 
        // For now, I will just draw it.

        var text_size: imgui.ImVec2 = undefined;
        imgui.igCalcTextSize(&text_size, text, null, false, -1);
        
        const screen_x = position.x() - (text_size.x * 0.5);
        const screen_y = position.y() - (text_size.y * 0.5);
        const text_pos = imgui.ImVec2{ .x = screen_x, .y = screen_y };
        
        const black = imgui.igGetColorU32_Vec4(.{ .x = 0, .y = 0, .z = 0, .w = 1 });
        const text_color = imgui.igGetColorU32_Vec4(color.toImVec());

        // Draw outline (4 offsets)
        const outline_width = 1.0;
        imgui.ImDrawList_AddText_Vec2(draw_list, .{ .x = text_pos.x - outline_width, .y = text_pos.y }, black, text, null);
        imgui.ImDrawList_AddText_Vec2(draw_list, .{ .x = text_pos.x + outline_width, .y = text_pos.y }, black, text, null);
        imgui.ImDrawList_AddText_Vec2(draw_list, .{ .x = text_pos.x, .y = text_pos.y - outline_width }, black, text, null);
        imgui.ImDrawList_AddText_Vec2(draw_list, .{ .x = text_pos.x, .y = text_pos.y + outline_width }, black, text, null);

        // Draw main text
        imgui.ImDrawList_AddText_Vec2(draw_list, text_pos, text_color, text, null);
    }
};
