const std = @import("std");
const sdk = @import("../../sdk/root.zig");

pub const SkeletonPointId = enum {
    head,
    neck,
    upper_torso,
    left_shoulder,
    right_shoulder,
    left_elbow,
    right_elbow,
    left_hand,
    right_hand,
    lower_torso,
    left_pelvis,
    right_pelvis,
    left_knee,
    right_knee,
    left_ankle,
    right_ankle,
};

pub const SkeletonPoint = sdk.math.Vec3;

pub const Skeleton = std.EnumArray(SkeletonPointId, SkeletonPoint);
