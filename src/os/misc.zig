const std = @import("std");
const w32 = @import("win32").everything;
const errorContext = @import("../misc/root.zig").errorContext;
const os = @import("root.zig");

pub fn pathToFileName(path: []const u8) []const u8 {
    var last_separator_index: ?usize = null;
    var i: usize = path.len;
    while (i > 0) {
        i -= 1;
        const character = path[i];
        if (character == '\\' or character == '/') {
            last_separator_index = i;
            break;
        }
    }
    if (last_separator_index) |index| {
        return path[(index + 1)..path.len];
    } else {
        return path;
    }
}

pub fn setConsoleCloseHandler(onConsoleClose: *const fn () void) !void {
    const Handler = struct {
        var function: ?*const fn () void = null;
        fn call(event: u32) callconv(.C) w32.BOOL {
            if (event != w32.CTRL_C_EVENT and event != w32.CTRL_CLOSE_EVENT) {
                return 0;
            }
            (function orelse unreachable)();
            return 0;
        }
    };
    Handler.function = onConsoleClose;
    const success = w32.SetConsoleCtrlHandler(Handler.call, 1);
    if (success == 0) {
        errorContext().newFmt(null, "{}", os.OsError.getLast());
        errorContext().append(error.OsError, "SetConsoleCtrlHandler returned 0.");
        return error.OsError;
    }
}

const testing = std.testing;

test "pathToFileName should return correct value" {
    try testing.expectEqualStrings("test3.exe", pathToFileName("test1\\test2\\test3.exe"));
    try testing.expectEqualStrings("test3", pathToFileName("test1\\test2\\test3"));
    try testing.expectEqualStrings("test3", pathToFileName("test1/test2/test3"));
    try testing.expectEqualStrings("test", pathToFileName("test"));
    try testing.expectEqualStrings("", pathToFileName("test\\"));
    try testing.expectEqualStrings("test", pathToFileName("\\test"));
    try testing.expectEqualStrings("", pathToFileName(""));
    try testing.expectEqualStrings("", pathToFileName("\\"));
}
