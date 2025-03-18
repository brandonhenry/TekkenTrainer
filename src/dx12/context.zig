const std = @import("std");
const builtin = @import("builtin");
const w32 = @import("win32").everything;
const misc = @import("../misc/root.zig");
const dx12 = @import("root.zig");

pub fn Context(comptime buffer_count: usize, comptime svr_heap_size: usize) type {
    return struct {
        rtv_descriptor_heap: *w32.ID3D12DescriptorHeap,
        srv_descriptor_heap: *w32.ID3D12DescriptorHeap,
        srv_allocator: dx12.DescriptorHeapAllocator(svr_heap_size),
        buffer_contexts: [buffer_count]BufferContext,
        test_allocation: if (builtin.is_test) *u8 else void,

        const Self = @This();

        pub fn init(device: *const w32.ID3D12Device, swap_chain: *const w32.IDXGISwapChain) !Self {
            var rtv_descriptor_heap: *w32.ID3D12DescriptorHeap = undefined;
            const rtv_return_code = device.ID3D12Device_CreateDescriptorHeap(&.{
                .Type = .RTV,
                .NumDescriptors = buffer_count,
                .Flags = .{},
                .NodeMask = 1,
            }, w32.IID_ID3D12DescriptorHeap, @ptrCast(&rtv_descriptor_heap));
            if (rtv_return_code != w32.S_OK) {
                misc.errorContext().newFmt(
                    error.Dx12Error,
                    "ID3D12Device.CreateDescriptorHeap returned: {}",
                    .{rtv_return_code},
                );
                misc.errorContext().append(error.Dx12Error, "Failed to create RTV descriptor heap.");
                return error.Dx12Error;
            }
            errdefer _ = rtv_descriptor_heap.IUnknown_Release();

            var srv_descriptor_heap: *w32.ID3D12DescriptorHeap = undefined;
            const srv_return_code = device.ID3D12Device_CreateDescriptorHeap(&.{
                .Type = .CBV_SRV_UAV,
                .NumDescriptors = svr_heap_size,
                .Flags = .{ .SHADER_VISIBLE = 1 },
                .NodeMask = 0,
            }, w32.IID_ID3D12DescriptorHeap, @ptrCast(&srv_descriptor_heap));
            if (srv_return_code != w32.S_OK) {
                misc.errorContext().newFmt(
                    error.Dx12Error,
                    "ID3D12Device.CreateDescriptorHeap returned: {}",
                    .{srv_return_code},
                );
                misc.errorContext().append(error.Dx12Error, "Failed to create SRV descriptor heap.");
                return error.Dx12Error;
            }
            errdefer _ = srv_descriptor_heap.IUnknown_Release();

            const srv_allocator = dx12.DescriptorHeapAllocator(svr_heap_size){
                .cpu_start = dx12.getCpuDescriptorHandleForHeapStart(srv_descriptor_heap),
                .gpu_start = dx12.getGpuDescriptorHandleForHeapStart(srv_descriptor_heap),
                .increment = device.ID3D12Device_GetDescriptorHandleIncrementSize(.CBV_SRV_UAV),
            };

            var buffer_contexts: [buffer_count]BufferContext = undefined;
            inline for (0..buffer_contexts.len) |index| {
                buffer_contexts[index] = BufferContext.init(
                    device,
                    swap_chain,
                    rtv_descriptor_heap,
                    index,
                ) catch |err| {
                    misc.errorContext().appendFmt(err, "Failed to create buffer context with index: {}", .{index});
                    return err;
                };
                errdefer buffer_contexts[index].deinit();
            }

            const test_allocation = if (builtin.is_test) try std.testing.allocator.create(u8) else {};

            return .{
                .rtv_descriptor_heap = rtv_descriptor_heap,
                .srv_descriptor_heap = srv_descriptor_heap,
                .srv_allocator = srv_allocator,
                .buffer_contexts = buffer_contexts,
                .test_allocation = test_allocation,
            };
        }

        pub fn deinit(self: *const Self) void {
            inline for (self.buffer_contexts) |context| {
                context.deinit();
            }

            _ = self.srv_descriptor_heap.IUnknown_Release();
            _ = self.rtv_descriptor_heap.IUnknown_Release();

            if (builtin.is_test) {
                std.testing.allocator.destroy(self.test_allocation);
            }
        }
    };
}

