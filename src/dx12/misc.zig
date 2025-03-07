const std = @import("std");
const w32 = @import("win32").everything;
const dx12 = @import("root.zig");
const misc = @import("../misc/root.zig");

pub fn getWindowFromSwapChain(swap_chain: *const w32.IDXGISwapChain) !w32.HWND {
    var desc: w32.DXGI_SWAP_CHAIN_DESC = undefined;
    const return_code = swap_chain.IDXGISwapChain_GetDesc(&desc);
    if (return_code != w32.S_OK) {
        misc.errorContext().newFmt(error.Dx12Error, "IDXGISwapChain.GetDesc returned: {}", .{return_code});
        return error.Dx12Error;
    }
    return desc.OutputWindow orelse error.NotFound;
}

pub fn getDeviceFromSwapChain(swap_chain: *const w32.IDXGISwapChain) !(*const w32.ID3D12Device) {
    var device: *const w32.ID3D12Device = undefined;
    const return_code = swap_chain.IDXGIDeviceSubObject_GetDevice(w32.IID_ID3D12Device, @ptrCast(&device));
    if (return_code != w32.S_OK) {
        misc.errorContext().newFmt(error.Dx12Error, "IDXGISwapChain.GetDevice returned: {}", .{return_code});
        return error.Dx12Error;
    }
    return device;
}

const testing = std.testing;

test "getWindowFromSwapChain should return correct value" {
    const context = try dx12.TestingContext.init();
    defer context.deinit();
    try testing.expectEqual(context.window, getWindowFromSwapChain(context.swap_chain));
}

test "getDeviceFromSwapChain should return correct value" {
    const context = try dx12.TestingContext.init();
    defer context.deinit();
    try testing.expectEqual(context.device, getDeviceFromSwapChain(context.swap_chain));
}
