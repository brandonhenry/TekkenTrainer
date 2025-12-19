const build_info = @import("build_info");
pub const t7 = @import("t7/root.zig");
pub const t8 = @import("t8/root.zig");
const game = switch (build_info.game) {
    .t7 => t7,
    .t8 => t8,
};
pub const FrameDetectCapturer = game.FrameDetectCapturer;
pub const Hooks = game.Hooks;
pub const Memory = game.Memory;
