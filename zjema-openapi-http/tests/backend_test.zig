const std = @import("std");
const zjema_http = @import("zjema_openapi_http");

test "StdHttpBackend type exists" {
    // Ensures the type is accessible and has the expected methods
    const T = @TypeOf(zjema_http.StdHttpBackend);
    _ = @typeInfo(T);
}

test "Stream type exists" {
    _ = @TypeOf(zjema_http.Stream);
}
