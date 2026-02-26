const std = @import("std");
const zjema_openapi = @import("zjema_openapi");
const backend = zjema_openapi.backend;

pub const StdHttpBackend = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !@This() {
        return @This(){
            .allocator = allocator,
            .base_url = base_url,
            .client = std.http.Client{ .allocator = allocator },
        };
    }

    // Convert std.http.Client.Response -> backend.BackendResponse
    fn toBackendResponse(self: *@This(), resp: std.http.Client.Response) !backend.BackendResponse {
        const status_code = @intFromEnum(resp.status);
        const body = try self.readAllBody(resp);
        errdefer self.allocator.free(body);

        // Convert std.http.Headers to []backend.Header
        const src_headers = resp.headers.items;
        const hdrs = try self.allocator.alloc(backend.Header, src_headers.len);
        for (src_headers, 0..) |src, i| {
            hdrs[i] = .{
                .name = src.name,
                .value = src.value,
            };
        }

        return backend.BackendResponse{
            .status_code = status_code,
            .body = body,
            .headers = hdrs,
        };
    }

    fn readAllBody(self: *@This(), resp: std.http.Client.Response) ![]u8 {
        const content_length = resp.headers.contentLength();
        if (content_length) |len| {
            const buf = try self.allocator.alloc(u8, len);
            var stream = resp.body.reader();
            const n = try stream.readAll(buf);
            if (n != len) {
                self.allocator.free(buf);
                return error.IncompleteResponse;
            }
            return buf;
        } else {
            var list = std.ArrayList(u8).init(self.allocator);
            var stream = resp.body.reader();
            while (true) {
                const chunk = try stream.readAllAlloc(self.allocator, 4096);
                if (chunk.len == 0) {
                    self.allocator.free(chunk);
                    break;
                }
                try list.appendSlice(chunk);
                self.allocator.free(chunk);
            }
            return list.toOwnedSlice();
        }
    }

    pub fn get(self: *@This(), url: []const u8, headers: []const backend.Header) !backend.BackendResponse {
        var req = try self.client.request(.GET, url, .{});
        try appendHeaders(&req, headers);
        try req.send();
        const resp = try req.wait();
        return self.toBackendResponse(resp);
    }

    pub fn post(self: *@This(), allocator: std.mem.Allocator, url: []const u8, body: []const u8, headers: []const backend.Header) !backend.BackendResponse {
        _ = allocator;
        var req = try self.client.request(.POST, url, .{});
        try appendHeaders(&req, headers);
        req.body = body;
        try req.send();
        const resp = try req.wait();
        return self.toBackendResponse(resp);
    }

    pub fn delete(self: *@This(), url: []const u8, headers: []const backend.Header) !backend.BackendResponse {
        var req = try self.client.request(.DELETE, url, .{});
        try appendHeaders(&req, headers);
        try req.send();
        const resp = try req.wait();
        return self.toBackendResponse(resp);
    }

    pub fn put(self: *@This(), allocator: std.mem.Allocator, url: []const u8, body: []const u8, headers: []const backend.Header) !backend.BackendResponse {
        _ = allocator;
        var req = try self.client.request(.PUT, url, .{});
        try appendHeaders(&req, headers);
        req.body = body;
        try req.send();
        const resp = try req.wait();
        return self.toBackendResponse(resp);
    }

    pub fn patch(self: *@This(), allocator: std.mem.Allocator, url: []const u8, body: []const u8, headers: []const backend.Header) !backend.BackendResponse {
        _ = allocator;
        var req = try self.client.request(.PATCH, url, .{});
        try appendHeaders(&req, headers);
        req.body = body;
        try req.send();
        const resp = try req.wait();
        return self.toBackendResponse(resp);
    }

    pub fn getStream(self: *@This(), url: []const u8, headers: []const backend.Header) !backend.Stream {
        var req = try self.client.request(.GET, url, .{});
        try appendHeaders(&req, headers);
        try req.send();
        const resp = try req.wait();
        if (resp.status != .ok) {
            return error.RequestFailed;
        }
        return backend.Stream.init(self.allocator, resp);
    }

    fn appendHeaders(req: *std.http.Request, headers: []const backend.Header) !void {
        for (headers) |h| {
            try req.headers.append(.{ .name = h.name, .value = h.value });
        }
    }

    pub fn deinit(self: *@This()) void {
        self.client.deinit();
    }
};
