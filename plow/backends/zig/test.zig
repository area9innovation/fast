const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn i2s(allocator: *Allocator, i : i32) !std.ArrayList(u8) {
    var buf: [8]u8 = undefined;
    const slice = try std.fmt.bufPrint(&buf, "{d}", .{i});
    var digits = std.ArrayList(u8).fromOwnedSlice(allocator, &buf);
    return digits;
}

pub fn main() !void {
    var memory: [2 * 1024 * 1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&memory).allocator;

    const i : i32 = 1;
    const number = try i2s(allocator, i);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}", .{number.items});
    return;
}
