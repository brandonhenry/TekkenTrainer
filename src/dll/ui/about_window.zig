const std = @import("std");
const build_info = @import("build_info");
const imgui = @import("imgui");
const sdk = @import("../../sdk/root.zig");

pub const AboutWindow = struct {
    is_open: bool = false,

    const Self = @This();
    pub const name = "About";

    pub fn draw(self: *Self) void {
        if (!self.is_open) {
            return;
        }

        const display_size = imgui.igGetIO_Nil().*.DisplaySize;
        imgui.igSetNextWindowPos(
            .{ .x = 0.5 * display_size.x, .y = 0.5 * display_size.y },
            imgui.ImGuiCond_FirstUseEver,
            .{ .x = 0.5, .y = 0.5 },
        );
        imgui.igSetNextWindowSize(.{ .x = 420, .y = 360 }, imgui.ImGuiCond_FirstUseEver);

        const render_content = imgui.igBegin(name, &self.is_open, imgui.ImGuiWindowFlags_HorizontalScrollbar);
        defer imgui.igEnd();
        if (!render_content) {
            return;
        }

        imgui.igText("%s", build_info.display_name);

        imgui.igBulletText("Version:");
        imgui.igSameLine(0, -1);
        imgui.igText("%s", build_info.version);

        imgui.igBulletText("Compatible with game version:");
        imgui.igSameLine(0, -1);
        imgui.igText("%s", build_info.game_version);

        imgui.igBulletText("Home page:");
        imgui.igSameLine(0, -1);
        _ = imgui.igTextLinkOpenURL(build_info.home_page, build_info.home_page);

        imgui.igBulletText("Author:");
        imgui.igIndent(0);
        imgui.igBulletText("%s", build_info.author);
        imgui.igUnindent(0);

        imgui.igBulletText("Contributors:");
        imgui.igIndent(0);
        inline for (build_info.contributors) |contributor| {
            imgui.igBulletText("%s", contributor);
        }
        imgui.igUnindent(0);

        const maybe_timestamp = sdk.misc.Timestamp.fromNano(std.time.nanoTimestamp(), .local) catch null;
        if (maybe_timestamp) |*timestamp| {
            imgui.igBulletText("©2025-%d", timestamp.year);
        } else {
            imgui.igBulletText("©2025");
        }
    }
};

const testing = std.testing;
