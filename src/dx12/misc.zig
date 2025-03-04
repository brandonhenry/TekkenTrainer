const std = @import("std");
const w32 = @import("win32").everything;
const dx12 = @import("root.zig");
const misc = @import("../misc/root.zig");

pub fn getDeviceFromSwapChain(swap_chain: *const w32.IDXGISwapChain) !(*const w32.ID3D12Device) {
    var device: *const w32.ID3D12Device = undefined;
    const device_return_code = swap_chain.IDXGIDeviceSubObject_GetDevice(w32.IID_ID3D12Device, @ptrCast(&device));
    if (device_return_code != w32.S_OK) {
        misc.errorContext().newFmt(error.DirectXError, "IDXGISwapChain.GetDevice returned: {}", .{device_return_code});
        return error.DirectXError;
    }
    return device;
}

const testing = std.testing;

test "getDeviceFromSwapChain should return correct value" {
    const context = try dx12.TestingContext.init();
    defer context.deinit();
    try testing.expectEqual(context.device, getDeviceFromSwapChain(context.swap_chain));
}
