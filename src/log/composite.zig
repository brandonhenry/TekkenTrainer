const std = @import("std");
const log = @import("root.zig");

pub const CompositeLoggerConfig = struct {
    console: ?log.ConsoleLoggerConfig = null,
    file: ?log.FileLoggerConfig = null,
};

pub fn CompositeLogger(comptime config: CompositeLoggerConfig) type {
    return struct {
        pub const console = if (config.console) |c| log.ConsoleLogger(c) else void;
        pub const file = if (config.file) |c| log.FileLogger(c) else void;

        pub fn logFn(
            comptime level: std.log.Level,
            comptime scope: @Type(.EnumLiteral),
            comptime format: []const u8,
            args: anytype,
        ) void {
            if (config.console != null) {
                console.logFn(level, scope, format, args);
            }
            if (config.file != null) {
                file.logFn(level, scope, format, args);
            }
        }
    };
}
