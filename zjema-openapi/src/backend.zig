const std = @import("std");

/// Header type used by backend interface
pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

/// Response type returned by backend methods (note: different from parser.Response)
pub const BackendResponse = struct {
    status_code: u16,
    body: []const u8,
    headers: []const Header = &.{},

    /// Free resources associated with the response
    pub fn deinit(self: BackendResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        if (self.headers.len > 0) {
            allocator.free(@constCast(self.headers));
        }
    }
};

/// Stream for reading streaming responses (SSE)
pub const Stream = struct {
    resp: std.http.Client.Response,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, resp: std.http.Client.Response) @This() {
        return .{
            .allocator = allocator,
            .resp = resp,
        };
    }

    pub fn reader(self: *Stream) std.io.Reader {
        return self.resp.body.reader();
    }

    /// Close the stream (no-op for now)
    pub fn close(self: *Stream) void {
        _ = self;
    }
};
