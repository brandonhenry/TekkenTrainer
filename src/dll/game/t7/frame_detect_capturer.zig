const model = @import("../../model/root.zig");
const t7 = @import("root.zig");

pub const FrameDetectCapturer = struct {
    const Self = @This();

    pub fn detectAndCaptureFrame(self: *Self, memory: *const t7.Memory) ?model.Frame {
        _ = self;
        _ = memory;
        return null;
    }
};
