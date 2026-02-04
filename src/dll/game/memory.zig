const std = @import("std");
const builtin = @import("builtin");
const build_info = @import("build_info");
const sdk = @import("../../sdk/root.zig");
const game = @import("root.zig");

pub fn Memory(comptime game_id: build_info.Game) type {
    return struct {
        player_1: sdk.memory.StructProxy(game.Player(game_id)),
        player_2: sdk.memory.StructProxy(game.Player(game_id)),
        player_1_animation: sdk.memory.StructProxy(game.Animation),
        player_2_animation: sdk.memory.StructProxy(game.Animation),
        camera: sdk.memory.Proxy(game.Camera(game_id)),
        functions: Functions,

        const Self = @This();
        pub const Functions = struct {
            tick: ?*const game.TickFunction(game_id) = null,
            updateCamera: ?*const game.UpdateCameraFunction = null,
            unrealFree: ?*const game.UnrealFreeFunction = null,
            findUClass: ?*const game.FindUClassFunction = null,
            getObjectsOfClass: ?*const game.GetObjectsOfClassFunction = null,
            decryptHealth: (switch (game_id) {
                .t7 => void,
                .t8 => ?*const game.DecryptT8HealthFunction,
            }) = switch (game_id) {
                .t7 => {},
                .t8 => null,
            },
        };
        pub const PartialCopy = struct {
            player_1: sdk.misc.Partial(game.Player(game_id)) = .{},
            player_2: sdk.misc.Partial(game.Player(game_id)) = .{},
            player_1_animation: sdk.misc.Partial(game.Animation) = .{},
            player_2_animation: sdk.misc.Partial(game.Animation) = .{},
            camera: ?game.Camera(game_id) = null,
        };

        const pattern_cache_file_name = "pattern_cache_" ++ @tagName(game_id) ++ ".json";

        pub fn init(
            allocator: std.mem.Allocator,
            base_dir: ?*const sdk.misc.BaseDir,
            last_camera_manager_address_pointer: *const usize,
        ) Self {
            var cache = initPatternCache(allocator, base_dir, pattern_cache_file_name) catch |err| block: {
                sdk.misc.error_context.append("Failed to initialize pattern cache.", .{});
                sdk.misc.error_context.logError(err);
                break :block null;
            };
            defer if (cache) |*pattern_cache| {
                deinitPatternCache(pattern_cache, base_dir, pattern_cache_file_name);
            };
            return switch (game_id) {
                .t7 => t7Init(&cache, last_camera_manager_address_pointer),
                .t8 => t8Init(&cache, last_camera_manager_address_pointer),
            };
        }

        pub fn takePartialCopy(self: *const Self) PartialCopy {
            return .{
                .player_1 = self.player_1.takePartialCopy(),
                .player_2 = self.player_2.takePartialCopy(),
                .player_1_animation = self.player_1_animation.takePartialCopy(),
                .player_2_animation = self.player_2_animation.takePartialCopy(),
                .camera = self.camera.takeCopy(),
            };
        }

        fn t7Init(cache: *?sdk.memory.PatternCache, last_camera_manager_address_pointer: *const usize) Self {
            const player_offsets = structOffsets(game.Player(.t7), .{
                .is_picked_by_main_player = 0x9,
                .character_id = 0xD8,
                .transform_matrix = 0x130,
                .floor_z = 0x1B0,
                .rotation = 0x1BE,
                .animation_frame = 0x1D4,
                .animation_pointer = 0x218,
                .state_flags = 0x264,
                .attack_damage = 0x324,
                .attack_type = 0x328,
                .animation_id = 0x350,
                .can_move = 0x390,
                .animation_total_frames = 0x39C,
                .hit_outcome = 0x3D8,
                .simple_state = 0x428,
                .power_crushing = 0x6C0,
                .frames_since_round_start = 0x95C,
                .in_rage = 0xC00,
                .phase_flags = 0xC40,
                .input_side = 0xDE4,
                .input = 0xE0C,
                .hit_lines = 0xE50,
                .hurt_cylinders = 0xF10,
                .collision_spheres = 0x10D0,
                .health = 0x14E8,
            });
            const animation_offsets = structOffsets(game.Animation, .{
                .airborne_start = 0x6C,
                .airborne_end = 0x70,
            });
            return .{
                .player_1 = structProxy("player_1", game.Player(.t7), .{
                    relativeOffset(u32, add(0x3, pattern(cache, "48 8B 15 ?? ?? ?? ?? 44 8B C3"))),
                    0x0,
                }, player_offsets),
                .player_2 = structProxy("player_2", game.Player(.t7), .{
                    relativeOffset(u32, add(0xD, pattern(cache, "48 8B 15 ?? ?? ?? ?? 44 8B C3"))),
                    0x0,
                }, player_offsets),
                .player_1_animation = structProxy("player_1_animation", game.Animation, .{
                    relativeOffset(u32, add(0x3, pattern(cache, "48 8B 15 ?? ?? ?? ?? 44 8B C3"))),
                    player_offsets.animation_pointer.getOffsets()[0].?,
                    0x0,
                }, animation_offsets),
                .player_2_animation = structProxy("player_2_animation", game.Animation, .{
                    relativeOffset(u32, add(0xD, pattern(cache, "48 8B 15 ?? ?? ?? ?? 44 8B C3"))),
                    player_offsets.animation_pointer.getOffsets()[0].?,
                    0x0,
                }, animation_offsets),
                .camera = proxy("camera", game.Camera(.t7), .{
                    @intFromPtr(last_camera_manager_address_pointer),
                    0x03F8,
                }),
                .functions = .{
                    .tick = functionPointer(
                        "tick",
                        game.TickFunction(.t7),
                        pattern(cache, "4C 8B DC 55 41 57 49 8D 6B A1 48 81 EC E8"),
                    ),
                    .updateCamera = functionPointer(
                        "updateCamera",
                        game.UpdateCameraFunction,
                        pattern(cache, "4C 8B DC 55 49 8D AB 68 FC"),
                    ),
                    .unrealFree = functionPointer(
                        "unrealFree",
                        game.UnrealFreeFunction,
                        pattern(cache, "48 85 C9 74 ?? 53 48 83 EC 20 48 8B D9 48 8B 0D"),
                    ),
                    .findUClass = functionPointer(
                        "findUClass",
                        game.FindUClassFunction,
                        relativeOffset(i32, add(0x8, pattern(cache, "45 33 C0 48 83 C9 FF E8"))),
                    ),
                    .getObjectsOfClass = functionPointer(
                        "getObjectsOfClass",
                        game.GetObjectsOfClassFunction,
                        pattern(cache, "48 89 5C 24 18 48 89 74 24 20 55 57 41 54 41 56 41 57 48 8D 6C 24 D1 48 81 EC A0 00 00 00"),
                    ),
                    .decryptHealth = {},
                },
            };
        }

        fn t8Init(cache: *?sdk.memory.PatternCache, last_camera_manager_address_pointer: *const usize) Self {
            const player_offsets = structOffsets(game.Player(.t8), .{
                .is_picked_by_main_player = 0x9,
                .character_id = 0x168,
                .transform_matrix = 0x200,
                .floor_z = 0x354,
                .rotation = 0x376,
                .animation_frame = deref(u32, add(8, pattern(
                    cache,
                    "8B 81 ?? ?? 00 00 39 81 ?? ?? 00 00 0F 84 ?? ?? 00 00 48 C7 81",
                ))), // 0x390
                .animation_pointer = 0x3D8,
                .state_flags = 0x434,
                .attack_damage = 0x504,
                .attack_type = deref(u32, add(2, pattern(
                    cache,
                    "89 8E ?? ?? 00 00 48 8D 8E ?? ?? 00 00 E8 ?? ?? ?? ?? 48 8D 8E ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 86",
                ))), // 0x510
                .animation_id = 0x548,
                .can_move = 0x5C8,
                .animation_total_frames = 0x5D4,
                .hit_outcome = 0x610,
                .simple_state = 0x660,
                .is_a_parry_move = 0xA2C,
                .power_crushing = 0xBEC,
                .in_rage = 0xF51,
                .used_rage = 0xF88,
                .frames_since_round_start = 0x1590,
                .phase_flags = 0x1BC4,
                .heat_gauge = 0x2440,
                .used_heat = 0x2450,
                .in_heat = 0x2471,
                .input_side = 0x27BC,
                .input = 0x27E4,
                .hit_lines = 0x2850,
                .hurt_cylinders = 0x2C50,
                .collision_spheres = 0x3090,
                .health = 0x3810,
            });
            const animation_offsets = structOffsets(game.Animation, .{
                .airborne_start = 0x124,
                .airborne_end = 0x128,
            });
            const self = Self{
                .player_1 = structProxy("player_1", game.Player(.t8), .{
                    relativeOffset(u32, add(3, pattern(cache, "4C 89 35 ?? ?? ?? ?? 41 88 5E 28"))),
                    0x30,
                    0x0,
                }, player_offsets),
                .player_2 = structProxy("player_2", game.Player(.t8), .{
                    relativeOffset(u32, add(3, pattern(cache, "4C 89 35 ?? ?? ?? ?? 41 88 5E 28"))),
                    0x38,
                    0x0,
                }, player_offsets),
                .player_1_animation = structProxy("player_1_animation", game.Animation, .{
                    relativeOffset(u32, add(3, pattern(cache, "4C 89 35 ?? ?? ?? ?? 41 88 5E 28"))),
                    0x30,
                    player_offsets.animation_pointer.getOffsets()[0].?,
                    0x0,
                }, animation_offsets),
                .player_2_animation = structProxy("player_2_animation", game.Animation, .{
                    relativeOffset(u32, add(3, pattern(cache, "4C 89 35 ?? ?? ?? ?? 41 88 5E 28"))),
                    0x38,
                    player_offsets.animation_pointer.getOffsets()[0].?,
                    0x0,
                }, animation_offsets),
                .camera = proxy("camera", game.Camera(.t8), .{
                    @intFromPtr(last_camera_manager_address_pointer),
                    0x22D0,
                }),
                .functions = .{
                    .tick = functionPointer(
                        "tick",
                        game.TickFunction(.t8),
                        pattern(cache, "48 8B 0D ?? ?? ?? ?? 48 85 C9 74 0A 48 8B 01 0F 28 C8"),
                    ),
                    .updateCamera = functionPointer(
                        "updateCamera",
                        game.UpdateCameraFunction,
                        pattern(cache, "48 8B C4 48 89 58 18 55 56 57 48 81 EC 50"),
                    ),
                    .unrealFree = functionPointer(
                        "unrealFree",
                        game.UnrealFreeFunction,
                        pattern(cache, "48 85 C9 74 ?? 53 48 83 EC 20 48 8B D9 48 8B 0D"),
                    ),
                    .findUClass = functionPointer(
                        "findUClass",
                        game.FindUClassFunction,
                        relativeOffset(i32, add(0x7, pattern(cache, "45 33 C0 49 8B CF E8 ?? ?? ?? ?? 48 8B 4C 24 60"))),
                    ),
                    .getObjectsOfClass = functionPointer(
                        "getObjectsOfClass",
                        game.GetObjectsOfClassFunction,
                        relativeOffset(i32, add(0x1, pattern(cache, "E8 ?? ?? ?? ?? 90 48 89 6C 24 30"))),
                    ),
                    .decryptHealth = functionPointer(
                        "decryptHealth",
                        game.DecryptT8HealthFunction,
                        pattern(cache, "48 89 5C 24 08 57 48 83 EC ?? 48 8D 79 08 48 8B D9 48 8B CF E8 ?? ?? ?? ?? 85 C0"),
                    ),
                },
            };
            game.conversion_globals.decryptT8Health = self.functions.decryptHealth;
            return self;
        }

        fn initPatternCache(
            allocator: std.mem.Allocator,
            base_dir: ?*const sdk.misc.BaseDir,
            file_name: []const u8,
        ) !sdk.memory.PatternCache {
            const main_module = sdk.os.Module.getMain() catch |err| {
                sdk.misc.error_context.append("Failed to get main module.", .{});
                return err;
            };
            const range = main_module.getMemoryRange() catch |err| {
                sdk.misc.error_context.append("Failed to get main module memory range.", .{});
                return err;
            };
            var cache = sdk.memory.PatternCache.init(allocator, range);
            if (base_dir) |dir| {
                loadPatternCache(&cache, dir, file_name) catch |err| {
                    sdk.misc.error_context.append("Failed to load memory pattern cache. Using empty cache.", .{});
                    sdk.misc.error_context.logWarning(err);
                };
            }
            return cache;
        }

        fn deinitPatternCache(
            cache: *sdk.memory.PatternCache,
            base_dir: ?*const sdk.misc.BaseDir,
            file_name: []const u8,
        ) void {
            if (base_dir) |dir| {
                savePatternCache(cache, dir, file_name) catch |err| {
                    sdk.misc.error_context.append("Failed to save memory pattern cache.", .{});
                    sdk.misc.error_context.logWarning(err);
                };
            }
            cache.deinit();
        }

        fn loadPatternCache(cache: *sdk.memory.PatternCache, base_dir: *const sdk.misc.BaseDir, file_name: []const u8) !void {
            var buffer: [sdk.os.max_file_path_length]u8 = undefined;
            const file_path = base_dir.getPath(&buffer, file_name) catch |err| {
                sdk.misc.error_context.append("Failed to construct file path.", .{});
                return err;
            };

            const executable_timestamp = sdk.os.getExecutableTimestamp() catch |err| {
                sdk.misc.error_context.append("Failed to get executable timestamp.", .{});
                return err;
            };

            return cache.load(file_path, executable_timestamp);
        }

        fn savePatternCache(cache: *sdk.memory.PatternCache, base_dir: *const sdk.misc.BaseDir, file_name: []const u8) !void {
            var buffer: [sdk.os.max_file_path_length]u8 = undefined;
            const file_path = base_dir.getPath(&buffer, file_name) catch |err| {
                sdk.misc.error_context.append("Failed to construct file path.", .{});
                return err;
            };

            const executable_timestamp = sdk.os.getExecutableTimestamp() catch |err| {
                sdk.misc.error_context.append("Failed to get executable timestamp.", .{});
                return err;
            };

            return cache.save(file_path, executable_timestamp);
        }
    };
}

