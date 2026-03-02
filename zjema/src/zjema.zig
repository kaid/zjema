// zjema: JSON Schema types and utilities
// This is the core library, independent of OpenAPI and HTTP

pub const schema = @import("schema.zig");
pub const serde = @import("serialize.zig");
pub const codegen = @import("codegen.zig");

const izo = @import("izomorph");

pub const json = struct {
    pub const Mapper = izo.Mapper;
    pub const Root = izo.json.Root;
    pub const encode = izo.json.encode;
    pub const encodeToWriter = izo.json.encodeToWriter;
    pub const EncodeOptions = izo.json.EncodeOptions;
    pub const decode = izo.json.decode;
    pub const decodeFromReader = izo.json.decodeFromReader;
    pub const DecodeOptions = izo.json.DecodeOptions;
};

test {
    _ = @import("schema.zig");
    _ = @import("serialize.zig");
    _ = @import("codegen.zig");
}
