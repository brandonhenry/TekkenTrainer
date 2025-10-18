const std = @import("std");
const sdk = @import("../../sdk/root.zig");

const FieldIndex = u8;
const FieldPathLength = u8;
const FieldOffset = u16;
const FieldSize = u16;
const NumberOfFrames = u64;
const LocalField = struct {
    path: []const u8,
    access: []const AccessElement,
    Type: type,
};
const RemoteField = struct {
    local_index: ?usize,
    size: FieldSize,
};
const AccessElement = union(enum) {
    name: []const u8,
    index: usize,
};

const magic_number = "irony";
const endian = std.builtin.Endian.little;
const max_number_of_fields = std.math.maxInt(FieldIndex);
const max_field_path_len = std.math.maxInt(FieldPathLength);

pub fn saveRecording(comptime Frame: type, frames: []const Frame, file_path: []const u8) !void {
    const file = std.fs.cwd().createFile(file_path, .{}) catch |err| {
        sdk.misc.error_context.new("Failed to create or open file: {s}", .{file_path});
        return err;
    };
    defer file.close();
    var buffer: [1024]u8 = undefined;
    var file_writer = file.writer(&buffer);
    const writer = &file_writer.interface;

    writer.writeAll(magic_number) catch |err| {
        sdk.misc.error_context.new("Failed to write magic number.", .{});
        return err;
    };

    const fields = getLocalFields(Frame);
    writeFieldList(writer, fields) catch |err| {
        sdk.misc.error_context.append("Failed to write field list.", .{});
        return err;
    };

    const initial_values = if (frames.len > 0) &frames[0] else &Frame{};
    writeInitialValues(Frame, writer, initial_values, fields) catch |err| {
        sdk.misc.error_context.append("Failed to write initial values.", .{});
        return err;
    };

    writeFrames(Frame, writer, initial_values, frames, fields) catch |err| {
        sdk.misc.error_context.append("Failed to write frames.", .{});
        return err;
    };

    file_writer.end() catch |err| {
        sdk.misc.error_context.new("Failed to end file writing.", .{});
        return err;
    };
}

pub fn loadRecording(comptime Frame: type, allocator: std.mem.Allocator, file_path: []const u8) ![]Frame {
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        sdk.misc.error_context.new("Failed to open file: {s}", .{file_path});
        return err;
    };
    defer file.close();
    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    const reader = &file_reader.interface;

    var magic_buffer: [magic_number.len]u8 = undefined;
    reader.readSliceAll(&magic_buffer) catch |err| {
        sdk.misc.error_context.new("Failed to read magic number.", .{});
        return err;
    };
    if (!std.mem.eql(u8, &magic_buffer, magic_number)) {
        sdk.misc.error_context.new("Incorrect magic number.", .{});
        return error.MagicNumber;
    }

    const local_fields = getLocalFields(Frame);
    var remote_fields_buffer: [max_number_of_fields]RemoteField = undefined;
    const remote_fields_len = readFieldList(reader, &remote_fields_buffer, local_fields) catch |err| {
        sdk.misc.error_context.append("Failed to read fields list.", .{});
        return err;
    };
    const remote_fields = remote_fields_buffer[0..remote_fields_len];

    const initial_values = readInitialValues(Frame, reader, remote_fields, local_fields) catch |err| {
        sdk.misc.error_context.append("Failed to read initial values.", .{});
        return err;
    };

    const frames = readFrames(Frame, allocator, reader, &initial_values, remote_fields, local_fields) catch |err| {
        sdk.misc.error_context.append("Failed to read frames.", .{});
        return err;
    };

    return frames;
}

fn writeFieldList(writer: *std.io.Writer, comptime fields: []const LocalField) !void {
    writer.writeInt(FieldIndex, @intCast(fields.len), endian) catch |err| {
        sdk.misc.error_context.new("Failed to write number of fields: {}", .{fields.len});
        return err;
    };
    inline for (fields) |*field| {
        errdefer sdk.misc.error_context.append("Failed to write field: {s}", .{field.path});
        writer.writeInt(FieldPathLength, @intCast(field.path.len), endian) catch |err| {
            sdk.misc.error_context.new("Failed to write the size of field path: {}", .{field.path.len});
            return err;
        };
        writer.writeAll(field.path) catch |err| {
            sdk.misc.error_context.new("Failed to write the field path: {s}", .{field.path});
            return err;
        };
        const size: FieldSize = comptime @intCast(getTypeSize(field.Type));
        writer.writeInt(FieldSize, size, endian) catch |err| {
            sdk.misc.error_context.new("Failed to write the field size: {}", .{size});
            return err;
        };
    }
}

