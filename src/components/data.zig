const std = @import("std");
const imgui = @import("imgui");
const memory = @import("../memory/root.zig");

const error_color = imgui.ImVec4{ .x = 1, .y = 0.5, .z = 0.5, .w = 1 };
const null_color = imgui.ImVec4{ .x = 0, .y = 1, .z = 1, .w = 1 };

pub fn drawData(label: [:0]const u8, pointer: anytype) void {
    const base_info = @typeInfo(@TypeOf(pointer));
    const ChildType = switch (base_info) {
        .pointer => |info| info.child,
        else => @compileError(
            "The drawData function expects a pointer but provided value is of type: " ++ @typeName(@TypeOf(pointer)),
        ),
    };
    if (hasTag(ChildType, memory.converted_value_tag)) {
        drawConvertedValue(label, pointer);
    } else if (hasTag(ChildType, memory.pointer_tag)) {
        drawPointer(label, pointer);
    } else if (hasTag(ChildType, memory.pointer_trail_tag)) {
        drawPointerTrail(label, pointer);
    } else if (hasTag(ChildType, memory.self_sortable_array_tag)) {
        drawSelfSortableArray(label, pointer);
    } else switch (@typeInfo(ChildType)) {
        .pointer => drawData(label, pointer.*),
        .void => drawVoid(label),
        .null => drawNull(label),
        .undefined => drawUndefined(),
        .bool => drawBool(label, pointer),
        .int => drawNumber(label, pointer),
        .float => drawNumber(label, pointer),
        .comptime_float => drawComptimeNumber(label, pointer),
        .comptime_int => drawComptimeNumber(label, pointer),
        .@"fn" => drawMemoryAddress(label, pointer),
        .@"opaque" => drawMemoryAddress(label, pointer),
        .type => drawType(label, pointer),
        .enum_literal => drawEnumLiteral(label, pointer),
        .@"enum" => drawEnum(label, pointer),
        .error_set => drawError(label, pointer),
        .optional => drawOptional(label, pointer),
        .error_union => drawErrorUnion(label, pointer),
        .array => drawArray(label, pointer),
        .@"struct" => drawStruct(label, pointer),
        .@"union" => drawUnion(label, pointer),
        else => @compileError("Unsupported data type: " ++ @tagName(@typeInfo(ChildType))),
    }
}

fn drawConvertedValue(label: [:0]const u8, pointer: anytype) void {
    drawData(label, &pointer.getValue());
}

fn drawPointer(label: [:0]const u8, pointer: anytype) void {
    if (pointer.toConstPointer()) |ptr| {
        drawData(label, ptr);
    } else {
        drawText(label, "Invalid pointer.", error_color);
    }
}

fn drawPointerTrail(label: [:0]const u8, pointer: anytype) void {
    if (pointer.toConstPointer()) |ptr| {
        drawData(label, ptr);
    } else {
        drawText(label, "Invalid pointer trail.", error_color);
    }
}

fn drawSelfSortableArray(label: [:0]const u8, pointer: anytype) void {
    drawData(label, pointer.sortedConst());
}

fn drawVoid(label: [:0]const u8) void {
    drawText(label, "{} (void instance)", null);
}

fn drawNull(label: [:0]const u8) void {
    drawText(label, "null", null_color);
}

fn drawUndefined(label: [:0]const u8) void {
    drawText(label, "undefined", null);
}

fn drawBool(label: [:0]const u8, pointer: *const bool) void {
    const text = if (pointer.*) "true" else "false";
    drawText(label, text, null);
}

fn drawNumber(label: [:0]const u8, pointer: anytype) void {
    var buffer: [64]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buffer, "{}", .{pointer.*}) catch {
        drawText(label, "Display error.", error_color);
        return;
    };
    drawText(label, text, null);
}

fn drawComptimeNumber(label: [:0]const u8, pointer: anytype) void {
    const text = std.fmt.comptimePrint("{}", .{pointer.*});
    drawText(label, text, null);
}

