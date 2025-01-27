const std = @import("std");
const testing = std.testing;

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