fn readFieldList(
    reader: *std.io.Reader,
    remote_fields_buffer: []RemoteField,
    comptime local_fields: []const LocalField,
) !usize {
    const remote_fields_len = reader.takeInt(FieldIndex, endian) catch |err| {
        sdk.misc.error_context.new("Failed to read number of fields.", .{});
        return err;
    };
    if (remote_fields_len > remote_fields_buffer.len) {
        sdk.misc.error_context.new(
            "Number of fields {} exceeds maximum allowed number: {}",
            .{ remote_fields_len, remote_fields_buffer.len },
        );
        return error.TooManyFields;
    }
    for (0..remote_fields_len) |index| {
        errdefer sdk.misc.error_context.append("Failed to read field: {}", .{index});
        const path_len = reader.takeInt(FieldPathLength, endian) catch |err| {
            sdk.misc.error_context.new("Failed to read the size of the field path.", .{});
            return err;
        };
        var path_buffer: [max_field_path_len]u8 = undefined;
        const path = path_buffer[0..path_len];
        reader.readSliceAll(path) catch |err| {
            sdk.misc.error_context.new("Failed to read the field path.", .{});
            return err;
        };
        const remote_size = reader.takeInt(FieldSize, endian) catch |err| {
            sdk.misc.error_context.new("Failed to read the field size. Field path is: {s}", .{path});
            return err;
        };
        inline for (local_fields, 0..) |*local_field, local_index| {
            const local_size = getTypeSize(local_field.Type);
            if (std.mem.eql(u8, local_field.path, path) and local_size == remote_size) {
                remote_fields_buffer[index] = .{
                    .local_index = local_index,
                    .size = remote_size,
                };
                break;
            }
        } else {
            remote_fields_buffer[index] = .{
                .local_index = null,
                .size = remote_size,
            };
        }
    }
    return remote_fields_len;
}

fn writeInitialValues(
    comptime Frame: type,
    writer: *std.io.Writer,
    frame: *const Frame,
    comptime fields: []const LocalField,
) !void {
    inline for (fields) |*field| {
        const field_pointer = getConstFieldPointer(frame, field);
        writeValue(writer, field_pointer) catch |err| {
            sdk.misc.error_context.new("Failed to write the value of field: {s}", .{field.path});
            return err;
        };
    }
}

fn readInitialValues(
    comptime Frame: type,
    reader: *std.io.Reader,
    remote_fields: []const RemoteField,
    comptime local_fields: []const LocalField,
) !Frame {
    var frame = Frame{};
    for (remote_fields) |*remote_field| {
        const local_index = remote_field.local_index orelse {
            reader.toss(remote_field.size);
            continue;
        };
        inline for (local_fields, 0..) |*local_field, index| {
            if (local_index == index) {
                const field_pointer = getFieldPointer(&frame, local_field);
                field_pointer.* = readValue(local_field.Type, reader) catch |err| {
                    sdk.misc.error_context.new("Failed to read the value of field: {s}", .{local_field.path});
                    return err;
                };
                break;
            }
        } else unreachable;
    }
    return frame;
}

