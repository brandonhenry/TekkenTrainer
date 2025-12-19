const std = @import("std");
const core = @import("../core/root.zig");
const game = @import("../game/root.zig");
const model = @import("../model/root.zig");

pub const Core = struct {
    frame_detect_capturer: game.FrameDetectCapturer,
    pause_detector: core.PauseDetector(.{}),
    hit_detector: core.HitDetector,
    move_detector: core.MoveDetector,
    move_measurer: core.MoveMeasurer,
    controller: core.Controller,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .frame_detect_capturer = .{},
            .pause_detector = .{},
            .hit_detector = .{},
            .move_detector = .{},
            .move_measurer = .{},
            .controller = core.Controller.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.controller.deinit();
    }

    pub fn tick(
        self: *Self,
        game_memory: *const game.Memory,
        context: anytype,
        processFrame: *const fn (context: @TypeOf(context), frame: *const model.Frame) void,
    ) void {
        var frame = self.frame_detect_capturer.detectAndCaptureFrame(game_memory) orelse return;
        self.pause_detector.update();
        self.hit_detector.detect(&frame);
        self.move_detector.detect(&frame);
        self.move_measurer.measure(&frame);
        self.controller.processFrame(&frame, context, processFrame);
    }

    pub fn update(
        self: *Self,
        delta_time: f32,
        context: anytype,
        processFrame: *const fn (context: @TypeOf(context), frame: *const model.Frame) void,
    ) void {
        self.controller.update(delta_time, context, processFrame);
    }
};
