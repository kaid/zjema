const std = @import("std");
const json = std.json;

/// OpenAPI 3.x Specification AST (simplified)
pub const OpenApiSpec = struct {
    openapi: []const u8,
    info: Info,
    paths: std.array_hash_map.String(PathItem),
    components: ?Components = null,
    servers: []Server = &.{},
};

pub const Info = struct {
    title: []const u8,
    version: []const u8,
    description: ?[]const u8 = null,
};

pub const Server = struct {
    url: []const u8,
    description: ?[]const u8 = null,
};

pub const PathItem = struct {
    get: ?Operation = null,
    put: ?Operation = null,
    post: ?Operation = null,
    delete: ?Operation = null,
    options: ?Operation = null,
    head: ?Operation = null,
    patch: ?Operation = null,
    trace: ?Operation = null,
};

pub const Operation = struct {
    operationId: []const u8,
    summary: ?[]const u8 = null,
    description: ?[]const u8 = null,
    parameters: []Parameter = &.{},
    requestBody: ?RequestBody = null,
    responses: std.array_hash_map.String(Response),
    tags: [][]const u8 = &.{},
};

pub const Parameter = struct {
    name: []const u8,
    in: ParameterLocation,
    description: ?[]const u8 = null,
    required: bool = false,
    schema: Schema,
};

pub const ParameterLocation = enum {
    query,
    path,
    header,
    cookie,
};

pub const RequestBody = struct {
    description: ?[]const u8 = null,
    required: bool = false,
    content: std.array_hash_map.String(MediaType),
};

pub const MediaType = struct {
    schema: Schema,
    example: ?json.Value = null,
};

pub const Response = struct {
    description: []const u8,
    content: std.array_hash_map.String(MediaType),
};

pub const Components = struct {
    schemas: std.array_hash_map.String(Schema),
};

pub const Schema = union(enum) {
    ref: []const u8,
    object: *const SchemaObject,

    pub fn getObject(self: Schema) *const SchemaObject {
        return switch (self) {
            .ref => |ref| {
                _ = ref;
                @compileError("Schema.ref must be resolved before getObject()");
            },
            .object => |ptr| ptr,
        };
    }
};

pub const SchemaObject = struct {
    type: ?[]const u8 = null,
    properties: ?std.array_hash_map.String(Schema) = null,
    required: []const []const u8 = &.{},
    items: ?Schema = null,
    oneOf: []Schema = &.{},
    anyOf: []Schema = &.{},
    allOf: []Schema = &.{},
    @"enum": []json.Value = &.{},
    format: ?[]const u8 = null,
    description: ?[]const u8 = null,
    nullable: bool = false,
};
