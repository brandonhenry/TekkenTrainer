const std = @import("std");
const w32 = @import("win32").everything;
const os = @import("root.zig");
const memory = @import("../memory/root.zig");

pub const Module = struct {
    process: os.Process,
    handle: w32.HINSTANCE,

    const Self = @This();
    pub const max_file_path = 260;
    pub const max_modules = 8192;

    pub fn getMain() !Self {
        const handle = w32.GetModuleHandleW(null) orelse return error.OsError;
        return .{ .process = os.Process.getCurrent(), .handle = handle };
    }

    pub fn getLocal(name: []const u8) !Self {
        var buffer = [_:0]u16{0} ** max_file_path;
        const size = try std.unicode.utf8ToUtf16Le(&buffer, name);
        const utf16_name = buffer[0..size :0];
        const handle = w32.GetModuleHandleW(utf16_name) orelse return error.OsError;
        return .{ .process = os.Process.getCurrent(), .handle = handle };
    }

    pub fn getRemote(process: os.Process, file_name: []const u8) !Self {
        var buffer: [max_modules]?w32.HINSTANCE = undefined;
        var number_of_bytes: u32 = undefined;
        const success = w32.K32EnumProcessModules(
            process.handle,
            &buffer[0],
            @sizeOf(@TypeOf(buffer)),
            &number_of_bytes,
        );
        if (success == 0) {
            return error.OsError;
        }
        const size: usize = number_of_bytes / @sizeOf(w32.HINSTANCE);
        const handles = buffer[0..size];
        for (handles) |optional_handle| {
            const handle = optional_handle orelse continue;
            const module = Self{ .process = process, .handle = handle };
            var path_buffer: [max_file_path]u8 = undefined;
            const path_size = module.getFilePath(&path_buffer) catch continue;
            const path = path_buffer[0..path_size];
            const name = os.pathToFileName(path);
            if (std.mem.eql(u8, name, file_name)) {
                return module;
            }
        }
        return error.NotFound;
    }

    pub fn getFilePath(self: *const Self, path_buffer: *[max_file_path]u8) !usize {
        var buffer: [max_file_path:0]u16 = undefined;
        const size = w32.K32GetModuleFileNameExW(self.process.handle, self.handle, &buffer, buffer.len);
        if (size == 0) {
            return error.OsError;
        }
        return std.unicode.utf16LeToUtf8(path_buffer, buffer[0..size]);
    }

    pub fn getMemoryRange(self: *const Self) !memory.MemoryRange {
        var info: w32.MODULEINFO = undefined;
        const success = w32.K32GetModuleInformation(self.process.handle, self.handle, &info, @sizeOf(@TypeOf(info)));
        if (success == 0) {
            return error.OsError;
        }
        return .{
            .base_address = @intFromPtr(info.lpBaseOfDll),
            .size_in_bytes = info.SizeOfImage,
        };
    }

    pub fn getProcedureAddress(self: *const Self, procedure_name: [:0]const u8) !usize {
        if (self.process.handle != os.Process.getCurrent().handle) {
            return error.NotCurrentProcess;
        }
        const address = w32.GetProcAddress(self.handle, procedure_name) orelse return error.OsError;
        return @intFromPtr(address);
    }
};

const testing = std.testing;

test "getMain should return a module with readable memory range" {
    const module = try Module.getMain();
    const memory_range = try module.getMemoryRange();
    try testing.expectEqual(true, memory_range.isReadable());
}

test "getLocal should return a module with readable memory range when module name is valid" {
    const module = try Module.getLocal("kernel32.dll");
    const memory_range = try module.getMemoryRange();
    try testing.expectEqual(true, memory_range.isReadable());
}

test "getLocal should error when module name is invalid" {
    try testing.expectError(error.OsError, Module.getLocal("invalid module name"));
}

test "getRemote should return a module with readable memory range when module name is valid" {
    const module = try Module.getRemote(os.Process.getCurrent(), "kernel32.dll");
    const memory_range = try module.getMemoryRange();
    try testing.expectEqual(true, memory_range.isReadable());
}

test "getRemote should error when module name is invalid" {
    try testing.expectError(error.NotFound, Module.getRemote(os.Process.getCurrent(), "invalid module name"));
}

test "getFilePath should return correct value" {
    const module = try Module.getLocal("kernel32.dll");
    var buffer: [Module.max_file_path]u8 = undefined;
    const size = try module.getFilePath(&buffer);
    const path = buffer[0..size];
    try testing.expectStringEndsWith(path, "kernel32.dll");
}

test "getProcedureAddress should return a address when procedure name is valid" {
    const module = try Module.getLocal("kernel32.dll");
    _ = try module.getProcedureAddress("GetModuleHandleW");
}

test "getProcedureAddress should error when procedure name is invalid" {
    const module = try Module.getLocal("kernel32.dll");
    try testing.expectError(error.OsError, module.getProcedureAddress("invalid procedure name"));
}
