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
        spawn_position: sdk.math.Vec3 = .zero,
    };

    pub fn draw(
        self: *Self,
        settings: *const model.FrameDataOverlaySettings,
        frame: *const model.Frame,
        matrix: sdk.math.Mat4,
        draw_list: ?*imgui.ImDrawList,
    ) void {
        if (!settings.enabled) return;

        // Always render only the active player's frame advantage to avoid duplicate
        // numbers stacked in world overlay mode.
        const main_player_id = frame.main_player_id;
        const main_player = frame.getPlayerById(main_player_id);
        const opponent_id: model.PlayerId = if (main_player_id == .player_1) .player_2 else .player_1;
        const opponent_player = frame.getPlayerById(opponent_id);

        self.drawPlayerFrameAdvantage(0, main_player, opponent_player, matrix, draw_list);
    }

    fn drawPlayerFrameAdvantage(
        self: *Self,
        player_index: usize,
        player: *const model.Player,
        opponent: *const model.Player,
        matrix: sdk.math.Mat4,
        draw_list: ?*imgui.ImDrawList,
    ) void {
        _ = matrix;
        const current_time = imgui.igGetTime();
        const frame_advantage = player.getFrameAdvantage(opponent).actual;
        
        var history = &self.history[player_index];

        if (frame_advantage) |adv| {
            // New advantage found or value changed
            if (history.last_advantage == null or history.last_advantage.? != adv) {
                history.last_advantage = adv;
                history.last_timestamp = current_time;
                
                if (draw_list != null) {
                    // SCREEN OVERLAY: fixed screen center.
                    const display_size = imgui.igGetIO_Nil().*.DisplaySize;
                    history.spawn_position = sdk.math.Vec3.fromArray(.{ 
                        display_size.x * 0.5, 
                        display_size.y * 0.5, 
                        0.5 
                    });
                } else {
                    // INTERNAL CAMERA WINDOW: center per-view window.
                    var window_pos: imgui.ImVec2 = undefined;
                    var window_size: imgui.ImVec2 = undefined;
                    imgui.igGetWindowPos(&window_pos);
                    imgui.igGetWindowSize(&window_size);
                    history.spawn_position = sdk.math.Vec3.fromArray(.{
                        window_pos.x + (window_size.x * 0.5),
                        window_pos.y + (window_size.y * 0.5),
                        0.5,
                    });
                }
            } else {
                history.last_timestamp = current_time;
            }
        }

        const time_elapsed = current_time - history.last_timestamp;
        const display_advantage = if (history.last_advantage) |adv| 
            if (time_elapsed < 1.5) adv else return
        else 
            return;

        var screen_pos: sdk.math.Vec3 = undefined;
        if (draw_list != null) {
            // SCREEN OVERLAY: Float UP in screen space (pixels)
            const float_speed = 120.0; // pixels per second
            const vertical_offset = @as(f32, @floatCast(time_elapsed)) * float_speed;
            screen_pos = history.spawn_position.subtract(sdk.math.Vec3.fromArray(.{ 0, vertical_offset, 0 }));
        } else {
            // INTERNAL WINDOW: float in screen space, centered in each view.
            const float_speed = 70.0;
            const vertical_offset = @as(f32, @floatCast(time_elapsed)) * float_speed;
            screen_pos = history.spawn_position.subtract(sdk.math.Vec3.fromArray(.{ 0, vertical_offset, 0 }));
        }

        if (screen_pos.z() < 0 or screen_pos.z() > 1) return;

        var buffer: [32]u8 = undefined;
        const magnitude = @abs(display_advantage);
        const text = std.fmt.bufPrintZ(&buffer, "{d}", .{magnitude}) catch return;

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
        
        const font_size: f32 = if (draw_list != null) 90.0 else 44.0;
        imgui.igPushFont(null, font_size);
        defer imgui.igPopFont();

        var text_size: imgui.ImVec2 = undefined;
        imgui.igCalcTextSize(&text_size, text, null, false, -1);
        
        const screen_x = position.x() - (text_size.x * 0.5);
        const screen_y = position.y() - (text_size.y * 0.5);
        const text_pos = imgui.ImVec2{ .x = screen_x, .y = screen_y };
        
        const black = imgui.igGetColorU32_Vec4(.{ .x = 0, .y = 0, .z = 0, .w = 1 });
        const text_color = imgui.igGetColorU32_Vec4(color.toImVec());

        // Draw ultra-thick 8-way outline
        const thickness: f32 = if (draw_list != null) 5.0 else 2.0;
        const offsets = [_][2]f32{
            .{ -thickness, -thickness }, .{ 0, -thickness }, .{ thickness, -thickness },
            .{ -thickness, 0 },                             .{ thickness, 0 },
            .{ -thickness, thickness },  .{ 0, thickness },  .{ thickness, thickness },
        };

        for (offsets) |off| {
            imgui.ImDrawList_AddText_Vec2(final_draw_list, .{ .x = text_pos.x + off[0], .y = text_pos.y + off[1] }, black, text, null);
        }

        // Draw main text
        imgui.ImDrawList_AddText_Vec2(final_draw_list, text_pos, text_color, text, null);
    }
};
