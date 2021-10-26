const std = @import("std");

/// Describes the components of a RFC 3986 URI.
pub const ParsedUri = struct {
    /// The complete uri that was parsed, in case that it needs to be passed along to something else.
    uri: []const u8 = undefined,

    scheme: []const u8 = undefined,

    authority: ?[]const u8 = null,
    userinfo: ?[]const u8 = null,
    host: ?[]const u8 = null,
    port: ?[]const u8 = null,

    path: []const u8 = "",
    query: ?[]const u8 = null,
    fragment: ?[]const u8 = null,
};

pub fn parse(uri: []const u8) !ParsedUri {
    var parsed = ParsedUri{ .uri = uri };

    // Find the scheme

    const scheme_end = std.mem.indexOfScalar(u8, uri, ':') orelse return error.MissingScheme;

    parsed.scheme = uri[0..scheme_end];

    // Check and find if we have an authority

    if (uri.len - scheme_end > 3 and uri[scheme_end + 1] == '/' and uri[scheme_end + 2] == '/') {
        const authority_start = scheme_end + 3;
        const path_start = std.mem.indexOfScalarPos(u8, uri, authority_start, '/');
        const query_start = std.mem.indexOfScalarPos(u8, uri, path_start orelse authority_start, '?');
        const fragment_start = std.mem.indexOfScalarPos(u8, uri, query_start orelse path_start orelse authority_start, '#');

        // Authority is ended by a '/', '?', '#', or the end of the string.
        const authority_end = path_start orelse query_start orelse fragment_start orelse uri.len;

        // Path is ended by a '?', '#', or the end of the string.
        const path_end = query_start orelse fragment_start orelse uri.len;

        // Query is ended by a '#', or the end of the string.
        const query_end = fragment_start orelse uri.len;

        // Fragment is ended by the end of the string.
        const fragment_end = uri.len;

        // Start handling the authority components.
        parsed.authority = uri[authority_start..authority_end];

        const host_start = std.mem.indexOfScalarPos(u8, uri, authority_start, '@') orelse authority_start;
        const port_start = std.mem.indexOfScalarPos(u8, uri, host_start, ':');

        const host_end = port_start orelse authority_end;

        if (host_start == authority_start and uri[authority_start] != '@') {
            parsed.host = uri[authority_start..host_end];
        } else {
            parsed.userinfo = uri[authority_start..host_start];
            parsed.host = uri[host_start + 1 .. host_end];
        }

        if (port_start) |pos| {
            parsed.port = uri[pos + 1 .. authority_end];
        }

        // We handled the authority

        if (path_start) |pos| {
            parsed.path = uri[pos + 1 .. path_end];
        }

        if (query_start) |pos| {
            parsed.query = uri[pos + 1 .. query_end];
        }

        if (fragment_start) |pos| {
            parsed.fragment = uri[pos + 1 .. fragment_end];
        }
    } else {
        // Otherwise we have a URN and everything is in the path.
        parsed.path = uri[scheme_end + 1 ..];
    }

    return parsed;
}

const testing = std.testing;

fn check(uri: []const u8, expected: ParsedUri) !void {
    const parsed = try parse(uri);

    try std.testing.expectEqualStrings(expected.scheme, parsed.scheme);
    try std.testing.expectEqualStrings(expected.path, parsed.path);

    if (expected.authority == null or parsed.authority == null) {
        try std.testing.expectEqual(expected.authority, parsed.authority);
    } else {
        try std.testing.expectEqualStrings(expected.authority.?, parsed.authority.?);
    }

    if (expected.userinfo == null or parsed.userinfo == null) {
        try std.testing.expectEqual(expected.userinfo, parsed.userinfo);
    } else {
        try std.testing.expectEqualStrings(expected.userinfo.?, parsed.userinfo.?);
    }

    if (expected.host == null or parsed.host == null) {
        try std.testing.expectEqual(expected.host, parsed.host);
    } else {
        try std.testing.expectEqualStrings(expected.host.?, parsed.host.?);
    }

    if (expected.port == null or parsed.port == null) {
        try std.testing.expectEqual(expected.port, parsed.port);
    } else {
        try std.testing.expectEqualStrings(expected.port.?, parsed.port.?);
    }

    if (expected.query == null or parsed.query == null) {
        try std.testing.expectEqual(expected.query, parsed.query);
    } else {
        try std.testing.expectEqualStrings(expected.query.?, parsed.query.?);
    }

    if (expected.fragment == null or parsed.fragment == null) {
        try std.testing.expectEqual(expected.fragment, parsed.fragment);
    } else {
        try std.testing.expectEqualStrings(expected.fragment.?, parsed.fragment.?);
    }
}

const unreserved_characters = [128]u1{
    // 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 1
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, // 2
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, // 3

    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, // 4
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, // 5
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, // 6
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, // 7
} ++ ([_]u1{0} ** 128);

