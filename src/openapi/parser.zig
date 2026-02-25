const std = @import("std");
const json = std.json;
const ast = @import("ast.zig");

// Empty slices for default values
const empty_params = &[_]ast.Parameter{};
const empty_strings = &[_][]const u8{};

pub const ParsedOpenApi = struct {
    spec: ast.OpenApiSpec,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
    }
};

pub fn parse(allocator: std.mem.Allocator, json_data: []const u8) !ParsedOpenApi {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_alloc = arena.allocator();

    var parsed = try json.parseFromSlice(json.Value, arena_alloc, json_data, .{});
    defer parsed.deinit();
    const root = parsed.value;

    if (root != .object) return error.InvalidOpenAPI;
    const root_obj = root.object;

    const openapi = try getString(root_obj, "openapi");
    const info = try parseInfo(arena_alloc, root_obj, "info");
    const paths = try parsePaths(arena_alloc, root_obj, "paths");
    const components = if (root_obj.get("components")) |comp_val|
        try parseComponents(arena_alloc, comp_val)
    else
        null;
    const servers = if (root_obj.get("servers")) |srv_val|
        try parseServers(arena_alloc, srv_val)
    else
        try arena_alloc.alloc(ast.Server, 0);

    const spec = ast.OpenApiSpec{
        .openapi = openapi,
        .info = info,
        .paths = paths,
        .components = components,
        .servers = servers,
    };

    return ParsedOpenApi{
        .spec = spec,
        .arena = arena,
    };
}

fn getString(obj: json.ObjectMap, key: []const u8) ![]const u8 {
    const val = obj.get(key) orelse return error.MissingField;
    if (val != .string) return error.InvalidType;
    return val.string;
}

fn getOptionalString(obj: json.ObjectMap, key: []const u8) ?[]const u8 {
    const val = obj.get(key) orelse return null;
    if (val != .string) return null;
    return val.string;
}

fn asObject(v: json.Value) !json.ObjectMap {
    if (v != .object) return error.InvalidType;
    return v.object;
}

fn asArray(v: json.Value) !json.Array {
    if (v != .array) return error.InvalidType;
    return v.array;
}

fn parseInfo(allocator: std.mem.Allocator, root_obj: json.ObjectMap, key: []const u8) !ast.Info {
    _ = allocator;
    const val = root_obj.get(key) orelse return error.MissingField;
    const info_obj = try asObject(val);
    const title = try getString(info_obj, "title");
    const version = try getString(info_obj, "version");
    const description = getOptionalString(info_obj, "description");
    return ast.Info{
        .title = title,
        .version = version,
        .description = description,
    };
}

fn parseServers(allocator: std.mem.Allocator, val: json.Value) ![]ast.Server {
    const arr = try asArray(val);
    var list = std.ArrayList(ast.Server){};
    errdefer list.deinit(allocator);
    const items = arr.items;
    var i: usize = 0;
    while (i < items.len) : (i += 1) {
        const obj = try asObject(items[i]);
        const url = try getString(obj, "url");
        const description = getOptionalString(obj, "description");
        try list.append(allocator, ast.Server{
            .url = url,
            .description = description,
        });
    }
    return try list.toOwnedSlice(allocator);
}

fn parsePaths(allocator: std.mem.Allocator, root_obj: json.ObjectMap, key: []const u8) !std.StringArrayHashMap(ast.PathItem) {
    const val = root_obj.get(key) orelse return error.MissingField;
    const paths_obj = try asObject(val);
    var map = std.StringArrayHashMap(ast.PathItem).init(allocator);
    var it = paths_obj.iterator();
    var i: usize = 0;
    while (i < it.len) : (i += 1) {
        const key_str = it.keys[i];
        const value = it.values[i];
        const path_item = try parsePathItem(allocator, value);
        try map.put(key_str, path_item);
    }
    return map;
}

fn parsePathItem(allocator: std.mem.Allocator, val: json.Value) !ast.PathItem {
    const obj = try asObject(val);
    return ast.PathItem{
        .get = if (obj.get("get")) |v| try parseOperation(allocator, v) else null,
        .put = if (obj.get("put")) |v| try parseOperation(allocator, v) else null,
        .post = if (obj.get("post")) |v| try parseOperation(allocator, v) else null,
        .delete = if (obj.get("delete")) |v| try parseOperation(allocator, v) else null,
        .options = if (obj.get("options")) |v| try parseOperation(allocator, v) else null,
        .head = if (obj.get("head")) |v| try parseOperation(allocator, v) else null,
        .patch = if (obj.get("patch")) |v| try parseOperation(allocator, v) else null,
        .trace = if (obj.get("trace")) |v| try parseOperation(allocator, v) else null,
    };
}

