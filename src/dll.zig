const std = @import("std");
const w32 = @import("win32").everything;
const log = @import("log/root.zig");
const os = @import("os/root.zig");

pub const module_name = "irony.dll";
pub const log_file_name = "irony.log";

pub const logger = log.CompositeLogger(.{
    .file = .{ .file_path = .{ .lazy = getLogFilePath } },
});
pub const std_options = .{
    .log_level = .debug,
    .logFn = logger.logFn,
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
            std.log.info("DLL_PROCESS_ATTACH", .{});
            return 1;
        },
        w32.DLL_PROCESS_DETACH => {
            std.log.info("DLL_PROCESS_DETACH", .{});
            return 1;
        },
        else => return 0,
    }
}

fn getLogFilePath(buffer: *[os.max_file_path_length]u8) ?usize {
    const module = os.Module.getLocal(module_name) catch |err| {
        std.debug.print("Failed to get local module: {s} Cause: {}\n", .{ module_name, err });
        return null;
    };
    var file_path_buffer: *[os.max_file_path_length]u8 = undefined;
    const size = module.getFilePath(file_path_buffer) catch |err| {
        std.debug.print("Failed to get file path of module: {s} Cause: {}\n", .{ module_name, err });
        return null;
    };
    const file_path = file_path_buffer[0..size];
    const directory_path = os.filePathToDirectoryPath(file_path);
    const log_file_path = std.fmt.bufPrint(buffer, "{s}\\{s}", .{ directory_path, log_file_name }) catch |err| {
        std.debug.print(
            "Failed to put log file path into the buffer: {s}\\{s} Cause: {}\n",
            .{ directory_path, log_file_name, err },
        );
        return null;
    };
    return log_file_path.len;
}
