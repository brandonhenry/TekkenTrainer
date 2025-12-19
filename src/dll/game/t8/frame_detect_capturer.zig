const model = @import("../../model/root.zig");
const t8 = @import("root.zig");

pub const FrameDetectCapturer = struct {
    detector: t8.FrameDetector = .{},
    capturer: t8.Capturer = .{},

    const Self = @This();

    pub fn detectAndCaptureFrame(self: *Self, memory: *const t8.Memory) ?model.Frame {
        const player_1 = memory.player_1.takePartialCopy();
        const player_2 = memory.player_2.takePartialCopy();
        if (!self.detector.detect(&player_1, &player_2)) {
            return null;
        }
        const camera = memory.camera.takeCopy();
        return self.capturer.captureFrame(&.{ .player_1 = player_1, .player_2 = player_2, .camera = camera });
    }
};