fn structOffsets(comptime Struct: type, offsets: anytype) sdk.misc.FieldMap(Struct, sdk.memory.PointerTrail, null) {
    @setEvalBranchQuota(2000);
    const struct_fields = switch (@typeInfo(Struct)) {
        .@"struct" => |*info| info.fields,
        else => @compileError("Expecting Struct to be a struct type but got: " ++ @typeName(Struct)),
    };
    const offsets_fields = switch (@typeInfo(@TypeOf(offsets))) {
        .@"struct" => |*info| info.fields,
        else => @compileError("Expecting offsets to be of a struct type but got: " ++ @typeName(@TypeOf(offsets))),
    };
    comptime {
        var struct_field_paired = [1]bool{false} ** struct_fields.len;
        var offsets_field_paired = [1]bool{false} ** offsets_fields.len;
        for (struct_fields, &struct_field_paired) |*struct_field, *struct_paired| {
            for (offsets_fields, &offsets_field_paired) |*offsets_field, *offset_paired| {
                if (std.mem.eql(u8, offsets_field.name, struct_field.name)) {
                    struct_paired.* = true;
                    offset_paired.* = true;
                    break;
                }
            }
        }
        for (struct_fields, struct_field_paired) |*field, paired| {
            if (!paired) {
                @compileError(
                    "No offset provided for struct field \"" ++ field.name ++ "\" in struct: " ++ @typeName(Struct),
                );
            }
        }
        for (offsets_fields, offsets_field_paired) |*field, paired| {
            if (!paired) {
                @compileError(
                    "Offset provided for field \"" ++ field.name ++
                        "\", but that field does not exist in struct: " ++ @typeName(Struct),
                );
            }
        }
    }
    var last_error: ?struct { err: anyerror, field_name: []const u8, index: ?usize } = null;
    var trails: sdk.misc.FieldMap(Struct, sdk.memory.PointerTrail, null) = undefined;
    inline for (struct_fields) |*field| {
        const offset = @field(offsets, field.name);
        @field(trails, field.name) = switch (@typeInfo(@TypeOf(offset))) {
            .int, .comptime_int => sdk.memory.PointerTrail.fromArray(.{offset}),
            .error_set => block: {
                last_error = .{ .err = offset, .field_name = field.name, .index = null };
                break :block sdk.memory.PointerTrail.fromArray(.{null});
            },
            .error_union => |*info| switch (@typeInfo(info.payload)) {
                .int, .comptime_int => block: {
                    if (offset) |value| {
                        break :block sdk.memory.PointerTrail.fromArray(.{value});
                    } else |err| {
                        last_error = .{ .err = err, .field_name = field.name, .index = null };
                        break :block sdk.memory.PointerTrail.fromArray(.{null});
                    }
                },
                else => @compileError(
                    "Offset \"" ++ field.name ++ "\" is of unexpected type: " ++ @typeName(field.type),
                ),
            },
            .@"struct" => |*info| block: {
                if (!info.is_tuple) {
                    @compileError(
                        "Offset \"" ++ field.name ++ "\" is of unexpected type: " ++ @typeName(field.type),
                    );
                }
                var trail_elements: [info.fields.len]?usize = undefined;
                inline for (info.fields, 0..) |*sub_field, index| {
                    const sub_offset = @field(offset, sub_field.name);
                    trail_elements[index] = switch (@typeInfo(sub_field.type)) {
                        .int, .comptime_int => sub_offset,
                        .error_set => sub_block: {
                            last_error = .{ .err = sub_offset, .field_name = field.name, .index = index };
                            break :sub_block null;
                        },
                        .error_union => |*sub_info| switch (@typeInfo(sub_info.payload)) {
                            .int, .comptime_int => sub_block: {
                                if (sub_offset) |value| {
                                    break :sub_block value;
                                } else |err| {
                                    last_error = .{ .err = err, .field_name = field.name, .index = index };
                                    break :sub_block null;
                                }
                            },
                            else => @compileError(
                                "Offset \"" ++ field.name ++ "." ++ sub_field.name ++
                                    " is of unexpected type: " ++ @typeName(field.type),
                            ),
                        },
                        else => @compileError(
                            "Offset \"" ++ field.name ++ "." ++ sub_field.name ++
                                " is of unexpected type: " ++ @typeName(field.type),
                        ),
                    };
                }
                break :block sdk.memory.PointerTrail.fromArray(trail_elements);
            },
            else => @compileError(
                "Offset \"" ++ field.name ++ "\" is of unexpected type: " ++ @typeName(field.type),
            ),
        };
    }
    if (last_error) |err| {
        if (!builtin.is_test) {
            if (err.index) |i| {
                sdk.misc.error_context.append("Failed to resolve element on index: {}", .{i});
            }
            sdk.misc.error_context.append("Failed to resolve offset for field: {s}", .{err.field_name});
            sdk.misc.error_context.append("Failed to resolve field trails for struct: {s}", .{@typeName(Struct)});
            sdk.misc.error_context.logError(err.err);
        }
    }
    return trails;
}