test "parse" {
    try check("abc:", .{
        .scheme = "abc",
        .path = "",
    });

    try check("abc:anything", .{
        .scheme = "abc",
        .path = "anything",
    });

    try check("abc://host/path?query#frag", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .path = "path",
        .query = "query",
        .fragment = "frag",
    });

    try check("abc://host/path?query", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .path = "path",
        .query = "query",
    });

    try check("abc://host/path#frag", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .path = "path",
        .fragment = "frag",
    });

    try check("abc://host/path", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .path = "path",
    });

    try check("abc://host?query#frag", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .query = "query",
        .fragment = "frag",
    });

    try check("abc://host?query", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .query = "query",
    });

    try check("abc://host#frag", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .fragment = "frag",
    });

    try check("abc://host", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
    });

    try check("abc://host/?query#frag", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .path = "",
        .query = "query",
        .fragment = "frag",
    });

    try check("abc://host/path?#frag", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .path = "path",
        .query = "",
        .fragment = "frag",
    });

    try check("abc://host/path?query#", .{
        .scheme = "abc",
        .authority = "host",
        .host = "host",
        .path = "path",
        .query = "query",
        .fragment = "",
    });

    try check("abc:///path?query#frag", .{
        .scheme = "abc",
        .authority = "",
        .host = "",
        .path = "path",
        .query = "query",
        .fragment = "frag",
    });

    try check("abc:///path?query", .{
        .scheme = "abc",
        .authority = "",
        .host = "",
        .path = "path",
        .query = "query",
    });

    try check("abc:///path#frag", .{
        .scheme = "abc",
        .authority = "",
        .host = "",
        .path = "path",
        .fragment = "frag",
    });

    try check("abc:///path", .{
        .scheme = "abc",
        .authority = "",
        .host = "",
        .path = "path",
    });

    try check("abc://user:pass@host:123", .{
        .scheme = "abc",
        .authority = "user:pass@host:123",
        .userinfo = "user:pass",
        .host = "host",
        .port = "123",
        .path = "",
    });

    try check("abc://user:@host:123", .{
        .scheme = "abc",
        .authority = "user:@host:123",
        .userinfo = "user:",
        .host = "host",
        .port = "123",
        .path = "",
    });

    try check("abc://:pass@host:123", .{
        .scheme = "abc",
        .authority = ":pass@host:123",
        .userinfo = ":pass",
        .host = "host",
        .port = "123",
        .path = "",
    });

    try check("abc://@host:123", .{
        .scheme = "abc",
        .authority = "@host:123",
        .userinfo = "",
        .host = "host",
        .port = "123",
        .path = "",
    });

    try check("abc://host:123", .{
        .scheme = "abc",
        .authority = "host:123",
        .host = "host",
        .port = "123",
        .path = "",
    });

    try check("abc://user:pass@host", .{
        .scheme = "abc",
        .authority = "user:pass@host",
        .userinfo = "user:pass",
        .host = "host",
        .path = "",
    });
}

pub fn urlEncode(allocator: *std.mem.Allocator, str: []const u8) ![]u8 {
    var size: usize = str.len;

    for (str) |c| {
        if (unreserved_characters[c] == 0) {
            // the percent takes the place of the character, so only 2 more are required
            size += 2;
        }
    }

    var duped = try allocator.alloc(u8, size);
    var stream = std.io.fixedBufferStream(duped);

    const writer = stream.writer();

    for (str) |c| {
        if (unreserved_characters[c] == 0) {
            try writer.print("%{X:0<2}", .{c});
        } else {
            try writer.writeByte(c);
        }
    }

    return duped;
}

test "urlEncode" {
    const str = try urlEncode(testing.allocator, "hello world");
    defer testing.allocator.free(str);

    try testing.expectEqualStrings("hello%20world", str);
}

pub fn urlDecode(allocator: *std.mem.Allocator, str: []const u8) ![]u8 {
    var size: usize = str.len;

    for (str) |c| {
        if (c == '%') {
            if (size < 2) {
                size = 0;
                break;
            }

            size -= 2;
        }
    }

    if (size == 0) {
        return try allocator.alloc(u8, 0);
    }

    var duped = try allocator.alloc(u8, size);
    var stream = std.io.fixedBufferStream(duped);

    const writer = stream.writer();

    var pos: usize = 0;

    while (pos < str.len) : (pos += 1) {
        var c = str[pos];

        if (c == '%') {
            const byte = try std.fmt.parseUnsigned(u8, str[pos + 1 ..][0..2], 16);
            pos += 2;

            try writer.writeByte(byte);
        } else {
            try writer.writeByte(c);
        }
    }

    return duped;
}
test "urlDecode" {
    const str = try urlDecode(testing.allocator, "hello%20world");
    defer testing.allocator.free(str);

    try testing.expectEqualStrings("hello world", str);
}
