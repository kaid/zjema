const std = @import("std");

/// HTTP Backend abstraction using comptime polymorphism.
/// Implement this interface for your HTTP client of choice.
///
/// Example implementation using std.http:
/// ```zig
/// pub const StdHttpBackend = struct {
///     allocator: std.mem.Allocator,
///     base_url: []const u8,
///     client: std.http.Client,
///
///     pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !@This() {
///         return .{
///             .allocator = allocator,
///             .base_url = base_url,
///             .client = std.http.Client{ .allocator = allocator },
///         };
///     }
///
///     pub fn get(self: *@This(), url: []const u8, headers: []const Header) !Response {
///         var req = try self.client.request(.GET, url, .{ .headers = headers });
///         try req.send();
///         return try req.wait();
///     }
///
///     pub fn post(self: *@This(), allocator: std.mem.Allocator, url: []const u8, body: []const u8, headers: []const Header) !Response {
///         var req = try self.client.request(.POST, url, .{ .headers = headers, .body = body });
///         try req.send();
///         return try req.wait();
///     }
///
///     pub fn deinit(self: *@This()) void {
///         self.client.deinit();
///     }
/// };
/// ```
pub const HttpBackend = struct {
    /// Initialize the backend with an allocator and base URL
    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) anyerror!@This() {
        _ = allocator;
        _ = base_url;
        @compileError("HttpBackend.init must be implemented by concrete backend type");
    }

    /// Send a GET request
    /// Returns Response with .status_code, .body, .headers
    pub fn get(self: *@This(), url: []const u8, headers: []const Header) anyerror!Response {
        _ = self;
        _ = url;
        _ = headers;
        @compileError("HttpBackend.get must be implemented by concrete backend type");
    }

    /// Send a POST request with body
    /// The backend owns the body string after the call - don't free it
    pub fn post(self: *@This(), allocator: std.mem.Allocator, url: []const u8, body: []const u8, headers: []const Header) anyerror!Response {
        _ = self;
        _ = allocator;
        _ = url;
        _ = body;
        _ = headers;
        @compileError("HttpBackend.post must be implemented by concrete backend type");
    }

    /// Clean up resources
    pub fn deinit(self: *@This()) void {
        _ = self;
        // Default no-op
    }
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Response = struct {
    status_code: u16,
    body: []const u8,
    headers: []const Header = &.{},

    pub fn deinit(self: Response, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        if (self.headers.ptr != null) {
            allocator.free(@constCast(self.headers));
        }
    }
};

/// Default implementation using std.http (Zig 0.16+)
pub const StdHttpBackend = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !StdHttpBackend {
        var self: StdHttpBackend = undefined;
        self.allocator = allocator;
        self.base_url = base_url;
        self.client = std.http.Client{ .allocator = allocator };
        return self;
    }

    pub fn get(self: *StdHttpBackend, url: []const u8, headers: []const Header) !Response {
        // Build request
        var req = try self.client.request(.GET, url, .{
            .headers = headers,
        });
        try req.send();
        const resp = try req.wait();

        // Read body
        const body = try self.readAllocResponseBody(resp);
        errdefer self.allocator.free(body);

        // Convert headers
        const hdrs = try self.allocator.dupe(Header, resp.headers.items);
        errdefer self.allocator.free(hdrs);

        return Response{
            .status_code = resp.status,
            .body = body,
            .headers = hdrs,
        };
    }

    pub fn post(self: *StdHttpBackend, allocator: std.mem.Allocator, url: []const u8, body: []const u8, headers: []const Header) !Response {
        _ = allocator; // Use self.allocator
        var req = try self.client.request(.POST, url, .{
            .headers = headers,
            .body = body,
        });
        try req.send();
        const resp = try req.wait();

        const resp_body = try self.readAllocResponseBody(resp);
        errdefer self.allocator.free(resp_body);

        const hdrs = try self.allocator.dupe(Header, resp.headers.items);
        errdefer self.allocator.free(hdrs);

        return Response{
            .status_code = resp.status,
            .body = resp_body,
            .headers = hdrs,
        };
    }

    pub fn deinit(self: *StdHttpBackend) void {
        self.client.deinit();
    }

    fn readAllocResponseBody(self: *StdHttpBackend, resp: std.http.Response) ![]u8 {
        // Determine length
        const content_length = resp.headers.contentLength();
        if (content_length) |len| {
            const buf = try self.allocator.alloc(u8, len);
            var stream = resp.body;
            const read_len = try stream.readAll(buf);
            if (read_len != len) {
                self.allocator.free(buf);
                return error.IncompleteResponse;
            }
            return buf;
        } else {
            // Unknown length - read into ArrayList
            var list = std.ArrayList(u8).init(self.allocator);
            var stream = resp.body;
            while (true) {
                const chunk = try stream.reader().readAllAlloc(self.allocator, 4096);
                if (chunk.len == 0) break;
                try list.append(chunk);
                self.allocator.free(chunk); // readAlloc returns owned slice each time
            }
            return list.toOwnedSlice();
        }
    }
};