fn proxy(
    name: []const u8,
    comptime Type: type,
    offsets: anytype,
) sdk.memory.Proxy(Type) {
    if (@typeInfo(@TypeOf(offsets)) != .array) {
        const coerced: [offsets.len]anyerror!usize = offsets;
        return proxy(name, Type, coerced);
    }
    var last_error: ?anyerror = null;
    var mapped_offsets: [offsets.len]?usize = undefined;
    for (offsets, 0..) |offset, i| {
        if (offset) |o| {
            mapped_offsets[i] = o;
        } else |err| {
            last_error = err;
            mapped_offsets[i] = null;
        }
    }
    if (last_error) |err| {
        if (!builtin.is_test) {
            sdk.misc.error_context.append("Failed to resolve proxy: {s}", .{name});
            sdk.misc.error_context.logError(err);
        }
    }
    return .fromArray(mapped_offsets);
}

fn structProxy(
    name: []const u8,
    comptime Struct: type,
    base_offsets: anytype,
    field_trails: sdk.misc.FieldMap(Struct, sdk.memory.PointerTrail, null),
) sdk.memory.StructProxy(Struct) {
    if (@typeInfo(@TypeOf(base_offsets)) != .array) {
        const coerced: [base_offsets.len]anyerror!usize = base_offsets;
        return structProxy(name, Struct, coerced, field_trails);
    }
    var last_error: ?anyerror = null;
    var mapped_offsets: [base_offsets.len]?usize = undefined;
    for (base_offsets, 0..) |offset, i| {
        if (offset) |o| {
            mapped_offsets[i] = o;
        } else |err| {
            last_error = err;
            mapped_offsets[i] = null;
        }
    }
    if (last_error) |err| {
        if (!builtin.is_test) {
            sdk.misc.error_context.append("Failed to resolve struct proxy: {s}", .{name});
            sdk.misc.error_context.logError(err);
        }
    }
    return .{
        .base_trail = .fromArray(mapped_offsets),
        .field_trails = field_trails,
    };
}

