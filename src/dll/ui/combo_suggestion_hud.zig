const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("root.zig");
const logic = @import("../logic/root.zig");

pub const ComboSuggestionHud = struct {
    const Self = @This();
    
    // Instance of matcher to track history
    matcher: ?logic.ComboMatcher = null,
    allocator: ?std.mem.Allocator = null,

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.matcher = logic.ComboMatcher.init(allocator);
    }

    pub fn deinit(self: *Self) void {
        if (self.matcher) |*m| m.deinit();
    }

    pub fn draw(self: *Self, frame: *const model.Frame, settings: *const model.Settings, base_dir: *const sdk.misc.BaseDir) void {
        if (!settings.combo_suggestion.enabled) return;
        
        // Ensure matcher is initialized
        if (self.matcher == null and self.allocator != null) {
            self.matcher = logic.ComboMatcher.init(self.allocator.?);
        }
        
        if (self.matcher == null) return;
        const matcher = &self.matcher.?;
        
        // Initial load
        if (matcher.combo_data == null) {
            matcher.loadCombos(base_dir);
        }
        
        matcher.update(frame, settings);

        const viewport = imgui.igGetMainViewport();
        const display_size = viewport.*.WorkSize;
        
        const window_width: f32 = 600;
        const window_height: f32 = 120;
        const window_pos = imgui.ImVec2{
            .x = (display_size.x - window_width) / 2.0,
            .y = display_size.y - window_height - 60,
        };

        imgui.igSetNextWindowPos(window_pos, imgui.ImGuiCond_Always, .{});
        imgui.igSetNextWindowSize(.{ .x = window_width, .y = window_height }, imgui.ImGuiCond_Always);
        
        const flags = imgui.ImGuiWindowFlags_NoDecoration | 
                     imgui.ImGuiWindowFlags_AlwaysAutoResize | 
                     imgui.ImGuiWindowFlags_NoSavedSettings | 
                     imgui.ImGuiWindowFlags_NoFocusOnAppearing | 
                     imgui.ImGuiWindowFlags_NoNav |
                     imgui.ImGuiWindowFlags_NoMove;

        imgui.igPushStyleColor_Vec4(imgui.ImGuiCol_WindowBg, settings.misc.ui_background_color.toImVec());
        defer imgui.igPopStyleColor(1);

        if (imgui.igBegin("Combo Suggestion HUD", null, flags)) {
            defer imgui.igEnd();

            // Row 1: History
            self.drawMoveRow("History", matcher.history.items, 0.5);
            
            imgui.igSeparator();
            
            // Row 2: Suggestions
            if (matcher.getBestMatch()) |combo_val| {
                const moves_val = combo_val.object.get("moves").?;
                const moves = moves_val.array;
                
                self.drawJsonMoveRow("Suggest", moves.items, 1.0);
                
                // Show damage/hits
                imgui.igSameLine(0, 20);
                if (combo_val.object.get("damage")) |dmg| {
                    imgui.igTextColored(.{ .x = 1, .y = 0.5, .z = 0.5, .w = 1 }, dmg.string.ptr);
                }
            } else {
                imgui.igText("Perform a starter move to see suggestions...");
            }
        }
    }

    fn drawMoveRow(self: *Self, label: []const u8, moves: []const logic.ComboMatcher.Move, alpha: f32) void {
        _ = self;
        imgui.igPushStyleVar_Float(imgui.ImGuiStyleVar_Alpha, alpha);
        defer imgui.igPopStyleVar(1);

        imgui.igText(label.ptr);
        imgui.igSameLine(80, -1);
        
        for (moves, 0..) |move, i| {
            if (i > 0) {
                imgui.igSameLine(0, 5);
                imgui.igText(">");
                imgui.igSameLine(0, 5);
            }
            
            const color = if (move.type == .img) 
                imgui.ImVec4{ .x = 1.0, .y = 0.8, .z = 0.2, .w = 1.0 } 
            else 
                imgui.ImVec4{ .x = 0.2, .y = 0.8, .z = 1.0, .w = 1.0 };

            imgui.igTextColored(color, move.name.ptr);
        }
    }

    fn drawJsonMoveRow(self: *Self, label: []const u8, moves: []const std.json.Value, alpha: f32) void {
        _ = self;
        imgui.igPushStyleVar_Float(imgui.ImGuiStyleVar_Alpha, alpha);
        defer imgui.igPopStyleVar(1);

        imgui.igText(label.ptr);
        imgui.igSameLine(80, -1);
        
        for (moves, 0..) |move_val, i| {
            if (i > 0) {
                imgui.igSameLine(0, 5);
                imgui.igText(">");
                imgui.igSameLine(0, 5);
            }
            
            const name = move_val.object.get("name").?.string;
            const move_type = move_val.object.get("type").?.string;
            
            const color = if (std.mem.eql(u8, move_type, "img")) 
                imgui.ImVec4{ .x = 1.0, .y = 0.8, .z = 0.2, .w = 1.0 } 
            else 
                imgui.ImVec4{ .x = 0.2, .y = 0.8, .z = 1.0, .w = 1.0 };

            imgui.igTextColored(color, name.ptr);
        }
    }
};
