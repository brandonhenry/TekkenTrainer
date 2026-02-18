const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("root.zig");

pub const FrameDataOverlay = struct {
    const Self = @This();

    history: [2]PlayerHistory = .{ .{}, .{} },

    pub const PlayerHistory = struct {
        last_advantage: ?i32 = null,
        last_timestamp: f64 = -100.0,
    };

    pub fn draw(
        self: *Self,
        settings: *const model.FrameDataOverlaySettings,
        frame: *const model.Frame,
        matrix: sdk.math.Mat4,
        draw_list: ?*imgui.ImDrawList,
    ) void {
        if (!settings.enabled) return;

        const player_1 = frame.getPlayerById(.player_1);
        const player_2 = frame.getPlayerById(.player_2);

        self.drawPlayerFrameAdvantage(0, player_1, player_2, matrix, draw_list);
        self.drawPlayerFrameAdvantage(1, player_2, player_1, matrix, draw_list);
    }

    fn drawPlayerFrameAdvantage(
        self: *Self,
        player_index: usize,
        player: *const model.Player,
        opponent: *const model.Player,
        matrix: sdk.math.Mat4,
        draw_list: ?*imgui.ImDrawList,
    ) void {
        const current_time = imgui.igGetTime();
        const frame_advantage = player.getFrameAdvantage(opponent).actual;
        
        var history = &self.history[player_index];

        if (frame_advantage) |adv| {
            // New advantage found
            if (history.last_advantage == null or history.last_advantage.? != adv) {
                history.last_advantage = adv;
                history.last_timestamp = current_time;
            } else {
                // Same advantage, but it's still being "active" in the current frame.
                // Resetting timer to keep it alive while it's active.
                history.last_timestamp = current_time;
            }
        }

        // Determine if we should draw
        const display_advantage = if (frame_advantage) |adv| 
            adv 
        else if (history.last_advantage) |adv| 
            if (current_time - history.last_timestamp < 1.5) adv else return
        else 
            return;

        // Determine position (above head)
        var position = if (player.getSkeleton()) |skeleton|
            skeleton.get(.head)
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
        
        const text = if (display_advantage > 0)
             std.fmt.bufPrintZ(&buffer, "+{d}", .{display_advantage}) catch return
        else 
             std.fmt.bufPrintZ(&buffer, "{d}", .{display_advantage}) catch return;

        // Select color
        const color = if (display_advantage > 0)
            sdk.math.Vec4.fromArray(.{ 0.0, 1.0, 0.0, 1.0 }) // Green
        else if (display_advantage < 0)
            sdk.math.Vec4.fromArray(.{ 1.0, 0.0, 0.0, 1.0 }) // Red
        else
            sdk.math.Vec4.fromArray(.{ 1.0, 1.0, 1.0, 1.0 }); // White

        drawOutlinedText(text, screen_pos, color, draw_list);
    }

    fn drawOutlinedText(text: [:0]const u8, position: sdk.math.Vec3, color: sdk.math.Vec4, draw_list: ?*imgui.ImDrawList) void {
        const final_draw_list = draw_list orelse imgui.igGetWindowDrawList();
        
        const font_size = 150.0;
        imgui.igPushFont(null, font_size);
        defer imgui.igPopFont();

        var text_size: imgui.ImVec2 = undefined;
        imgui.igCalcTextSize(&text_size, text, null, false, -1);
        
        const screen_x = position.x() - (text_size.x * 0.5);
        const screen_y = position.y() - (text_size.y * 0.5);
        const text_pos = imgui.ImVec2{ .x = screen_x, .y = screen_y };
        
        const black = imgui.igGetColorU32_Vec4(.{ .x = 0, .y = 0, .z = 0, .w = 1 });
        const text_color = imgui.igGetColorU32_Vec4(color.toImVec());

        // Draw outline (4 offsets)
        const outline_width = 3.0;
        imgui.ImDrawList_AddText_Vec2(final_draw_list, .{ .x = text_pos.x - outline_width, .y = text_pos.y }, black, text, null);
        imgui.ImDrawList_AddText_Vec2(final_draw_list, .{ .x = text_pos.x + outline_width, .y = text_pos.y }, black, text, null);
        imgui.ImDrawList_AddText_Vec2(final_draw_list, .{ .x = text_pos.x, .y = text_pos.y - outline_width }, black, text, null);
        imgui.ImDrawList_AddText_Vec2(final_draw_list, .{ .x = text_pos.x, .y = text_pos.y + outline_width }, black, text, null);

        // Draw main text
        imgui.ImDrawList_AddText_Vec2(final_draw_list, text_pos, text_color, text, null);
    }
};
