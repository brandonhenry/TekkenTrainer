const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("root.zig");

pub const SettingsWindow = struct {
    is_open: bool = false,
    navigation_layout: ui.NavigationLayout = .{},

    const Self = @This();
    pub const name = "Settings";

    pub fn draw(self: *Self, settings: *model.Settings) void {
        if (!self.is_open) {
            return;
        }
        const render_content = imgui.igBegin(name, &self.is_open, imgui.ImGuiWindowFlags_HorizontalScrollbar);
        defer imgui.igEnd();
        if (!render_content) {
            return;
        }
        self.navigation_layout.draw(settings, &.{
            .{
                .name = "Hit Lines",
                .content = struct {
                    fn call(s: *model.Settings) void {
                        drawPlayerSettings(
                            model.HitLinesSettings,
                            &s.hit_lines,
                            drawHitLinesSettings,
                        );
                    }
                }.call,
            },
            .{
                .name = "Hurt Cylinders",
                .content = struct {
                    fn call(s: *model.Settings) void {
                        drawPlayerSettings(
                            model.HurtCylindersSettings,
                            &s.hurt_cylinders,
                            drawHurtCylindersSettings,
                        );
                    }
                }.call,
            },
            .{
                .name = "Collision Spheres",
                .content = struct {
                    fn call(s: *model.Settings) void {
                        drawPlayerSettings(
                            model.CollisionSpheresSettings,
                            &s.collision_spheres,
                            drawCollisionSpheresSettings,
                        );
                    }
                }.call,
            },
            .{
                .name = "Skeletons",
                .content = struct {
                    fn call(s: *model.Settings) void {
                        drawPlayerSettings(
                            model.SkeletonSettings,
                            &s.skeletons,
                            drawSkeletonSettings,
                        );
                    }
                }.call,
            },
            .{
                .name = "Forward Directions",
                .content = struct {
                    fn call(s: *model.Settings) void {
                        drawPlayerSettings(
                            model.ForwardDirectionSettings,
                            &s.forward_directions,
                            drawForwardDirectionsSettings,
                        );
                    }
                }.call,
            },
            .{
                .name = "Floor",
                .content = struct {
                    fn call(s: *model.Settings) void {
                        drawFloorSettings(&s.floor);
                    }
                }.call,
            },
            .{
                .name = "Ingame Camera",
                .content = struct {
                    fn call(s: *model.Settings) void {
                        drawIngameCameraSettings(&s.ingame_camera);
                    }
                }.call,
            },
        });
    }
};

