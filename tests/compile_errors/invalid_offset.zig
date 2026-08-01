const chroma_logger = @import("chroma-logger");

comptime {
    _ = chroma_logger.Logger(.{ .utc_offset_minutes = 1_440 });
}
