// Minimal izomorph stub for demonstration
// Provides Mapper and json encode/decode using std.json

const std = @import("std");

/// Mapper simply returns the type itself for simplicity.
pub fn Mapper(comptime T: type, comptime _: anytype) type {
    return T;
}

pub const json = .{
    .encode = encode,
    .decode = decode,
};

/// Encode a value to JSON bytes.
pub fn encode(allocator: std.mem.Allocator, value: anytype, mapper: anytype, options: anytype) ![]u8 {
    _ = mapper;
    _ = options;
    return std.json.stringifyAlloc(allocator, value, .{});
}

/// Decode JSON bytes into a value of type T.
pub fn decode(allocator: std.mem.Allocator, comptime T: type, bytes: []const u8) !T {
    return try std.json.parseFromSliceLeaky(T, allocator, bytes, .{});
}