fn drawPlayerSettings(
    comptime Type: type,
    settings: *model.PlayerSettings(Type),
    drawContent: *const fn (settings: *Type) void,
) void {
    const same_name = "Same Settings";
    const id_separated_name = "Player 1 / Player 2";
    const side_separated_name = "Left Player / Right Player";
    const role_separated_name = "Main Player / Secondary Player";
    const preview_value = switch (settings.*) {
        .same => same_name,
        .id_separated => id_separated_name,
        .side_separated => side_separated_name,
        .role_separated => role_separated_name,
    };
    if (imgui.igBeginCombo("Player Separation", preview_value, 0)) {
        defer imgui.igEndCombo();
        if (imgui.igSelectable_Bool(same_name, settings.* == .same, 0, .{})) {
            settings.* = switch (settings.*) {
                .same => |s| .{ .same = s },
                .id_separated => |s| .{ .same = s.player_1 },
                .side_separated => |s| .{ .same = s.left },
                .role_separated => |s| .{ .same = s.main },
            };
        }
        if (imgui.igSelectable_Bool(id_separated_name, settings.* == .id_separated, 0, .{})) {
            settings.* = switch (settings.*) {
                .same => |s| .{ .id_separated = .{ .player_1 = s, .player_2 = s } },
                .id_separated => |s| .{ .id_separated = .{ .player_1 = s.player_1, .player_2 = s.player_2 } },
                .side_separated => |s| .{ .id_separated = .{ .player_1 = s.left, .player_2 = s.right } },
                .role_separated => |s| .{ .id_separated = .{ .player_1 = s.main, .player_2 = s.secondary } },
            };
        }
        if (imgui.igSelectable_Bool(side_separated_name, settings.* == .side_separated, 0, .{})) {
            settings.* = switch (settings.*) {
                .same => |s| .{ .side_separated = .{ .left = s, .right = s } },
                .id_separated => |s| .{ .side_separated = .{ .left = s.player_1, .right = s.player_2 } },
                .side_separated => |s| .{ .side_separated = .{ .left = s.left, .right = s.right } },
                .role_separated => |s| .{ .side_separated = .{ .left = s.main, .right = s.secondary } },
            };
        }
        if (imgui.igSelectable_Bool(role_separated_name, settings.* == .role_separated, 0, .{})) {
            settings.* = switch (settings.*) {
                .same => |s| .{ .role_separated = .{ .main = s, .secondary = s } },
                .id_separated => |s| .{ .role_separated = .{ .main = s.player_1, .secondary = s.player_2 } },
                .side_separated => |s| .{ .role_separated = .{ .main = s.left, .secondary = s.right } },
                .role_separated => |s| .{ .role_separated = .{ .main = s.main, .secondary = s.secondary } },
            };
        }
    }

    switch (settings.*) {
        .same => |*s| drawContent(s),
        .id_separated => |*s| {
            if (imgui.igBeginTable("players", 2, imgui.ImGuiTableFlags_BordersInner, .{}, 0)) {
                defer imgui.igEndTable();
                if (imgui.igTableNextColumn()) {
                    imgui.igPushID_Str("player_1");
                    defer imgui.igPopID();
                    imgui.igSeparatorText("Player 1");
                    drawContent(&s.player_1);
                }
                if (imgui.igTableNextColumn()) {
                    imgui.igPushID_Str("player_2");
                    defer imgui.igPopID();
                    imgui.igSeparatorText("Player 2");
                    drawContent(&s.player_2);
                }
            }
        },
        .side_separated => |*s| {
            if (imgui.igBeginTable("players", 2, imgui.ImGuiTableFlags_BordersInner, .{}, 0)) {
                defer imgui.igEndTable();
                if (imgui.igTableNextColumn()) {
                    imgui.igPushID_Str("left");
                    defer imgui.igPopID();
                    imgui.igSeparatorText("Left Player");
                    drawContent(&s.left);
                }
                if (imgui.igTableNextColumn()) {
                    imgui.igPushID_Str("right");
                    defer imgui.igPopID();
                    imgui.igSeparatorText("Right Player");
                    drawContent(&s.right);
                }
            }
        },
        .role_separated => |*s| {
            if (imgui.igBeginTable("players", 2, imgui.ImGuiTableFlags_BordersInner, .{}, 0)) {
                defer imgui.igEndTable();
                if (imgui.igTableNextColumn()) {
                    imgui.igPushID_Str("main");
                    defer imgui.igPopID();
                    imgui.igSeparatorText("Main Player");
                    drawContent(&s.main);
                }
                if (imgui.igTableNextColumn()) {
                    imgui.igPushID_Str("secondary");
                    defer imgui.igPopID();
                    imgui.igSeparatorText("Secondary Player");
                    drawContent(&s.secondary);
                }
            }
        },
    }
}

fn drawHitLinesSettings(settings: *model.HitLinesSettings) void {
    const defaults = model.HitLinesSettings{};

    drawBool("Enabled", &settings.enabled, defaults.enabled);
    imgui.igBeginDisabled(!settings.enabled);
    defer imgui.igEndDisabled();

    const drawColors = struct {
        fn call(
            label: [:0]const u8,
            value: *std.EnumArray(model.AttackType, sdk.math.Vec4),
            default_value: std.EnumArray(model.AttackType, sdk.math.Vec4),
        ) void {
            imgui.igText("%s", label.ptr);
            imgui.igPushID_Str(label);
            defer imgui.igPopID();
            imgui.igIndent(0);
            defer imgui.igUnindent(0);
            inline for (@typeInfo(model.AttackType).@"enum".fields) |*field| {
                const attack_type: model.AttackType = @enumFromInt(field.value);
                const color_label = switch (attack_type) {
                    .not_attack => "Not Attack",
                    .high => "High",
                    .mid => "Mid",
                    .low => "Low",
                    .special_low => "Special Low",
                    .unblockable_high => "Unblockable High",
                    .unblockable_mid => "Unblockable Mid",
                    .unblockable_low => "Unblockable Low",
                    .throw => "Throw",
                    .projectile => "Projectile",
                    .antiair_only => "Anti-Air Only",
                };
                drawColor(color_label, value.getPtr(attack_type), default_value.get(attack_type));
            }
        }
    }.call;
    const drawColorsAndThickness = struct {
        fn call(
            label: [:0]const u8,
            value: *model.HitLinesSettings.ColorsAndThickness,
            default_value: model.HitLinesSettings.ColorsAndThickness,
        ) void {
            imgui.igText("%s", label.ptr);
            imgui.igPushID_Str(label);
            defer imgui.igPopID();
            imgui.igIndent(0);
            defer imgui.igUnindent(0);
            drawColors("Colors", &value.colors, default_value.colors);
            drawThickness("Thickness", &value.thickness, default_value.thickness);
        }
    }.call;
    const drawFillAndOutline = struct {
        fn call(
            label: [:0]const u8,
            value: *model.HitLinesSettings.FillAndOutline,
            default_value: model.HitLinesSettings.FillAndOutline,
        ) void {
            imgui.igText("%s", label.ptr);
            imgui.igPushID_Str(label);
            defer imgui.igPopID();
            imgui.igIndent(0);
            defer imgui.igUnindent(0);
            drawColorsAndThickness("Fill", &value.fill, default_value.fill);
            drawColorsAndThickness("Outline", &value.outline, default_value.outline);
        }
    }.call;

    drawFillAndOutline("Normal", &settings.normal, defaults.normal);
    drawFillAndOutline("Inactive Or Crushed", &settings.inactive_or_crushed, defaults.inactive_or_crushed);
    drawDuration("Duration", &settings.duration, defaults.duration);
}

