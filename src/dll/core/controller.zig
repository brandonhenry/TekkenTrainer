const std = @import("std");
const core = @import("../core/root.zig");
const game = @import("../game/root.zig");
const model = @import("../model/root.zig");

pub const Controller = struct {
    frame: model.Frame = .{},
    frame_detector: core.FrameDetector = .{},
    pause_detector: core.PauseDetector(.{}) = .{},
    capturer: core.Capturer = .{},
    hit_detector: core.HitDetector = .{},

    const Self = @This();

    pub fn tick(self: *Self, game_memory: *const game.Memory) void {
        const player_1 = game_memory.player_1.takePartialCopy();
        const player_2 = game_memory.player_2.takePartialCopy();
        if (!self.frame_detector.detect(&player_1, &player_2)) {
            return;
        }
        self.pause_detector.update();
        var frame = self.capturer.captureFrame(&.{ .player_1 = player_1, .player_2 = player_2 });
        self.hit_detector.detect(&frame);
        self.frame = frame;
    }
};
