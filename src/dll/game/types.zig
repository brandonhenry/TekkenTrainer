const std = @import("std");
const build_info = @import("build_info");
const sdk = @import("../../sdk/root.zig");
const game = @import("root.zig");

pub const PlayerSide = enum(u8) {
    left = 0,
    right = 1,
    _,
};

pub const StateFlags = sdk.memory.Bitfield(u32, &.{
    .{ .name = "crouching", .backing_value = 1 },
    .{ .name = "standing_or_airborne", .backing_value = 2 },
    .{ .name = "being_juggled_or_downed", .backing_value = 4 },
    .{ .name = "blocking_lows", .backing_value = 8 },
    .{ .name = "blocking_mids", .backing_value = 16 },
    .{ .name = "wants_to_crouch", .backing_value = 32 },
    .{ .name = "standing_or_airborne_and_not_juggled", .backing_value = 64 },
    .{ .name = "downed", .backing_value = 128 },
    .{ .name = "neutral_blocking", .backing_value = 256 },
    .{ .name = "face_down", .backing_value = 512 },
    .{ .name = "being_juggled", .backing_value = 1024 },
    .{ .name = "not_blocking_or_neutral_blocking", .backing_value = 2048 },
    .{ .name = "blocking", .backing_value = 4096 },
    .{ .name = "force_airborne_no_low_crushing", .backing_value = 8192 },
    .{ .name = "airborne_move_or_downed", .backing_value = 16384 },
    .{ .name = "low_crushing_move", .backing_value = 32768 },
    .{ .name = "forward_move_modifier", .backing_value = 65536 },
    .{ .name = "crouched_but_not_fully", .backing_value = 262144 },
});

pub const PhaseFlags = sdk.memory.Bitfield(u32, &.{
    .{ .name = "is_active", .backing_value = 256 },
    .{ .name = "is_recovery", .backing_value = 1024 },
});

