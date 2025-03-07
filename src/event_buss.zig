const std = @import("std");
const w32 = @import("win32").everything;
const dx12 = @import("dx12/root.zig");
const misc = @import("misc/root.zig");

pub const EventBuss = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    descriptor_heap: ?dx12.DescriptorHeap,

    const Self = @This();

    pub fn init(
        window: w32.HWND,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
        swap_chain: *const w32.IDXGISwapChain,
    ) Self {
        _ = window;
        _ = command_queue;
        _ = swap_chain;

        const gpa = std.heap.GeneralPurposeAllocator(.{}){};

        std.log.debug("Creating a DX12 descriptor heap...", .{});
        const descriptor_heap = if (dx12.DescriptorHeap.create(device)) |heap| block: {
            std.log.info("DX12 descriptor heap created.", .{});
            break :block heap;
        } else |err| block: {
            misc.errorContext().append(err, "Failed to create DX12 descriptor heap.");
            misc.errorContext().logError();
            break :block null;
        };

        return .{
            .gpa = gpa,
            .descriptor_heap = descriptor_heap,
        };
    }

    pub fn deinit(
        self: *Self,
        window: w32.HWND,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
        swap_chain: *const w32.IDXGISwapChain,
    ) void {
        _ = window;
        _ = device;
        _ = command_queue;
        _ = swap_chain;

        std.log.debug("Destroying the DX12 descriptor heap...", .{});
        if (self.descriptor_heap) |heap| {
            if (heap.destroy()) {
                std.log.info("DX12 descriptor heap destroyed.", .{});
                self.descriptor_heap = null;
            } else |err| {
                misc.errorContext().append(err, "Failed to destroy DX12 descriptor heap.");
                misc.errorContext().logError();
            }
        } else {
            std.log.debug("Nothing to destroy.", .{});
        }

        switch (self.gpa.deinit()) {
            .ok => {},
            .leak => std.log.err("GPA detected a memory leak.", .{}),
        }
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
