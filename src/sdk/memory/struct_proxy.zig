const std = @import("std");
const os = @import("../os/root.zig");
const misc = @import("../misc/root.zig");
const memory = @import("root.zig");

pub const struct_proxy_tag = opaque {};

pub fn StructProxy(comptime Struct: type) type {
    const struct_fields = switch (@typeInfo(Struct)) {
        .@"struct" => |info| info.fields,
        else => @compileError("StructProxy expects a struct type as argument."),
    };
    return struct {
        base_trail: memory.PointerTrail,
        field_trails: FieldTrails,

        const Self = @This();
        pub const FieldTrails = misc.FieldMap(Struct, memory.PointerTrail, null);
        pub const tag = struct_proxy_tag;
        pub const Child = Struct;

        pub fn findBaseAddress(self: *const Self) ?usize {
            return self.base_trail.resolve(0);
        }

        pub fn findFieldAddress(self: *const Self, comptime field_name: []const u8) ?usize {
            const base_address = self.findBaseAddress() orelse return null;
            return findFieldAddressInternal(base_address, &self.field_trails, field_name);
        }

        pub fn findConstFieldPointer(
            self: *const Self,
            comptime field_name: []const u8,
        ) ?*const @FieldType(Struct, field_name) {
            const base_address = self.findBaseAddress() orelse return null;
            return findConstFieldPointerInternal(base_address, &self.field_trails, field_name);
        }

        pub fn findMutableFieldPointer(
            self: *const Self,
            comptime field_name: []const u8,
        ) ?*@FieldType(Struct, field_name) {
            const base_address = self.findBaseAddress() orelse return null;
            return findMutableFieldPointerInternal(base_address, &self.field_trails, field_name);
        }

        pub fn takeFullCopy(self: *const Self) ?Struct {
            const base_address = self.findBaseAddress() orelse return null;
            var copy: Struct = undefined;
            inline for (struct_fields) |*field| {
                if (findConstFieldPointerInternal(base_address, &self.field_trails, field.name)) |field_pointer| {
                    @field(copy, field.name) = field_pointer.*;
                } else {
                    return null;
                }
            }
            return copy;
        }

        pub fn takePartialCopy(self: *const Self) misc.Partial(Struct) {
            const base_address = self.findBaseAddress() orelse return .{};
            var copy: misc.Partial(Struct) = undefined;
            inline for (struct_fields) |*field| {
                if (findConstFieldPointerInternal(base_address, &self.field_trails, field.name)) |field_pointer| {
                    @field(copy, field.name) = field_pointer.*;
                } else {
                    @field(copy, field.name) = null;
                }
            }
            return copy;
        }

        pub fn findSizeFromMaxOffset(self: *const Self) usize {
            var max: usize = 0;
            inline for (struct_fields) |*field| {
                const trail: *const memory.PointerTrail = &@field(self.field_trails, field.name);
                const offsets = trail.getOffsets();
                switch (offsets.len) {
                    0 => {},
                    1 => if (offsets[0]) |offset| {
                        const result = @addWithOverflow(offset, @sizeOf(field.type));
                        if (result[1] == 0 and result[0] > max) {
                            max = result[0];
                        }
                    },
                    else => if (offsets[0]) |offset| {
                        const result = @addWithOverflow(offset, @sizeOf(usize));
                        if (result[1] == 0 and result[0] > max) {
                            max = result[0];
                        }
                    },
                }
            }
            return max;
        }

        fn findFieldAddressInternal(
            base_address: usize,
            field_trails: *const FieldTrails,
            comptime field_name: []const u8,
        ) ?usize {
            const field_trail: memory.PointerTrail = @field(field_trails, field_name);
            return field_trail.resolve(base_address);
        }

        fn findConstFieldPointerInternal(
            base_address: usize,
            field_trails: *const FieldTrails,
            comptime field_name: []const u8,
        ) ?*const @FieldType(Struct, field_name) {
            const Field = @FieldType(Struct, field_name);
            const address = findFieldAddressInternal(base_address, field_trails, field_name) orelse return null;
            if (address % @alignOf(Field) != 0) {
                return null;
            }
            if (!os.isMemoryReadable(address, @sizeOf(Field))) {
                return null;
            }
            return @ptrFromInt(address);
        }

        fn findMutableFieldPointerInternal(
            base_address: usize,
            field_trails: *const FieldTrails,
            comptime field_name: []const u8,
        ) ?*@FieldType(Struct, field_name) {
            const Field = @FieldType(Struct, field_name);
            const address = findFieldAddressInternal(base_address, field_trails, field_name) orelse return null;
            if (address % @alignOf(Field) != 0) {
                return null;
            }
            if (!os.isMemoryWriteable(address, @sizeOf(Field))) {
                return null;
            }
            return @ptrFromInt(address);
        }
    };
}