pub const AttackType = enum(u32) {
    not_attack = 0xC000001D,
    high = 0xA000050F,
    mid = 0x8000020A,
    low = 0x20000112,
    special_low = 0x60000402,
    unblockable_high = 0x2000081B,
    unblockable_mid = 0xC000071A,
    unblockable_low = 0x2000091A,
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

pub const SimpleState = enum(u32) {
    standing_forward = 1,
    standing_back = 2,
    standing = 3,
    steve = 4,
    crouch_forward = 5,
    crouch_back = 6,
    crouch = 7,
    ground_face_up = 12,
    ground_face_down = 13,
    juggled = 14,
    knockdown = 15,
    off_axis_getup = 8,
    wall_splat_18 = 18,
    wall_splat_19 = 19,
    invincible = 20,
    airborne_24 = 24,
    airborne = 25,
    airborne_26 = 26,
    fly = 27,
    _,
};

pub fn Input(comptime game_id: build_info.Game) type {
    const extra_members = switch (game_id) {
        .t7 => [_]sdk.memory.BitfieldMember(u32){},
        .t8 => [_]sdk.memory.BitfieldMember(u32){.{ .name = "heat", .backing_value = 512 }},
    };
    const members = [_]sdk.memory.BitfieldMember(u32){
        .{ .name = "up", .backing_value = 1 },
        .{ .name = "down", .backing_value = 2 },
        .{ .name = "left", .backing_value = 4 },
        .{ .name = "right", .backing_value = 8 },
        .{ .name = "button_1", .backing_value = 16384 },
        .{ .name = "button_2", .backing_value = 32768 },
        .{ .name = "button_3", .backing_value = 4096 },
        .{ .name = "button_4", .backing_value = 8192 },
        .{ .name = "special_style", .backing_value = 256 },
        .{
            .name = "rage",
            .backing_value = switch (game_id) {
                .t7 => 512,
                .t8 => 2048,
            },
        },
    } ++ extra_members;
    return sdk.memory.Bitfield(u32, &members);
}

pub const HitLinePoint = extern struct {
    position: sdk.math.Vec3 = .zero,
    _padding: f32 = 0,

    comptime {
        std.debug.assert(@sizeOf(@This()) == 16);
    }
};

pub const HitLine = extern struct {
    points: [3]HitLinePoint = [1]HitLinePoint{.{}} ** 3,
    _padding_1: [8]u8 = [1]u8{0} ** 8,
    ignore: sdk.memory.Boolean(.{}) = .false,
    _padding_2: [7]u8 = [1]u8{0} ** 7,

    comptime {
        std.debug.assert(@sizeOf(@This()) == 64);
    }
};

pub fn HitLines(comptime game_id: build_info.Game) type {
    return switch (game_id) {
        .t7 => [6]sdk.memory.ConvertedValue(
            HitLinePoint,
            HitLinePoint,
            game.hitLinePointToUnrealSpace,
            game.hitLinePointFromUnrealSpace,
        ),
        .t8 => [4]sdk.memory.ConvertedValue(
            HitLine,
            HitLine,
            game.hitLineToUnrealSpace,
            game.hitLineFromUnrealSpace,
        ),
    };
}
fn getDefaultHitLines(comptime game_id: build_info.Game) HitLines(game_id) {
    return switch (game_id) {
        .t7 => .{ .fromRaw(.{}), .fromRaw(.{}), .fromRaw(.{}), .fromRaw(.{}), .fromRaw(.{}), .fromRaw(.{}) },
        .t8 => .{ .fromRaw(.{}), .fromRaw(.{}), .fromRaw(.{}), .fromRaw(.{}) },
    };
}
comptime {
    std.debug.assert(@sizeOf(HitLines(.t7)) == 96);
    std.debug.assert(@sizeOf(HitLines(.t8)) == 256);
}

pub fn HurtCylinder(comptime game_id: build_info.Game) type {
    return extern struct {
        center: sdk.math.Vec3 = .zero,
        multiplier: f32 = 0,
        half_height: f32 = 0,
        squared_radius: f32 = 0,
        radius: f32 = 0,
        _padding: [
            switch (game_id) {
                .t7 => 1,
                .t8 => 9,
            }
        ]f32 = switch (game_id) {
            .t7 => [1]f32{0} ** 1,
            .t8 => [1]f32{0} ** 9,
        },

        comptime {
            switch (game_id) {
                .t7 => std.debug.assert(@sizeOf(@This()) == 32),
                .t8 => std.debug.assert(@sizeOf(@This()) == 64),
            }
        }
    };
}

pub fn HurtCylinders(comptime game_id: build_info.Game) type {
    return extern struct {
        left_ankle: Element = .fromRaw(.{}),
        right_ankle: Element = .fromRaw(.{}),
        left_hand: Element = .fromRaw(.{}),
        right_hand: Element = .fromRaw(.{}),
        left_knee: Element = .fromRaw(.{}),
        right_knee: Element = .fromRaw(.{}),
        left_elbow: Element = .fromRaw(.{}),
        right_elbow: Element = .fromRaw(.{}),
        head: Element = .fromRaw(.{}),
        left_shoulder: Element = .fromRaw(.{}),
        right_shoulder: Element = .fromRaw(.{}),
        upper_torso: Element = .fromRaw(.{}),
        left_pelvis: Element = .fromRaw(.{}),
        right_pelvis: Element = .fromRaw(.{}),

        const Self = @This();
        pub const Element = sdk.memory.ConvertedValue(
            HurtCylinder(game_id),
            HurtCylinder(game_id),
            game.hurtCylinderToUnrealSpace(game_id),
            game.hurtCylinderFromUnrealSpace(game_id),
        );

        pub const len = @typeInfo(Self).@"struct".fields.len;

        pub fn asArray(self: anytype) sdk.misc.SelfBasedPointer(@TypeOf(self), Self, [len]Element) {
            return @ptrCast(self);
        }

        comptime {
            switch (game_id) {
                .t7 => std.debug.assert(@sizeOf(Self) == 448),
                .t8 => std.debug.assert(@sizeOf(Self) == 896),
            }
        }
    };
}

pub const CollisionSphere = extern struct {
    center: sdk.math.Vec3 = .zero,
    multiplier: f32 = 0,
    radius: f32 = 0,
    _padding: [3]f32 = [1]f32{0} ** 3,

    comptime {
        std.debug.assert(@sizeOf(@This()) == 32);
    }
};

pub const CollisionSpheres = extern struct {
    neck: Element = .fromRaw(.{}),
    left_elbow: Element = .fromRaw(.{}),
    right_elbow: Element = .fromRaw(.{}),
    lower_torso: Element = .fromRaw(.{}),
    left_knee: Element = .fromRaw(.{}),
    right_knee: Element = .fromRaw(.{}),
    left_ankle: Element = .fromRaw(.{}),
    right_ankle: Element = .fromRaw(.{}),

    const Self = @This();
    pub const Element = sdk.memory.ConvertedValue(
        CollisionSphere,
        CollisionSphere,
        game.collisionSphereToUnrealSpace,
        game.collisionSphereFromUnrealSpace,
    );

    pub const len = @typeInfo(Self).@"struct".fields.len;

    pub fn asArray(self: anytype) sdk.misc.SelfBasedPointer(@TypeOf(self), Self, [len]Element) {
        return @ptrCast(self);
    }

    comptime {
        std.debug.assert(@sizeOf(Self) == 256);
    }
};

pub fn Health(comptime game_id: build_info.Game) type {
    return switch (game_id) {
        .t7 => extern struct {
            value: u32 = 0,
            encryption_key: u64 = 0,
        },
        .t8 => [16]u64,
    };
}

pub fn Player(comptime game_id: build_info.Game) type {
    const Bool = sdk.memory.Boolean(.{});
    const Bool2 = sdk.memory.Boolean(.{ .true_value = 2 });
    const AnimationPointer = sdk.memory.Pointer(Animation(game_id));
    const Transform = sdk.memory.ConvertedValue(
        sdk.math.Mat4,
        sdk.math.Mat4,
        game.matrixToUnrealSpace,
        game.matrixFromUnrealSpace,
    );
    const FloorZ = sdk.memory.ConvertedValue(
        f32,
        f32,
        game.scaleToUnrealSpace,
        game.scaleFromUnrealSpace,
    );
    const Rotation = sdk.memory.ConvertedValue(
        u16,
        f32,
        game.u16ToRadians,
        game.u16FromRadians,
    );
    const HeatGauge = sdk.memory.ConvertedValue(
        u32,
        f32,
        game.decryptHeatGauge,
        game.encryptHeatGauge,
    );
    const T7Health = sdk.memory.ConvertedValue(
        Health(.t7),
        Health(.t7),
        game.decryptT7Health,
        game.encryptT7Health,
    );
    const T8Health = sdk.memory.ConvertedValue(
        Health(.t8),
        ?i32,
        game.decryptT8Health,
        null,
    );
    @setEvalBranchQuota(40000);
    return switch (game_id) {
        .t7 => sdk.memory.StructWithOffsets(null, &.{
            .{ .offset = 0x0009, .name = "is_picked_by_main_player", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x00D8, .name = "character_id", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x0130, .name = "transform_matrix", .type = Transform, .default_value_ptr = &Transform.fromRaw(.identity) },
            .{ .offset = 0x01B0, .name = "floor_z", .type = FloorZ, .default_value_ptr = &FloorZ.fromRaw(0) },
            .{ .offset = 0x01BE, .name = "rotation", .type = Rotation, .default_value_ptr = &Rotation.fromRaw(0) },
            .{ .offset = 0x01D4, .name = "animation_frame", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x0218, .name = "animation", .type = AnimationPointer, .default_value_ptr = &AnimationPointer.fromPointer(null) },
            .{ .offset = 0x0264, .name = "state_flags", .type = StateFlags, .default_value_ptr = &StateFlags{} },
            .{ .offset = 0x0324, .name = "attack_damage", .type = i32, .default_value_ptr = &@as(i32, 0) },
            .{ .offset = 0x0328, .name = "attack_type", .type = AttackType, .default_value_ptr = &AttackType.not_attack },
            .{ .offset = 0x0350, .name = "animation_id", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x0390, .name = "can_move", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x039C, .name = "animation_total_frames", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x03D8, .name = "hit_outcome", .type = HitOutcome, .default_value_ptr = &HitOutcome.none },
            .{ .offset = 0x0428, .name = "simple_state", .type = SimpleState, .default_value_ptr = &SimpleState.standing },
            .{ .offset = 0x06C0, .name = "power_crushing", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x095C, .name = "frames_since_round_start", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x0AE0, .name = "floor_number", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x0C00, .name = "in_rage", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x0C40, .name = "phase_flags", .type = PhaseFlags, .default_value_ptr = &PhaseFlags{} },
            .{ .offset = 0x0DE4, .name = "input_side", .type = PlayerSide, .default_value_ptr = &PlayerSide.left },
            .{ .offset = 0x0E0C, .name = "input", .type = Input(.t7), .default_value_ptr = &Input(.t7){} },
            .{ .offset = 0x0E50, .name = "hit_lines", .type = HitLines(.t7), .default_value_ptr = &getDefaultHitLines(.t7) },
            .{ .offset = 0x0F10, .name = "hurt_cylinders", .type = HurtCylinders(.t7), .default_value_ptr = &HurtCylinders(.t7){} },
            .{ .offset = 0x10D0, .name = "collision_spheres", .type = CollisionSpheres, .default_value_ptr = &CollisionSpheres{} },
            .{ .offset = 0x14E8, .name = "health", .type = T7Health, .default_value_ptr = &T7Health.fromRaw(.{}) },
        }),
        .t8 => sdk.memory.StructWithOffsets(null, &.{
            .{ .offset = 0x0009, .name = "is_picked_by_main_player", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x0168, .name = "character_id", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x0200, .name = "transform_matrix", .type = Transform, .default_value_ptr = &Transform.fromRaw(.identity) },
            .{ .offset = 0x0354, .name = "floor_z", .type = FloorZ, .default_value_ptr = &FloorZ.fromRaw(0) },
            .{ .offset = 0x0376, .name = "rotation", .type = Rotation, .default_value_ptr = &Rotation.fromRaw(0) },
            .{ .offset = 0x0390, .name = "animation_frame", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x03D8, .name = "animation", .type = AnimationPointer, .default_value_ptr = &AnimationPointer.fromPointer(null) },
            .{ .offset = 0x0434, .name = "state_flags", .type = StateFlags, .default_value_ptr = &StateFlags{} },
            .{ .offset = 0x0504, .name = "attack_damage", .type = i32, .default_value_ptr = &@as(i32, 0) },
            .{ .offset = 0x0510, .name = "attack_type", .type = AttackType, .default_value_ptr = &AttackType.not_attack },
            .{ .offset = 0x0548, .name = "animation_id", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x05C8, .name = "can_move", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x05D4, .name = "animation_total_frames", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x0610, .name = "hit_outcome", .type = HitOutcome, .default_value_ptr = &HitOutcome.none },
            .{ .offset = 0x0660, .name = "simple_state", .type = SimpleState, .default_value_ptr = &SimpleState.standing },
            .{ .offset = 0x0A2C, .name = "is_a_parry_move", .type = Bool2, .default_value_ptr = &Bool2.false },
            .{ .offset = 0x0BEC, .name = "power_crushing", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x0F51, .name = "in_rage", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x0F88, .name = "used_rage", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x1590, .name = "frames_since_round_start", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x1970, .name = "floor_number", .type = u32, .default_value_ptr = &@as(u32, 0) },
            .{ .offset = 0x1BC4, .name = "phase_flags", .type = PhaseFlags, .default_value_ptr = &PhaseFlags{} },
            .{ .offset = 0x2440, .name = "heat_gauge", .type = HeatGauge, .default_value_ptr = &HeatGauge.fromRaw(0) },
            .{ .offset = 0x2450, .name = "used_heat", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x2471, .name = "in_heat", .type = Bool, .default_value_ptr = &Bool.false },
            .{ .offset = 0x27BC, .name = "input_side", .type = PlayerSide, .default_value_ptr = &PlayerSide.left },
            .{ .offset = 0x27E4, .name = "input", .type = Input(.t8), .default_value_ptr = &Input(.t8){} },
            .{ .offset = 0x2850, .name = "hit_lines", .type = HitLines(.t8), .default_value_ptr = &getDefaultHitLines(.t8) },
            .{ .offset = 0x2C50, .name = "hurt_cylinders", .type = HurtCylinders(.t8), .default_value_ptr = &HurtCylinders(.t8){} },
            .{ .offset = 0x3090, .name = "collision_spheres", .type = CollisionSpheres, .default_value_ptr = &CollisionSpheres{} },
            .{ .offset = 0x3810, .name = "health", .type = T8Health, .default_value_ptr = &T8Health.fromRaw([1]u64{0} ** 16) },
        }),
    };
}

pub fn Animation(comptime game_id: build_info.Game) type {
    const offsets = switch (game_id) {
        .t7 => .{
            .airborne_start = 0x6C,
            .airborne_end = 0x70,
        },
        .t8 => .{
            .airborne_start = 0x124,
            .airborne_end = 0x128,
        },
    };
    return sdk.memory.StructWithOffsets(null, &.{
        .{ .name = "airborne_start", .offset = offsets.airborne_start, .type = u32, .default_value_ptr = &@as(u32, 0) },
        .{ .name = "airborne_end", .offset = offsets.airborne_end, .type = u32, .default_value_ptr = &@as(u32, 0) },
    });
}

// UE: APlayerCameraManager
pub fn CameraManager(comptime game_id: build_info.Game) type {
    const Float = switch (game_id) {
        .t7 => f32,
        .t8 => f64,
    };
    const Vec = sdk.memory.ConvertedValue(
        sdk.math.Vector(3, Float),
        sdk.math.Vec3,
        game.convertEachVectorElement(3, game.floatCast(Float, f32)),
        game.convertEachVectorElement(3, game.floatCast(f32, Float)),
    );
    const Rot = sdk.memory.ConvertedValue(
        sdk.math.Vector(3, Float),
        sdk.math.Vec3,
        game.convertEachVectorElement(3, game.composeConversions(.{
            game.degreesToRadians(Float),
            game.floatCast(Float, f32),
        })),
        game.convertEachVectorElement(3, game.composeConversions(.{
            game.floatCast(f32, Float),
            game.radiansToDegrees(Float),
        })),
    );
    const offsets = switch (game_id) {
        .t7 => .{
            .position = 0x3F8,
            .rotation = 0x404,
        },
        .t8 => .{
            .position = 0x22D0,
            .rotation = 0x22E8,
        },
    };
    return sdk.memory.StructWithOffsets(null, &.{
        .{ .name = "position", .offset = offsets.position, .type = Vec, .default_value_ptr = &Vec.fromRaw(.zero) },
        .{ .name = "rotation", .offset = offsets.rotation, .type = Rot, .default_value_ptr = &Rot.fromRaw(.zero) },
    });
}

// UE: USceneComponent
pub fn SceneComponent(comptime game_id: build_info.Game) type {
    const Float = switch (game_id) {
        .t7 => f32,
        .t8 => f64,
    };
    const Vec = sdk.memory.ConvertedValue(
        sdk.math.Vector(3, Float),
        sdk.math.Vec3,
        game.convertEachVectorElement(3, game.floatCast(Float, f32)),
        game.convertEachVectorElement(3, game.floatCast(f32, Float)),
    );
    const Rot = sdk.memory.ConvertedValue(
        sdk.math.Vector(3, Float),
        sdk.math.Vec3,
        game.convertEachVectorElement(3, game.composeConversions(.{
            game.degreesToRadians(Float),
            game.floatCast(Float, f32),
        })),
        game.convertEachVectorElement(3, game.composeConversions(.{
            game.floatCast(f32, Float),
            game.radiansToDegrees(Float),
        })),
    );
    const offsets = switch (game_id) {
        .t7 => .{
            .relative_position = 0x180,
            .relative_rotation = 0x18C,
            .relative_scale = 0x1C0,
        },
        .t8 => .{
            .relative_position = 0x128,
            .relative_rotation = 0x140,
            .relative_scale = 0x158,
        },
    };
    return sdk.memory.StructWithOffsets(null, &.{
        .{ .name = "relative_position", .offset = offsets.relative_position, .type = Vec, .default_value_ptr = &Vec.fromRaw(.zero) },
        .{ .name = "relative_rotation", .offset = offsets.relative_rotation, .type = Rot, .default_value_ptr = &Rot.fromRaw(.zero) },
        .{ .name = "relative_scale", .offset = offsets.relative_scale, .type = Vec, .default_value_ptr = &Vec.fromRaw(.zero) },
    });
}

// T7: TekkenWallActor, T8: PolarisStageWallActor
pub fn Wall(comptime game_id: build_info.Game) type {
    const RootComponent = sdk.memory.Pointer(SceneComponent(game_id));
    const offsets = switch (game_id) {
        .t7 => .{
            .root_component = 0x160,
            .floor_number = 0x390,
        },
        .t8 => .{
            .root_component = 0x1A0,
            .floor_number = 0x2B8,
        },
    };
    return sdk.memory.StructWithOffsets(null, &.{
        .{ .name = "root_component", .offset = offsets.root_component, .type = RootComponent, .default_value_ptr = &RootComponent.fromPointer(null) },
        .{ .name = "floor_number", .offset = offsets.floor_number, .type = u32, .default_value_ptr = &@as(u32, 0) },
    });
}

// UE: TArray
pub fn UnrealArrayList(comptime Element: type) type {
    return extern struct {
        data: ?[*]Element, // UE: AllocatorInstance
        len: i32, // UE: ArrayNum
        capacity: i32, // UE: ArrayMax

        const Self = @This();
        pub const empty = Self{
            .data = null,
            .len = 0,
            .capacity = 0,
        };

        pub fn free(self: *Self, unrealFree: *const UnrealFreeFunction) void {
            if (self.data) |data| {
                unrealFree(@ptrCast(data));
                self.data = null;
            }
            self.len = 0;
            self.capacity = 0;
        }

        pub fn asSlice(self: anytype) sdk.misc.SelfBasedSlice(@TypeOf(self), Self, Element) {
            const data = self.data orelse return &.{};
            if (self.len < 0) {
                return &.{};
            }
            const len: usize = @intCast(self.len);
            return data[0..len];
        }
    };
}

// UE: EObjectFlags
pub const UnrealObjectFlags = packed struct(u32) {
    public: bool = false,
    standalone: bool = false,
    mark_as_native: bool = false,
    transactional: bool = false,
    class_default_object: bool = false,
    archetype_object: bool = false,
    transient: bool = false,
    mark_as_root_set: bool = false,
    tag_garbage_temp: bool = false,
    need_initialization: bool = false,
    need_load: bool = false,
    keep_for_cooker: bool = false,
    need_post_load: bool = false,
    need_post_load_subobjects: bool = false,
    newer_version_exists: bool = false,
    begin_destroyed: bool = false,
    finish_destroyed: bool = false,
    being_regenerated: bool = false,
    default_sub_object: bool = false,
    was_loaded: bool = false,
    text_export_transient: bool = false,
    load_completed: bool = false,
    inheritable_component_template: bool = false,
    duplicate_transient: bool = false,
    strong_ref_on_frame: bool = false,
    non_pie_duplicate_transient: bool = false,
    dynamic: bool = false,
    will_be_loaded: bool = false,
    has_external_package: bool = false,
    pending_kill: bool = false,
    garbage: bool = false,
    allocated_in_shared_page: bool = false,

    const Self = @This();

    pub const default_exclude = Self{
        .class_default_object = true,
        .archetype_object = true,
        .need_initialization = true,
        .need_load = true,
        .newer_version_exists = true,
        .begin_destroyed = true,
        .finish_destroyed = true,
        .pending_kill = true,
        .garbage = true,
    };
};

// UE: EInternalObjectFlags
pub const UnrealInternalObjectFlags = sdk.memory.Bitfield(u32, &.{
    .{ .name = "loader_import", .backing_value = 0x100000 },
    .{ .name = "garbage", .backing_value = 0x200000 },
    .{ .name = "reachable_in_cluster", .backing_value = 0x800000 },
    .{ .name = "cluster_root", .backing_value = 0x1000000 },
    .{ .name = "native", .backing_value = 0x2000000 },
    .{ .name = "async", .backing_value = 0x4000000 },
    .{ .name = "async_loading", .backing_value = 0x8000000 },
    .{ .name = "unreachable", .backing_value = 0x10000000 },
    .{ .name = "pending_kill", .backing_value = 0x20000000 },
    .{ .name = "root_set", .backing_value = 0x40000000 },
    .{ .name = "pending_construction", .backing_value = 0x80000000 },
});

// UE: UClass
pub const UnrealClass = opaque {};

// UE: UObject
pub const UnrealObject = opaque {};

pub fn TickFunction(comptime game_id: build_info.Game) type {
    return switch (game_id) {
        // UE: AGameMode::Tick
        .t7 => fn (game_mode_address: usize, delta_time: f32) callconv(.c) void,
        // T8
        .t8 => fn (delta_time: f64) callconv(.c) void,
    };
}

// UE: FMemory::Free
pub const UnrealFreeFunction = fn (original: *anyopaque) callconv(.c) void;

// UE: FindObject<UClass>
pub const FindUnrealClassFunction = fn (
    outer: ?*const UnrealObject,
    name: [*:0]const u16,
    exact_class: bool,
) callconv(.c) ?*const UnrealClass;

// UE: GetObjectsOfClass
pub const FindUnrealObjectsOfClassFunction = fn (
    class_to_look_for: *const UnrealClass,
    results: *UnrealArrayList(*UnrealObject),
    b_include_derived_classes: bool,
    exclude_flags: UnrealObjectFlags,
    exclusion_internal_flags: UnrealInternalObjectFlags,
) callconv(.c) void;

// T8
pub const DecryptT8HealthFunction = fn (encrypted_health: *const Health(.t8)) callconv(.c) i64;