fn drawHurtCylindersSettings(settings: *model.HurtCylindersSettings) void {
    const defaults = model.HurtCylindersSettings{};

    drawBool("Enabled", &settings.enabled, defaults.enabled);
    imgui.igBeginDisabled(!settings.enabled);
    defer imgui.igEndDisabled();

    const drawColorAndThickness = struct {
        fn call(
            label: [:0]const u8,
            value: *model.HurtCylindersSettings.ColorAndThickness,
            default_value: model.HurtCylindersSettings.ColorAndThickness,
        ) void {
            imgui.igText("%s", label.ptr);
            imgui.igPushID_Str(label);
            defer imgui.igPopID();
            imgui.igIndent(0);
            defer imgui.igUnindent(0);
            drawColor("Color", &value.color, default_value.color);
            drawThickness("Thickness", &value.thickness, default_value.thickness);
        }
    }.call;
    const drawColorThicknessAndDuration = struct {
        fn call(
            label: [:0]const u8,
            value: *model.HurtCylindersSettings.ColorThicknessAndDuration,
            default_value: model.HurtCylindersSettings.ColorThicknessAndDuration,
        ) void {
            imgui.igText("%s", label.ptr);
            imgui.igPushID_Str(label);
            defer imgui.igPopID();
            imgui.igIndent(0);
            defer imgui.igUnindent(0);
            drawColor("Color", &value.color, default_value.color);
            drawThickness("Thickness", &value.thickness, default_value.thickness);
            drawDuration("Duration", &value.duration, default_value.duration);
        }
    }.call;
    const drawCrushing = struct {
        fn call(
            label: [:0]const u8,
            value: *model.HurtCylindersSettings.Crushing,
            default_value: model.HurtCylindersSettings.Crushing,
        ) void {
            imgui.igText("%s", label.ptr);
            imgui.igPushID_Str(label);
            defer imgui.igPopID();
            imgui.igIndent(0);
            defer imgui.igUnindent(0);
            drawColorAndThickness("Normal", &value.normal, default_value.normal);
            drawColorAndThickness("High Crushing", &value.high_crushing, default_value.high_crushing);
            drawColorAndThickness("Low Crushing", &value.low_crushing, default_value.low_crushing);
            drawColorAndThickness("Invincible", &value.invincible, default_value.invincible);
        }
    }.call;

    drawCrushing("Not Power-Crushing", &settings.normal, defaults.normal);
    drawCrushing("Power-Crushing", &settings.power_crushing, defaults.power_crushing);
    drawColorThicknessAndDuration("Connected", &settings.connected, defaults.connected);
    drawColorThicknessAndDuration("Lingering", &settings.lingering, defaults.lingering);
}

fn drawCollisionSpheresSettings(settings: *model.CollisionSpheresSettings) void {
    const defaults = model.CollisionSpheresSettings{};

    drawBool("Enabled", &settings.enabled, defaults.enabled);
    imgui.igBeginDisabled(!settings.enabled);
    defer imgui.igEndDisabled();

    drawColor("Color", &settings.color, defaults.color);
    drawThickness("Thickness", &settings.thickness, defaults.thickness);
}