const testing = std.testing;

test "findBaseAddress should return a value when base trail is resolvable" {
    const Struct = struct {};
    const proxy = StructProxy(Struct){
        .base_trail = .fromArray(.{12345}),
        .field_trails = .{},
    };
    try testing.expectEqual(12345, proxy.findBaseAddress());
}

test "findBaseAddress should return null when base trail is not resolvable" {
    const Struct = struct {};
    const proxy = StructProxy(Struct){
        .base_trail = .fromArray(.{ 0, 100 }),
        .field_trails = .{},
    };
    try testing.expectEqual(null, proxy.findBaseAddress());
}

test "findFieldAddress should return a value when findBaseAddress succeeds and field trail is resolvable" {
    const Struct = struct { field_1: u8, field_2: u16, field_3: u32 };
    const value = Struct{ .field_1 = 1, .field_2 = 2, .field_3 = 3 };
    const proxy_1 = StructProxy(Struct){
        .base_trail = .fromArray(.{100}),
        .field_trails = .{
            .field_1 = .fromArray(.{10}),
            .field_2 = .fromArray(.{20}),
            .field_3 = .fromArray(.{30}),
        },
    };
    const proxy_2 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{ 0, 10 }),
            .field_2 = .fromArray(.{ 0, 20 }),
            .field_3 = .fromArray(.{ 0, 30 }),
        },
    };
    try testing.expectEqual(110, proxy_1.findFieldAddress("field_1"));
    try testing.expectEqual(120, proxy_1.findFieldAddress("field_2"));
    try testing.expectEqual(130, proxy_1.findFieldAddress("field_3"));
    try testing.expectEqual(@intFromPtr(&value) + 10, proxy_2.findFieldAddress("field_1"));
    try testing.expectEqual(@intFromPtr(&value) + 20, proxy_2.findFieldAddress("field_2"));
    try testing.expectEqual(@intFromPtr(&value) + 30, proxy_2.findFieldAddress("field_3"));
}

test "findFieldAddress should return null when findBaseAddress fails or field trail is not resolvable" {
    const Struct = struct { field: u8 };
    const proxy_1 = StructProxy(Struct){
        .base_trail = .fromArray(.{ 0, 100 }),
        .field_trails = .{ .field = .fromArray(.{10}) },
    };
    const proxy_2 = StructProxy(Struct){
        .base_trail = .fromArray(.{100}),
        .field_trails = .{ .field = .fromArray(.{null}) },
    };
    const proxy_3 = StructProxy(Struct){
        .base_trail = .fromArray(.{100}),
        .field_trails = .{ .field = .fromArray(.{std.math.maxInt(usize)}) },
    };
    const proxy_4 = StructProxy(Struct){
        .base_trail = .fromArray(.{0}),
        .field_trails = .{ .field = .fromArray(.{ 0, 10 }) },
    };
    try testing.expectEqual(null, proxy_1.findFieldAddress("field"));
    try testing.expectEqual(null, proxy_2.findFieldAddress("field"));
    try testing.expectEqual(null, proxy_3.findFieldAddress("field"));
    try testing.expectEqual(null, proxy_4.findFieldAddress("field"));
}

