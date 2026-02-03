const std = @import("std");

pub fn BitfieldMember(comptime BackingInt: type) type {
    return struct {
        name: [:0]const u8,
        backing_value: BackingInt,
        default_value: bool = false,
    };
}

pub fn Bitfield(comptime BackingInt: type, comptime members: []const BitfieldMember(BackingInt)) type {
    @setEvalBranchQuota(20000);

    for (members) |*member| {
        if (!std.math.isPowerOfTwo(member.backing_value)) {
            @compileError(std.fmt.comptimePrint(
                "Failed to create a bitfield type. Member \"{s}\" has a backing value {} that is not a power of two.",
                .{ member.name, member.backing_value },
            ));
        }
    }

    const number_of_bits = @bitSizeOf(BackingInt);
    var fields: [number_of_bits]std.builtin.Type.StructField = undefined;
    for (&fields, 0..) |*field, index| {
        const backing_value = 1 << index;
        var member_at_bit: ?*const BitfieldMember(BackingInt) = null;
        for (members) |*member| {
            if (member.backing_value != backing_value) {
                continue;
            }
            if (member_at_bit != null) {
                @compileError(std.fmt.comptimePrint(
                    "Failed to create a bitfield type. Bit with backing value {} has multiple members.",
                    .{member.backing_value},
                ));
            }
            member_at_bit = member;
        }
        field.* = if (member_at_bit) |member| .{
            .name = member.name,
            .type = bool,
            .default_value_ptr = if (member.default_value == true) &true else &false,
            .is_comptime = false,
            .alignment = 0,
        } else .{
            .name = std.fmt.comptimePrint("_{}", .{index}),
            .type = bool,
            .default_value_ptr = &false,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    return @Type(.{ .@"struct" = .{
        .layout = .@"packed",
        .backing_integer = BackingInt,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

const testing = std.testing;

test "should have same size as the backing integer" {
    try testing.expectEqual(@sizeOf(u8), @sizeOf(Bitfield(u8, &.{})));
    try testing.expectEqual(@sizeOf(u16), @sizeOf(Bitfield(u16, &.{})));
    try testing.expectEqual(@sizeOf(u32), @sizeOf(Bitfield(u32, &.{})));
    try testing.expectEqual(@sizeOf(u64), @sizeOf(Bitfield(u64, &.{})));
}

test "should place members at correct bits" {
    const Bits = Bitfield(u16, &.{
        .{ .name = "bit_3", .backing_value = 8 },
        .{ .name = "bit_10", .backing_value = 1024 },
        .{ .name = "bit_6", .backing_value = 64 },
    });
    const bit_3: u16 = @bitCast(Bits{ .bit_3 = true });
    const bit_10: u16 = @bitCast(Bits{ .bit_10 = true });
    const bit_6: u16 = @bitCast(Bits{ .bit_6 = true });
    try testing.expectEqual(8, bit_3);
    try testing.expectEqual(1024, bit_10);
    try testing.expectEqual(64, bit_6);
}

test "should have correctly working default member values" {
    const Bits = Bitfield(u16, &.{
        .{ .name = "bit_3", .backing_value = 8, .default_value = false },
        .{ .name = "bit_10", .backing_value = 1024, .default_value = true },
        .{ .name = "bit_6", .backing_value = 64 },
    });
    const default_value: u16 = @bitCast(Bits{});
    try testing.expectEqual(1024, default_value);
}