fn functionPointer(
    name: []const u8,
    comptime Function: type,
    address: anyerror!usize,
) ?*const Function {
    const addr = address catch |err| {
        if (!builtin.is_test) {
            sdk.misc.error_context.append("Failed to resolve function pointer: {s}", .{name});
            sdk.misc.error_context.logError(err);
        }
        return null;
    };
    if (!sdk.os.isMemoryReadable(addr, 6)) {
        if (!builtin.is_test) {
            sdk.misc.error_context.new("The memory address is not readable: 0x{X}", .{addr});
            sdk.misc.error_context.append("Failed to resolve function pointer: {s}", .{name});
            sdk.misc.error_context.logError(error.NotReadable);
        }
        return null;
    }
    return @ptrFromInt(addr);
}

fn pattern(pattern_cache: *?sdk.memory.PatternCache, comptime pattern_string: []const u8) !usize {
    const cache = if (pattern_cache.*) |*c| c else {
        sdk.misc.error_context.new("No memory pattern cache to find the memory pattern in.", .{});
        return error.NoPatternCache;
    };
    const memory_pattern = sdk.memory.Pattern.fromComptime(pattern_string);
    const address = cache.findAddress(&memory_pattern) catch |err| {
        sdk.misc.error_context.append("Failed to find address of memory pattern: {f}", .{memory_pattern});
        return err;
    };
    return address;
}

