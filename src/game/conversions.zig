const std = @import("std");
const game = @import("root.zig");
const math = @import("../math/root.zig");

const to_unreal_scale = 0.1;
const from_unreal_scale = 1.0 / to_unreal_scale;

pub fn pointToUnrealSpace(value: math.Vec3) math.Vec3 {
    return math.Vec3.fromArray(.{
        value.z() * to_unreal_scale,
        -value.x() * to_unreal_scale,
        value.y() * to_unreal_scale,
    });
}

pub fn pointFromUnrealSpace(value: math.Vec3) math.Vec3 {
    return math.Vec3.fromArray(.{
        -value.y() * from_unreal_scale,
        value.z() * from_unreal_scale,
        value.x() * from_unreal_scale,
    });
}

pub fn scaleToUnrealSpace(value: f32) f32 {
    return value * to_unreal_scale;
}

pub fn scaleFromUnrealSpace(value: f32) f32 {
    return value * from_unreal_scale;
}

pub fn hitLineToUnrealSpace(value: game.HitLine) game.HitLine {
    var converted: game.HitLine = value;
    for (value.points, 0..) |element, index| {
        converted.points[index].position = pointToUnrealSpace(element.position);
    }
    return converted;
}

pub fn hitLineFromUnrealSpace(value: game.HitLine) game.HitLine {
    var converted: game.HitLine = value;
    for (value.points, 0..) |element, index| {
        converted.points[index].position = pointFromUnrealSpace(element.position);
    }
    return converted;
}

pub fn hurtCylinderToUnrealSpace(value: game.HurtCylinder) game.HurtCylinder {
    var converted = value;
    converted.center = pointToUnrealSpace(value.center);
    converted.half_height = scaleToUnrealSpace(value.half_height);
    converted.squared_radius = scaleToUnrealSpace(scaleToUnrealSpace(value.squared_radius));
    converted.radius = scaleToUnrealSpace(value.radius);
    return converted;
}

pub fn hurtCylinderFromUnrealSpace(value: game.HurtCylinder) game.HurtCylinder {
    var converted = value;
    converted.center = pointFromUnrealSpace(value.center);
    converted.half_height = scaleFromUnrealSpace(value.half_height);
    converted.squared_radius = scaleFromUnrealSpace(scaleFromUnrealSpace(value.squared_radius));
    converted.radius = scaleFromUnrealSpace(value.radius);
    return converted;
}

pub fn collisionSphereToUnrealSpace(value: game.CollisionSphere) game.CollisionSphere {
    var converted = value;
    converted.center = pointToUnrealSpace(value.center);
    converted.radius = scaleToUnrealSpace(value.radius);
    return converted;
}

pub fn collisionSphereFromUnrealSpace(value: game.CollisionSphere) game.CollisionSphere {
    var converted = value;
    converted.center = pointFromUnrealSpace(value.center);
    converted.radius = scaleFromUnrealSpace(value.radius);
    return converted;
}

const testing = std.testing;

test "pointToUnrealSpace and pointFromUnrealSpace should cancel out" {
    const value = math.Vec3.fromArray(.{ 1, 2, 3 });
    try testing.expectEqual(value, pointToUnrealSpace(pointFromUnrealSpace(value)));
    try testing.expectEqual(value, pointFromUnrealSpace(pointToUnrealSpace(value)));
}

test "scaleToUnrealSpace and scaleFromUnrealSpace should cancel out" {
    const value: f32 = 123;
    try testing.expectEqual(value, scaleToUnrealSpace(scaleFromUnrealSpace(value)));
    try testing.expectEqual(value, scaleFromUnrealSpace(scaleToUnrealSpace(value)));
}

test "hitLineToUnrealSpace and hitLineFromUnrealSpace should cancel out" {
    const value = game.HitLine{
        .points = .{
            .{ .position = .fromArray(.{ 1, 2, 3 }), ._padding = undefined },
            .{ .position = .fromArray(.{ 4, 5, 6 }), ._padding = undefined },
            .{ .position = .fromArray(.{ 7, 8, 9 }), ._padding = undefined },
        },
        ._padding_1 = undefined,
        .ignore = true,
        ._padding_2 = undefined,
    };
    try testing.expectEqual(value, hitLineToUnrealSpace(hitLineFromUnrealSpace(value)));
    try testing.expectEqual(value, hitLineFromUnrealSpace(hitLineToUnrealSpace(value)));
}

test "hurtCylinderToUnrealSpace and hurtCylinderFromUnrealSpace should cancel out" {
    const value = game.HurtCylinder{
        .center = .fromArray(.{ 1, 2, 3 }),
        .multiplier = 4,
        .half_height = 5,
        .squared_radius = 6,
        .radius = 7,
        ._padding = undefined,
    };
    try testing.expectEqual(value, hurtCylinderToUnrealSpace(hurtCylinderFromUnrealSpace(value)));
    try testing.expectEqual(value, hurtCylinderFromUnrealSpace(hurtCylinderToUnrealSpace(value)));
}

test "collisionSphereToUnrealSpace and collisionSphereFromUnrealSpace should cancel out" {
    const value = game.CollisionSphere{
        .center = .fromArray(.{ 1, 2, 3 }),
        .multiplier = 4,
        .radius = 5,
        ._padding = undefined,
    };
    try testing.expectEqual(value, collisionSphereToUnrealSpace(collisionSphereFromUnrealSpace(value)));
    try testing.expectEqual(value, collisionSphereFromUnrealSpace(collisionSphereToUnrealSpace(value)));
}
