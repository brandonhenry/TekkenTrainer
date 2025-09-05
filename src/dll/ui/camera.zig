const std = @import("std");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");
const model = @import("../model/root.zig");
const ui = @import("../ui/root.zig");

pub const Camera = struct {
    windows: std.EnumArray(ui.ViewDirection, Window) = .initFill(.{}),

    const Self = @This();
    pub const Window = struct {
        position: sdk.math.Vec2 = .zero,
        size: sdk.math.Vec2 = .zero,
    };

    pub fn updateWindowState(self: *Self, direction: ui.ViewDirection) void {
        var window: Window = undefined;
        imgui.igGetCursorScreenPos(window.position.asImVec());
        imgui.igGetContentRegionAvail(window.size.asImVec());
        self.windows.set(direction, window);
    }

    pub fn calculateMatrix(self: *const Self, frame: *const model.Frame, direction: ui.ViewDirection) ?sdk.math.Mat4 {
        const look_at_matrix = calculateLookAtMatrix(frame, direction) orelse return null;
        const orthographic_matrix = self.calculateOrthographicMatrix(frame, direction, look_at_matrix) orelse return null;
        const window_matrix = self.calculateWindowMatrix(direction);
        return look_at_matrix.multiply(orthographic_matrix).multiply(window_matrix);
    }

    fn calculateLookAtMatrix(
        frame: *const model.Frame,
        direction: ui.ViewDirection,
    ) ?sdk.math.Mat4 {
        const left_player = frame.getPlayerBySide(.left).position orelse return null;
        const right_player = frame.getPlayerBySide(.right).position orelse return null;
        const eye = left_player.add(right_player).scale(0.5);
        const difference_2d = right_player.swizzle("xy").subtract(left_player.swizzle("xy"));
        const player_dir = if (!difference_2d.isZero(0)) difference_2d.normalize().extend(0) else sdk.math.Vec3.plus_x;
        const look_direction = switch (direction) {
            .front => player_dir.cross(sdk.math.Vec3.minus_z),
            .side => player_dir.negate(),
            .top => sdk.math.Vec3.plus_z,
        };
        const target = eye.add(look_direction);
        const up = switch (direction) {
            .front, .side => sdk.math.Vec3.plus_z,
            .top => player_dir.cross(sdk.math.Vec3.plus_z),
        };
        return sdk.math.Mat4.fromLookAt(eye, target, up);
    }

    fn calculateOrthographicMatrix(
        self: *const Self,
        frame: *const model.Frame,
        direction: ui.ViewDirection,
        look_at_matrix: sdk.math.Mat4,
    ) ?sdk.math.Mat4 {
        var min = sdk.math.Vec3.fill(std.math.inf(f32));
        var max = sdk.math.Vec3.fill(-std.math.inf(f32));
        for (&frame.players) |*player| {
            if (player.collision_spheres) |*spheres| {
                for (&spheres.values) |*sphere| {
                    const pos = sphere.center.pointTransform(look_at_matrix);
                    const half_size = sdk.math.Vec3.fill(sphere.radius);
                    min = sdk.math.Vec3.minElements(min, pos.subtract(half_size));
                    max = sdk.math.Vec3.maxElements(max, pos.add(half_size));
                }
            }
            if (player.hurt_cylinders) |*cylinders| {
                for (&cylinders.values) |*hurt_cylinder| {
                    const cylinder = &hurt_cylinder.cylinder;
                    const pos = cylinder.center.pointTransform(look_at_matrix);
                    const half_size = sdk.math.Vec3.fromArray(.{
                        cylinder.radius,
                        cylinder.radius,
                        cylinder.half_height,
                    });
                    min = sdk.math.Vec3.minElements(min, pos.subtract(half_size));
                    max = sdk.math.Vec3.maxElements(max, pos.add(half_size));
                }
            }
        }
        const padding = sdk.math.Vec3.fill(50);
        const world_box = sdk.math.Vec3.maxElements(min.negate(), max).add(padding).scale(2);
        const screen_box = switch (direction) {
            .front => sdk.math.Vec3.fromArray(.{
                @min(self.windows.get(.front).size.x(), self.windows.get(.top).size.x()),
                @min(self.windows.get(.front).size.y(), self.windows.get(.side).size.y()),
                @min(self.windows.get(.top).size.y(), self.windows.get(.side).size.x()),
            }),
            .side => sdk.math.Vec3.fromArray(.{
                @min(self.windows.get(.side).size.x(), self.windows.get(.top).size.y()),
                @min(self.windows.get(.side).size.y(), self.windows.get(.front).size.y()),
                @min(self.windows.get(.front).size.x(), self.windows.get(.top).size.x()),
            }),
            .top => sdk.math.Vec3.fromArray(.{
                @min(self.windows.get(.top).size.x(), self.windows.get(.front).size.x()),
                @min(self.windows.get(.top).size.y(), self.windows.get(.side).size.x()),
                @min(self.windows.get(.front).size.y(), self.windows.get(.side).size.y()),
            }),
        };
        const scale_factors = world_box.divideElements(screen_box);
        const max_factor = @max(scale_factors.x(), scale_factors.y(), scale_factors.z());
        const viewport_size = self.windows.get(direction).size.extend(screen_box.z()).scale(max_factor);
        return sdk.math.Mat4.fromOrthographic(
            -0.5 * viewport_size.x(),
            0.5 * viewport_size.x(),
            -0.5 * viewport_size.y(),
            0.5 * viewport_size.y(),
            -0.5 * viewport_size.z(),
            0.5 * viewport_size.z(),
        );
    }

    fn calculateWindowMatrix(self: *const Self, direction: ui.ViewDirection) sdk.math.Mat4 {
        const window = self.windows.get(direction);
        return sdk.math.Mat4.identity
            .scale(sdk.math.Vec3.fromArray(.{ 0.5 * window.size.x(), -0.5 * window.size.y(), 1 }))
            .translate(window.size.scale(0.5).add(window.position).extend(0));
    }
};
