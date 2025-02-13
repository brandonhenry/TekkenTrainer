const std = @import("std");
const misc = @import("../misc/root.zig");
const os = @import("../os/root.zig");

pub const FileLoggerConfig = struct {
    file_path: FilePath,
    level: std.log.Level = .debug,
    time_zone: misc.TimeZone = .local,
    nanoTimestamp: *const fn () i128 = std.time.nanoTimestamp,

    pub const FilePath = union(enum) {
        eager: []const u8,
        lazy: *const fn (buffer: *[os.max_file_path_length]u8) ?usize,
    };
};

pub fn FileLogger(comptime config: FileLoggerConfig) type {
    return struct {
        var log_file: ?std.fs.File = null;
        var log_writer: ?std.fs.File.Writer = null;
        var mutex = std.Thread.Mutex{};

        pub fn logFn(
            comptime level: std.log.Level,
            comptime scope: @Type(.EnumLiteral),
            comptime format: []const u8,
            args: anytype,
        ) void {
            if (@intFromEnum(level) > @intFromEnum(config.level)) {
                return;
            }
            const timestamp = misc.Timestamp.fromNano(config.nanoTimestamp(), config.time_zone) catch null;
            const scope_prefix = if (scope != std.log.default_log_scope) "(" ++ @tagName(scope) ++ ") " else "";
            const level_prefix = "[" ++ comptime level.asText() ++ "] ";

            var writer = log_writer orelse w: {
                mutex.lock();
                defer mutex.unlock();
                const file = openLogFile() orelse return;
                const writer = file.writer();
                log_file = file;
                log_writer = writer;
                break :w writer;
            };

            mutex.lock();
            defer mutex.unlock();
            writer.print(
                "{?} " ++ level_prefix ++ scope_prefix ++ format ++ "\n",
                .{timestamp} ++ args,
            ) catch |err| {
                std.debug.print("Failed to write log message with file logger. Cause: {}\n", .{err});
                return;
            };
        }

        fn openLogFile() ?std.fs.File {
            var buffer: [os.max_file_path_length]u8 = undefined;
            const file_path = switch (config.file_path) {
                .eager => |path| path,
                .lazy => |getPath| p: {
                    const size = getPath(&buffer) orelse {
                        std.debug.print("Failed to evaluate lazy path of log file.\n", .{});
                        return null;
                    };
                    const path = buffer[0..size];
                    break :p path;
                },
            };
            const file = std.fs.cwd().createFile(file_path, .{ .truncate = false }) catch |err| {
                std.debug.print("Failed to open log file: {s} Cause: {}\n", .{ file_path, err });
                return null;
            };
            const end_pos = file.getEndPos() catch |err| {
                std.debug.print("Failed to get the end position of the log file: {s} Cause: {}\n", .{ file_path, err });
                return null;
            };
            file.seekTo(end_pos) catch |err| {
                std.debug.print(
                    "Failed to seek to the end position ({}) of the log file: {s} Cause: {}\n",
                    .{ end_pos, file_path, err },
                );
                return null;
            };
            return file;
        }
    };
}

const testing = std.testing;

test "should format output correctly" {
    const file_path = "./test_assets/tmp1.log";
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const logger = FileLogger(.{
        .file_path = .{ .eager = file_path },
        .level = .debug,
        .time_zone = .utc,
        .nanoTimestamp = nanoTimestamp,
    });
    logger.logFn(.debug, std.log.default_log_scope, "Message: {}", .{1});
    logger.logFn(.info, .scope_1, "Message: {}", .{2});
    logger.logFn(.warn, .scope_2, "Message: {}", .{3});
    logger.logFn(.err, .scope_3, "Message: {}", .{4});
    logger.log_file.?.close();

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, file_path, 1_000_000);
    defer testing.allocator.free(content);
    std.fs.cwd().deleteFile(file_path) catch unreachable;

    const expected =
        \\2020-01-02T03:04:05.123456789 [debug] Message: 1
        \\2020-01-02T03:04:05.123456789 [info] (scope_1) Message: 2
        \\2020-01-02T03:04:05.123456789 [warning] (scope_2) Message: 3
        \\2020-01-02T03:04:05.123456789 [error] (scope_3) Message: 4
        \\
    ;
    try testing.expectEqualStrings(expected, content);
}

test "should filter based on log level correctly" {
    const file_path = "./test_assets/tmp2.log";
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const logger = FileLogger(.{
        .file_path = .{ .eager = file_path },
        .level = .warn,
        .time_zone = .utc,
        .nanoTimestamp = nanoTimestamp,
    });
    logger.logFn(.debug, std.log.default_log_scope, "Message: 1", .{});
    logger.logFn(.info, std.log.default_log_scope, "Message: 2", .{});
    logger.logFn(.warn, std.log.default_log_scope, "Message: 3", .{});
    logger.logFn(.err, std.log.default_log_scope, "Message: 4", .{});
    logger.log_file.?.close();

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, file_path, 1_000_000);
    defer testing.allocator.free(content);
    std.fs.cwd().deleteFile(file_path) catch unreachable;

    const expected =
        \\2020-01-02T03:04:05.123456789 [warning] Message: 3
        \\2020-01-02T03:04:05.123456789 [error] Message: 4
        \\
    ;
    try testing.expectEqualStrings(expected, content);
}

test "should work correctly when lazy file path" {
    const file_path = "./test_assets/tmp3.log";
    const getFilePath = struct {
        fn call(buffer: *[os.max_file_path_length]u8) ?usize {
            for (file_path, 0..) |char, i| {
                buffer[i] = char;
            }
            return file_path.len;
        }
    }.call;
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const logger = FileLogger(.{
        .file_path = .{ .lazy = getFilePath },
        .level = .debug,
        .time_zone = .utc,
        .nanoTimestamp = nanoTimestamp,
    });
    logger.logFn(.info, std.log.default_log_scope, "Message.", .{});
    logger.log_file.?.close();

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, file_path, 1_000_000);
    defer testing.allocator.free(content);
    std.fs.cwd().deleteFile(file_path) catch unreachable;

    const expected =
        \\2020-01-02T03:04:05.123456789 [info] Message.
        \\
    ;
    try testing.expectEqualStrings(expected, content);
}

test "should append logs to the end of the file" {
    const file_path = "./test_assets/tmp4.log";
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const file = try std.fs.cwd().createFile(file_path, .{});
    try file.writeAll("Content before logging.\n");
    file.close();

    const logger = FileLogger(.{
        .file_path = .{ .eager = file_path },
        .level = .debug,
        .time_zone = .utc,
        .nanoTimestamp = nanoTimestamp,
    });
    logger.logFn(.info, std.log.default_log_scope, "Logging content.", .{});
    logger.log_file.?.close();

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, file_path, 1_000_000);
    defer testing.allocator.free(content);
    std.fs.cwd().deleteFile(file_path) catch unreachable;

    const expected =
        \\Content before logging.
        \\2020-01-02T03:04:05.123456789 [info] Logging content.
        \\
    ;
    try testing.expectEqualStrings(expected, content);
}