fn deref(comptime Type: type, address: anyerror!usize) !usize {
    if (Type != u8 and Type != u16 and Type != u32 and Type != u64) {
        @compileError("Unsupported deref type: " ++ @typeName(Type));
    }
    const addr = try address;
    const value = sdk.memory.dereferenceMisaligned(Type, addr) catch |err| {
        sdk.misc.error_context.append("Failed to dereference {s} on memory address: 0x{X}", .{ @typeName(Type), addr });
        return err;
    };
    return @intCast(value);
}

fn relativeOffset(comptime Offset: type, address: anyerror!usize) !usize {
    const addr = try address;
    const offset_address = sdk.memory.resolveRelativeOffset(Offset, addr) catch |err| {
        sdk.misc.error_context.append(
            "Failed to resolve {s} relative memory offset at address: 0x{X}",
            .{ @typeName(Offset), addr },
        );
        return err;
    };
    return offset_address;
}

fn add(comptime addition: comptime_int, address: anyerror!usize) !usize {
    const addr = try address;
    const result = if (addition >= 0) @addWithOverflow(addr, addition) else @subWithOverflow(addr, -addition);
    if (result[1] == 1) {
        sdk.misc.error_context.new("Adding 0x{X} to address 0x{X} resulted in a overflow.", .{ addr, addition });
        return error.Overflow;
    }
    return result[0];
}

