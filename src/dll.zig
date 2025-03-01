const std = @import("std");
const builtin = @import("builtin");
const w32 = @import("win32").everything;
const misc = @import("misc/root.zig");
const log = @import("log/root.zig");
const os = @import("os/root.zig");
const memory = @import("memory/hooking.zig");
const EventBuss = @import("event_buss.zig").EventBuss;

pub const module_name = "irony.dll";

pub const log_file_name = "irony.log";
// TODO start and stop fileLogger
pub const file_logger = log.FileLogger(.{});
pub const std_options = .{
    .log_level = .debug,
    .logFn = file_logger.logFn,
};

pub fn DllMain(
    module_handle: w32.HINSTANCE,
    forward_reason: u32,
    reserved: *anyopaque,
) callconv(std.os.windows.WINAPI) w32.BOOL {
    _ = module_handle;
    _ = reserved;
    switch (forward_reason) {
        w32.DLL_PROCESS_ATTACH => {
            std.log.info("DLL attached event detected.", .{});
            std.log.debug("Spawning the initialization thread...", .{});
            const thread = std.Thread.spawn(.{}, init, .{}) catch |err| {
                misc.errorContext().new(err, "Failed to spawn initialization thread.");
                misc.errorContext().logError();
                return 0;
            };
            thread.detach();
            std.log.debug("Initialization thread spawned.", .{});
            std.log.info("DLL attached successfully.", .{});
            return 1;
        },
        w32.DLL_PROCESS_DETACH => {
            std.log.info("DLL detach event detected.", .{});
            deinit();
            std.log.info("Detaching from the process now...", .{});
            return 1;
        },
        else => return 0,
    }
}

fn init() void {
    std.log.info("Running initialization...", .{});

    std.log.debug("Starting file logging...", .{});
    if (startFileLogging()) {
        std.log.info("File logging started.", .{});
    } else |err| {
        misc.errorContext().append(err, "Failed to start file logging.");
        misc.errorContext().logError();
    }

    std.log.debug("Finding DX12 functions...", .{});
    const dx12Functions = os.Dx12Functions.find() catch |err| {
        misc.errorContext().append(err, "Failed to find DX12 functions.");
        misc.errorContext().logError();
        return;
    };
    std.log.info("DX12 functions found.", .{});

    std.log.debug("Initializing hooking...", .{});
    if (memory.Hooking.init()) {
        std.log.info("Hooking initialized.", .{});
    } else |err| {
        misc.errorContext().append(err, "Failed to initialize hooking.");
        misc.errorContext().logError();
    }

    std.log.debug("Creating the execute command lists hook...", .{});
    execute_command_lists_hook = memory.Hook(os.Dx12Functions.ExecuteCommandLists).create(
        dx12Functions.executeCommandLists,
        onExecuteCommandLists,
    ) catch |err| {
        misc.errorContext().append(err, "Failed to create execute command lists hook.");
        misc.errorContext().logError();
        return;
    };
    std.log.info("Execute command lists hook created.", .{});

    std.log.debug("Creating the present hook...", .{});
    present_hook = memory.Hook(os.Dx12Functions.Present).create(dx12Functions.present, onPresent) catch |err| {
        misc.errorContext().append(err, "Failed to create present hook.");
        misc.errorContext().logError();
        return;
    };
    std.log.info("Present hook created.", .{});

    std.log.debug("Enabling execute command lists hook...", .{});
    execute_command_lists_hook.?.enable() catch |err| {
        misc.errorContext().append(err, "Failed to enable execute command lists hook.");
        misc.errorContext().logError();
        return;
    };
    std.log.info("Execute command lists hook enabled.", .{});

    std.log.debug("Enabling present hook...", .{});
    present_hook.?.enable() catch |err| {
        misc.errorContext().append(err, "Failed to enable present hook.");
        misc.errorContext().logError();
        return;
    };
    std.log.info("Present hook enabled.", .{});

    std.log.info("Initialization completed.", .{});
}

