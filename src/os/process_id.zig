const std = @import("std");
const w32 = @import("win32").everything;

pub const ProcessId = struct {
    raw: u32,

    const Self = @This();
    const buffer_size = 4096;

    pub fn getCurrent() Self {
        return .{ .raw = w32.GetCurrentProcessId() };
    }

    pub fn findAll() !Iterator {
        var buffer: [buffer_size]u32 = undefined;
        var number_of_bytes: u32 = undefined;
        const success = w32.K32EnumProcesses(
            &buffer[0],
            @sizeOf(@TypeOf(buffer)),
            &number_of_bytes,
        );
        if (success == 0) {
            return error.OsError;
        }
        const number_of_elements = number_of_bytes / @sizeOf(u32);
        return .{
            .buffer = buffer,
            .number_of_elements = number_of_elements,
        };
    }

    pub const Iterator = struct {
        buffer: [buffer_size]u32,
        number_of_elements: u32,
        index: u32 = 0,

        fn next(self: *Iterator) ?ProcessId {
            if (self.index >= self.number_of_elements or self.index >= buffer_size) {
                return null;
            }
            const raw = self.buffer[self.index];
            self.index += 1;
            return .{ .raw = raw };
        }
    };
};

const testing = std.testing;

test "getCurrent should return process id of the current process" {
    const expected = std.os.windows.GetCurrentProcessId();
    const actual = ProcessId.getCurrent().raw;
    try testing.expectEqual(expected, actual);
}

test "findAll should find current process id" {
    const current = ProcessId.getCurrent();
    var has_current = false;
    var iterator = try ProcessId.findAll();
    while (iterator.next()) |process_id| {
        if (std.meta.eql(process_id, current)) {
            has_current = true;
        }
    }
    try testing.expect(has_current);
}