fn drawMemoryAddress(label: [:0]const u8, pointer: anytype) void {
    const address = @intFromPtr(pointer);
    var buffer: [64]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buffer, "0x{X}", .{address}) catch {
        drawText(label, "Display error.", error_color);
        return;
    };
    drawText(label, text, null);
}

fn drawType(label: [:0]const u8, pointer: *const type) void {
    const text = @typeName(pointer.*);
    drawText(label, text, null);
}

fn drawEnumLiteral(label: [:0]const u8, pointer: anytype) void {
    const text = @tagName(pointer.*);
    drawText(label, text, null);
}

fn drawEnum(label: [:0]const u8, pointer: anytype) void {
    const child_type = @typeInfo(@TypeOf(pointer)).pointer.child;
    const info = @typeInfo(child_type).@"enum";
    const value = @intFromEnum(pointer.*);
    inline for (info.fields) |*field| {
        if (field.value == value) {
            drawText(label, field.name, null);
            break;
        }
    } else {
        drawData(label, &value);
    }
}

fn drawError(label: [:0]const u8, pointer: anytype) void {
    const text = @errorName(pointer.*);
    drawText(label, text, error_color);
}

fn drawOptional(label: [:0]const u8, pointer: anytype) void {
    if (pointer.*) |*data| {
        drawData(label, data);
    } else {
        drawNull(label);
    }
}

fn drawErrorUnion(label: [:0]const u8, pointer: anytype) void {
    if (pointer.*) |*data| {
        drawData(label, data);
    } else |err| {
        drawError(label, &err);
    }
}

fn drawArray(label: [:0]const u8, pointer: anytype) void {
    if (!imgui.igTreeNode_Str(label)) {
        return;
    }
    defer imgui.igTreePop();
    for (pointer, 0..) |*element, index| {
        var buffer: [64]u8 = undefined;
        const element_label = std.fmt.bufPrintZ(&buffer, "{}", .{index}) catch "display error";
        drawData(element_label, element);
    }
}

fn drawStruct(label: [:0]const u8, pointer: anytype) void {
    const child_type = @typeInfo(@TypeOf(pointer)).pointer.child;
    const info = @typeInfo(child_type).@"struct";
    if (!imgui.igTreeNode_Str(label)) {
        return;
    }
    defer imgui.igTreePop();
    inline for (info.fields) |*field| {
        if (comptime std.mem.startsWith(u8, field.name, "_")) {
            continue;
        }
        drawData(field.name, &@field(pointer, field.name));
    }
}

fn drawUnion(label: [:0]const u8, pointer: anytype) void {
    const child_type = @typeInfo(@TypeOf(pointer)).pointer.child;
    const info = @typeInfo(child_type).@"union";
    if (!imgui.igTreeNode_Str(label)) {
        return;
    }
    defer imgui.igTreePop();
    if (info.tag_type) |tag_type| {
        drawData("tag", &@as(tag_type, pointer.*));
        switch (pointer.*) {
            inline else => |*value_pointer| drawData("value", value_pointer),
        }
    } else inline for (info.fields) |*field| {
        const field_pointer: *const field.type = @ptrCast(pointer);
        drawData(field.name, field_pointer);
    }
}

pub inline fn hasTag(comptime Type: type, comptime tag: type) bool {
    comptime {
        if (@typeInfo(Type) != .@"struct") return false;
        if (!@hasDecl(Type, "tag")) return false;
        if (@TypeOf(Type.tag) != type) return false;
        return Type.tag == tag;
    }
}

fn drawText(label: [:0]const u8, text: [:0]const u8, color: ?imgui.ImVec4) void {
    imgui.igIndent(0.0);
    defer imgui.igUnindent(0.0);
    imgui.igText("%s:", label.ptr);
    imgui.igSameLine(0.0, -0.1);
    if (color) |col| {
        imgui.igTextColored(col, "%s", text.ptr);
    } else {
        imgui.igText("%s", text.ptr);
    }
}
