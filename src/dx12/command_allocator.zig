const std = @import("std");
const builtin = @import("builtin");
const w32 = @import("win32").everything;
const misc = @import("../misc/root.zig");
const dx12 = @import("root.zig");

pub const CommandAllocator = struct {
    raw: *const w32.ID3D12CommandAllocator,
    test_allocation: if (builtin.is_test) *u8 else void,

    const Self = @This();

    pub fn create(device: *const w32.ID3D12Device) !Self {
        var command_allocator: *const w32.ID3D12CommandAllocator = undefined;
        const return_code = device.ID3D12Device_CreateCommandAllocator(
            .DIRECT,
            w32.IID_ID3D12CommandAllocator,
            @ptrCast(&command_allocator),
        );
        if (return_code != w32.S_OK) {
            misc.errorContext().newFmt(
                error.Dx12Error,
                "ID3D12Device.CreateCommandAllocator returned: {}",
                .{return_code},
            );
            return error.Dx12Error;
        }
        const test_allocation = if (builtin.is_test) try std.testing.allocator.create(u8) else {};
        return .{
            .raw = command_allocator,
            .test_allocation = test_allocation,
        };
    }

    pub fn destroy(self: *const Self) !void {
        const return_code = self.raw.IUnknown_Release();
        if (return_code != w32.S_OK) {
            misc.errorContext().newFmt(
                error.Dx12Error,
                "ID3D12CommandAllocator.Release returned: {}",
                .{return_code},
            );
            return error.Dx12Error;
        }
        if (builtin.is_test) {
            std.testing.allocator.destroy(self.test_allocation);
        }
    }
};

test "create and destroy should succeed" {
    const context = try dx12.TestingContext.init();
    defer context.deinit();
    const allocator = try CommandAllocator.create(context.device);
    defer allocator.destroy() catch @panic("Failed to destroy command allocator.");
}
