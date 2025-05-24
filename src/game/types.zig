const std = @import("std");
const memory = @import("../memory/root.zig");

pub const AttackType = enum(u32) {
    not_attack = 0xC000001D,
    high = 0xA000050F,
    mid = 0x8000020A,
    low = 0x20000112,
    special_mid = 0x60000402,
    high_unblockable = 0x2000081B,
    mid_unblockable = 0xC000071A,
    low_unblockable = 0x2000091A,
    throw = 0x60000A1D,
    projectile = 0x10000302,
    antiair_only = 0x10000B1A,
    _,
};

pub const HitOutcome = enum(u32) {
    none = 0,
    blocked_standing = 1,
    blocked_crouching = 2,
    juggle = 3,
    screw = 4,
    unknown_screw_5 = 5,
    unknown_6 = 6,
    unknown_screw_7 = 7,
    grounded_face_down = 8,
    grounded_face_up = 9,
    counter_hit_standing = 10,
    counter_hit_crouching = 11,
    normal_hit_standing = 12,
    normal_hit_crouching = 13,
    normal_hit_standing_left = 14,
    normal_hit_crouching_left = 15,
    normal_hit_standing_back = 16,
    normal_hit_crouching_back = 17,
    normal_hit_standing_right = 18,
    normal_hit_crouching_right = 19,
    _,
};

pub const Stun = packed struct(u32) {
    _0: bool = false,
    _1: bool = false,
    _2: bool = false,
    _3: bool = false,
    _4: bool = false,
    _5: bool = false,
    _6: bool = false,
    _7: bool = false,
    _8: bool = false,
    _9: bool = false,
    _10: bool = false,
    _11: bool = false,
    _12: bool = false,
    _13: bool = false,
    _14: bool = false,
    _15: bool = false,
    any_stun: bool = false,
    _17: bool = false,
    _18: bool = false,
    _19: bool = false,
    _20: bool = false,
    _21: bool = false,
    _22: bool = false,
    _23: bool = false,
    attacking: bool = false,
    _25: bool = false,
    _26: bool = false,
    _27: bool = false,
    _28: bool = false,
    _29: bool = false,
    _30: bool = false,
    _31: bool = false,

    const Self = @This();

    fn fromInt(int: u32) Self {
        return @bitCast(int);
    }

    fn toInt(self: Self) u32 {
        return @bitCast(self);
    }

    comptime {
        std.debug.assert((Self{ .any_stun = true }).toInt() == 65536);
        std.debug.assert((Self{ .attacking = true }).toInt() == 16777216);
    }
};

pub const CancelFlags = packed struct(u32) {
    _0: bool = false,
    _1: bool = false,
    _2: bool = false,
    _3: bool = false,
    _4: bool = false,
    _5: bool = false,
    _6: bool = false,
    _7: bool = false,
    _8: bool = false,
    _9: bool = false,
    _10: bool = false,
    _11: bool = false,
    _12: bool = false,
    _13: bool = false,
    _14: bool = false,
    _15: bool = false,
    cancellable: bool = false,
    _17: bool = false,
    _18: bool = false,
    _19: bool = false,
    _20: bool = false,
    _21: bool = false,
    _22: bool = false,
    _23: bool = false,
    _24: bool = false,
    _25: bool = false,
    _26: bool = false,
    _27: bool = false,
    _28: bool = false,
    _29: bool = false,
    _30: bool = false,
    _31: bool = false,

    const Self = @This();

    fn fromInt(int: u32) Self {
        return @bitCast(int);
    }

    fn toInt(self: Self) u32 {
        return @bitCast(self);
    }

    comptime {
        std.debug.assert((Self{ .cancellable = true }).toInt() == 65536);
    }
};

