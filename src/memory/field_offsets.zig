const std = @import("std");

pub fn FieldOffsets(comptime Struct: type) type {
    const struct_fields: []const std.builtin.Type.StructField = switch (@typeInfo(Struct)) {
        .@"struct" => |info| info.fields,
        else => @compileError("FieldOffsets expects a struct type as argument."),
    };
    var offset_fields: [struct_fields.len]std.builtin.Type.StructField = undefined;
    for (struct_fields, 0..) |*field, index| {
        offset_fields[index] = .{
            .name = field.name,
            .type = usize,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(usize),
        };
    }
    const offsets_struct = std.builtin.Type.Struct{
        .layout = .auto,
        .backing_integer = null,
        .fields = &offset_fields,
        .decls = &.{},
        .is_tuple = false,
    };
    return @Type(.{ .@"struct" = offsets_struct });
}

comptime {
    const Struct = struct {
        field_1: u8,
        field_2: u16,
        field_3: u32,
    };
    const StructOffsets = FieldOffsets(Struct);
    std.debug.assert(@FieldType(StructOffsets, "field_1") == usize);
    std.debug.assert(@FieldType(StructOffsets, "field_2") == usize);
    std.debug.assert(@FieldType(StructOffsets, "field_3") == usize);
}
