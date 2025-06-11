const std = @import("std");
const imgui = @import("imgui");

pub const QuadrantLayout = struct {
    division: imgui.ImVec2 = .{ .x = 0.5, .y = 0.5 },

    const Self = @This();
    pub fn Quadrant(comptime Context: type) type {
        return struct {
            id: [:0]const u8,
            content: *const fn (context: Context) void,
        };
    }
    pub fn Quadrants(comptime Context: type) type {
        return struct {
            top_left: Quadrant(Context),
            top_right: Quadrant(Context),
            bottom_left: Quadrant(Context),
            bottom_right: Quadrant(Context),
        };
    }

    pub fn draw(self: *Self, context: anytype, quadrants: *const Quadrants(@TypeOf(context))) void {
        var cursor: imgui.ImVec2 = undefined;
        imgui.igGetCursorPos(&cursor);
        self.drawQuadrants(context, quadrants);
        imgui.igSetCursorPos(cursor);
        self.drawBorders();
    }

    fn drawQuadrants(self: *const Self, context: anytype, quadrants: *const Quadrants(@TypeOf(context))) void {
        var content_size: imgui.ImVec2 = undefined;
        imgui.igGetContentRegionAvail(&content_size);
        const border_size = imgui.igGetStyle().*.ChildBorderSize;

        const available_size = imgui.ImVec2{
            .x = content_size.x - (3.0 * border_size),
            .y = content_size.y - (3.0 * border_size),
        };
        const size_1 = imgui.ImVec2{
            .x = std.math.round(self.division.x * available_size.x),
            .y = std.math.round(self.division.y * available_size.y),
        };
        const size_2 = imgui.ImVec2{
            .x = available_size.x - size_1.x,
            .y = available_size.y - size_1.y,
        };

        imgui.igPushStyleVar_Vec2(imgui.ImGuiStyleVar_ItemSpacing, .{ .x = 0, .y = 0 });
        defer imgui.igPopStyleVar(1);

        if (self.division.x > 0.0001 and self.division.y > 0.0001) {
            imgui.igSetCursorPos(.{ .x = border_size, .y = border_size });
            if (imgui.igBeginChild_Str(quadrants.top_left.id, size_1, 0, 0)) {
                quadrants.top_left.content(context);
            }
            imgui.igEndChild();
        }

        if (self.division.x < 0.9999 and self.division.y > 0.0001) {
            imgui.igSetCursorPos(.{ .x = size_1.x + (2.0 * border_size), .y = border_size });
            if (imgui.igBeginChild_Str(quadrants.top_right.id, .{ .x = size_2.x, .y = size_1.y }, 0, 0)) {
                quadrants.top_right.content(context);
            }
            imgui.igEndChild();
        }

        if (self.division.x > 0.0001 and self.division.y < 0.9999) {
            imgui.igSetCursorPos(.{ .x = border_size, .y = size_1.y + (2.0 * border_size) });
            if (imgui.igBeginChild_Str(quadrants.bottom_left.id, .{ .x = size_1.x, .y = size_2.y }, 0, 0)) {
                quadrants.bottom_left.content(context);
            }
            imgui.igEndChild();
        }

        if (self.division.x < 0.9999 and self.division.y < 0.9999) {
            imgui.igSetCursorPos(.{ .x = size_1.x + (2.0 * border_size), .y = size_1.y + (2.0 * border_size) });
            if (imgui.igBeginChild_Str(quadrants.bottom_right.id, size_2, 0, 0)) {
                quadrants.bottom_right.content(context);
            }
            imgui.igEndChild();
        }
    }

    fn drawBorders(self: *Self) void {
        const color = imgui.igGetColorU32_Vec4(imgui.igGetStyleColorVec4(imgui.ImGuiCol_Separator).*);
        const hovered_color = imgui.igGetColorU32_Vec4(imgui.igGetStyleColorVec4(imgui.ImGuiCol_SeparatorHovered).*);
        const active_color = imgui.igGetColorU32_Vec4(imgui.igGetStyleColorVec4(imgui.ImGuiCol_SeparatorActive).*);
        const border_size = imgui.igGetStyle().*.ChildBorderSize;
        const extra_padding = 4.0;
        const hit_box_size = border_size + (2.0 * extra_padding);

        var cursor: imgui.ImVec2 = undefined;
        imgui.igGetCursorScreenPos(&cursor);
        var content_size: imgui.ImVec2 = undefined;
        imgui.igGetContentRegionAvail(&content_size);

        const available_size = imgui.ImVec2{
            .x = content_size.x - (2.0 * border_size),
            .y = content_size.y - (2.0 * border_size),
        };
        const start = imgui.ImVec2{
            .x = cursor.x,
            .y = cursor.y,
        };
        const center = imgui.ImVec2{
            .x = std.math.round(cursor.x + border_size + (self.division.x * available_size.x)),
            .y = std.math.round(cursor.y + border_size + (self.division.y * available_size.y)),
        };
        const end = imgui.ImVec2{
            .x = cursor.x + content_size.x - border_size,
            .y = cursor.y + content_size.y - border_size,
        };

        var x_color = color;
        imgui.igSetCursorScreenPos(.{ .x = center.x - extra_padding, .y = start.y });
        if (imgui.igBeginChild_Str("x-handle", .{ .x = hit_box_size, .y = content_size.y }, 0, 0)) {
            _ = imgui.igInvisibleButton("button", .{ .x = hit_box_size, .y = content_size.y }, 0);
            if (imgui.igIsItemHovered(0)) {
                x_color = hovered_color;
                imgui.igSetMouseCursor(imgui.ImGuiMouseCursor_ResizeEW);
            }
            if (imgui.igIsItemActive()) {
                x_color = active_color;
                self.division.x += imgui.igGetIO().*.MouseDelta.x / available_size.x;
                self.division.x = std.math.clamp(self.division.x, 0.0, 1.0);
            }
        }
        imgui.igEndChild();

        var y_color = color;
        imgui.igSetCursorScreenPos(.{ .x = start.x, .y = center.y - extra_padding });
        if (imgui.igBeginChild_Str("y-handle", .{ .x = content_size.x, .y = hit_box_size }, 0, 0)) {
            _ = imgui.igInvisibleButton("button", .{ .x = content_size.x, .y = hit_box_size }, 0);
            if (imgui.igIsItemHovered(0)) {
                y_color = hovered_color;
                imgui.igSetMouseCursor(imgui.ImGuiMouseCursor_ResizeNS);
            }
            if (imgui.igIsItemActive()) {
                y_color = active_color;
                self.division.y += imgui.igGetIO().*.MouseDelta.y / available_size.y;
                self.division.y = std.math.clamp(self.division.y, 0.0, 1.0);
            }
        }
        imgui.igEndChild();

        imgui.igSetCursorScreenPos(.{ .x = center.x - extra_padding, .y = center.y - extra_padding });
        if (imgui.igBeginChild_Str("center-handle", .{ .x = hit_box_size, .y = hit_box_size }, 0, 0)) {
            _ = imgui.igInvisibleButton("button", .{ .x = hit_box_size, .y = hit_box_size }, 0);
            if (imgui.igIsItemHovered(0)) {
                x_color = hovered_color;
                y_color = hovered_color;
                imgui.igSetMouseCursor(imgui.ImGuiMouseCursor_ResizeAll);
            }
            if (imgui.igIsItemActive()) {
                x_color = active_color;
                y_color = active_color;
                self.division.x += imgui.igGetIO().*.MouseDelta.x / available_size.x;
                self.division.y += imgui.igGetIO().*.MouseDelta.y / available_size.y;
                self.division.x = std.math.clamp(self.division.x, 0.0, 1.0);
                self.division.y = std.math.clamp(self.division.y, 0.0, 1.0);
            }
        }
        imgui.igEndChild();

        const draw_list = imgui.igGetWindowDrawList();
        imgui.ImDrawList_AddLine(draw_list, .{ .x = center.x, .y = start.y }, .{ .x = center.x, .y = end.y }, x_color, border_size);
        imgui.ImDrawList_AddLine(draw_list, .{ .x = start.x, .y = center.y }, .{ .x = end.x, .y = center.y }, y_color, border_size);
        imgui.ImDrawList_AddLine(draw_list, start, .{ .x = end.x, .y = start.y }, color, border_size);
        imgui.ImDrawList_AddLine(draw_list, start, .{ .x = start.x, .y = end.y }, color, border_size);
        imgui.ImDrawList_AddLine(draw_list, end, .{ .x = end.x, .y = start.y }, color, border_size);
        imgui.ImDrawList_AddLine(draw_list, end, .{ .x = start.x, .y = end.y }, color, border_size);

        imgui.igSetCursorScreenPos(.{ .x = cursor.x + content_size.x, .y = cursor.y + content_size.y });
    }
};
