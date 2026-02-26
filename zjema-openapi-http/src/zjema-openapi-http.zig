// zjema-openapi-http: HTTP backend implementations for zjema-openapi
// Provides StdHttpBackend and re-exports backend interface from zjema-openapi.

const zjema_openapi = @import("zjema_openapi");
const backend = zjema_openapi.backend;

// Re-export backend interface types
pub const Header = backend.Header;
pub const Response = backend.Response;
pub const Stream = backend.Stream;

// Re-export StdHttpBackend
pub const StdHttpBackend = @import("std_backend.zig").StdHttpBackend;
