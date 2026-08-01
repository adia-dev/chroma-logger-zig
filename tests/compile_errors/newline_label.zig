const chroma_logger = @import("chroma-logger");

comptime {
    _ = chroma_logger.Logger(.{
        .labels = .{ .info = "INFO\n" },
    });
}
