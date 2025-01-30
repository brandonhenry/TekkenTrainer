const std = @import("std");
const memory = @import("../os/memory.zig");

pub const MemoryRange = struct {
    base_address: usize,
    size_in_bytes: usize,

    const Self = @This();

    pub fn isReadable(self: *const Self) bool {
        return memory.isMemoryReadable(self.base_address, self.size_in_bytes);
    }

    pub fn isWriteable(self: *const Self) bool {
        return memory.isMemoryWriteable(self.base_address, self.size_in_bytes);
    }
};

const testing = std.testing;

test "isReadable should return true when memory is readable and writable" {
    var array = [_]u8{ 0, 1, 2, 3, 4 };
    const memory_range = MemoryRange{
        .base_address = @intFromPtr(&array),
        .size_in_bytes = @sizeOf(@TypeOf(array)),
    };
    try testing.expectEqual(true, memory_range.isReadable());
}

test "isReadable should return true when memory is only readable" {
    const array = [_]u8{ 0, 1, 2, 3, 4 };
    const memory_range = MemoryRange{
        .base_address = @intFromPtr(&array),
        .size_in_bytes = @sizeOf(@TypeOf(array)),
    };
    try testing.expectEqual(true, memory_range.isReadable());
}

test "isReadable should return false when memory not readable" {
    const memory_range = MemoryRange{
        .base_address = std.math.maxInt(usize) - 5,
        .size_in_bytes = 5,
    };
    try testing.expectEqual(false, memory_range.isReadable());
}

test "isReadable should return false when base address is null" {
    const memory_range = MemoryRange{
        .base_address = 0,
        .size_in_bytes = 5,
    };
    try testing.expectEqual(false, memory_range.isReadable());
}

test "isWriteable should return true when memory is readable and writable" {
    var array = [_]u8{ 0, 1, 2, 3, 4 };
    const memory_range = MemoryRange{
        .base_address = @intFromPtr(&array),
        .size_in_bytes = @sizeOf(@TypeOf(array)),
    };
    try testing.expectEqual(true, memory_range.isWriteable());
}

test "isWriteable should return false when memory is only readable" {
    const array = [_]u8{ 0, 1, 2, 3, 4 };
    const memory_range = MemoryRange{
        .base_address = @intFromPtr(&array),
        .size_in_bytes = @sizeOf(@TypeOf(array)),
    };
    try testing.expectEqual(false, memory_range.isWriteable());
}

test "isWriteable should return false when memory not readable" {
    const memory_range = MemoryRange{
        .base_address = std.math.maxInt(usize) - 5,
        .size_in_bytes = 5,
    };
    try testing.expectEqual(false, memory_range.isWriteable());
}

test "isWriteable should return false when base address is null" {
    const memory_range = MemoryRange{
        .base_address = 0,
        .size_in_bytes = 5,
    };
    try testing.expectEqual(false, memory_range.isWriteable());
}
