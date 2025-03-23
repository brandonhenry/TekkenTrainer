const std = @import("std");
const w32 = @import("win32").everything;
const misc = @import("../misc/root.zig");
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

pub fn filePathToDirectoryPath(path: []const u8) []const u8 {
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
        if (index == 0) {
            return path[0..1];
        } else {
            return path[0..index];
        }
    } else {
        return ".";
    }
}

pub fn getPathRelativeFromModule(
    buffer: *[os.max_file_path_length]u8,
    module: *const os.Module,
    path_from_module: []const u8,
) !usize {
    var module_path_buffer: [os.max_file_path_length]u8 = undefined;
    const size = module.getFilePath(&module_path_buffer) catch |err| {
        misc.errorContext().append(err, "Failed to get file path of module.");
        return err;
    };
    const module_path = module_path_buffer[0..size];
    const directory_path = filePathToDirectoryPath(module_path);
    const full_path = std.fmt.bufPrint(buffer, "{s}\\{s}", .{ directory_path, path_from_module }) catch |err| {
        misc.errorContext().newFmt(
            err,
            "Failed to put path into the buffer: {s}\\{s}",
            .{ directory_path, path_from_module },
        );
        return err;
    };
    return full_path.len;
}

pub fn getFullPath(full_path_buffer: *[os.max_file_path_length]u8, short_path: []const u8) !usize {
    var short_path_buffer_utf16 = [_:0]u16{0} ** os.max_file_path_length;
    const short_path_size = std.unicode.utf8ToUtf16Le(&short_path_buffer_utf16, short_path) catch |err| {
        misc.errorContext().newFmt(err, "Failed to convert UTF8 string \"{s}\" to UTF16-LE.", .{short_path});
        return err;
    };
    const short_path_utf16 = short_path_buffer_utf16[0..short_path_size :0];
    var full_path_buffer_utf16: [os.max_file_path_length:0]u16 = undefined;
    const full_path_size = w32.GetFullPathNameW(
        short_path_utf16,
        full_path_buffer_utf16.len,
        &full_path_buffer_utf16,
        null,
    );
    if (full_path_size == 0) {
        misc.errorContext().newFmt(null, "{}", os.Error.getLast());
        misc.errorContext().append(error.OsError, "GetFullPathNameW returned 0.");
        return error.OsError;
    }
    const full_path_utf16 = full_path_buffer_utf16[0..full_path_size];
    return std.unicode.utf16LeToUtf8(full_path_buffer, full_path_utf16) catch |err| {
        misc.errorContext().new(err, "Failed to convert UTF16-LE string to UTF8.");
        return err;
    };
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
        misc.errorContext().newFmt(null, "{}", os.Error.getLast());
        misc.errorContext().append(error.OsError, "SetConsoleCtrlHandler returned 0.");
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

test "filePathToDirectoryPath should return correct value" {
    try testing.expectEqualStrings("test1\\test2", filePathToDirectoryPath("test1\\test2\\test3.exe"));
    try testing.expectEqualStrings("test1\\test2", filePathToDirectoryPath("test1\\test2\\test3"));
    try testing.expectEqualStrings(".\\test1\\test2", filePathToDirectoryPath(".\\test1\\test2\\test3"));
    try testing.expectEqualStrings("\\test1\\test2", filePathToDirectoryPath("\\test1\\test2\\test3"));
    try testing.expectEqualStrings("test1/test2", filePathToDirectoryPath("test1/test2/test3"));
    try testing.expectEqualStrings(".", filePathToDirectoryPath("test"));
    try testing.expectEqualStrings("test", filePathToDirectoryPath("test\\"));
    try testing.expectEqualStrings("\\", filePathToDirectoryPath("\\test"));
    try testing.expectEqualStrings(".", filePathToDirectoryPath(""));
    try testing.expectEqualStrings("\\", filePathToDirectoryPath("\\"));
}

test "getFullPath should produce correct full path" {
    var buffer: [os.max_file_path_length]u8 = undefined;
    const size = try getFullPath(&buffer, "./test_1/test_2/test_3.txt");
    const full_path = buffer[0..size];
    try testing.expectStringEndsWith(full_path, "\\test_1\\test_2\\test_3.txt");
}

test "getPathRelativeFromModule should return correct path" {
    const module = try os.Module.getMain();
    var module_path_buffer: [os.max_file_path_length]u8 = undefined;
    const module_path_size = try module.getFilePath(&module_path_buffer);
    const module_path = module_path_buffer[0..module_path_size];
    const module_directory = filePathToDirectoryPath(module_path);

    var buffer: [os.max_file_path_length]u8 = undefined;
    const size = try getPathRelativeFromModule(&buffer, &module, "test_1\\test_2\\test_3.txt");
    const path = buffer[0..size];

    try testing.expectStringStartsWith(path, module_directory);
    try testing.expectStringEndsWith(path, "\\test_1\\test_2\\test_3.txt");
    try testing.expectEqual(module_directory.len + "\\test_1\\test_2\\test_3.txt".len, path.len);
}
