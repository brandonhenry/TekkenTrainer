const std = @import("std");
const w32 = @import("win32").everything;

pub fn isMemoryReadable(address: usize, size_in_bytes: usize) bool {
    var info: w32.MEMORY_BASIC_INFORMATION = undefined;
    const success = w32.VirtualQuery(@ptrFromInt(address), &info, @sizeOf(@TypeOf(info)));
    return success != 0 and
        address >= @intFromPtr(info.BaseAddress) and
        address + size_in_bytes <= @intFromPtr(info.BaseAddress) + info.RegionSize and
        (info.Protect.PAGE_EXECUTE == 1 or
        info.Protect.PAGE_EXECUTE_READWRITE == 1 or
        info.Protect.PAGE_EXECUTE_WRITECOPY == 1 or
        info.Protect.PAGE_READONLY == 1 or
        info.Protect.PAGE_READWRITE == 1 or
        info.Protect.PAGE_WRITECOPY == 1);
}

pub fn isMemoryWriteable(address: usize, size_in_bytes: usize) bool {
    var info: w32.MEMORY_BASIC_INFORMATION = undefined;
    const success = w32.VirtualQuery(@ptrFromInt(address), &info, @sizeOf(@TypeOf(info)));
    return success != 0 and
        address >= @intFromPtr(info.BaseAddress) and
        address + size_in_bytes <= @intFromPtr(info.BaseAddress) + info.RegionSize and
        info.State.COMMIT == 1 and
        (info.Protect.PAGE_EXECUTE_READWRITE == 1 or
        info.Protect.PAGE_EXECUTE_WRITECOPY == 1 or
        info.Protect.PAGE_READWRITE == 1 or
        info.Protect.PAGE_WRITECOPY == 1);
}

const testing = std.testing;

test "isMemoryReadable should return true when memory range is readable and writeable" {
    var memory = [_]u8{ 0, 1, 2, 3, 4 };
    const address = @intFromPtr(&memory);
    const size_in_bytes = @sizeOf(@TypeOf(memory));
    try testing.expectEqual(true, isMemoryReadable(address, size_in_bytes));
}

test "isMemoryReadable should return true when memory range is only readable" {
    const memory = [_]u8{ 0, 1, 2, 3, 4 };
    const address = @intFromPtr(&memory);
    const size_in_bytes = @sizeOf(@TypeOf(memory));
    try testing.expectEqual(true, isMemoryReadable(address, size_in_bytes));
}

test "isMemoryReadable should return false when memory range is not readable" {
    const address = std.math.maxInt(usize) - 5;
    const size_in_bytes = 5;
    try testing.expectEqual(false, isMemoryReadable(address, size_in_bytes));
}

test "isMemoryReadable should return false when memory address is null" {
    const address = 0;
    const size_in_bytes = 5;
    try testing.expectEqual(false, isMemoryReadable(address, size_in_bytes));
}

test "isMemoryWriteable should return true when memory range is readable and writeable" {
    var memory = [_]u8{ 0, 1, 2, 3, 4 };
    const address = @intFromPtr(&memory);
    const size_in_bytes = @sizeOf(@TypeOf(memory));
    try testing.expectEqual(true, isMemoryWriteable(address, size_in_bytes));
}

test "isMemoryWriteable should return false when memory range is only readable" {
    const memory = [_]u8{ 0, 1, 2, 3, 4 };
    const address = @intFromPtr(&memory);
    const size_in_bytes = @sizeOf(@TypeOf(memory));
    try testing.expectEqual(false, isMemoryWriteable(address, size_in_bytes));
}

test "isMemoryWriteable should return false when memory range is not readable" {
    const address = std.math.maxInt(usize) - 5;
    const size_in_bytes = 5;
    try testing.expectEqual(false, isMemoryWriteable(address, size_in_bytes));
}

test "isMemoryWriteable should return false when memory address is null" {
    const address = 0;
    const size_in_bytes = 5;
    try testing.expectEqual(false, isMemoryWriteable(address, size_in_bytes));
}
