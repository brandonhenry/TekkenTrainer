const std = @import("std");
const imgui = @import("imgui");

pub const MessageWindowPlacement = enum {
    top,
    center,
    bottom,
};

pub fn drawMessageWindow(id: [:0]const u8, message: [:0]const u8, placement: MessageWindowPlacement) void {
    const display_size = imgui.igGetIO_Nil().*.DisplaySize;
    var message_size: imgui.ImVec2 = undefined;
    imgui.igCalcTextSize(&message_size, message, null, false, -1.0);
    const window_size = imgui.ImVec2{
        .x = message_size.x + (2 * imgui.igGetStyle().*.WindowPadding.x + imgui.igGetStyle().*.WindowBorderSize),
        .y = message_size.y + (2 * imgui.igGetStyle().*.WindowPadding.y + imgui.igGetStyle().*.WindowBorderSize),
    };
    const window_position = imgui.ImVec2{
        .x = 0.5 * display_size.x - 0.5 * window_size.x,
        .y = switch (placement) {
            .top => 0,
            .center => 0.5 * display_size.y - 0.5 * window_size.y,
            .bottom => display_size.y - window_size.y,
        },
    };

    const window_flags = imgui.ImGuiWindowFlags_AlwaysAutoResize |
        imgui.ImGuiWindowFlags_NoDecoration |
        imgui.ImGuiWindowFlags_NoInputs |
        imgui.ImGuiWindowFlags_NoSavedSettings |
        imgui.ImGuiWindowFlags_NoFocusOnAppearing;
    imgui.igSetNextWindowPos(window_position, imgui.ImGuiCond_Always, .{});
    imgui.igSetNextWindowSize(window_size, imgui.ImGuiCond_Always);

    const is_open = imgui.igBegin(id, null, window_flags);
    defer imgui.igEnd();
    if (!is_open) {
        return;
    }

    imgui.igText("%s", message.ptr);
}