fn drawSkeletonSettings(settings: *model.SkeletonSettings) void {
    const defaults = model.SkeletonSettings{};

    drawBool("Enabled", &settings.enabled, defaults.enabled);
    imgui.igBeginDisabled(!settings.enabled);
    defer imgui.igEndDisabled();

    const drawColors = struct {
        fn call(
            label: [:0]const u8,
            value: *std.EnumArray(model.Blocking, sdk.math.Vec4),
            default_value: std.EnumArray(model.Blocking, sdk.math.Vec4),
        ) void {
            imgui.igText("%s", label.ptr);
            imgui.igPushID_Str(label);
            defer imgui.igPopID();
            imgui.igIndent(0);
            defer imgui.igUnindent(0);
            inline for (@typeInfo(model.Blocking).@"enum".fields) |*field| {
                const blocking: model.Blocking = @enumFromInt(field.value);
                const color_label = switch (blocking) {
                    .not_blocking => "Not Blocking",
                    .neutral_blocking_mids => "Neutral Blocking Mids",
                    .fully_blocking_mids => "Fully Blocking Mids",
                    .neutral_blocking_lows => "Neutral Blocking Lows",
                    .fully_blocking_lows => "Fully Blocking Lows",
                };
                drawColor(color_label, value.getPtr(blocking), default_value.get(blocking));
            }
        }
    }.call;

    drawColors("Colors", &settings.colors, defaults.colors);
    drawThickness("Thickness", &settings.thickness, defaults.thickness);
    drawFloat("Can't Move Alpha", &settings.cant_move_alpha, defaults.cant_move_alpha, 0.01, 0, 1, "%.2f", 0);
}

fn drawForwardDirectionsSettings(settings: *model.ForwardDirectionSettings) void {
    const defaults = model.ForwardDirectionSettings{};

    drawBool("Enabled", &settings.enabled, defaults.enabled);
    imgui.igBeginDisabled(!settings.enabled);
    defer imgui.igEndDisabled();

    drawColor("Color", &settings.color, defaults.color);
    drawLength("Length", &settings.length, defaults.length);
    drawThickness("Thickness", &settings.thickness, defaults.thickness);
}

fn drawFloorSettings(settings: *model.FloorSettings) void {
    const defaults = model.FloorSettings{};

    drawBool("Enabled", &settings.enabled, defaults.enabled);
    imgui.igBeginDisabled(!settings.enabled);
    defer imgui.igEndDisabled();

    drawColor("Color", &settings.color, defaults.color);
    drawThickness("Thickness", &settings.thickness, defaults.thickness);
}

fn drawIngameCameraSettings(settings: *model.IngameCameraSettings) void {
    const defaults = model.IngameCameraSettings{};

    drawBool("Enabled", &settings.enabled, defaults.enabled);
    imgui.igBeginDisabled(!settings.enabled);
    defer imgui.igEndDisabled();

    drawColor("Color", &settings.color, defaults.color);
    drawLength("Length", &settings.length, defaults.length);
    drawThickness("Thickness", &settings.thickness, defaults.thickness);
}

fn drawBool(label: [:0]const u8, value: *bool, default_value: bool) void {
    _ = imgui.igCheckbox(label, value);
    imgui.igSameLine(0, -1);
    drawDefaultButton(value, default_value);
}

fn drawLength(label: [:0]const u8, value: *f32, default_value: f32) void {
    drawFloat(label, value, default_value, 1, 0, 10000, "%.0f cm", 0);
}

fn drawThickness(label: [:0]const u8, value: *f32, default_value: f32) void {
    drawFloat(label, value, default_value, 0.1, 0, 100, "%.1f px", 0);
}

fn drawDuration(label: [:0]const u8, value: *f32, default_value: f32) void {
    drawFloat(label, value, default_value, 0.1, 0, 100, "%.1f s", 0);
}

fn drawColor(label: [:0]const u8, value: *sdk.math.Vec4, default_value: sdk.math.Vec4) void {
    imgui.igPushID_Str(label);
    drawDefaultButton(value, default_value);
    imgui.igPopID();
    imgui.igSameLine(0, -1);
    _ = imgui.igColorEdit4(label, &value.array, 0);
}

fn drawFloat(
    label: [:0]const u8,
    value: *f32,
    default_value: f32,
    step: f32,
    min: f32,
    max: f32,
    format: [:0]const u8,
    flags: imgui.ImGuiInputTextFlags,
) void {
    imgui.igPushID_Str(label);
    drawDefaultButton(value, default_value);
    imgui.igPopID();
    imgui.igSameLine(0, -1);
    _ = imgui.igDragFloat(label, value, step, min, max, format, flags);
}

fn drawDefaultButton(value_pointer: anytype, default_value: @TypeOf(value_pointer.*)) void {
    imgui.igBeginDisabled(std.meta.eql(value_pointer.*, default_value));
    defer imgui.igEndDisabled();
    if (imgui.igButton(" ↺ ###default", .{})) {
        value_pointer.* = default_value;
    }
    if (imgui.igIsItemHovered(0)) {
        imgui.igSetTooltip("Reset To Default Value");
    }
}