fn writeFrames(
    comptime Frame: type,
    writer: *std.io.Writer,
    initial_values: *const Frame,
    frames: []const Frame,
    comptime fields: []const LocalField,
) !void {
    writer.writeInt(NumberOfFrames, @intCast(frames.len), endian) catch |err| {
        sdk.misc.error_context.new("Failed to write number of frames: {}", .{frames.len});
        return err;
    };
    var last_frame: *const Frame = initial_values;
    for (frames, 0..) |*frame, frame_index| {
        errdefer sdk.misc.error_context.append("Failed to write frame: {}", .{frame_index});
        var number_of_changes: FieldIndex = 0;
        inline for (fields) |*field| {
            const field_pointer = getConstFieldPointer(frame, field);
            const last_field_pointer = getConstFieldPointer(last_frame, field);
            if (!std.meta.eql(field_pointer.*, last_field_pointer.*)) {
                number_of_changes += 1;
            }
        }
        writer.writeInt(FieldIndex, number_of_changes, endian) catch |err| {
            sdk.misc.error_context.new("Failed to write number of changes: {}", .{number_of_changes});
            return err;
        };
        inline for (fields, 0..) |*field, field_index| {
            errdefer sdk.misc.error_context.append("Failed to write change for field: {s}", .{field.path});
            const field_pointer = getConstFieldPointer(frame, field);
            const last_field_pointer = getConstFieldPointer(last_frame, field);
            if (!std.meta.eql(field_pointer.*, last_field_pointer.*)) {
                writer.writeInt(FieldIndex, @intCast(field_index), endian) catch |err| {
                    sdk.misc.error_context.new("Failed to write field index: {}", .{field_index});
                    return err;
                };
                writeValue(writer, field_pointer) catch |err| {
                    sdk.misc.error_context.new("Failed to write the new value.", .{});
                    return err;
                };
            }
        }
        last_frame = frame;
    }
}

fn readFrames(
    comptime Frame: type,
    allocator: std.mem.Allocator,
    reader: *std.io.Reader,
    initial_values: *const Frame,
    remote_fields: []const RemoteField,
    comptime local_fields: []const LocalField,
) ![]Frame {
    const number_of_frames = reader.takeInt(NumberOfFrames, endian) catch |err| {
        sdk.misc.error_context.new("Failed to read number of frames.", .{});
        return err;
    };
    const frames = allocator.alloc(Frame, number_of_frames) catch |err| {
        sdk.misc.error_context.new(
            "Failed to allocate enough memory to store the recording frames. Number of frames is: {}",
            .{number_of_frames},
        );
        return err;
    };
    var current_frame = initial_values.*;
    for (0..number_of_frames) |frame_index| {
        errdefer sdk.misc.error_context.append("Failed read frame: {}", .{frame_index});
        const number_of_changes = reader.takeInt(FieldIndex, endian) catch |err| {
            sdk.misc.error_context.new("Failed to read number changes.", .{});
            return err;
        };
        for (0..number_of_changes) |change_index| {
            errdefer sdk.misc.error_context.append("Failed read change: {}", .{change_index});
            const remote_index = reader.takeInt(FieldIndex, endian) catch |err| {
                sdk.misc.error_context.new("Failed to read field index.", .{});
                return err;
            };
            if (remote_index >= remote_fields.len) {
                sdk.misc.error_context.new(
                    "Field index {} is out of bounds. Number of fields is: {}",
                    .{ remote_index, remote_fields.len },
                );
                return error.IndexOutOfBounds;
            }
            const remote_field = remote_fields[remote_index];
            const local_index = remote_field.local_index orelse {
                reader.toss(remote_field.size);
                continue;
            };
            inline for (local_fields, 0..) |*local_field, index| {
                if (index == local_index) {
                    const field_pointer = getFieldPointer(&current_frame, local_field);
                    field_pointer.* = readValue(local_field.Type, reader) catch |err| {
                        sdk.misc.error_context.new("Failed to read the new value of: {s}", .{local_field.path});
                        return err;
                    };
                    break;
                }
            } else unreachable;
        }
        frames[frame_index] = current_frame;
    }
    return frames;
}

