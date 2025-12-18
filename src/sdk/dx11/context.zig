const std = @import("std");
const w32 = @import("win32").everything;

pub const HostContext = struct {
    window: w32.HWND,
    device: *const w32.ID3D11Device,
    swap_chain: *const w32.IDXGISwapChain,
};
