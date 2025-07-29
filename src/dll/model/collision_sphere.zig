const std = @import("std");
const sdk = @import("../../sdk/root.zig");

pub const CollisionSphereId = enum {
    neck,
    left_elbow,
    right_elbow,
    lower_torso,
    left_knee,
    right_knee,
    left_ankle,
    right_ankle,
};

pub const CollisionSphere = sdk.math.Sphere;

pub const CollisionSpheres = std.EnumArray(CollisionSphereId, CollisionSphere);