fn writeValue(writer: *std.io.Writer, value_pointer: anytype) !void {
    const Type = switch (@typeInfo(@TypeOf(value_pointer))) {
        .pointer => |info| info.child,
        else => @compileError("Expected value_pointer to be a pointer but got: " ++ @typeName(@TypeOf(value_pointer))),
    };
    switch (@typeInfo(Type)) {
        .void => {},
        .bool => {
            const byte: u8 = switch (value_pointer.*) {
                false => 0,
                true => 1,
            };
            try writer.writeByte(byte);
        },
        .int => |info| {
            const WriteType = @Type(.{ .int = .{
                .signedness = info.signedness,
                .bits = @sizeOf(Type) * std.mem.byte_size_in_bits,
            } });
            try writer.writeInt(WriteType, value_pointer.*, endian);
        },
        .float => |*info| {
            const IntType = @Type(.{ .int = .{ .signedness = .unsigned, .bits = info.bits } });
            const int: IntType = @bitCast(value_pointer.*);
            try writer.writeInt(IntType, int, endian);
        },
        .@"enum" => |*info| {
            const Tag = info.tag_type;
            const tag: Tag = @intFromEnum(value_pointer.*);
            try writeValue(writer, &tag);
        },
        .optional => |*info| {
            if (value_pointer.*) |*child_pointer| {
                try writer.writeByte(1);
                try writeValue(writer, child_pointer);
            } else {
                try writer.writeByte(0);
                for (0..getTypeSize(info.child)) |_| {
                    try writer.writeByte(0);
                }
            }
        },
        .array => {
            for (value_pointer) |*element_pointer| {
                try writeValue(writer, element_pointer);
            }
        },
        .@"struct" => |*info| {
            inline for (info.fields) |*field| {
                const field_pointer = &@field(value_pointer, field.name);
                try writeValue(writer, field_pointer);
            }
        },
        .@"union" => |*info| {
            const Tag = info.tag_type orelse {
                @compileError("Unsupported type: " ++ @typeName(Type) ++ " (Only tagged version of unions is supported.)");
            };
            const tag = @intFromEnum(value_pointer.*);
            try writeValue(writer, &tag);
            switch (value_pointer.*) {
                inline else => |*payload_pointer| {
                    const Payload = @TypeOf(payload_pointer.*);
                    try writeValue(writer, payload_pointer);
                    const padding_size = getTypeSize(Type) - getTypeSize(Tag) - getTypeSize(Payload);
                    for (0..padding_size) |_| {
                        try writer.writeByte(0);
                    }
                },
            }
        },
        else => @compileError("Unsupported type: " ++ @typeName(Type)),
    }
}

fn readValue(comptime Type: type, reader: *std.io.Reader) !Type {
    switch (@typeInfo(Type)) {
        .void => return {},
        .bool => {
            const byte = try reader.takeByte();
            return switch (byte) {
                0 => false,
                1 => true,
                else => error.InvalidValue,
            };
        },
        .int => |info| {
            const ReadType = @Type(.{ .int = .{
                .signedness = info.signedness,
                .bits = @sizeOf(Type) * std.mem.byte_size_in_bits,
            } });
            const read_int = try reader.takeInt(ReadType, endian);
            return @intCast(read_int); // TODO Handle if it can't be casted.
        },
        .float => |*info| {
            const IntType = @Type(.{ .int = .{ .signedness = .unsigned, .bits = info.bits } });
            const int = try reader.takeInt(IntType, endian);
            return @bitCast(int);
        },
        .@"enum" => |*info| {
            const Tag = info.tag_type;
            const tag = try readValue(Tag, reader);
            inline for (info.fields) |*field| {
                if (field.value == tag) {
                    return @enumFromInt(tag);
                }
            }
            return error.InvalidValue;
        },
        .optional => |*info| {
            const byte = try reader.takeByte();
            return switch (byte) {
                0 => {
                    reader.toss(getTypeSize(info.child));
                    return null;
                },
                1 => try readValue(info.child, reader),
                else => {
                    reader.toss(getTypeSize(info.child));
                    return error.InvalidValue;
                },
            };
        },
        .array => |*info| {
            var value: Type = undefined;
            for (&value) |*element| {
                element = try readValue(info.child, reader);
            }
            return value;
        },
        .@"struct" => |*info| {
            var value: Type = undefined;
            inline for (info.fields) |*field| {
                const field_value = try readValue(field.type, reader);
                @field(value, field.name) = field_value;
            }
            return value;
        },
        .@"union" => |*info| {
            const Tag = info.tag_type orelse {
                @compileError("Unsupported type: " ++ @typeName(Type) ++ " (Only tagged version of unions is supported.)");
            };
            const tag = try readValue(Tag, reader);
            inline for (info.fields) |*field| {
                if (std.mem.eql(u8, @tagName(tag), field.name)) {
                    const Payload = field.type;
                    const payload = try readValue(Payload, reader);
                    const padding_size = getTypeSize(Type) - getTypeSize(Tag) - getTypeSize(Payload);
                    reader.toss(padding_size);
                    return @unionInit(Type, field.name, payload);
                }
            }
            const padding_size = getTypeSize(Type) - getTypeSize(Tag);
            reader.toss(padding_size);
            return error.InvalidValue;
        },
        else => @compileError("Unsupported type: " ++ @typeName(Type)),
    }
}

