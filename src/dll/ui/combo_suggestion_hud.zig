const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const logic = @import("../logic/root.zig");

pub const ComboSuggestionHud = struct {
    const Self = @This();
    const raster_icon_size = 96;

    const TextureEntry = struct {
        tex_data: [*c]imgui.ImTextureData,
        tex_ref: imgui.ImTextureRef,
    };
    
    // Instance of matcher to track history
    matcher: ?logic.ComboMatcher = null,
    allocator: ?std.mem.Allocator = null,
    texture_cache: std.StringHashMapUnmanaged(TextureEntry) = .empty,
    missing_texture_cache: std.StringHashMapUnmanaged(void) = .empty,
    raw_inputs_dir: ?[]u8 = null,

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.matcher = logic.ComboMatcher.init(allocator);
    }

    pub fn deinit(self: *Self) void {
        if (self.matcher) |*m| m.deinit();
        if (self.allocator) |allocator| {
            var iterator = self.texture_cache.iterator();
            while (iterator.next()) |entry| {
                imgui.igUnregisterUserTexture(entry.value_ptr.tex_data);
                imgui.ImTextureData_destroy(entry.value_ptr.tex_data);
                allocator.free(entry.key_ptr.*);
            }
            self.texture_cache.deinit(allocator);

            var missing_iterator = self.missing_texture_cache.iterator();
            while (missing_iterator.next()) |entry| {
                allocator.free(entry.key_ptr.*);
            }
            self.missing_texture_cache.deinit(allocator);

            if (self.raw_inputs_dir) |path| {
                allocator.free(path);
                self.raw_inputs_dir = null;
            }
        }
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
        
        const window_width: f32 = 1200;
        const window_height: f32 = 300;
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
                     imgui.ImGuiWindowFlags_NoBackground |
                     imgui.ImGuiWindowFlags_NoNav |
                     imgui.ImGuiWindowFlags_NoMove;

        if (imgui.igBegin("Combo Suggestion HUD", null, flags)) {
            defer imgui.igEnd();
            imgui.igPushFont(null, 42.0);
            defer imgui.igPopFont();

            // Section 1: History (horizontal)
            self.drawMoveRow("History", matcher.history.items, 0.5, base_dir);
            
            imgui.igSeparator();
            
            // Section 2: Suggestions (horizontal)
            if (matcher.getBestMatch()) |combo_val| {
                const moves_val = combo_val.object.get("moves").?;
                const moves = moves_val.array;
                
                self.drawJsonMoveRow("Suggest", moves.items, 1.0, base_dir);
                
                // Show damage/hits
                if (combo_val.object.get("damage")) |dmg| {
                    drawTextSliceColored(.{ .x = 1, .y = 0.5, .z = 0.5, .w = 1 }, dmg.string);
                }
            } else {
                imgui.igText("Perform a starter move to see suggestions...");
            }
        }
    }

    fn drawMoveRow(self: *Self, label: []const u8, moves: []const logic.ComboMatcher.Move, alpha: f32, base_dir: *const sdk.misc.BaseDir) void {
        imgui.igPushStyleVar_Float(imgui.ImGuiStyleVar_Alpha, alpha);
        defer imgui.igPopStyleVar(1);

        drawTextSlice(label);
        imgui.igSameLine(260, -1);
        if (moves.len == 0) {
            drawTextSliceColored(.{ .x = 0.6, .y = 0.6, .z = 0.6, .w = 1.0 }, "(no input yet)");
            return;
        }
        
        for (moves, 0..) |move, i| {
            if (i > 0) {
                imgui.igSameLine(0, 5);
                drawTextSliceColored(.{ .x = 0.7, .y = 0.7, .z = 0.7, .w = 1.0 }, ">");
                imgui.igSameLine(0, 5);
            }
            
            const color = if (move.type == .img) 
                imgui.ImVec4{ .x = 1.0, .y = 0.8, .z = 0.2, .w = 1.0 } 
            else 
                imgui.ImVec4{ .x = 0.2, .y = 0.8, .z = 1.0, .w = 1.0 };

            if (move.type == .img and move.img != null) {
                if (!self.drawImageToken(move.img.?, base_dir)) {
                    drawTextSliceColored(color, tokenFromImageName(move.img.?));
                }
            } else {
                drawTextSliceColored(color, move.name);
            }
            if (i + 1 < moves.len) imgui.igSameLine(0, 0);
        }
    }

    fn drawJsonMoveRow(self: *Self, label: []const u8, moves: []const std.json.Value, alpha: f32, base_dir: *const sdk.misc.BaseDir) void {
        imgui.igPushStyleVar_Float(imgui.ImGuiStyleVar_Alpha, alpha);
        defer imgui.igPopStyleVar(1);

        drawTextSlice(label);
        imgui.igSameLine(260, -1);
        
        for (moves, 0..) |move_val, i| {
            if (i > 0) {
                imgui.igSameLine(0, 5);
                drawTextSliceColored(.{ .x = 0.7, .y = 0.7, .z = 0.7, .w = 1.0 }, ">");
                imgui.igSameLine(0, 5);
            }
            
            const name = move_val.object.get("name").?.string;
            const move_type = move_val.object.get("type").?.string;
            const img_name = if (move_val.object.get("img")) |img_val| img_val.string else null;
            
            const color = if (std.mem.eql(u8, move_type, "img")) 
                imgui.ImVec4{ .x = 1.0, .y = 0.8, .z = 0.2, .w = 1.0 } 
            else 
                imgui.ImVec4{ .x = 0.2, .y = 0.8, .z = 1.0, .w = 1.0 };

            if (std.mem.eql(u8, move_type, "img")) {
                if (img_name) |img_token| {
                    if (!self.drawImageToken(img_token, base_dir)) {
                        drawTextSliceColored(color, tokenFromImageName(img_token));
                    }
                } else {
                    drawTextSliceColored(color, name);
                }
            } else {
                drawTextSliceColored(color, name);
            }
            if (i + 1 < moves.len) imgui.igSameLine(0, 0);
        }
    }

    fn drawTextSlice(text: []const u8) void {
        drawTextSliceColored(.{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, text);
    }

    fn drawTextSliceColored(color: imgui.ImVec4, text: []const u8) void {
        var z_buffer: [128]u8 = undefined;
        if (text.len >= z_buffer.len) {
            imgui.igTextColored(color, "%.*s", @as(c_int, @intCast(text.len)), text.ptr);
            return;
        }

        @memcpy(z_buffer[0..text.len], text);
        z_buffer[text.len] = 0;
        const z_text = z_buffer[0..text.len :0];

        var text_size: imgui.ImVec2 = undefined;
        imgui.igCalcTextSize(&text_size, z_text.ptr, null, false, -1);

        const draw_list = imgui.igGetWindowDrawList();
        var text_pos: imgui.ImVec2 = undefined;
        imgui.igGetCursorScreenPos(&text_pos);
        const outline_color = imgui.igGetColorU32_Vec4(.{ .x = 0, .y = 0, .z = 0, .w = 1 });
        const text_color = imgui.igGetColorU32_Vec4(color);
        const thickness: f32 = 3.0;
        const offsets = [_][2]f32{
            .{ -thickness, -thickness }, .{ 0, -thickness }, .{ thickness, -thickness },
            .{ -thickness, 0 },                               .{ thickness, 0 },
            .{ -thickness, thickness },  .{ 0, thickness },  .{ thickness, thickness },
        };

        for (offsets) |off| {
            imgui.ImDrawList_AddText_Vec2(
                draw_list,
                .{ .x = text_pos.x + off[0], .y = text_pos.y + off[1] },
                outline_color,
                z_text,
                null,
            );
        }
        imgui.ImDrawList_AddText_Vec2(draw_list, text_pos, text_color, z_text, null);
        imgui.igDummy(text_size);
    }

    fn tokenFromImageName(img_name: []const u8) []const u8 {
        if (std.mem.eql(u8, img_name, "follow.svg")) return ">";
        if (std.mem.endsWith(u8, img_name, ".svg")) {
            return img_name[0 .. img_name.len - 4];
        }
        return img_name;
    }

    fn drawImageToken(self: *Self, img_name: []const u8, base_dir: *const sdk.misc.BaseDir) bool {
        if (self.getTexture(img_name, base_dir)) |texture| {
            const draw_size = imgui.ImVec2{ .x = 44, .y = 44 };
            imgui.igImage(
                texture.tex_ref,
                draw_size,
                .{ .x = 0, .y = 0 },
                .{ .x = 1, .y = 1 },
            );
            return true;
        }
        return false;
    }

    fn getTexture(self: *Self, img_name: []const u8, base_dir: *const sdk.misc.BaseDir) ?TextureEntry {
        if (self.texture_cache.get(img_name)) |texture| {
            return texture;
        }
        if (self.missing_texture_cache.contains(img_name)) {
            return null;
        }
        self.loadTexture(img_name, base_dir);
        return self.texture_cache.get(img_name);
    }

    fn loadTexture(self: *Self, img_name: []const u8, base_dir: *const sdk.misc.BaseDir) void {
        const allocator = self.allocator orelse return;
        self.resolveRawInputsDir(base_dir);
        const raw_dir = self.raw_inputs_dir orelse return;

        var raw_name_buffer: [64]u8 = undefined;
        const raw_name = toRawFileName(img_name, &raw_name_buffer) orelse {
            self.markTextureMissing(img_name);
            return;
        };
        var path_buffer: [sdk.os.max_file_path_length]u8 = undefined;
        const full_path = std.fmt.bufPrintZ(&path_buffer, "{s}\\{s}", .{ raw_dir, raw_name }) catch return;

        const file = std.fs.openFileAbsolute(full_path, .{}) catch {
            self.markTextureMissing(img_name);
            return;
        };
        defer file.close();
        const expected_bytes = raster_icon_size * raster_icon_size * 4;
        const bytes = file.readToEndAlloc(allocator, expected_bytes + 1) catch {
            self.markTextureMissing(img_name);
            return;
        };
        defer allocator.free(bytes);
        if (bytes.len != expected_bytes) {
            self.markTextureMissing(img_name);
            return;
        }

        const tex_data = imgui.ImTextureData_ImTextureData();
        imgui.ImTextureData_Create(tex_data, imgui.ImTextureFormat_RGBA32, raster_icon_size, raster_icon_size);
        const pixels_any = imgui.ImTextureData_GetPixels(tex_data) orelse {
            imgui.ImTextureData_destroy(tex_data);
            return;
        };
        const pixels: [*]u8 = @ptrCast(@alignCast(pixels_any));
        @memcpy(pixels[0..expected_bytes], bytes);

        imgui.igRegisterUserTexture(tex_data);
        var tex_ref: imgui.ImTextureRef = undefined;
        imgui.ImTextureData_GetTexRef(&tex_ref, tex_data);

        const key = allocator.dupe(u8, img_name) catch {
            imgui.igUnregisterUserTexture(tex_data);
            imgui.ImTextureData_destroy(tex_data);
            return;
        };
        self.texture_cache.put(allocator, key, .{
            .tex_data = tex_data,
            .tex_ref = tex_ref,
        }) catch {
            allocator.free(key);
            imgui.igUnregisterUserTexture(tex_data);
            imgui.ImTextureData_destroy(tex_data);
        };
    }

    fn markTextureMissing(self: *Self, img_name: []const u8) void {
        const allocator = self.allocator orelse return;
        if (self.missing_texture_cache.contains(img_name)) return;
        const key = allocator.dupe(u8, img_name) catch return;
        self.missing_texture_cache.put(allocator, key, {}) catch {
            allocator.free(key);
        };
    }

    fn resolveRawInputsDir(self: *Self, base_dir: *const sdk.misc.BaseDir) void {
        if (self.raw_inputs_dir != null) return;
        const allocator = self.allocator orelse return;
        const candidate_paths = [_][]const u8{
            "assets\\inputs_raw",
            "..\\assets\\inputs_raw",
            "src\\dll\\ui\\assets\\inputs_raw",
            "..\\src\\dll\\ui\\assets\\inputs_raw",
            "..\\..\\src\\dll\\ui\\assets\\inputs_raw",
        };
        var path_buffer: [sdk.os.max_file_path_length]u8 = undefined;
        for (candidate_paths) |candidate| {
            const path = base_dir.getPath(&path_buffer, candidate) catch continue;
            var dir = std.fs.openDirAbsolute(path, .{}) catch continue;
            dir.close();
            self.raw_inputs_dir = allocator.dupe(u8, std.mem.sliceTo(path, 0)) catch null;
            if (self.raw_inputs_dir != null) break;
        }
    }

    fn toRawFileName(img_name: []const u8, out: *[64]u8) ?[]const u8 {
        if (img_name.len < 5) return null;
        if (!std.mem.endsWith(u8, img_name, ".svg")) return null;
        const stem_len = img_name.len - 4;
        if (stem_len + 5 > out.len) return null;
        @memcpy(out[0..stem_len], img_name[0..stem_len]);
        @memcpy(out[stem_len .. stem_len + 5], ".rgba");
        return out[0 .. stem_len + 5];
    }
};