const testing = std.testing;

test "structOffsets should map errors to null values" {
    const Struct = struct {
        field_1: u8,
        field_2: u16,
        field_3: u32,
        field_4: u64,
    };
    const offsets = structOffsets(Struct, .{
        .field_1 = 1,
        .field_2 = error.Test,
        .field_3 = .{ 2, error.Test },
        .field_4 = .{ error.Test, 3 },
    });
    try testing.expectEqualSlices(?usize, &.{1}, offsets.field_1.getOffsets());
    try testing.expectEqualSlices(?usize, &.{null}, offsets.field_2.getOffsets());
    try testing.expectEqualSlices(?usize, &.{ 2, null }, offsets.field_3.getOffsets());
    try testing.expectEqualSlices(?usize, &.{ null, 3 }, offsets.field_4.getOffsets());
}

test "proxy should construct a proxy from offsets" {
    const byte_proxy = proxy("byte_proxy", u8, .{ 1, 2, 3 });
    try testing.expectEqualSlices(?usize, &.{ 1, 2, 3 }, byte_proxy.trail.getOffsets());
}

test "proxy should map errors to null values" {
    sdk.misc.error_context.new("Test error.", .{});
    const byte_proxy = proxy("byte_proxy", u8, .{ 1, error.Test, 2, error.Test });
    try testing.expectEqualSlices(?usize, &.{ 1, null, 2, null }, byte_proxy.trail.getOffsets());
}

