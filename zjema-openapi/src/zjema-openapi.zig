// zjema-openapi: OpenAPI 3.x code generation built on zjema
// This module provides:
// - OpenAPI parser
// - Type generator (Zig types from JSON Schema)
// - Client generator (ApiClient from OpenAPI operations)
// - Backend interface types (Header, Response, Stream)

// Core modules
pub const parser_mod = @import("openapi/parser.zig");
pub const ast = @import("openapi/ast.zig");
pub const type_generator = @import("codegen/type_generator.zig");
pub const client_generator = @import("client_generator.zig");
pub const backend = @import("backend.zig");

// Re-export AST types directly
pub const OpenApiSpec = ast.OpenApiSpec;
pub const Info = ast.Info;
pub const Server = ast.Server;
pub const PathItem = ast.PathItem;
pub const Operation = ast.Operation;
pub const Parameter = ast.Parameter;
pub const ParameterLocation = ast.ParameterLocation;
pub const RequestBody = ast.RequestBody;
pub const MediaType = ast.MediaType;
pub const Response = ast.Response;
pub const Components = ast.Components;
pub const Schema = ast.Schema;
pub const SchemaObject = ast.SchemaObject;

// Re-export parser functions
pub const parse = parser_mod.parse;
pub const ParsedOpenApi = parser_mod.ParsedOpenApi;

// Re-export type generation
pub const TypeGenConfig = type_generator.TypeGenConfig;
pub const GenerateOptions = client_generator.GenerateOptions;
pub const ClientGenerator = client_generator.ClientGenerator;

// Backend types
pub const Header = backend.Header;
pub const Stream = backend.Stream;
pub const BackendResponse = backend.BackendResponse; // renamed for clarity