fn parseOperation(allocator: std.mem.Allocator, val: json.Value) !ast.Operation {
    const obj = try asObject(val);
    const operationId = try getString(obj, "operationId");
    const summary = getOptionalString(obj, "summary");
    const description = getOptionalString(obj, "description");

    const parameters = if (obj.get("parameters")) |params_val|
        try parseParameters(allocator, params_val)
    else
        @constCast(empty_params);

    const requestBody = if (obj.get("requestBody")) |rb|
        try parseRequestBody(allocator, rb)
    else
        null;

    const responses = try parseResponses(allocator, obj, "responses");

    const tags = if (obj.get("tags")) |tags_val|
        try parseStringArray(allocator, tags_val)
    else
        @constCast(empty_strings);

    return ast.Operation{
        .operationId = operationId,
        .summary = summary,
        .description = description,
        .parameters = parameters,
        .requestBody = requestBody,
        .responses = responses,
        .tags = tags,
    };
}

fn parseStringArray(allocator: std.mem.Allocator, val: json.Value) ![][]const u8 {
    const arr = try asArray(val);
    var list = std.ArrayList([]const u8){};
    errdefer list.deinit(allocator);
    const items = arr.items;
    var i: usize = 0;
    while (i < items.len) : (i += 1) {
        if (items[i] != .string) return error.InvalidType;
        try list.append(allocator, items[i].string);
    }
    return try list.toOwnedSlice(allocator);
}

fn parseParameters(allocator: std.mem.Allocator, val: json.Value) ![]ast.Parameter {
    const arr = try asArray(val);
    var list = std.ArrayList(ast.Parameter){};
    errdefer list.deinit(allocator);
    const items = arr.items;
    var i: usize = 0;
    while (i < items.len) : (i += 1) {
        const obj = try asObject(items[i]);
        const name = try getString(obj, "name");
        const in_str = try getString(obj, "in");
        const in = std.meta.stringToEnum(ast.ParameterLocation, in_str) orelse return error.UnknownParameterLocation;
        const description = getOptionalString(obj, "description");
        const required = if (obj.get("required")) |r| r.bool else false;
        const schema_val = obj.get("schema") orelse return error.MissingSchema;
        const schema = try parseSchema(allocator, schema_val);
        try list.append(allocator, ast.Parameter{
            .name = name,
            .in = in,
            .description = description,
            .required = required,
            .schema = schema,
        });
    }
    return try list.toOwnedSlice(allocator);
}

fn parseRequestBody(allocator: std.mem.Allocator, val: json.Value) !ast.RequestBody {
    const obj = try asObject(val);
    const description = getOptionalString(obj, "description");
    const required = if (obj.get("required")) |r| r.bool else false;
    const content_val = obj.get("content") orelse return error.MissingContent;
    const content = try parseMediaTypes(allocator, content_val);
    return ast.RequestBody{
        .description = description,
        .required = required,
        .content = content,
    };
}

fn parseMediaTypes(allocator: std.mem.Allocator, val: json.Value) !std.StringArrayHashMap(ast.MediaType) {
    const obj = try asObject(val);
    var map = std.StringArrayHashMap(ast.MediaType).init(allocator);
    var it = obj.iterator();
    var i: usize = 0;
    while (i < it.len) : (i += 1) {
        const key_str = it.keys[i];
        const value = it.values[i];
        const media_obj = try asObject(value);
        const schema_val = media_obj.get("schema") orelse return error.MissingSchema;
        const schema = try parseSchema(allocator, schema_val);
        const example = if (media_obj.get("example")) |ex| ex else null;
        try map.put(key_str, ast.MediaType{
            .schema = schema,
            .example = example,
        });
    }
    return map;
}

fn parseResponses(allocator: std.mem.Allocator, obj: json.ObjectMap, key: []const u8) !std.StringArrayHashMap(ast.Response) {
    const val = obj.get(key) orelse return error.MissingField;
    const responses_obj = try asObject(val);
    var map = std.StringArrayHashMap(ast.Response).init(allocator);
    var it = responses_obj.iterator();
    var i: usize = 0;
    while (i < it.len) : (i += 1) {
        const key_str = it.keys[i];
        const value = it.values[i];
        const resp_obj = try asObject(value);
        const description = try getString(resp_obj, "description");
        const content_map = if (resp_obj.get("content")) |content_val|
            try parseMediaTypes(allocator, content_val)
        else
            std.StringArrayHashMap(ast.MediaType).init(allocator);
        try map.put(key_str, ast.Response{
            .description = description,
            .content = content_map,
        });
    }
    return map;
}