pub const BufferContext = struct {
    command_allocator: *w32.ID3D12CommandAllocator,
    command_list: *w32.ID3D12GraphicsCommandList,
    resource: *w32.ID3D12Resource,
    rtv_descriptor_handle: w32.D3D12_CPU_DESCRIPTOR_HANDLE,
    test_allocation: if (builtin.is_test) *u8 else void,

    const Self = @This();

    pub fn init(
        device: *const w32.ID3D12Device,
        swap_chain: *const w32.IDXGISwapChain,
        rtv_descriptor_heap: *w32.ID3D12DescriptorHeap,
        index: u32,
    ) !Self {
        var command_allocator: *w32.ID3D12CommandAllocator = undefined;
        const allocator_return_code = device.ID3D12Device_CreateCommandAllocator(
            .DIRECT,
            w32.IID_ID3D12CommandAllocator,
            @ptrCast(&command_allocator),
        );
        if (allocator_return_code != w32.S_OK) {
            misc.errorContext().newFmt(
                error.Dx12Error,
                "ID3D12Device.CreateCommandAllocator returned: {}",
                .{allocator_return_code},
            );
            misc.errorContext().append(error.Dx12Error, "Failed to create command allocator.");
            return error.Dx12Error;
        }
        errdefer _ = command_allocator.IUnknown_Release();

        var command_list: *w32.ID3D12GraphicsCommandList = undefined;
        const list_return_code = device.ID3D12Device_CreateCommandList(
            0,
            .DIRECT,
            command_allocator,
            null,
            w32.IID_ID3D12GraphicsCommandList,
            @ptrCast(&command_list),
        );
        if (list_return_code != w32.S_OK) {
            misc.errorContext().newFmt(
                error.Dx12Error,
                "ID3D12Device.CreateCommandList returned: {}",
                .{list_return_code},
            );
            misc.errorContext().append(error.Dx12Error, "Failed to create command list.");
            return error.Dx12Error;
        }
        errdefer _ = command_list.IUnknown_Release();

        const close_return_code = command_list.ID3D12GraphicsCommandList_Close();
        if (close_return_code != w32.S_OK) {
            misc.errorContext().newFmt(
                error.Dx12Error,
                "ID3D12GraphicsCommandList.Close returned: {}",
                .{close_return_code},
            );
            misc.errorContext().append(error.Dx12Error, "Failed to close command list.");
            return error.Dx12Error;
        }

        var resource: *w32.ID3D12Resource = undefined;
        const resource_return_code = swap_chain.IDXGISwapChain_GetBuffer(
            index,
            w32.IID_ID3D12Resource,
            @ptrCast(&resource),
        );
        if (resource_return_code != w32.S_OK) {
            misc.errorContext().newFmt(
                error.Dx12Error,
                "IDXGISwapChain.GetBuffer returned: {}",
                .{resource_return_code},
            );
            misc.errorContext().append(error.Dx12Error, "Failed to get buffer resource.");
            return error.Dx12Error;
        }
        errdefer _ = resource.IUnknown_Release();

        const rtv_heap_start = dx12.getCpuDescriptorHandleForHeapStart(rtv_descriptor_heap);
        const rtv_increment_size = device.ID3D12Device_GetDescriptorHandleIncrementSize(.RTV);
        const rtv_descriptor_handle = w32.D3D12_CPU_DESCRIPTOR_HANDLE{
            .ptr = rtv_heap_start.ptr + index * rtv_increment_size,
        };
        device.ID3D12Device_CreateRenderTargetView(resource, null, rtv_descriptor_handle);

        const test_allocation = if (builtin.is_test) try std.testing.allocator.create(u8) else {};

        return .{
            .command_allocator = command_allocator,
            .command_list = command_list,
            .rtv_descriptor_handle = rtv_descriptor_handle,
            .resource = resource,
            .test_allocation = test_allocation,
        };
    }

    pub fn deinit(self: *const Self) void {
        _ = self.resource.IUnknown_Release();
        _ = self.command_list.IUnknown_Release();
        _ = self.command_allocator.IUnknown_Release();

        if (builtin.is_test) {
            std.testing.allocator.destroy(self.test_allocation);
        }
    }
};

const testing = std.testing;

test "init and deinit should succeed" {
    const testing_context = try dx12.TestingContext.init();
    defer testing_context.deinit();
    const context = try Context(3, 64).init(testing_context.device, testing_context.swap_chain);
    defer context.deinit();
}
