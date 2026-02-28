// zjema: JSON Schema types and utilities
// This is the core library, independent of OpenAPI and HTTP

pub const schema = @import("schema.zig");
pub const serde = @import("serialize.zig");
pub const codegen = @import("codegen.zig");

test {
    _ = @import("schema.zig");
    _ = @import("serialize.zig");
    _ = @import("codegen.zig");
}