test "findConstFieldPointer should return a pointer when findFieldAddress succeeds, address is aligned and memory is readable" {
    const Struct = struct { field_1: u8, field_2: u16, field_3: u32 };
    const value = Struct{ .field_1 = 1, .field_2 = 2, .field_3 = 3 };
    const proxy_1 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{@offsetOf(Struct, "field_1")}),
            .field_2 = .fromArray(.{@offsetOf(Struct, "field_2")}),
            .field_3 = .fromArray(.{@offsetOf(Struct, "field_3")}),
        },
    };
    const proxy_2 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{ 0, @offsetOf(Struct, "field_1") }),
            .field_2 = .fromArray(.{ 0, @offsetOf(Struct, "field_2") }),
            .field_3 = .fromArray(.{ 0, @offsetOf(Struct, "field_3") }),
        },
    };
    try testing.expectEqual(&value.field_1, proxy_1.findConstFieldPointer("field_1"));
    try testing.expectEqual(&value.field_2, proxy_1.findConstFieldPointer("field_2"));
    try testing.expectEqual(&value.field_3, proxy_1.findConstFieldPointer("field_3"));
    try testing.expectEqual(&value.field_1, proxy_2.findConstFieldPointer("field_1"));
    try testing.expectEqual(&value.field_2, proxy_2.findConstFieldPointer("field_2"));
    try testing.expectEqual(&value.field_3, proxy_2.findConstFieldPointer("field_3"));
}

test "findConstFieldPointer should return null when findFieldAddress fails, address is misaligned or memory is not readable" {
    const Struct = extern struct { field_1: u64, field_2: u64 };
    const offset_1 = @offsetOf(Struct, "field_1");
    const offset_2 = @offsetOf(Struct, "field_2");
    const value = Struct{ .field_1 = 1, .field_2 = 2 };
    const proxy_1 = StructProxy(Struct){
        .base_trail = .fromArray(.{ 0, 100 }),
        .field_trails = .{
            .field_1 = .fromArray(.{offset_1}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    const proxy_2 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{std.math.maxInt(usize)}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    const proxy_3 = StructProxy(Struct){
        .base_trail = .fromArray(.{0}),
        .field_trails = .{
            .field_1 = .fromArray(.{offset_1}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    const proxy_4 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{offset_1 + 1}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    try testing.expectEqual(null, proxy_1.findConstFieldPointer("field_1"));
    try testing.expectEqual(null, proxy_2.findConstFieldPointer("field_1"));
    try testing.expectEqual(null, proxy_3.findConstFieldPointer("field_1"));
    try testing.expectEqual(null, proxy_4.findConstFieldPointer("field_1"));
}

test "findMutableFieldPointer should return a pointer when findFieldAddress succeeds, address is aligned and memory is writable" {
    const Struct = struct { field_1: u8, field_2: u16, field_3: u32 };
    var value = Struct{ .field_1 = 1, .field_2 = 2, .field_3 = 3 };
    const proxy_1 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{@offsetOf(Struct, "field_1")}),
            .field_2 = .fromArray(.{@offsetOf(Struct, "field_2")}),
            .field_3 = .fromArray(.{@offsetOf(Struct, "field_3")}),
        },
    };
    const proxy_2 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{ 0, @offsetOf(Struct, "field_1") }),
            .field_2 = .fromArray(.{ 0, @offsetOf(Struct, "field_2") }),
            .field_3 = .fromArray(.{ 0, @offsetOf(Struct, "field_3") }),
        },
    };
    try testing.expectEqual(&value.field_1, proxy_1.findMutableFieldPointer("field_1"));
    try testing.expectEqual(&value.field_2, proxy_1.findMutableFieldPointer("field_2"));
    try testing.expectEqual(&value.field_3, proxy_1.findMutableFieldPointer("field_3"));
    try testing.expectEqual(&value.field_1, proxy_2.findMutableFieldPointer("field_1"));
    try testing.expectEqual(&value.field_2, proxy_2.findMutableFieldPointer("field_2"));
    try testing.expectEqual(&value.field_3, proxy_2.findMutableFieldPointer("field_3"));
}

