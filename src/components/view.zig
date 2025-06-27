const std = @import("std");
const imgui = @import("imgui");
const math = @import("../math/root.zig");
const game = @import("../game/root.zig");

pub const View = enum {
    front,
    side,
    top,

    const Self = @This();
    pub const Player = struct {
        hit_lines_start: game.HitLinePoints,
        hit_lines_end: game.HitLinePoints,
        hurt_cylinders: game.HurtCylinders,
        collision_spheres: game.CollisionSpheres,
    };

    const collision_spheres_color = imgui.ImVec4{ .x = 0.0, .y = 0.0, .z = 1.0, .w = 0.5 };
    const collision_spheres_thickness = 1.0;
    const hurt_cylinders_color = imgui.ImVec4{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 0.5 };
    const hurt_cylinders_thickness = 1.0;
    const stick_figure_color = imgui.ImVec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 };
    const stick_figure_thickness = 2.0;

    pub fn draw(self: Self, player_1: *const Player, player_2: *const Player) void {
        const matrix = self.calculateFinalMatrix(player_1, player_2);
        const inverse_matrix = matrix.inverse() orelse math.Mat4.identity;
        drawCollisionSpheres(player_1, matrix, inverse_matrix);
        drawCollisionSpheres(player_2, matrix, inverse_matrix);
        self.drawHurtCylinders(player_1, matrix, inverse_matrix);
        self.drawHurtCylinders(player_2, matrix, inverse_matrix);
        drawStickFigure(player_1, matrix);
        drawStickFigure(player_2, matrix);
    }

    fn calculateFinalMatrix(self: Self, player_1: *const Player, player_2: *const Player) math.Mat4 {
        const look_at_matrix = self.calculateLookAtMatrix(player_1, player_2);
        const orthographic_matrix = calculateOrthographicMatrix(player_1, player_2, look_at_matrix);
        const window_matrix = calculateWindowMatrix();
        return look_at_matrix.multiply(orthographic_matrix).multiply(window_matrix);
    }

    fn calculateWindowMatrix() math.Mat4 {
        var window_pos: math.Vec2 = undefined;
        imgui.igGetCursorScreenPos(window_pos.asImVecPointer());
        var window_size: math.Vec2 = undefined;
        imgui.igGetContentRegionAvail(window_size.asImVecPointer());
        return math.Mat4.identity
            .scale(math.Vec3.fromArray(.{ 0.5 * window_size.x(), -0.5 * window_size.y(), 1 }))
            .translate(window_size.scale(0.5).add(window_pos).extend(0));
    }

    fn calculateLookAtMatrix(self: Self, player_1: *const Player, player_2: *const Player) math.Mat4 {
        const p1 = getPlayerPosition(player_1);
        const p2 = getPlayerPosition(player_2);
        const eye = p1.add(p2).scale(0.5);
        const difference_2d = p2.swizzle("xy").subtract(p1.swizzle("xy"));
        const player_dir = if (!difference_2d.isZero(0)) difference_2d.normalize().extend(0) else math.Vec3.plus_x;
        const look_direction = switch (self) {
            .front => player_dir.cross(math.Vec3.minus_z),
            .side => player_dir,
            .top => math.Vec3.minus_z,
        };
        const target = eye.add(look_direction);
        const up = switch (self) {
            .front, .side => math.Vec3.plus_z,
            .top => player_dir.cross(math.Vec3.minus_z),
        };
        return math.Mat4.fromLookAt(eye, target, up);
    }

    fn calculateOrthographicMatrix(player_1: *const Player, player_2: *const Player, look_at_matrix: math.Mat4) math.Mat4 {
        var min = math.Vec3.fill(std.math.inf(f32));
        var max = math.Vec3.fill(-std.math.inf(f32));
        for ([2](*const Player){ player_1, player_2 }) |player| {
            for (player.hurt_cylinders.values) |c| {
                const cylinder = c.getValue();
                const pos = math.Vec3.fromArray(cylinder.position).pointTransform(look_at_matrix);
                const half_size = math.Vec3.fromArray(.{
                    cylinder.radius,
                    cylinder.radius,
                    cylinder.half_height,
                }).directionTransform(look_at_matrix);
                const min_pos = pos.subtract(half_size);
                const max_pos = pos.add(half_size);
                if (min_pos.x() < min.x()) min.coords.x = min_pos.x();
                if (min_pos.y() < min.y()) min.coords.y = min_pos.y();
                if (min_pos.z() < min.z()) min.coords.z = min_pos.z();
                if (max_pos.x() > max.x()) max.coords.x = max_pos.x();
                if (max_pos.y() > max.y()) max.coords.y = max_pos.y();
                if (max_pos.z() > max.z()) max.coords.z = max_pos.z();
            }
            for (player.collision_spheres.values) |s| {
                const sphere = s.getValue();
                const pos = math.Vec3.fromArray(sphere.position).pointTransform(look_at_matrix);
                const half_size = math.Vec3.fill(sphere.radius).directionTransform(look_at_matrix);
                const min_pos = pos.subtract(half_size);
                const max_pos = pos.add(half_size);
                if (min_pos.x() < min.x()) min.coords.x = min_pos.x();
                if (min_pos.y() < min.y()) min.coords.y = min_pos.y();
                if (min_pos.z() < min.z()) min.coords.z = min_pos.z();
                if (max_pos.x() > max.x()) max.coords.x = max_pos.x();
                if (max_pos.y() > max.y()) max.coords.y = max_pos.y();
                if (max_pos.z() > max.z()) max.coords.z = max_pos.z();
            }
        }
        const padding = math.Vec3.fill(50);
        min = min.subtract(padding);
        max = max.add(padding);
        return math.Mat4.fromOrthographic(min.x(), max.x(), min.y(), max.y(), min.z(), max.z());
    }

    fn getPlayerPosition(player: *const Player) math.Vec3 {
        return math.Vec3.fromArray(player.collision_spheres.get(.lower_torso).getValue().position);
    }

    fn drawCollisionSpheres(player: *const Player, matrix: math.Mat4, inverse_matrix: math.Mat4) void {
        const world_right = math.Vec3.plus_x.directionTransform(inverse_matrix).normalize();
        const world_up = math.Vec3.plus_y.directionTransform(inverse_matrix).normalize();

        const color = imgui.igGetColorU32_Vec4(collision_spheres_color);
        const thickness = collision_spheres_thickness;

        const draw_list = imgui.igGetWindowDrawList();
        for (player.collision_spheres.values) |s| {
            const sphere = s.getValue();
            const pos = math.Vec3.fromArray(sphere.position).pointTransform(matrix).swizzle("xy");
            const radius = world_up.add(world_right).scale(sphere.radius).directionTransform(matrix).swizzle("xy");
            imgui.ImDrawList_AddEllipse(draw_list, pos.toImVec(), radius.toImVec(), color, 0, 32, thickness);
        }
    }

    fn drawHurtCylinders(self: Self, player: *const Player, matrix: math.Mat4, inverse_matrix: math.Mat4) void {
        const world_right = math.Vec3.plus_x.directionTransform(inverse_matrix).normalize();
        const world_up = math.Vec3.plus_y.directionTransform(inverse_matrix).normalize();

        const color = imgui.igGetColorU32_Vec4(hurt_cylinders_color);
        const thickness = hurt_cylinders_thickness;

        const draw_list = imgui.igGetWindowDrawList();
        for (player.hurt_cylinders.values) |c| {
            const cylinder = c.getValue();
            const pos = math.Vec3.fromArray(cylinder.position).pointTransform(matrix).swizzle("xy");
            switch (self) {
                .front, .side => {
                    const half_size = world_up.scale(cylinder.half_height)
                        .add(world_right.scale(cylinder.radius))
                        .directionTransform(matrix)
                        .swizzle("xy");
                    const min = pos.subtract(half_size);
                    const max = pos.add(half_size);
                    imgui.ImDrawList_AddRect(draw_list, min.toImVec(), max.toImVec(), color, 0, 0, thickness);
                },
                .top => {
                    const radius = world_up
                        .add(world_right)
                        .scale(cylinder.radius)
                        .directionTransform(matrix).swizzle("xy");
                    imgui.ImDrawList_AddEllipse(draw_list, pos.toImVec(), radius.toImVec(), color, 0, 32, thickness);
                },
            }
        }
    }

    fn drawStickFigure(player: *const Player, matrix: math.Mat4) void {
        const transform = struct {
            fn call(body_part: anytype, m: math.Mat4) imgui.ImVec2 {
                return math.Vec3.fromArray(body_part.getValue().position).pointTransform(m).swizzle("xy").toImVec();
            }
        }.call;
        const cylinders = &player.hurt_cylinders;
        const spheres = &player.collision_spheres;

        const head = transform(cylinders.get(.head), matrix);
        const neck = transform(spheres.get(.neck), matrix);
        const upper_torso = transform(cylinders.get(.upper_torso), matrix);
        const left_shoulder = transform(cylinders.get(.left_shoulder), matrix);
        const right_shoulder = transform(cylinders.get(.right_shoulder), matrix);
        const left_elbow = transform(cylinders.get(.left_elbow), matrix);
        const right_elbow = transform(cylinders.get(.right_elbow), matrix);
        const left_hand = transform(cylinders.get(.left_hand), matrix);
        const right_hand = transform(cylinders.get(.right_hand), matrix);
        const lower_torso = transform(spheres.get(.lower_torso), matrix);
        const left_pelvis = transform(cylinders.get(.left_pelvis), matrix);
        const right_pelvis = transform(cylinders.get(.right_pelvis), matrix);
        const left_knee = transform(cylinders.get(.left_knee), matrix);
        const right_knee = transform(cylinders.get(.right_knee), matrix);
        const left_ankle = transform(cylinders.get(.left_ankle), matrix);
        const right_ankle = transform(cylinders.get(.right_ankle), matrix);

        const color = imgui.igGetColorU32_Vec4(stick_figure_color);
        const thickness = stick_figure_thickness;

        const draw_list = imgui.igGetWindowDrawList();
        imgui.ImDrawList_AddLine(draw_list, head, neck, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, neck, upper_torso, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, upper_torso, left_shoulder, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, upper_torso, right_shoulder, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, left_shoulder, left_elbow, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, right_shoulder, right_elbow, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, left_elbow, left_hand, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, right_elbow, right_hand, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, upper_torso, lower_torso, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, lower_torso, left_pelvis, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, lower_torso, right_pelvis, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, left_pelvis, left_knee, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, right_pelvis, right_knee, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, left_knee, left_ankle, color, thickness);
        imgui.ImDrawList_AddLine(draw_list, right_knee, right_ankle, color, thickness);
    }
};
