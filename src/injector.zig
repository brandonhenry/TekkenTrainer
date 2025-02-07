const std = @import("std");
const os = @import("os/root.zig");
const injector = @import("injector/root.zig");

const process_name = "TEKKEN8.exe";
const access_rights = os.Process.AccessRights{
    .CREATE_THREAD = 1,
    .VM_OPERATION = 1,
    .VM_READ = 1,
    .VM_WRITE = 1,
    .QUERY_INFORMATION = 1,
    .QUERY_LIMITED_INFORMATION = 1,
    .SYNCHRONIZE = 1,
};
const interval_ns = 1_000_000_000;

pub fn main() !void {
    injector.runProcessLoop(process_name, access_rights, interval_ns, onProcessOpen, onProcessClose);
}

pub fn onProcessOpen(process: *const os.Process) void {
    _ = process;
}

pub fn onProcessClose(process: *const os.Process) void {
    _ = process;
}