test "findMutableFieldPointer should return null when findFieldAddress fails, address is misaligned or memory is not writeable" {
    const Struct = extern struct { field_1: u64, field_2: u64 };
    const offset_1 = @offsetOf(Struct, "field_1");
    const offset_2 = @offsetOf(Struct, "field_2");
    const const_value = Struct{ .field_1 = 1, .field_2 = 2 };
    var var_value = Struct{ .field_1 = 1, .field_2 = 2 };
    const proxy_1 = StructProxy(Struct){
        .base_trail = .fromArray(.{ 0, 100 }),
        .field_trails = .{
            .field_1 = .fromArray(.{offset_1}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    const proxy_2 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&var_value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{std.math.maxInt(usize)}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    const proxy_3 = StructProxy(Struct){
        .base_trail = .fromArray(.{0}),
        .field_trails = .{
            .field_1 = .fromArray(.{offset_1}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    const proxy_4 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&var_value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{offset_1 + 1}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    const proxy_5 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&const_value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{offset_1}),
            .field_2 = .fromArray(.{offset_2}),
        },
    };
    try testing.expectEqual(null, proxy_1.findMutableFieldPointer("field_1"));
    try testing.expectEqual(null, proxy_2.findMutableFieldPointer("field_1"));
    try testing.expectEqual(null, proxy_3.findMutableFieldPointer("field_1"));
    try testing.expectEqual(null, proxy_4.findMutableFieldPointer("field_1"));
    try testing.expectEqual(null, proxy_5.findMutableFieldPointer("field_1"));
}

test "takeFullCopy should return struct copy when findConstFieldPointer succeeds for every field of the struct" {
    const Struct = struct { field_1: u8, field_2: u16, field_3: u32 };
    const value = Struct{ .field_1 = 1, .field_2 = 2, .field_3 = 3 };
    const proxy_1 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{@offsetOf(Struct, "field_1")}),
            .field_2 = .fromArray(.{@offsetOf(Struct, "field_2")}),
            .field_3 = .fromArray(.{@offsetOf(Struct, "field_3")}),
        },
    };
    const proxy_2 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{ 0, @offsetOf(Struct, "field_1") }),
            .field_2 = .fromArray(.{ 0, @offsetOf(Struct, "field_2") }),
            .field_3 = .fromArray(.{ 0, @offsetOf(Struct, "field_3") }),
        },
    };
    const copy_1 = proxy_1.takeFullCopy();
    const copy_2 = proxy_2.takeFullCopy();
    try testing.expect(copy_1 != null);
    try testing.expectEqual(value, copy_1.?);
    try testing.expect(copy_2 != null);
    try testing.expectEqual(value, copy_2.?);
}

test "takeFullCopy should return null when findConstFieldPointer fails for at least one field of the struct" {
    const Struct = struct { field_1: u8, field_2: u16, field_3: u32 };
    const value = Struct{ .field_1 = 1, .field_2 = 2, .field_3 = 3 };
    const proxy = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{@offsetOf(Struct, "field_1")}),
            .field_2 = .fromArray(.{@offsetOf(Struct, "field_2")}),
            .field_3 = .fromArray(.{std.math.maxInt(usize)}),
        },
    };
    try testing.expectEqual(null, proxy.takeFullCopy());
}

test "takePartialCopy should return fields with ether copy or null depending on the success of findConstFieldPointer" {
    const Struct = struct { field_1: u8, field_2: u16, field_3: u32 };
    const Partial = misc.Partial(Struct);
    const value = Struct{ .field_1 = 1, .field_2 = 2, .field_3 = 3 };
    const proxy_1 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{@offsetOf(Struct, "field_1")}),
            .field_2 = .fromArray(.{std.math.maxInt(usize)}),
            .field_3 = .fromArray(.{@offsetOf(Struct, "field_3")}),
        },
    };
    const proxy_2 = StructProxy(Struct){
        .base_trail = .fromArray(.{@intFromPtr(&&value)}),
        .field_trails = .{
            .field_1 = .fromArray(.{ 0, @offsetOf(Struct, "field_1") }),
            .field_2 = .fromArray(.{ 0, @offsetOf(Struct, "field_2") }),
            .field_3 = .fromArray(.{ 0, std.math.maxInt(usize) }),
        },
    };
    try testing.expectEqual(Partial{ .field_1 = 1, .field_2 = null, .field_3 = 3 }, proxy_1.takePartialCopy());
    try testing.expectEqual(Partial{ .field_1 = 1, .field_2 = 2, .field_3 = null }, proxy_2.takePartialCopy());
}

test "findSizeFromMaxOffset should return correct value" {
    const Struct = struct { field_1: u8, field_2: u16, field_3: u32 };
    const proxy = StructProxy(Struct){
        .base_trail = .fromArray(.{}),
        .field_trails = .{
            .field_1 = .fromArray(.{ 10, 0 }),
            .field_2 = .fromArray(.{30}),
            .field_3 = .fromArray(.{20}),
        },
    };
    try testing.expectEqual(32, proxy.findSizeFromMaxOffset());
}