pub const Player = extern struct {
    _0: [4]u8,
    player_id: i32,
    _1: [1]u8,
    is_picked_by_main_player: bool,
    _2: [350]u8,
    character_id: i32,
    character_id_2: i32,
    position_x: f32,
    _3: [4]u8,
    position_y: f32,
    _4: [8]u8,
    position_y_relative_to_floor: f32,
    _5: [4]u8,
    position_x_relative_to_floor: f32,
    _6: [20]u8,
    position_z_relative_to_floor: f32,
    _7: [104]u8,
    location: [4]f32,
    _8: [288]u8,
    b7: f32,
    _9: [44]u8,
    current_frame_int: i32,
    _10: [40]u8,
    current_frame_float: f32,
    _11: [24]u8,
    current_move_pointer: u64,
    current_move_pointer_2: u64,
    previous_move_pointer: u64,
    _12: [276]u8,
    attack_damage: i32,
    _13: [8]u8,
    attack_type: AttackType,
    _14: [40]u8,
    current_move_id: i32,
    _15: [124]u8,
    move: i32,
    _16: [68]u8,
    hit_outcome: HitOutcome,
    _17: [92]u8,
    already_attacked: i32,
    _18: [260]u8,
    stun: Stun,
    _19: [1288]u8,
    cancel_flags: CancelFlags,
    _20: [2548]u8,
    floor_number_1: i32,
    _21: [620]u8,
    frame_data_flags: i32,
    _22: [1356]u8,
    next_move_pointer: u64,
    _23: [20]u8,
    next_move_id: i32,
    reaction_to_have: i32,
    _24: [28]u8,
    attack_input: i32,
    direction_input: i32,
    _25: [3948]u8,
    health: i32,
    _26: [936]u8,

    const Self = @This();

    comptime {
        std.debug.assert(@sizeOf(Self) == 0x3170);
        std.debug.assert(@offsetOf(Self, "player_id") == 0x0004);
        std.debug.assert(@offsetOf(Self, "is_picked_by_main_player") == 0x0009);
        std.debug.assert(@offsetOf(Self, "character_id") == 0x0168);
        std.debug.assert(@offsetOf(Self, "character_id_2") == 0x016C);
        std.debug.assert(@offsetOf(Self, "position_x") == 0x0170);
        std.debug.assert(@offsetOf(Self, "position_y") == 0x0178);
        std.debug.assert(@offsetOf(Self, "position_y_relative_to_floor") == 0x0184);
        std.debug.assert(@offsetOf(Self, "position_x_relative_to_floor") == 0x018C);
        std.debug.assert(@offsetOf(Self, "position_z_relative_to_floor") == 0x01A4);
        std.debug.assert(@offsetOf(Self, "location") == 0x0210);
        std.debug.assert(@offsetOf(Self, "b7") == 0x0340);
        std.debug.assert(@offsetOf(Self, "current_frame_int") == 0x0370);
        std.debug.assert(@offsetOf(Self, "current_frame_float") == 0x039C);
        std.debug.assert(@offsetOf(Self, "current_move_pointer") == 0x03B8);
        std.debug.assert(@offsetOf(Self, "current_move_pointer_2") == 0x03C0);
        std.debug.assert(@offsetOf(Self, "previous_move_pointer") == 0x03C8);
        std.debug.assert(@offsetOf(Self, "attack_damage") == 0x04E4);
        std.debug.assert(@offsetOf(Self, "attack_type") == 0x04F0);
        std.debug.assert(@offsetOf(Self, "current_move_id") == 0x051C);
        std.debug.assert(@offsetOf(Self, "move") == 0x059C);
        std.debug.assert(@offsetOf(Self, "hit_outcome") == 0x05E4);
        std.debug.assert(@offsetOf(Self, "already_attacked") == 0x0644);
        std.debug.assert(@offsetOf(Self, "stun") == 0x074C);
        std.debug.assert(@offsetOf(Self, "cancel_flags") == 0x0C58);
        std.debug.assert(@offsetOf(Self, "floor_number_1") == 0x1650);
        std.debug.assert(@offsetOf(Self, "frame_data_flags") == 0x18C0);
        std.debug.assert(@offsetOf(Self, "next_move_pointer") == 0x1E10);
        std.debug.assert(@offsetOf(Self, "next_move_id") == 0x1E2C);
        std.debug.assert(@offsetOf(Self, "reaction_to_have") == 0x1E30);
        std.debug.assert(@offsetOf(Self, "attack_input") == 0x1E50);
        std.debug.assert(@offsetOf(Self, "direction_input") == 0x1E54);
        std.debug.assert(@offsetOf(Self, "health") == 0x2DC4);
    }
};
