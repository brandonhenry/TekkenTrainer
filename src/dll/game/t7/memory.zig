const std = @import("std");
const sdk = @import("../../../sdk/root.zig");

pub const Memory = struct {
    functions: Functions,

    const Self = @This();
    pub const Functions = struct {};

    const pattern_cache_file_name = "pattern_cache_t7.json";

    pub fn init(
        allocator: std.mem.Allocator,
        base_dir: ?*const sdk.misc.BaseDir,
        comptime game_hooks: type,
    ) Self {
        _ = allocator;
        _ = base_dir;
        _ = game_hooks;
        return .{ .functions = .{} };
    }
};
