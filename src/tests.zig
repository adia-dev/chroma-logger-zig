const std = @import("std");
const logger = @import("lib.zig");

test "Logger writes deterministic plain output" {
    const PlainLogger = logger.Logger(.{ .color = .never });
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);

    try PlainLogger.write(
        &writer,
        45_296,
        false,
        .info,
        .default,
        "started on port {d}",
        .{8080},
    );

    try std.testing.expectEqualStrings(
        "12:34:56  INFO   started on port 8080\n",
        writer.buffered(),
    );
}

test "Logger includes non-default scopes" {
    const ScopedLogger = logger.Logger(.{});
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);

    try ScopedLogger.write(
        &writer,
        0,
        false,
        .debug,
        .database,
        "query completed",
        .{},
    );

    try std.testing.expectEqualStrings(
        "00:00:00  DEBUG  [database]  query completed\n",
        writer.buffered(),
    );
}

test "Logger renders message styles into ANSI and plain variants" {
    const ThemedLogger = logger.Logger(.{
        .layout = .{ .timestamp = .none },
        .message_format = .{
            .styles = &.{.{
                .name = "success",
                .style = .{
                    .foreground = .{ .bright = .green },
                    .effects = &.{.bold},
                },
            }},
        },
    });

    var ansi_buffer: [256]u8 = undefined;
    var ansi_writer: std.Io.Writer = .fixed(&ansi_buffer);
    try ThemedLogger.write(
        &ansi_writer,
        0,
        true,
        .info,
        .default,
        "{#success}ready{#reset} in {d}ms",
        .{12},
    );
    try std.testing.expectEqualStrings(
        "\x1b[96;1mINFO\x1b[0m   \x1b[92;1mready\x1b[0m in 12ms\n",
        ansi_writer.buffered(),
    );

    var plain_buffer: [256]u8 = undefined;
    var plain_writer: std.Io.Writer = .fixed(&plain_buffer);
    try ThemedLogger.write(
        &plain_writer,
        0,
        false,
        .info,
        .default,
        "{#success}ready{#reset} in {d}ms",
        .{12},
    );
    try std.testing.expectEqualStrings(
        "INFO   ready in 12ms\n",
        plain_writer.buffered(),
    );
}

test "Logger supports custom layout labels and fixed UTC offsets" {
    const CustomLogger = logger.Logger(.{
        .utc_offset_minutes = 90,
        .layout = .{
            .timestamp = .date_time,
            .scope = .always,
            .separator = " | ",
            .scope_open = "(",
            .scope_close = ")",
            .level_width = 4,
        },
        .labels = .{ .err = "FAIL" },
    });

    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try CustomLogger.write(
        &writer,
        0,
        false,
        .err,
        .default,
        "offline",
        .{},
    );

    try std.testing.expectEqualStrings(
        "1970-01-01 01:30:00 | FAIL | (default) | offline\n",
        writer.buffered(),
    );
}

test "Logger formats timestamps before the Unix epoch" {
    const HistoricalLogger = logger.Logger(.{
        .layout = .{
            .timestamp = .date_time,
            .show_level = false,
            .scope = .never,
        },
    });
    var buffer: [128]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);

    try HistoricalLogger.write(&writer, -1, false, .info, .default, "tick", .{});
    try std.testing.expectEqualStrings(
        "1969-12-31 23:59:59  tick\n",
        writer.buffered(),
    );
}

test "resolveColor applies explicit policy before capability" {
    try std.testing.expect(!logger.resolveColor(.auto, false));
    try std.testing.expect(logger.resolveColor(.auto, true));
    try std.testing.expect(logger.resolveColor(.always, false));
    try std.testing.expect(!logger.resolveColor(.never, true));
}

test "Logger avoids a leading separator when all prefix fields are hidden" {
    const MessageOnlyLogger = logger.Logger(.{
        .layout = .{
            .timestamp = .none,
            .show_level = false,
            .scope = .never,
        },
    });
    var buffer: [64]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);

    try MessageOnlyLogger.write(&writer, 0, false, .info, .default, "hello", .{});
    try std.testing.expectEqualStrings("hello\n", writer.buffered());
}

test "Logger accepts custom Chroma message grammar" {
    const CustomSyntaxLogger = logger.Logger(.{
        .layout = .{ .timestamp = .none, .show_level = false },
        .message_format = .{
            .syntax = .{
                .marker = '@',
                .item_separator = '|',
                .value_separator = '=',
                .channel_separator = '/',
            },
        },
    });
    var buffer: [128]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);

    try CustomSyntaxLogger.write(
        &writer,
        0,
        true,
        .info,
        .default,
        "{@fg=12/34/56|bold}custom{@reset}",
        .{},
    );
    try std.testing.expectEqualStrings(
        "\x1b[38;2;12;34;56;1mcustom\x1b[0m\n",
        writer.buffered(),
    );
}

test "Logger propagates custom writer failures" {
    const PlainLogger = logger.Logger(.{});
    var buffer: [4]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);

    try std.testing.expectError(
        error.WriteFailed,
        PlainLogger.write(&writer, 0, false, .info, .default, "too long", .{}),
    );
}

test "Logger function is compatible with std.Options" {
    const options: std.Options = .{
        .log_level = .debug,
        .logFn = logger.Logger(.{ .color = .never }).log,
    };
    try std.testing.expectEqual(std.log.Level.debug, options.log_level);
}