fn parseComponents(allocator: std.mem.Allocator, val: json.Value) !ast.Components {
    const obj = try asObject(val);
    const schemas_val = obj.get("schemas") orelse return error.MissingSchemas;
    const schemas = try parseSchemas(allocator, schemas_val);
    return ast.Components{
        .schemas = schemas,
    };
}

fn parseSchemas(allocator: std.mem.Allocator, val: json.Value) !std.StringArrayHashMap(ast.Schema) {
    const obj = try asObject(val);
    var map = std.StringArrayHashMap(ast.Schema).init(allocator);
    var it = obj.iterator();
    var i: usize = 0;
    while (i < it.len) : (i += 1) {
        const key_str = it.keys[i];
        const value = it.values[i];
        const schema = try parseSchema(allocator, value);
        try map.put(key_str, schema);
    }
    return map;
}

fn parseSchema(allocator: std.mem.Allocator, val: json.Value) !ast.Schema {
    // Check for $ref
    if (val == .object) {
        const obj = val.object;
        if (obj.get("$ref")) |ref_val| {
            if (ref_val == .string) {
                return ast.Schema{ .ref = ref_val.string };
            }
        }
    }

    // Parse as SchemaObject
    const obj = try asObject(val);
    const type_field = getOptionalString(obj, "type");
    const format = getOptionalString(obj, "format");
    const description = getOptionalString(obj, "description");

    // Properties
    var props_map: ?std.StringArrayHashMap(ast.Schema) = null;
    if (obj.get("properties")) |props_val| {
        const props_obj = try asObject(props_val);
        props_map = std.StringArrayHashMap(ast.Schema).init(allocator);
        var it = props_obj.iterator();
        var i: usize = 0;
        while (i < it.len) : (i += 1) {
            const key_str = it.keys[i];
            const value = it.values[i];
            const prop_schema = try parseSchema(allocator, value);
            try props_map.?.put(key_str, prop_schema);
        }
    }

    // Required array
    var required_slice: []const []const u8 = &.{};
    if (obj.get("required")) |req_val| {
        const arr = try asArray(req_val);
        var req_list = std.ArrayList([]const u8){};
        errdefer req_list.deinit(allocator);
        const items = arr.items;
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            if (items[i] != .string) return error.InvalidRequired;
            try req_list.append(allocator, items[i].string);
        }
        required_slice = try req_list.toOwnedSlice(allocator);
    }

    // Items (for arrays)
    var items_schema: ?ast.Schema = null;
    if (obj.get("items")) |items_val| {
        items_schema = try parseSchema(allocator, items_val);
    }

    // oneOf
    var oneof_list: []ast.Schema = &.{};
    if (obj.get("oneOf")) |oneof_val| {
        const arr = try asArray(oneof_val);
        var list = std.ArrayList(ast.Schema){};
        errdefer list.deinit(allocator);
        const items = arr.items;
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            try list.append(allocator, try parseSchema(allocator, items[i]));
        }
        oneof_list = try list.toOwnedSlice(allocator);
    }

    // anyOf
    var anyof_list: []ast.Schema = &.{};
    if (obj.get("anyOf")) |anyof_val| {
        const arr = try asArray(anyof_val);
        var list = std.ArrayList(ast.Schema){};
        errdefer list.deinit(allocator);
        const items = arr.items;
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            try list.append(allocator, try parseSchema(allocator, items[i]));
        }
        anyof_list = try list.toOwnedSlice(allocator);
    }

    // allOf
    var allof_list: []ast.Schema = &.{};
    if (obj.get("allOf")) |allof_val| {
        const arr = try asArray(allof_val);
        var list = std.ArrayList(ast.Schema){};
        errdefer list.deinit(allocator);
        const items = arr.items;
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            try list.append(allocator, try parseSchema(allocator, items[i]));
        }
        allof_list = try list.toOwnedSlice(allocator);
    }

    // enum
    var enum_list: []json.Value = &.{};
    if (obj.get("enum")) |enum_val| {
        const arr = try asArray(enum_val);
        var list = std.ArrayList(json.Value){};
        errdefer list.deinit(allocator);
        const items = arr.items;
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            try list.append(allocator, items[i]);
        }
        enum_list = try list.toOwnedSlice(allocator);
    }

    // nullable
    const nullable = if (obj.get("nullable")) |n| n.bool else false;

    const schema_obj = try allocator.create(ast.SchemaObject);
    schema_obj.* = ast.SchemaObject{
        .type = type_field,
        .properties = props_map,
        .required = required_slice,
        .items = items_schema,
        .oneOf = oneof_list,
        .anyOf = anyof_list,
        .allOf = allof_list,
        .@"enum" = enum_list,
        .format = format,
        .description = description,
        .nullable = nullable,
    };
    return ast.Schema{ .object = schema_obj };
}
