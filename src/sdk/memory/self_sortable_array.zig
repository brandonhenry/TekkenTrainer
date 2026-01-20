const std = @import("std");
const misc = @import("../misc/root.zig");

pub const self_sortable_array_tag = opaque {};

pub fn SelfSortableArray(
    comptime length: usize,
    comptime Element: type,
    comptime lessThanFn: *const fn (lhs: *const Element, rhs: *const Element) bool,
) type {
    return extern struct {
        raw: [length]Element,

        const Self = @This();
        pub const tag = self_sortable_array_tag;

        pub fn sorted(self: anytype) [length]misc.SelfBasedPointer(@TypeOf(self), Self, Element) {
            return switch (@TypeOf(self)) {
                *Self => self.sortedMutable(),
                *const Self => self.sortedConst(),
                else => unreachable,
            };
        }

        fn sortedConst(self: *const Self) [length]*const Element {
            var pointers: [length]*const Element = undefined;
            for (0..length) |i| {
                pointers[i] = &self.raw[i];
            }
            std.sort.block(*const Element, &pointers, {}, compareConst);
            return pointers;
        }

        fn sortedMutable(self: *Self) [length]*Element {
            var pointers: [length]*Element = undefined;
            for (0..length) |i| {
                pointers[i] = &self.raw[i];
            }
            std.sort.block(*Element, &pointers, {}, compareMutable);
            return pointers;
        }

        fn compareConst(_: void, lhs: *const Element, rhs: *const Element) bool {
            return lessThanFn(lhs, rhs);
        }

        fn compareMutable(_: void, lhs: *Element, rhs: *Element) bool {
            return lessThanFn(lhs, rhs);
        }
    };
}

const testing = std.testing;

test "should have same size as raw array" {
    const lessThanFn = struct {
        fn call(lhs: *const i32, rhs: *const i32) bool {
            return lhs.* < rhs.*;
        }
    }.call;
    try testing.expectEqual(@sizeOf([32]i32), @sizeOf(SelfSortableArray(32, i32, lessThanFn)));
}

test "sorted should return a array of pointers sorted by value when value is immutable" {
    const lessThanFn = struct {
        fn call(lhs: *const i32, rhs: *const i32) bool {
            return lhs.* < rhs.*;
        }
    }.call;
    const array = SelfSortableArray(3, i32, lessThanFn){ .raw = .{ 2, 3, 1 } };
    const sorted = array.sorted();
    try testing.expectEqual(&array.raw[2], sorted[0]);
    try testing.expectEqual(&array.raw[0], sorted[1]);
    try testing.expectEqual(&array.raw[1], sorted[2]);
}

test "sorted should return a array of pointers sorted by value when value is mutable" {
    const lessThanFn = struct {
        fn call(lhs: *const i32, rhs: *const i32) bool {
            return lhs.* < rhs.*;
        }
    }.call;
    var array = SelfSortableArray(3, i32, lessThanFn){ .raw = .{ 2, 3, 1 } };
    const sorted = array.sorted();
    try testing.expectEqual(&array.raw[2], sorted[0]);
    try testing.expectEqual(&array.raw[0], sorted[1]);
    try testing.expectEqual(&array.raw[1], sorted[2]);
    sorted[0].* += 1;
}
