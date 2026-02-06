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
    position: sdk.math.Vec3,
    _padding: f32,

    comptime {
        std.debug.assert(@sizeOf(@This()) == 16);
    }
};

pub const HitLine = extern struct {
    points: [3]HitLinePoint,
    _padding_1: [8]u8,
    ignore: sdk.memory.Boolean(.{}),
    _padding_2: [7]u8,

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
comptime {
    std.debug.assert(@sizeOf(HitLines(.t7)) == 96);
    std.debug.assert(@sizeOf(HitLines(.t8)) == 256);
}

pub fn HurtCylinder(comptime game_id: build_info.Game) type {
    return extern struct {
        center: sdk.math.Vec3,
        multiplier: f32,
        half_height: f32,
        squared_radius: f32,
        radius: f32,
        _padding: [
            switch (game_id) {
                .t7 => 1,
                .t8 => 9,
            }
        ]f32,

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
        left_ankle: Element,
        right_ankle: Element,
        left_hand: Element,
        right_hand: Element,
        left_knee: Element,
        right_knee: Element,
        left_elbow: Element,
        right_elbow: Element,
        head: Element,
        left_shoulder: Element,
        right_shoulder: Element,
        upper_torso: Element,
        left_pelvis: Element,
        right_pelvis: Element,

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
    center: sdk.math.Vec3,
    multiplier: f32,
    radius: f32,
    _padding: [3]f32,

    comptime {
        std.debug.assert(@sizeOf(@This()) == 32);
    }
};

pub const CollisionSpheres = extern struct {
    neck: Element,
    left_elbow: Element,
    right_elbow: Element,
    lower_torso: Element,
    left_knee: Element,
    right_knee: Element,
    left_ankle: Element,
    right_ankle: Element,

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
            value: u32,
            encryption_key: u64,
        },
        .t8 => [16]u64,
    };
}

pub fn Player(comptime game_id: build_info.Game) type {
    return switch (game_id) {
        .t7 => struct {
            is_picked_by_main_player: sdk.memory.Boolean(.{}),
            character_id: u32,
            transform_matrix: sdk.memory.ConvertedValue(
                sdk.math.Mat4,
                sdk.math.Mat4,
                game.matrixToUnrealSpace,
                game.matrixFromUnrealSpace,
            ),
            floor_z: sdk.memory.ConvertedValue(
                f32,
                f32,
                game.scaleToUnrealSpace,
                game.scaleFromUnrealSpace,
            ),
            rotation: sdk.memory.ConvertedValue(
                u16,
                f32,
                game.u16ToRadians,
                game.u16FromRadians,
            ),
            animation_frame: u32,
            animation_pointer: u64,
            airborne_start: u32,
            airborne_end: u32,
            state_flags: StateFlags,
            attack_damage: i32,
            attack_type: AttackType,
            animation_id: u32,
            can_move: sdk.memory.Boolean(.{}),
            animation_total_frames: u32,
            hit_outcome: HitOutcome,
            simple_state: SimpleState,
            power_crushing: sdk.memory.Boolean(.{}),
            frames_since_round_start: u32,
            in_rage: sdk.memory.Boolean(.{}),
            phase_flags: PhaseFlags,
            input_side: PlayerSide,
            input: Input(.t7),
            hit_lines: HitLines(.t7),
            hurt_cylinders: HurtCylinders(.t7),
            collision_spheres: CollisionSpheres,
            health: sdk.memory.ConvertedValue(
                Health(.t7),
                Health(.t7),
                game.decryptT7Health,
                game.encryptT7Health,
            ),
        },
        .t8 => struct {
            is_picked_by_main_player: sdk.memory.Boolean(.{}),
            character_id: u32,
            transform_matrix: sdk.memory.ConvertedValue(
                sdk.math.Mat4,
                sdk.math.Mat4,
                game.matrixToUnrealSpace,
                game.matrixFromUnrealSpace,
            ),
            floor_z: sdk.memory.ConvertedValue(
                f32,
                f32,
                game.scaleToUnrealSpace,
                game.scaleFromUnrealSpace,
            ),
            rotation: sdk.memory.ConvertedValue(
                u16,
                f32,
                game.u16ToRadians,
                game.u16FromRadians,
            ),
            animation_frame: u32,
            animation_pointer: u64,
            airborne_start: u32,
            airborne_end: u32,
            state_flags: StateFlags,
            attack_damage: i32,
            attack_type: AttackType,
            animation_id: u32,
            can_move: sdk.memory.Boolean(.{}),
            animation_total_frames: u32,
            hit_outcome: HitOutcome,
            simple_state: SimpleState,
            is_a_parry_move: sdk.memory.Boolean(.{ .true_value = 2 }),
            power_crushing: sdk.memory.Boolean(.{}),
            in_rage: sdk.memory.Boolean(.{}),
            used_rage: sdk.memory.Boolean(.{}),
            frames_since_round_start: u32,
            phase_flags: PhaseFlags,
            heat_gauge: sdk.memory.ConvertedValue(
                u32,
                f32,
                game.decryptHeatGauge,
                game.encryptHeatGauge,
            ),
            used_heat: sdk.memory.Boolean(.{}),
            in_heat: sdk.memory.Boolean(.{}),
            input_side: PlayerSide,
            input: Input(.t8),
            hit_lines: HitLines(.t8),
            hurt_cylinders: HurtCylinders(.t8),
            collision_spheres: CollisionSpheres,
            health: sdk.memory.ConvertedValue(
                Health(.t8),
                ?i32,
                game.decryptT8Health,
                null,
            ),
        },
    };
}

pub fn RawCamera(comptime game_id: build_info.Game) type {
    const Float = switch (game_id) {
        .t7 => f32,
        .t8 => f64,
    };
    return extern struct {
        position: sdk.math.Vector(3, Float),
        pitch: Float,
        yaw: Float,
        roll: Float,
    };
}

pub const ConvertedCamera = extern struct {
    position: sdk.math.Vec3,
    pitch: f32,
    yaw: f32,
    roll: f32,
};

pub fn Camera(comptime game_id: build_info.Game) type {
    return sdk.memory.ConvertedValue(
        RawCamera(game_id),
        ConvertedCamera,
        game.rawToConvertedCamera(game_id),
        game.convertedToRawCamera(game_id),
    );
}

pub fn Wall(comptime game_id: build_info.Game) type {
    const Float = switch (game_id) {
        .t7 => f32,
        .t8 => f64,
    };
    return struct {
        relative_position: sdk.math.Vector(3, Float),
        relative_rotation: sdk.math.Vector(3, Float),
        relative_scale: sdk.math.Vector(3, Float),
        floor_number: u32,
    };
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
