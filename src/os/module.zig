const std = @import("std");
const w32 = @import("win32").everything;
const w = std.unicode.utf8ToUtf16LeStringLiteral;
const Process = @import("process.zig").Process;
const MemoryRange = @import("../memory/memory_range.zig").MemoryRange;

pub const Module = struct {
    handle: w32.HMODULE,

    const Self = @This();

    pub fn getMain() !Self {
        const optional_handle = w32.GetModuleHandleW(null);
        if (optional_handle) |handle| {
            return handle;
        } else {
            return error.OsError;
        }
    }

    pub fn getByName(comptime name: []const u8) !Self {
        const optional_handle = w32.GetModuleHandleW(w(name));
        if (optional_handle) |handle| {
            return handle;
        } else {
            return error.OsError;
        }
    }

    pub fn getMemoryRange(self: *const Self) !MemoryRange {
        const process = Process.getCurrent();
        var info: w32.MODULEINFO = undefined;
        const success = w32.GetModuleInformation(process.handle, self.handle, &info, @sizeOf(@TypeOf(info)));
        if (success == 0) {
            return error.OsError;
        }
        return .{
            .base_address = info.lpBaseOfDll,
            .size_in_bytes = info.SizeOfImage,
        };
    }

    pub fn getProcedureAddress(self: *const Self, procedure_name: []const u8) !usize {
        const optional_address = w32.GetProcAddress(self.handle, procedure_name);
        if (optional_address) |address| {
            return @intFromPtr(address);
        } else {
            return error.OsError;
        }
    }
};

const testing = std.testing;

test "getMain should return a module with readable memory range" {
    const module = try Module.getMain();
    const memory_range = try module.getMemoryRange();
    testing.expectEqual(true, memory_range.isReadable());
}

test "getByName should return a module with readable memory range when module name is valid" {
    const module = try Module.getByName("KERNEL32.DLL");
    const memory_range = try module.getMemoryRange();
    testing.expectEqual(true, memory_range.isReadable());
}

test "getByName should return error when module name is invalid" {
    testing.expectError(error.OsError, Module.getByName("invalid module name"));
}

test "getProcedureAddress should return a address when procedure name is valid" {
    const module = try Module.getByName("KERNEL32.DLL");
    _ = try module.getProcedureAddress("GetModuleHandleW");
}

test "getProcedureAddress should return error when procedure name is invalid" {
    const module = try Module.getByName("KERNEL32.DLL");
    testing.expectError(error.OsError, module.getProcedureAddress("invalid procedure name"));
}