fn getTypeSize(comptime Type: type) usize {
    return switch (@typeInfo(Type)) {
        .void => 0,
        .bool => 1,
        .int, .float, .@"enum" => @sizeOf(Type),
        .optional => |*info| 1 + getTypeSize(info.child),
        .array => |*info| info.len * getTypeSize(info.child),
        .@"struct" => |*info| {
            var sum: usize = 0;
            for (info.fields) |*field| {
                sum += getTypeSize(field.type);
            }
            return sum;
        },
        .@"union" => |*info| {
            const Tag = info.tag_type orelse {
                @compileError("Unsupported type: " ++ @typeName(Type) ++ " (Only tagged version of unions is supported.)");
            };
            var max: usize = 0;
            inline for (info.fields) |*field| {
                max = @max(max, getTypeSize(field.type));
            }
            return @sizeOf(Tag) + max;
        },
        else => @compileError("Unsupported type: " ++ @typeName(Type)),
    };
}

fn getFieldPointer(frame: anytype, comptime field: *const LocalField) *field.Type {
    return getFieldPointerRecursive(*field.Type, frame, field.access);
}

fn getConstFieldPointer(frame: anytype, comptime field: *const LocalField) *const field.Type {
    return getFieldPointerRecursive(*const field.Type, frame, field.access);
}

fn getFieldPointerRecursive(
    comptime Pointer: type,
    lhs_pointer: anytype,
    comptime access: []const AccessElement,
) Pointer {
    if (@typeInfo(Pointer) != .pointer) {
        @compileError("Expected Pointer to be a pointer type but got: " ++ @typeName(Pointer));
    }
    if (@typeInfo(@TypeOf(lhs_pointer)) != .pointer) {
        @compileError("Expected lhs_pointer to be a pointer but got: " ++ @typeName(@TypeOf(lhs_pointer)));
    }
    if (access.len == 0) {
        return lhs_pointer;
    }
    const next_pointer = switch (access[0]) {
        .name => |name| &@field(lhs_pointer, name),
        .index => |index| &lhs_pointer[index],
    };
    const next_access = access[1..];
    return getFieldPointerRecursive(Pointer, next_pointer, next_access);
}

inline fn getLocalFields(comptime Frame: type) []const LocalField {
    comptime {
        @setEvalBranchQuota(10000);
        var buffer: [max_number_of_fields]LocalField = undefined;
        var len: usize = 0;
        getLocalFieldsRecursive(Frame, "", &.{}, &buffer, &len);
        const array = buffer[0..len].*;
        return &array;
    }
}

fn getLocalFieldsRecursive(
    comptime Type: type,
    path: []const u8,
    access: []const AccessElement,
    buffer: []LocalField,
    len: *usize,
) void {
    const type_info = @typeInfo(Type);
    switch (type_info) {
        .void => {},
        .bool, .int, .float, .@"enum", .optional, .@"union" => {
            appendLocalField(buffer, len, .{
                .path = path,
                .access = access,
                .Type = Type,
            });
        },
        .@"struct" => |*info| {
            for (info.fields) |*field| {
                getLocalFieldsRecursive(
                    field.type,
                    std.fmt.comptimePrint("{s}.{s}", .{ path, field.name }),
                    access ++ &[1]AccessElement{.{ .name = field.name }},
                    buffer,
                    len,
                );
            }
        },
        .array => |*info| {
            inline for (0..info.len) |index| {
                getLocalFieldsRecursive(
                    info.child,
                    std.fmt.comptimePrint("{s}.{}", .{ path, index }),
                    access ++ &[1]AccessElement{.{ .index = index }},
                    buffer,
                    len,
                );
            }
        },
        else => @compileError("Unsupported type: " ++ @typeName(Type)),
    }
}

fn appendLocalField(
    buffer: []LocalField,
    len: *usize,
    field: LocalField,
) void {
    if (len.* >= buffer.len) {
        @compileError("Maximum number of fields exceeded.");
    }
    if (field.path.len > max_field_path_len) {
        @compileError("Maximum size of field path exceeded.");
    }
    buffer[len.*] = field;
    len.* += 1;
}

const testing = std.testing;

