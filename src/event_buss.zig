const std = @import("std");
const w32 = @import("win32").everything;
const gui = @import("zgui");

pub const EventBuss = struct {
    const Self = @This();

    pub fn init(
        window: w32.HWND,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
        swap_chain: *const w32.IDXGISwapChain,
    ) Self {
        _ = window;
        _ = device;
        _ = command_queue;
        _ = swap_chain;
        return .{};
    }

    pub fn deinit(
        self: *Self,
        window: w32.HWND,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
        swap_chain: *const w32.IDXGISwapChain,
    ) void {
        _ = self;
        _ = window;
        _ = device;
        _ = command_queue;
        _ = swap_chain;
    }

    pub fn update(
        self: *Self,
        window: w32.HWND,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
        swap_chain: *const w32.IDXGISwapChain,
    ) void {
        _ = self;
        _ = window;
        _ = device;
        _ = command_queue;
        _ = swap_chain;
    }
};
