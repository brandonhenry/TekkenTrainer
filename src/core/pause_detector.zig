const std = @import("std");
const core = @import("root.zig");

pub const PauseDetectorConfig = struct {
    nanoTimestamp: *const fn () i128 = std.time.nanoTimestamp,
    no_change_time_for_pause: i128 = 33 * std.time.ns_per_ms,
};

pub fn PauseDetector(comptime config: PauseDetectorConfig) type {
    return struct {
        last_change_timestamp: i128 = 0,
        last_frame_since_round_start: ?u32 = null,
        last_player_1_frame: ?u32 = null,
        last_player_2_frame: ?u32 = null,

        const Self = @This();

        pub fn update(self: *Self, frame: *const core.Frame) void {
            const current_timestamp = config.nanoTimestamp();
            const frames_since_round_start = frame.frames_since_round_start;
            const player_1_frame = frame.getPlayerById(.player_1).current_frame_number;
            const player_2_frame = frame.getPlayerById(.player_2).current_frame_number;
            const changed = frames_since_round_start != self.last_frame_since_round_start or
                player_1_frame != self.last_player_1_frame or
                player_2_frame != self.last_player_2_frame or
                (frames_since_round_start == null and player_1_frame == null and player_2_frame == null);
            if (changed) {
                self.last_change_timestamp = current_timestamp;
            }
            self.last_frame_since_round_start = frames_since_round_start;
            self.last_player_1_frame = player_1_frame;
            self.last_player_2_frame = player_2_frame;
        }

        pub fn isPaused(self: *const Self) bool {
            const current_timestamp = config.nanoTimestamp();
            const time = current_timestamp - self.last_change_timestamp;
            return time >= config.no_change_time_for_pause;
        }
    };
}

const testing = std.testing;

test "should report paused only if enough time passes without a change" {
    const NanoTimestamp = struct {
        var value: i128 = 0;
        fn call() i128 {
            return value;
        }
    };
    var detector: PauseDetector(.{
        .nanoTimestamp = NanoTimestamp.call,
        .no_change_time_for_pause = 10,
    }) = .{};
    const update = struct {
        fn call(det: *@TypeOf(detector), frame_1: ?u32, frame_2: ?u32, frame_3: ?u32) void {
            det.update(&.{
                .frames_since_round_start = frame_1,
                .players = .{
                    .{ .current_frame_number = frame_2 },
                    .{ .current_frame_number = frame_3 },
                },
            });
        }
    }.call;

    update(&detector, null, null, null);

    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 1;
    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 10;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 1, null, null);

    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 11;
    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 20;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 1, null, null);

    try testing.expectEqual(true, detector.isPaused());
    NanoTimestamp.value = 21;
    try testing.expectEqual(true, detector.isPaused());
    NanoTimestamp.value = 30;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 2, null, null);

    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 31;
    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 40;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 2, 1, null);

    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 41;
    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 50;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 2, 1, null);

    try testing.expectEqual(true, detector.isPaused());
    NanoTimestamp.value = 51;
    try testing.expectEqual(true, detector.isPaused());
    NanoTimestamp.value = 60;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 2, 2, null);

    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 61;
    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 70;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 2, 2, 1);

    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 71;
    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 80;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 2, 2, 1);

    try testing.expectEqual(true, detector.isPaused());
    NanoTimestamp.value = 81;
    try testing.expectEqual(true, detector.isPaused());
    NanoTimestamp.value = 90;
    try testing.expectEqual(true, detector.isPaused());

    update(&detector, 2, 2, 2);

    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 91;
    try testing.expectEqual(false, detector.isPaused());
    NanoTimestamp.value = 100;
    try testing.expectEqual(true, detector.isPaused());
}