test "structProxy should construct a proxy from offsets" {
    const Struct = struct { field_1: u8, field_2: u16 };
    const struct_proxy = structProxy(
        "pointer",
        Struct,
        .{ 1, 2, 3 },
        .{
            .field_1 = .fromArray(.{ 4, 5, 6 }),
            .field_2 = .fromArray(.{ null, 7, null }),
        },
    );
    try testing.expectEqualSlices(?usize, &.{ 1, 2, 3 }, struct_proxy.base_trail.getOffsets());
    try testing.expectEqualSlices(?usize, &.{ 4, 5, 6 }, struct_proxy.field_trails.field_1.getOffsets());
    try testing.expectEqualSlices(?usize, &.{ null, 7, null }, struct_proxy.field_trails.field_2.getOffsets());
}

test "structProxy should map errors to null values in base offsets" {
    const Struct = struct { field_1: u8, field_2: u16 };
    sdk.misc.error_context.new("Test error.", .{});
    const struct_proxy = structProxy(
        "pointer",
        Struct,
        .{ 1, error.Test, 2, error.Test },
        .{ .field_1 = .fromArray(.{}), .field_2 = .fromArray(.{}) },
    );
    try testing.expectEqualSlices(?usize, &.{ 1, null, 2, null }, struct_proxy.base_trail.getOffsets());
}

test "functionPointer should return a function pointer when address is valid" {
    const function = struct {
        fn call(a: i32, b: i32) i32 {
            return a + b;
        }
    }.call;
    const function_pointer = functionPointer("function", @TypeOf(function), @intFromPtr(&function));
    try testing.expectEqual(function, function_pointer);
}

test "functionPointer should return null when address is error" {
    const function_pointer = functionPointer("function", fn (i32, i32) i32, error.Test);
    try testing.expectEqual(null, function_pointer);
}

test "functionPointer should return null when address is not readable" {
    const function_pointer = functionPointer("function", fn (i32, i32) i32, std.math.maxInt(usize));
    try testing.expectEqual(null, function_pointer);
}

test "pattern should return correct value when pattern exists" {
    const data = [_]u8{ 0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9 };
    const range = sdk.memory.Range.fromPointer(&data);
    var cache: ?sdk.memory.PatternCache = sdk.memory.PatternCache.init(testing.allocator, range);
    defer if (cache) |*c| c.deinit();
    try testing.expectEqual(@intFromPtr(&data[4]), pattern(&cache, "04 ?? ?? 07"));
}

test "pattern should error when no cache" {
    var cache: ?sdk.memory.PatternCache = null;
    try testing.expectError(error.NoPatternCache, pattern(&cache, "04 ?? ?? 07"));
}

test "pattern should error when pattern does not exist" {
    const data = [_]u8{ 0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9 };
    const range = sdk.memory.Range.fromPointer(&data);
    var cache: ?sdk.memory.PatternCache = sdk.memory.PatternCache.init(testing.allocator, range);
    defer if (cache) |*c| c.deinit();
    try testing.expectError(error.NotFound, pattern(&cache, "05 ?? ?? 02"));
}

test "deref should return correct value when memory is readable" {
    const value: u64 = 0xFF00;
    const address = @intFromPtr(&value) + 1;
    try testing.expectEqual(0xFF, deref(u32, address));
}

test "deref should return error when error argument" {
    try testing.expectError(error.Test, deref(u64, error.Test));
}

test "deref should return error when memory is not readable" {
    try testing.expectError(error.NotReadable, deref(u64, 0));
}

test "relativeOffset should return correct value when good offset address" {
    const data = [_]u8{ 3, 1, 2, 3, 4 };
    const offset_address = relativeOffset(u8, @intFromPtr(&data[0]));
    try testing.expectEqual(@intFromPtr(&data[data.len - 1]), offset_address);
}

test "relativeOffset should error when error argument" {
    try testing.expectError(error.Test, relativeOffset(u8, error.Test));
}

test "relativeOffset should error when bad offset address" {
    try testing.expectError(error.NotReadable, relativeOffset(u8, std.math.maxInt(usize)));
}

test "add should return correct value when no overflow and positive argument" {
    try testing.expectEqual(3, add(1, 2));
    try testing.expectEqual(3, add(-2, 5));
}

test "add should error when error argument" {
    try testing.expectError(error.Test, add(1, error.Test));
}

test "add should error when address space overflows" {
    try testing.expectError(error.Overflow, add(1, std.math.maxInt(usize)));
    try testing.expectError(error.Overflow, add(-1, 0));
}