test "loadRecording should load the same recording that saveRecording saved" {
    const Frame = struct {
        bool: bool = false,
        u8: u8 = 0,
        u16: u16 = 0,
        u32: u32 = 0,
        u64: u64 = 0,
        i8: i8 = 0,
        i16: i16 = 0,
        i32: i32 = 0,
        i64: i64 = 0,
        f32: f32 = 0,
        f64: f64 = 0,
        optional: ?f32 = 0,
        @"enum": enum { a, b } = .a,
        @"struct": struct { a: f32 = 0, b: f32 = 0 } = .{},
        tuple: struct { f32, f32 } = .{ 0, 0 },
        array: [2]f32 = .{ 0, 0 },
        tagged_union: union(enum) { i: i32, f: f32 } = .{ .i = 0 },
        array_of_struct: [2]struct { a: f32 = 0, b: f32 = 0 } = .{ .{}, .{} },
        struct_of_array: struct { a: [2]f32 = .{ 0, 0 }, b: [2]f32 = .{ 0, 0 } } = .{},
    };
    const saved_recording = [_]Frame{
        .{
            .bool = false,
            .u8 = 1,
            .u16 = 2,
            .u32 = 3,
            .u64 = 4,
            .i8 = -1,
            .i16 = -2,
            .i32 = -3,
            .i64 = -4,
            .f32 = 0.1,
            .f64 = 0.2,
            .optional = null,
            .@"enum" = .a,
            .@"struct" = .{ .a = 1, .b = 2 },
            .tuple = .{ 3, 4 },
            .array = .{ 5, 6 },
            .tagged_union = .{ .i = 7 },
            .array_of_struct = .{ .{ .a = 8, .b = 9 }, .{ .a = 10, .b = 11 } },
            .struct_of_array = .{ .a = .{ 12, 13 }, .b = .{ 14, 15 } },
        },
        .{
            .bool = true,
            .u8 = 4,
            .u16 = 3,
            .u32 = 2,
            .u64 = 1,
            .i8 = -4,
            .i16 = -3,
            .i32 = -2,
            .i64 = -1,
            .f32 = 0.2,
            .f64 = 0.1,
            .optional = 123,
            .@"enum" = .b,
            .@"struct" = .{ .a = 15, .b = 14 },
            .array = .{ 13, 12 },
            .tuple = .{ 11, 10 },
            .tagged_union = .{ .f = 9 },
            .array_of_struct = .{ .{ .a = 8, .b = 7 }, .{ .a = 6, .b = 5 } },
            .struct_of_array = .{ .a = .{ 4, 3 }, .b = .{ 2, 1 } },
        },
    };
    try saveRecording(Frame, &saved_recording, "./test_assets/recording.irony");
    defer std.fs.cwd().deleteFile("./test_assets/recording.irony") catch @panic("Failed to cleanup test file.");
    const loaded_recording = try loadRecording(Frame, testing.allocator, "./test_assets/recording.irony");
    defer testing.allocator.free(loaded_recording);
    try testing.expectEqualSlices(Frame, &saved_recording, loaded_recording);
}

test "saveRecording should overwrite the file if it already exists" {
    const Frame = struct { a: f32 = 0 };
    try saveRecording(Frame, &.{
        .{ .a = 1 },
        .{ .a = 2 },
        .{ .a = 3 },
    }, "./test_assets/recording.irony");
    defer std.fs.cwd().deleteFile("./test_assets/recording.irony") catch @panic("Failed to cleanup test file.");
    try saveRecording(Frame, &.{
        .{ .a = 2 },
        .{ .a = 3 },
        .{ .a = 4 },
    }, "./test_assets/recording.irony");
    const recording = try loadRecording(Frame, testing.allocator, "./test_assets/recording.irony");
    defer testing.allocator.free(recording);
    try testing.expectEqualSlices(Frame, &.{
        .{ .a = 2 },
        .{ .a = 3 },
        .{ .a = 4 },
    }, recording);
}

test "loadRecording should succeed when when recording has more fields then expected" {
    const SavedFrame = struct { a: f32 = -1, b: f32 = -2 };
    const LoadedFrame = struct { a: f32 = -3 };
    try saveRecording(SavedFrame, &.{
        .{ .a = 1, .b = 2 },
        .{ .a = 3, .b = 4 },
        .{ .a = 5, .b = 6 },
    }, "./test_assets/recording.irony");
    defer std.fs.cwd().deleteFile("./test_assets/recording.irony") catch @panic("Failed to cleanup test file.");
    const recording = try loadRecording(LoadedFrame, testing.allocator, "./test_assets/recording.irony");
    defer testing.allocator.free(recording);
    try testing.expectEqualSlices(LoadedFrame, &.{
        .{ .a = 1 },
        .{ .a = 3 },
        .{ .a = 5 },
    }, recording);
}

