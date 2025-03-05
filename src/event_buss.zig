const std = @import("std");
const w32 = @import("win32").everything;
const gui = @import("zgui");

pub const EventBuss = struct {
    const Self = @This();

    pub fn init(
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
    ) Self {
        _ = device;
        _ = command_queue;
        return .{};
    }

    pub fn deinit(
        self: *Self,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
    ) void {
        _ = self;
        _ = device;
        _ = command_queue;
    }

    pub fn update(
        self: *Self,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
    ) void {
        _ = self;
        _ = device;
        _ = command_queue;
    }
};
