//! zjema - Compile-time JSON Schema generation for Zig
//!
//! ## Example
//! ```zig
//! const zjema = @import("zjema");
//!
//! const User = struct {
//!     id: u64,
//!     name: []const u8,
//!     email: ?[]const u8,
//! };
//!
//! const schema = zjema.generate(User);
//! const json = try zjema.stringify(std.testing.allocator, schema, .{});
//! ```

pub const schema = @import("schema.zig");
pub const serialize = @import("serialize.zig");
pub const backend = @import("backend.zig");
pub const client_generator_mod = @import("client_generator.zig");
pub const codegen = @import("codegen/type_generator.zig");

// Re-export ClientGenerator for convenience
pub const ClientGenerator = client_generator_mod.ClientGenerator;

// OpenAPI aggregator
pub const openapi = struct {
    pub const parser = @import("openapi/parser.zig");
    pub const ast = @import("openapi/ast.zig");
};

// Re-export main types and functions
pub const JsonSchema = schema.JsonSchema;
pub const generate = schema.generate;
pub const stringify = serialize.stringify;
pub const print = serialize.print;
pub const SerializeOptions = serialize.SerializeOptions;

// Re-export Property for convenience
pub const Property = schema.JsonSchema.Property;
