const std = @import("std");
const sdk = @import("../../sdk/root.zig");

pub const HurtCylinderId = enum {
    left_ankle,
    right_ankle,
    left_hand,
    right_hand,
    left_knee,
    right_knee,
    left_elbow,
    right_elbow,
    head,
    left_shoulder,
    right_shoulder,
    upper_torso,
    left_pelvis,
    right_pelvis,
};

pub const HurtCylinder = struct {
    cylinder: sdk.math.Cylinder,
    intersects: bool = false,
};

pub const HurtCylinders = std.EnumArray(HurtCylinderId, HurtCylinder);
