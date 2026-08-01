const std = @import("std");
const chroma_logger = @import("chroma-logger");

const BenchmarkLogger = chroma_logger.Logger(.{
    .message_format = .{
        .styles = &.{.{
            .name = "value",
            .style = .{
                .foreground = .{ .rgb = .{ .r = 255, .g = 184, .b = 108 } },
                .effects = &.{.bold},
            },
        }},
    },
});

test "compile many unique logger messages" {
    var buffer: [64 * 1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);

    inline for (0..128) |index| {
        try BenchmarkLogger.write(
            &writer,
            1_709_210_096,
            true,
            .info,
            .benchmark,
            std.fmt.comptimePrint("event {d}: {{#value}}value={{d}}{{#reset}}", .{index}),
            .{index},
        );
    }
}
