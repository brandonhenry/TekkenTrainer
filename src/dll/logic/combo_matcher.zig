const std = @import("std");
const model = @import("../model/root.zig");
const sdk = @import("../../sdk/root.zig");

pub const ComboMatcher = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    history: std.ArrayListUnmanaged(Move),
    last_input: model.Input = .{},
    combo_data: ?ComboDataRaw = null,
    current_character: [32]u8 = [_]u8{0} ** 32,
    
    pub const MoveType = enum { img, text };
    pub const Move = struct {
        type: MoveType,
        name: []const u8,
        img: ?[]const u8 = null,
    };

    pub const ComboDataRaw = struct {
        value: std.json.Parsed(std.json.Value),
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .history = .empty,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.history.deinit(self.allocator);
        if (self.combo_data) |*d| d.value.deinit();
    }
    
    pub fn loadCombos(self: *Self, base_dir: *const sdk.misc.BaseDir) void {
        var buffer: [sdk.os.max_file_path_length]u8 = undefined;
        const path = base_dir.getPath(&buffer, "assets\\combos.json") catch return;
        
        const file = std.fs.openFileAbsolute(path, .{}) catch return;
        defer file.close();
        
        const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch return;
        defer self.allocator.free(content);
        
        if (self.combo_data) |*d| d.value.deinit();
        
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, content, .{}) catch return;
        self.combo_data = .{ .value = parsed };
    }

    pub fn update(self: *Self, frame: *const model.Frame, settings: *const model.Settings) void {
        if (!settings.combo_suggestion.enabled) return;
        
        const char_name = settings.combo_suggestion.getCharacterName();
        if (!std.mem.eql(u8, std.mem.sliceTo(&self.current_character, 0), char_name)) {
            @memset(&self.current_character, 0);
            @memcpy(self.current_character[0..char_name.len], char_name);
        }

        const player = frame.getPlayerById(frame.main_player_id);
        const input_maybe = player.input;
        const side: model.PlayerSide = if (frame.main_player_id == frame.left_player_id) .left else .right;
        
        if (input_maybe) |input| {
            if (!std.meta.eql(input, self.last_input)) {
                const move = self.normalizeInput(input, side) orelse {
                    self.last_input = input;
                    return;
                };
                
                if (self.history.items.len == 0 or !std.mem.eql(u8, self.history.items[self.history.items.len-1].name, move.name)) {
                    self.history.append(self.allocator, move) catch {};
                    if (self.history.items.len > 10) {
                        _ = self.history.orderedRemove(0);
                    }
                }
                
                self.last_input = input;
            }
        }
    }
    
    fn normalizeInput(self: *Self, input: model.Input, side: model.PlayerSide) ?Move {
        _ = self;
        const f = if (side == .left) input.forward else input.back;
        const b = if (side == .left) input.back else input.forward;
        const d = input.down;
        const u = input.up;

        if (d and f) return .{ .type = .img, .name = "df", .img = "df.svg" };
        if (d and b) return .{ .type = .img, .name = "db", .img = "db.svg" };
        if (u and f) return .{ .type = .img, .name = "uf", .img = "uf.svg" };
        if (u and b) return .{ .type = .img, .name = "ub", .img = "ub.svg" };
        if (f) return .{ .type = .img, .name = "f", .img = "f.svg" };
        if (b) return .{ .type = .img, .name = "b", .img = "b.svg" };
        if (d) return .{ .type = .img, .name = "d", .img = "d.svg" };
        if (u) return .{ .type = .img, .name = "u", .img = "u.svg" };

        if (input.button_1 and input.button_2) return .{ .type = .img, .name = "1+2", .img = "12.svg" };
        if (input.button_3 and input.button_4) return .{ .type = .img, .name = "3+4", .img = "34.svg" };
        if (input.button_1) return .{ .type = .img, .name = "1", .img = "1.svg" };
        if (input.button_2) return .{ .type = .img, .name = "2", .img = "2.svg" };
        if (input.button_3) return .{ .type = .img, .name = "3", .img = "3.svg" };
        if (input.button_4) return .{ .type = .img, .name = "4", .img = "4.svg" };

        return null;
    }

    pub fn getBestMatch(self: *Self) ?std.json.Value {
        const data = self.combo_data orelse return null;
        const char_name = std.mem.sliceTo(&self.current_character, 0);
        if (char_name.len == 0) return null;

        const char_combos = data.value.value.object.get(char_name) orelse return null;
        const combo_list = char_combos.array;

        if (self.history.items.len == 0) return null;

        for (combo_list.items) |combo_val| {
            const moves_val = combo_val.object.get("moves") orelse continue;
            const moves = moves_val.array;
            
            var match_count: usize = 0;
            for (self.history.items) |hist_move| {
                if (match_count >= moves.items.len) break;
                
                const combo_move_name = moves.items[match_count].object.get("name").?.string;
                if (std.mem.eql(u8, hist_move.name, combo_move_name) or 
                    self.nameMatches(hist_move.name, combo_move_name)) {
                    match_count += 1;
                } else {
                    match_count = 0;
                }
            }
            
            if (match_count > 0 and match_count < moves.items.len) {
                // Return the combo Value so HUD can draw the remaining moves
                return combo_val;
            }
        }
        
        return null;
    }
    
    fn nameMatches(self: *Self, hist_name: []const u8, combo_name: []const u8) bool {
        _ = self;
        if (std.mem.eql(u8, hist_name, "1") and (std.mem.eql(u8, combo_name, "LP") or std.mem.eql(u8, combo_name, "1"))) return true;
        if (std.mem.eql(u8, hist_name, "2") and (std.mem.eql(u8, combo_name, "RP") or std.mem.eql(u8, combo_name, "2"))) return true;
        if (std.mem.eql(u8, hist_name, "3") and (std.mem.eql(u8, combo_name, "LK") or std.mem.eql(u8, combo_name, "3"))) return true;
        if (std.mem.eql(u8, hist_name, "4") and (std.mem.eql(u8, combo_name, "RK") or std.mem.eql(u8, combo_name, "4"))) return true;
        return false;
    }
};
