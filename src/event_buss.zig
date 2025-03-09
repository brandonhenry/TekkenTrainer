const std = @import("std");
const w32 = @import("win32").everything;
const gui = @import("zgui");
const dx12 = @import("dx12/root.zig");
const misc = @import("misc/root.zig");

pub const EventBuss = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    dx12_leftovers: ?dx12.Leftovers,
    is_gui_initialized: bool,

    const Self = @This();

    pub fn init(
        window: w32.HWND,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
        swap_chain: *const w32.IDXGISwapChain,
    ) Self {
        _ = swap_chain;

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};

        std.log.debug("Initializing DX12 leftovers...", .{});
        const dx12_leftovers = if (dx12.Leftovers.init(device)) |leftovers| block: {
            std.log.info("DX12 leftovers initialized.", .{});
            break :block leftovers;
        } else |err| block: {
            misc.errorContext().append(err, "Failed to initialize DX12 leftovers.");
            misc.errorContext().logError();
            break :block null;
        };

        const is_gui_initialized = if (dx12_leftovers) |leftovers| block: {
            std.log.debug("Initializing GUI...", .{});
            gui.init(gpa.allocator());
            gui.backend.init(window, .{
                .device = device,
                .command_queue = command_queue,
                .num_frames_in_flight = 2,
                .rtv_format = @intFromEnum(w32.DXGI_FORMAT_R8G8B8A8_UNORM),
                .dsv_format = @intFromEnum(w32.DXGI_FORMAT_UNKNOWN),
                .cbv_srv_heap = leftovers.descriptor_heap,
                .font_srv_cpu_desc_handle = @bitCast(leftovers.getCpuDescriptorHandle()),
                .font_srv_gpu_desc_handle = @bitCast(leftovers.getGpuDescriptorHandle()),
            });
            std.log.info("GUI initialized.", .{});
            break :block true;
        } else false;

        return .{
            .gpa = gpa,
            .dx12_leftovers = dx12_leftovers,
            .is_gui_initialized = is_gui_initialized,
        };
    }

    pub fn deinit(
        self: *Self,
        window: w32.HWND,
        device: *const w32.ID3D12Device,
        command_queue: *const w32.ID3D12CommandQueue,
        swap_chain: *const w32.IDXGISwapChain,
    ) void {
        _ = swap_chain;
        _ = window;
        _ = device;
        _ = command_queue;

        std.log.debug("De-initializing GUI...", .{});
        if (self.is_gui_initialized) {
            gui.backend.deinit();
            gui.deinit();
            std.log.info("GUI de-initialized.", .{});
        } else {
            std.log.debug("Nothing to de-initialize.", .{});
        }

        std.log.debug("De-initializing DX12 leftovers...", .{});
        if (self.dx12_leftovers) |leftovers| {
            leftovers.deinit();
            std.log.info("DX12 leftovers de-initialized.", .{});
        } else {
            std.log.debug("Nothing to de-initialize.", .{});
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
        _ = window;
        _ = device;
        _ = command_queue;

        const leftovers = self.dx12_leftovers orelse return;

        const swap_chain_2: *const w32.IDXGISwapChain2 = @ptrCast(swap_chain);
        var frame_buffer_width: u32 = undefined;
        var frame_buffer_height: u32 = undefined;
        const size_return_code = swap_chain_2.IDXGISwapChain2_GetSourceSize(&frame_buffer_width, &frame_buffer_height);
        if (size_return_code != w32.S_OK) {
            misc.errorContext().newFmt(
                error.Dx12Error,
                "IDXGISwapChain2.GetSourceSize returned: {}",
                .{size_return_code},
            );
            misc.errorContext().append(error.Dx12Error, "Failed to get frame buffer width and height.");
            misc.errorContext().logError();
        }

        gui.backend.newFrame(frame_buffer_width, frame_buffer_height);

        gui.text("Hello World!", .{});

        gui.backend.draw(leftovers.graphics_command_list);
    }
};
