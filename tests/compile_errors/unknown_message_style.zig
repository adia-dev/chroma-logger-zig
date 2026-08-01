const std = @import("std");
const chroma_logger = @import("chroma-logger");

test {
    const TestLogger = chroma_logger.Logger(.{});
    var buffer: [64]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try TestLogger.write(
        &writer,
        0,
        false,
        .info,
        .default,
        "{#missing}message",
        .{},
    );
}
