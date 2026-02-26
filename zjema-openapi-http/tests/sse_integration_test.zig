const std = @import("std");
const zjema_http = @import("zjema_openapi_http");

test "getStream method exists" {
    // Compile-time check that getStream is defined.
    const info = @typeInfo(@TypeOf(zjema_http.StdHttpBackend.getStream));
    _ = info;
}
