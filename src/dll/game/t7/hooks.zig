const std = @import("std");
const t7 = @import("root.zig");

pub fn Hooks(onTick: *const fn () void) type {
    _ = onTick;
    return struct {
        pub fn init(game_functions: *const t7.Memory.Functions) void {
            _ = game_functions;
        }

        pub fn deinit() void {}
    };
}
