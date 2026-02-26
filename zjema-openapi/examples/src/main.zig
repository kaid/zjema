const std = @import("std");
const api = @import("generated_api.zig");

// Simple in-memory backend for demonstration
const MockBackend = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }

    // Minimal backend methods for demo (just enough to compile)
    pub fn get(self: *@This(), url: []const u8, headers: []const api.backend.Header) !api.backend.BackendResponse {
        _ = url;
        _ = headers;
        const body_str =
            \\{ "id": "123", "name": "Fluffy", "tag": "cute" }
        ;
        const body = try self.allocator.dupe(u8, body_str);
        errdefer self.allocator.free(body);
        const hdrs = try self.allocator.alloc(api.backend.Header, 0);
        return api.backend.BackendResponse{
            .status_code = 200,
            .body = body,
            .headers = hdrs,
        };
    }

    pub fn post(self: *@This(), url: []const u8, body: []const u8, headers: []const api.backend.Header) !api.backend.BackendResponse {
        _ = url;
        _ = body;
        _ = headers;
        const body_str =
            \\{ "id": "new-123", "name": "New Pet" }
        ;
        const new_body = try self.allocator.dupe(u8, body_str);
        errdefer self.allocator.free(new_body);
        const hdrs = try self.allocator.alloc(api.backend.Header, 0);
        return api.backend.BackendResponse{
            .status_code = 200,
            .body = new_body,
            .headers = hdrs,
        };
    }
};

pub fn main() void {
    const allocator = std.heap.page_allocator;

    var backend = MockBackend.init(allocator);
    defer backend.deinit();

    var client = api.ApiClient(@TypeOf(backend)).init(allocator, "https://petstore.example.com", backend);
    defer client.deinit();

    // Example: get a pet
    const pet = client.getPet(allocator, "123") catch |err| {
        std.debug.print("Error getting pet: {s}\n", .{@errorName(err)});
        return;
    };
    std.debug.print("Pet ID: {s}\n", .{pet.id});
    std.debug.print("Pet name: {s}\n", .{pet.name});
    if (pet.tag) |tag| {
        std.debug.print("Pet tag: {s}\n", .{tag});
    }
}