fn deinit() void {
    std.log.info("Running de-initialization...", .{});

    std.log.debug("Destroying the present hook...", .{});
    if (present_hook) |hook| {
        if (hook.destroy()) {
            present_hook = null;
            std.log.info("Present hook destroyed.", .{});
        } else |err| {
            misc.errorContext().append(err, "Failed destroy present hook.");
            misc.errorContext().logError();
        }
    } else {
        std.log.debug("Nothing to destroy.", .{});
    }

    std.log.debug("Destroying the execute command lists hook...", .{});
    if (execute_command_lists_hook) |hook| {
        if (hook.destroy()) {
            execute_command_lists_hook = null;
            std.log.info("Execute command lists hook destroyed.", .{});
        } else |err| {
            misc.errorContext().append(err, "Failed destroy execute command lists hook.");
            misc.errorContext().logError();
        }
    } else {
        std.log.debug("Nothing to destroy.", .{});
    }

    std.log.debug("De-initializing hooking...", .{});
    if (memory.Hooking.deinit()) {
        std.log.info("Hooking de-initialized.", .{});
    } else |err| {
        misc.errorContext().append(err, "Failed to de-initialize hooking.");
        misc.errorContext().logError();
    }

    std.log.info("De-initializing event buss...", .{});
    if (g_event_buss) |*event_buss| {
        event_buss.deinit(g_device.?, g_command_queue.?);
        g_event_buss = null;
        g_device = null;
        g_command_queue = null;
    } else {
        std.log.info("Nothing to de-initialize.", .{});
    }

    std.log.info("Stopping file logging...", .{});
    file_logger.stop();
    std.log.info("File logging stopped.", .{});

    std.log.info("De-initialization completed.", .{});
}

fn startFileLogging() !void {
    const main_module = os.Module.getLocal(module_name) catch |err| {
        misc.errorContext().appendFmt(err, "Failed to get local module: {s}", .{module_name});
        return err;
    };
    var buffer: [os.max_file_path_length]u8 = undefined;
    const size = os.getPathRelativeFromModule(&buffer, &main_module, log_file_name) catch |err| {
        misc.errorContext().append(err, "Failed to find log file path.");
        return err;
    };
    const file_path = buffer[0..size];
    file_logger.start(file_path) catch |err| {
        misc.errorContext().appendFmt(err, "Failed to start file logging with file path: {s}", .{file_path});
        return err;
    };
}

var execute_command_lists_hook: ?memory.Hook(os.Dx12Functions.ExecuteCommandLists) = null;
var present_hook: ?memory.Hook(os.Dx12Functions.Present) = null;

var g_device: ?*const w32.ID3D12Device = null;
var g_command_queue: ?*const w32.ID3D12CommandQueue = null;

var g_event_buss: ?EventBuss = null;

fn onExecuteCommandLists(
    command_queue: *const w32.ID3D12CommandQueue,
    num_command_lists: u32,
    pp_command_lists: [*]?*w32.ID3D12CommandList,
) callconv(@import("std").os.windows.WINAPI) void {
    if (g_command_queue == null) {
        std.log.info("DX12 command queue found.", .{});
    }
    g_command_queue = command_queue;
    return execute_command_lists_hook.?.original(command_queue, num_command_lists, pp_command_lists);
}

fn onPresent(
    swap_chain: *const w32.IDXGISwapChain,
    sync_interval: u32,
    flags: u32,
) callconv(@import("std").os.windows.WINAPI) w32.HRESULT {
    const command_queue = g_command_queue orelse {
        std.log.debug("Present function was called before command queue was found. Skipping this frame.", .{});
        return present_hook.?.original(swap_chain, sync_interval, flags);
    };
    const device = os.getDeviceFromSwapChain(swap_chain) catch |err| {
        misc.errorContext().append(err, "Failed to get DX12 device from swap chain.");
        misc.errorContext().logError();
        return present_hook.?.original(swap_chain, sync_interval, flags);
    };
    if (g_device == null) {
        std.log.info("DX12 device found.", .{});
    }
    g_device = device;
    if (g_event_buss == null) {
        std.log.info("Initializing event buss...", .{});
        g_event_buss = EventBuss.init(device, command_queue);
        std.log.info("Event buss initialized.", .{});
    }
    g_event_buss.?.update(device, command_queue);
    return present_hook.?.original(swap_chain, sync_interval, flags);
}
