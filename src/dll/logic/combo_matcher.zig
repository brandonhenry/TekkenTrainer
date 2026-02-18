const std = @import("std");
const model = @import("../model/root.zig");
const sdk = @import("../../sdk/root.zig");

pub const ComboMatcher = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    history: std.ArrayListUnmanaged(Move),
    history_revision: u64 = 0,
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

    pub const MatchResult = struct {
        combo: std.json.Value,
        matched_count: usize,
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
        const candidate_paths = [_][]const u8{
            "assets\\combos.json",
            "..\\assets\\combos.json",
            "src\\dll\\ui\\assets\\combos.json",
            "..\\src\\dll\\ui\\assets\\combos.json",
            "..\\..\\src\\dll\\ui\\assets\\combos.json",
        };

        var path_buffer: [sdk.os.max_file_path_length]u8 = undefined;
        var file: ?std.fs.File = null;
        var resolved_path: ?[:0]u8 = null;

        for (candidate_paths) |candidate| {
            const path = base_dir.getPath(&path_buffer, candidate) catch continue;
            file = std.fs.openFileAbsolute(path, .{}) catch continue;
            resolved_path = path;
            break;
        }

        if (file == null or resolved_path == null) {
            std.log.warn("Combo suggestion: unable to locate combos.json from base dir: {s}", .{base_dir.get()});
            return;
        }
        defer file.?.close();

        const stat = file.?.stat() catch |err| {
            std.log.warn("Combo suggestion: failed to stat combos file at {s}: {}", .{ resolved_path.?, err });
            return;
        };

        // combos.json is large; read to the known file size instead of a fixed 1MB cap.
        const max_read = @as(usize, @intCast(stat.size + 1));
        const content = file.?.readToEndAlloc(self.allocator, max_read) catch |err| {
            std.log.warn("Combo suggestion: failed reading combos file at {s}: {}", .{ resolved_path.?, err });
            return;
        };
        defer self.allocator.free(content);

        if (self.combo_data) |*d| d.value.deinit();

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, content, .{}) catch |err| {
            std.log.warn("Combo suggestion: failed parsing combos file at {s}: {}", .{ resolved_path.?, err });
            return;
        };

        self.combo_data = .{ .value = parsed };
        std.log.info("Combo suggestion: loaded combo data from {s}", .{resolved_path.?});
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
                if (self.normalizeDirectionInput(input, side)) |move| {
                    self.appendHistoryMove(move);
                }
                if (self.normalizeButtonInput(input)) |move| {
                    self.appendHistoryMove(move);
                }
                self.last_input = input;
            }
        }
    }
    
    fn appendHistoryMove(self: *Self, move: Move) void {
        if (self.history.items.len == 0 or !std.mem.eql(u8, self.history.items[self.history.items.len - 1].name, move.name)) {
            self.history.append(self.allocator, move) catch return;
            if (self.history.items.len > 20) {
                _ = self.history.orderedRemove(0);
            }
            self.history_revision += 1;
        }
    }

    fn normalizeDirectionInput(self: *Self, input: model.Input, side: model.PlayerSide) ?Move {
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

        return null;
    }

    fn normalizeButtonInput(self: *Self, input: model.Input) ?Move {
        _ = self;
        if (input.button_1 and input.button_2) return .{ .type = .img, .name = "1+2", .img = "12.svg" };
        if (input.button_1 and input.button_3) return .{ .type = .img, .name = "1+3", .img = null };
        if (input.button_1 and input.button_4) return .{ .type = .img, .name = "1+4", .img = null };
        if (input.button_2 and input.button_3) return .{ .type = .img, .name = "2+3", .img = null };
        if (input.button_2 and input.button_4) return .{ .type = .img, .name = "2+4", .img = null };
        if (input.button_3 and input.button_4) return .{ .type = .img, .name = "3+4", .img = "34.svg" };
        if (input.button_1) return .{ .type = .img, .name = "1", .img = "1.svg" };
        if (input.button_2) return .{ .type = .img, .name = "2", .img = "2.svg" };
        if (input.button_3) return .{ .type = .img, .name = "3", .img = "3.svg" };
        if (input.button_4) return .{ .type = .img, .name = "4", .img = "4.svg" };

        return null;
    }

    pub fn getBestMatch(self: *Self) ?std.json.Value {
        if (self.getBestMatchWithCount()) |result| {
            return result.combo;
        }

        const data = self.combo_data orelse return null;
        const char_name = std.mem.sliceTo(&self.current_character, 0);
        if (char_name.len == 0) return null;
        const char_combos = data.value.value.object.get(char_name) orelse return null;
        const combo_list = char_combos.array;
        if (combo_list.items.len > 0) return combo_list.items[0];
        return null;
    }

    pub fn getBestMatchWithCount(self: *Self) ?MatchResult {
        const data = self.combo_data orelse return null;
        const char_name = std.mem.sliceTo(&self.current_character, 0);
        if (char_name.len == 0) return null;

        const char_combos = data.value.value.object.get(char_name) orelse return null;
        const combo_list = char_combos.array;

        if (self.history.items.len == 0) return null;

        var best: ?MatchResult = null;
        for (combo_list.items) |combo_val| {
            const moves_val = combo_val.object.get("moves") orelse continue;
            const moves = moves_val.array;

            const match_count = self.getMatchCountForMoves(moves.items);
            if (match_count > 0 and match_count < moves.items.len) {
                if (best == null or match_count > best.?.matched_count) {
                    best = .{ .combo = combo_val, .matched_count = match_count };
                }
            }
        }

        return best;
    }

    pub fn getComboById(self: *Self, combo_id: []const u8) ?std.json.Value {
        const data = self.combo_data orelse return null;
        const char_name = std.mem.sliceTo(&self.current_character, 0);
        if (char_name.len == 0) return null;

        const char_combos = data.value.value.object.get(char_name) orelse return null;
        const combo_list = char_combos.array;
        for (combo_list.items) |combo_val| {
            const id_val = combo_val.object.get("id") orelse continue;
            if (std.mem.eql(u8, id_val.string, combo_id)) return combo_val;
        }
        return null;
    }

    pub fn moveMatchesComboMove(self: *Self, history_move: Move, combo_move_name: []const u8) bool {
        return std.mem.eql(u8, history_move.name, combo_move_name) or self.nameMatches(history_move.name, combo_move_name);
    }

    fn getMatchCountForMoves(self: *Self, moves: []const std.json.Value) usize {
        var match_count: usize = 0;
        for (self.history.items) |hist_move| {
            if (match_count >= moves.len) break;
            const combo_move_name = moves[match_count].object.get("name").?.string;
            if (self.moveMatchesComboMove(hist_move, combo_move_name)) {
                match_count += 1;
            } else {
                match_count = 0;
            }
        }
        return match_count;
    }
    
    fn nameMatches(self: *Self, hist_name: []const u8, combo_name: []const u8) bool {
        _ = self;
        if (std.mem.eql(u8, hist_name, "f") and
            (std.mem.eql(u8, combo_name, "Forward") or std.mem.eql(u8, combo_name, "forward") or std.mem.eql(u8, combo_name, "f"))) return true;
        if (std.mem.eql(u8, hist_name, "b") and
            (std.mem.eql(u8, combo_name, "Back") or std.mem.eql(u8, combo_name, "back") or std.mem.eql(u8, combo_name, "b"))) return true;
        if (std.mem.eql(u8, hist_name, "d") and
            (std.mem.eql(u8, combo_name, "Down") or std.mem.eql(u8, combo_name, "down") or std.mem.eql(u8, combo_name, "d"))) return true;
        if (std.mem.eql(u8, hist_name, "u") and
            (std.mem.eql(u8, combo_name, "Up") or std.mem.eql(u8, combo_name, "up") or std.mem.eql(u8, combo_name, "u"))) return true;
        if (std.mem.eql(u8, hist_name, "df") and
            (std.mem.eql(u8, combo_name, "Down / Forward") or std.mem.eql(u8, combo_name, "d/f") or std.mem.eql(u8, combo_name, "df"))) return true;
        if (std.mem.eql(u8, hist_name, "db") and
            (std.mem.eql(u8, combo_name, "Down / Back") or std.mem.eql(u8, combo_name, "d/b") or std.mem.eql(u8, combo_name, "db"))) return true;
        if (std.mem.eql(u8, hist_name, "uf") and
            (std.mem.eql(u8, combo_name, "Up / Forward") or std.mem.eql(u8, combo_name, "u/f") or std.mem.eql(u8, combo_name, "uf"))) return true;
        if (std.mem.eql(u8, hist_name, "ub") and
            (std.mem.eql(u8, combo_name, "Up / Back") or std.mem.eql(u8, combo_name, "u/b") or std.mem.eql(u8, combo_name, "ub"))) return true;
        if (std.mem.eql(u8, hist_name, "1") and (std.mem.eql(u8, combo_name, "LP") or std.mem.eql(u8, combo_name, "1"))) return true;
        if (std.mem.eql(u8, hist_name, "2") and (std.mem.eql(u8, combo_name, "RP") or std.mem.eql(u8, combo_name, "2"))) return true;
        if (std.mem.eql(u8, hist_name, "3") and (std.mem.eql(u8, combo_name, "LK") or std.mem.eql(u8, combo_name, "3"))) return true;
        if (std.mem.eql(u8, hist_name, "4") and (std.mem.eql(u8, combo_name, "RK") or std.mem.eql(u8, combo_name, "4"))) return true;
        if (std.mem.eql(u8, hist_name, "1+2") and
            (std.mem.eql(u8, combo_name, "LP + RP") or std.mem.eql(u8, combo_name, "1+2") or std.mem.eql(u8, combo_name, "12"))) return true;
        if (std.mem.eql(u8, hist_name, "1+3") and
            (std.mem.eql(u8, combo_name, "LP + LK") or std.mem.eql(u8, combo_name, "1+3") or std.mem.eql(u8, combo_name, "13"))) return true;
        if (std.mem.eql(u8, hist_name, "1+4") and
            (std.mem.eql(u8, combo_name, "LP + RK") or std.mem.eql(u8, combo_name, "1+4") or std.mem.eql(u8, combo_name, "14"))) return true;
        if (std.mem.eql(u8, hist_name, "2+3") and
            (std.mem.eql(u8, combo_name, "RP + LK") or std.mem.eql(u8, combo_name, "2+3") or std.mem.eql(u8, combo_name, "23"))) return true;
        if (std.mem.eql(u8, hist_name, "2+4") and
            (std.mem.eql(u8, combo_name, "RP + RK") or std.mem.eql(u8, combo_name, "2+4") or std.mem.eql(u8, combo_name, "24"))) return true;
        if (std.mem.eql(u8, hist_name, "3+4") and
            (std.mem.eql(u8, combo_name, "LK + RK") or std.mem.eql(u8, combo_name, "3+4") or std.mem.eql(u8, combo_name, "34"))) return true;
        return false;
    }
};