test "loadRecording should load default value when recording does not contain a value" {
    const SavedFrame = struct { a: f32 = -1 };
    const LoadedFrame = struct { a: f32 = -2, b: f32 = -3 };
    try saveRecording(SavedFrame, &.{
        .{ .a = 1 },
        .{ .a = 2 },
        .{ .a = 3 },
    }, "./test_assets/recording.irony");
    defer std.fs.cwd().deleteFile("./test_assets/recording.irony") catch @panic("Failed to cleanup test file.");
    const recording = try loadRecording(LoadedFrame, testing.allocator, "./test_assets/recording.irony");
    defer testing.allocator.free(recording);
    try testing.expectEqualSlices(LoadedFrame, &.{
        .{ .a = 1, .b = -3 },
        .{ .a = 2, .b = -3 },
        .{ .a = 3, .b = -3 },
    }, recording);
}

test "loadRecording should use default value when a field has different size then expected" {
    const SavedFrame = struct { a: f32 = -1, b: f64 = -2 };
    const LoadedFrame = struct { a: f32 = -3, b: f32 = -4 };
    try saveRecording(SavedFrame, &.{
        .{ .a = 1, .b = 2 },
        .{ .a = 3, .b = 4 },
        .{ .a = 5, .b = 6 },
    }, "./test_assets/recording.irony");
    defer std.fs.cwd().deleteFile("./test_assets/recording.irony") catch @panic("Failed to cleanup test file.");
    const recording = try loadRecording(LoadedFrame, testing.allocator, "./test_assets/recording.irony");
    defer testing.allocator.free(recording);
    try testing.expectEqualSlices(LoadedFrame, &.{
        .{ .a = 1, .b = -4 },
        .{ .a = 3, .b = -4 },
        .{ .a = 5, .b = -4 },
    }, recording);
}

// TODO make these tests pass
// test "loadRecording should use default value when encountering invalid enum value" {
//     const Enum = enum(u8) { a = 1, b = 2 };
//     const SavedFrame = struct { a: u8 = 0, b: ?u8 = null };
//     const LoadedFrame = struct { a: Enum = .a, b: ?Enum = null };
//     try saveRecording(SavedFrame, &.{
//         .{ .a = 0, .b = null },
//         .{ .a = 0, .b = 0 },
//         .{ .a = 1, .b = 1 },
//         .{ .a = 2, .b = 2 },
//         .{ .a = 3, .b = 3 },
//     }, "./test_assets/recording.irony");
//     defer std.fs.cwd().deleteFile("./test_assets/recording.irony") catch @panic("Failed to cleanup test file.");
//     const recording = try loadRecording(LoadedFrame, testing.allocator, "./test_assets/recording.irony");
//     defer testing.allocator.free(recording);
//     try testing.expectEqualSlices(LoadedFrame, &.{
//         .{ .a = .a, .b = null },
//         .{ .a = .a, .b = null },
//         .{ .a = .a, .b = .a },
//         .{ .a = .b, .b = .b },
//         .{ .a = .a, .b = null },
//     }, recording);
// }
//
// test "loadRecording should use default value when encountering invalid bool value" {
//     const SavedFrame = struct { a: u8 = 0, b: ?u8 = null };
//     const LoadedFrame = struct { a: bool = false, b: ?bool = null };
//     try saveRecording(SavedFrame, &.{
//         .{ .a = 0, .b = null },
//         .{ .a = 0, .b = 0 },
//         .{ .a = 1, .b = 1 },
//         .{ .a = 2, .b = 2 },
//     }, "./test_assets/recording.irony");
//     defer std.fs.cwd().deleteFile("./test_assets/recording.irony") catch @panic("Failed to cleanup test file.");
//     const recording = try loadRecording(LoadedFrame, testing.allocator, "./test_assets/recording.irony");
//     defer testing.allocator.free(recording);
//     try testing.expectEqualSlices(LoadedFrame, &.{
//         .{ .a = false, .b = null },
//         .{ .a = false, .b = false },
//         .{ .a = true, .b = true },
//         .{ .a = false, .b = null },
//     }, recording);
// }
