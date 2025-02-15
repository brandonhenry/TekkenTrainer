const std = @import("std");
const builtin = @import("builtin");
const w32 = @import("win32").everything;
const log = @import("log/root.zig");
const os = @import("os/root.zig");

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
