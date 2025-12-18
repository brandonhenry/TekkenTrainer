const std = @import("std");
const w32 = @import("win32").everything;
const dx11 = @import("root.zig");

pub const HostContext = struct {
    window: w32.HWND,
    device: *const w32.ID3D11Device,
    device_context: *const w32.ID3D11DeviceContext,
    swap_chain: *const w32.IDXGISwapChain,
};

pub const ManagedContext = struct {
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, host_context: *const dx11.HostContext) !Self {
        _ = allocator;
        _ = host_context;
        return .{};
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn deinitBufferContexts(self: *Self) void {
        _ = self;
    }

    pub fn reinitBufferContexts(self: *Self, host_context: *const dx11.HostContext) !void {
        _ = self;
        _ = host_context;
    }
};

pub const BufferContext = void;

pub const Context = struct {
    window: w32.HWND,
    device: *const w32.ID3D11Device,
    device_context: *const w32.ID3D11DeviceContext,
    swap_chain: *const w32.IDXGISwapChain,

    const Self = @This();

    pub fn fromHostAndManaged(host_context: *const HostContext, managed_context: *ManagedContext) Self {
        _ = managed_context;
        return .{
            .window = host_context.window,
            .device = host_context.device,
            .device_context = host_context.device_context,
            .swap_chain = host_context.swap_chain,
        };
    }

    pub fn beforeRender(self: *const Self) !*BufferContext {
        _ = self;
        return undefined;
    }

    pub fn afterRender(self: *const Self, buffer_context: *BufferContext) !void {
        _ = self;
        _ = buffer_context;
    }
};

const testing = std.testing;

test "ManagedContext init and deinit should succeed" {
    const testing_context = try dx11.TestingContext.init();
    defer testing_context.deinit();
    const host_context = testing_context.getHostContext();
    var managed_context = try ManagedContext.init(testing.allocator, &host_context);
    defer managed_context.deinit();
}

test "Context beforeRender and afterRender should succeed" {
    const testing_context = try dx11.TestingContext.init();
    defer testing_context.deinit();
    const host_context = testing_context.getHostContext();
    var managed_context = try ManagedContext.init(testing.allocator, &host_context);
    defer managed_context.deinit();
    const context = Context.fromHostAndManaged(&testing_context.getHostContext(), &managed_context);
    for (0..10) |_| {
        const buffer_context = try context.beforeRender();
        try context.afterRender(buffer_context);
    }
}

test "ManagedContext deinitBufferContexts and reinitBufferContexts should succeed" {
    const testing_context = try dx11.TestingContext.init();
    defer testing_context.deinit();
    const host_context = testing_context.getHostContext();
    var managed_context = try ManagedContext.init(testing.allocator, &host_context);
    defer managed_context.deinit();
    const context = Context.fromHostAndManaged(&testing_context.getHostContext(), &managed_context);
    for (0..10) |_| {
        const buffer_context = try context.beforeRender();
        try context.afterRender(buffer_context);
    }
    managed_context.deinitBufferContexts();
    try managed_context.reinitBufferContexts(&host_context);
    for (0..10) |_| {
        const buffer_context = try context.beforeRender();
        try context.afterRender(buffer_context);
    }
}
