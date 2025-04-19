const std = @import("std");
const misc = @import("../misc/root.zig");

pub const BufferLoggerConfig = struct {
    level: std.log.Level = .debug,
    time_zone: misc.TimeZone = .local,
    buffer_size: usize = 4096,
    max_messages: usize = 64,
    nanoTimestamp: *const fn () i128 = std.time.nanoTimestamp,
};

pub fn BufferLogger(comptime config: BufferLoggerConfig) type {
    return struct {
        var buffer: [config.buffer_size]u8 = undefined;
        var messages = misc.CircularBuffer(config.max_messages, []const u8){};

        pub fn getMessage(index: usize) ![:0]const u8 {
            const message = try messages.get(index);
            return message[0..(message.len - 1) :0];
        }

        pub fn getLen() usize {
            return messages.len;
        }

        pub fn logFn(
            comptime level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) void {
            if (@intFromEnum(level) > @intFromEnum(config.level)) {
                return;
            }
            const timestamp = misc.Timestamp.fromNano(config.nanoTimestamp(), config.time_zone) catch null;
            const scope_prefix = if (scope != std.log.default_log_scope) "(" ++ @tagName(scope) ++ ") " else "";
            const level_prefix = "[" ++ comptime level.asText() ++ "] ";
            const full_format = "{?} " ++ level_prefix ++ scope_prefix ++ format ++ .{0};
            const full_args = .{timestamp} ++ args;
            const last_message = messages.getLast() catch {
                log(&buffer, full_format, full_args) catch return;
                return;
            };
            const start_index = (&last_message[0] - &buffer[0]) + last_message.len;
            log(buffer[start_index..], full_format, full_args) catch {
                log(&buffer, full_format, full_args) catch return;
            };
        }

        fn log(message_buffer: []u8, comptime format: []const u8, args: anytype) !void {
            const new_message = std.fmt.bufPrint(message_buffer, format, args) catch |err| {
                while (messages.getFirst() catch null) |message| {
                    if (!colides(message, message_buffer)) {
                        break;
                    }
                    _ = messages.removeFirst() catch unreachable;
                }
                return err;
            };
            while (messages.getFirst() catch null) |message| {
                if (!colides(message, new_message)) {
                    break;
                }
                _ = messages.removeFirst() catch unreachable;
            }
            _ = messages.addToBack(new_message);
        }

        fn colides(a: []const u8, b: []const u8) bool {
            if (a.len == 0 or b.len == 0) {
                return false;
            }
            const a_min = @intFromPtr(&a[0]);
            const a_max = @intFromPtr(&a[a.len - 1]);
            const b_min = @intFromPtr(&b[0]);
            const b_max = @intFromPtr(&b[b.len - 1]);
            return (a_max >= b_min) and (b_max >= a_min);
        }
    };
}

const testing = std.testing;

test "should format output correctly" {
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const logger = BufferLogger(.{
        .level = .debug,
        .time_zone = .utc,
        .buffer_size = 4096,
        .max_messages = 64,
        .nanoTimestamp = nanoTimestamp,
    });

    logger.logFn(.debug, std.log.default_log_scope, "Message: {}", .{1});
    logger.logFn(.info, .scope_1, "Message: {}", .{2});
    logger.logFn(.warn, .scope_2, "Message: {}", .{3});
    logger.logFn(.err, .scope_3, "Message: {}", .{4});

    try testing.expectEqual(4, logger.getLen());
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [debug] Message: 1",
        try logger.getMessage(0),
    );
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [info] (scope_1) Message: 2",
        try logger.getMessage(1),
    );
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [warning] (scope_2) Message: 3",
        try logger.getMessage(2),
    );
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [error] (scope_3) Message: 4",
        try logger.getMessage(3),
    );
}

test "should filter based on log level correctly" {
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const logger = BufferLogger(.{
        .level = .warn,
        .time_zone = .utc,
        .buffer_size = 4096,
        .max_messages = 64,
        .nanoTimestamp = nanoTimestamp,
    });

    logger.logFn(.debug, std.log.default_log_scope, "Message: 1", .{});
    logger.logFn(.info, std.log.default_log_scope, "Message: 2", .{});
    logger.logFn(.warn, std.log.default_log_scope, "Message: 3", .{});
    logger.logFn(.err, std.log.default_log_scope, "Message: 4", .{});

    try testing.expectEqual(2, logger.getLen());
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [warning] Message: 3",
        try logger.getMessage(0),
    );
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [error] Message: 4",
        try logger.getMessage(1),
    );
}

test "should discard earliest messages when exceeding max number of messages" {
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const logger = BufferLogger(.{
        .level = .debug,
        .time_zone = .utc,
        .buffer_size = 4096,
        .max_messages = 2,
        .nanoTimestamp = nanoTimestamp,
    });

    logger.logFn(.debug, std.log.default_log_scope, "Message: 1", .{});
    logger.logFn(.debug, std.log.default_log_scope, "Message: 2", .{});
    logger.logFn(.debug, std.log.default_log_scope, "Message: 3", .{});
    logger.logFn(.debug, std.log.default_log_scope, "Message: 4", .{});

    try testing.expectEqual(2, logger.getLen());
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [debug] Message: 3",
        try logger.getMessage(0),
    );
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [debug] Message: 4",
        try logger.getMessage(1),
    );
}

test "should discard earliest messages when exceeding buffer size" {
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const logger = BufferLogger(.{
        .level = .debug,
        .time_zone = .utc,
        .buffer_size = 98,
        .max_messages = 64,
        .nanoTimestamp = nanoTimestamp,
    });

    logger.logFn(.debug, std.log.default_log_scope, "Message: 1", .{});
    logger.logFn(.debug, std.log.default_log_scope, "Message: 2", .{});
    logger.logFn(.debug, std.log.default_log_scope, "Message: 3", .{});
    logger.logFn(.debug, std.log.default_log_scope, "Message: 4", .{});

    try testing.expectEqual(2, logger.getLen());
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [debug] Message: 3",
        try logger.getMessage(0),
    );
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [debug] Message: 4",
        try logger.getMessage(1),
    );

    logger.logFn(.debug, std.log.default_log_scope, "Message: 123", .{});
    logger.logFn(.debug, std.log.default_log_scope, "Message: 456", .{});

    try testing.expectEqual(1, logger.getLen());
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [debug] Message: 456",
        try logger.getMessage(0),
    );
}

test "should discard all logs when message is larger then buffer" {
    const nanoTimestamp = struct {
        fn call() i128 {
            return 1577934245123456789;
        }
    }.call;

    const logger = BufferLogger(.{
        .level = .debug,
        .time_zone = .utc,
        .buffer_size = 50,
        .max_messages = 64,
        .nanoTimestamp = nanoTimestamp,
    });

    logger.logFn(.debug, std.log.default_log_scope, "Message: 1", .{});

    try testing.expectEqual(1, logger.getLen());
    try testing.expectEqualStrings(
        "2020-01-02T03:04:05.123456789 [debug] Message: 1",
        try logger.getMessage(0),
    );

    logger.logFn(.debug, std.log.default_log_scope, "Message: 123", .{});

    try testing.expectEqual(0, logger.getLen());
}
