//! Configurable, comptime-first logging for Zig applications.
//!
//! `Logger` produces a `std.log` compatible function from a compile-time
//! configuration. Chroma directives in messages are parsed into ANSI and
//! plain variants at compile time; runtime work is limited to timestamps,
//! argument formatting, terminal selection, and writing the line.

const std = @import("std");
const chroma = @import("chroma");
const DateTime = @import("datetime.zig").DateTime;

pub const ColorPolicy = chroma.terminal.ColorPolicy;
pub const Style = chroma.Style;
pub const Color = chroma.Color;
pub const Effect = chroma.Effect;

/// Timestamp displayed before each log line.
pub const TimestampMode = enum {
    none,
    time,
    date_time,
};

/// Controls when the `std.log` scope is displayed.
pub const ScopeMode = enum {
    never,
    non_default,
    always,
};

/// Human-readable layout of a log line.
pub const Layout = struct {
    timestamp: TimestampMode = .time,
    show_level: bool = true,
    scope: ScopeMode = .non_default,
    separator: []const u8 = "  ",
    scope_open: []const u8 = "[",
    scope_close: []const u8 = "]",
    level_width: usize = 5,
};

/// Text used for Zig's four built-in log levels.
pub const Labels = struct {
    err: []const u8 = "ERROR",
    warn: []const u8 = "WARN",
    info: []const u8 = "INFO",
    debug: []const u8 = "DEBUG",
};

/// Typed Chroma styles for logger-owned fields.
pub const Theme = struct {
    timestamp: Style = .{
        .foreground = .{ .bright = .black },
        .effects = &.{.dim},
    },
    err: Style = .{
        .foreground = .{ .bright = .red },
        .effects = &.{.bold},
    },
    warn: Style = .{
        .foreground = .{ .bright = .yellow },
        .effects = &.{.bold},
    },
    info: Style = .{
        .foreground = .{ .bright = .cyan },
        .effects = &.{.bold},
    },
    debug: Style = .{
        .foreground = .{ .bright = .magenta },
        .effects = &.{.bold},
    },
    scope: Style = .{
        .foreground = .{ .bright = .black },
    },
};

/// Compile-time logger configuration.
pub const Config = struct {
    /// Automatic terminal detection, forced ANSI, or forced plain output.
    color: ColorPolicy = .auto,
    /// Fixed offset from UTC. This deliberately avoids hidden timezone I/O.
    utc_offset_minutes: i16 = 0,
    layout: Layout = .{},
    labels: Labels = .{},
    theme: Theme = .{},
    /// Chroma syntax and semantic styles accepted inside log messages.
    message_format: chroma.Config = .{},
};

/// Build a `std.log` compatible logger from compile-time configuration.
pub fn Logger(comptime config: Config) type {
    comptime validateConfig(config);

    const MessageFormatter = chroma.Formatter(config.message_format);
    const timestamp_style = comptime styleFragment(config.theme.timestamp);
    const scope_style = comptime styleFragment(config.theme.scope);
    const reset = comptime chroma.render("{#reset}");

    return struct {
        /// `std.Options.logFn` implementation using locked stderr.
        pub fn log(
            comptime level: std.log.Level,
            comptime scope: @EnumLiteral(),
            comptime message: []const u8,
            args: anytype,
        ) void {
            const io = std.Options.debug_io;
            const previous_protection = io.swapCancelProtection(.blocked);
            defer _ = io.swapCancelProtection(previous_protection);

            var buffer: [256]u8 = undefined;
            const locked = std.debug.lockStderr(&buffer);
            defer std.debug.unlockStderr();

            const terminal = locked.terminal();
            const use_color = resolveColor(config.color, terminal.mode == .escape_codes);
            const timestamp = if (config.layout.timestamp == .none)
                0
            else
                std.Io.Clock.real.now(io).toSeconds();

            write(
                terminal.writer,
                timestamp,
                use_color,
                level,
                scope,
                message,
                args,
            ) catch {};
        }

        /// Render one deterministic log line to any Zig writer.
        ///
        /// Supplying the timestamp and color decision makes this API suitable
        /// for tests, files, memory buffers, and application-owned sinks.
        pub fn write(
            writer: *std.Io.Writer,
            unix_seconds: i64,
            use_color: bool,
            comptime level: std.log.Level,
            comptime scope: @EnumLiteral(),
            comptime message: []const u8,
            args: anytype,
        ) std.Io.Writer.Error!void {
            var has_prefix = false;

            if (config.layout.timestamp != .none) {
                try writeTimestamp(writer, unix_seconds, use_color, timestamp_style, reset, config);
                has_prefix = true;
            }

            if (config.layout.show_level) {
                try writeSeparator(writer, &has_prefix, config.layout.separator);
                const label = levelLabel(config.labels, level);
                try writeStyled(writer, levelStyle(config.theme, level), reset, label, use_color);
                if (label.len < config.layout.level_width) {
                    try writer.splatByteAll(' ', config.layout.level_width - label.len);
                }
            }

            if (showScope(config.layout.scope, scope)) {
                try writeSeparator(writer, &has_prefix, config.layout.separator);
                try writeRendered(writer, scope_style, use_color);
                try writer.writeAll(config.layout.scope_open);
                try writer.writeAll(@tagName(scope));
                try writer.writeAll(config.layout.scope_close);
                if (scope_style.ansi.len != 0) try writeRendered(writer, reset, use_color);
            }

            try writeSeparator(writer, &has_prefix, config.layout.separator);
            const rendered_message = comptime MessageFormatter.render(message);
            if (use_color) {
                try writer.print(rendered_message.ansi, args);
            } else {
                try writer.print(rendered_message.plain, args);
            }
            try writer.writeByte('\n');
        }
    };
}

/// Default logger with time, level, automatic color, and non-default scopes.
pub const default = Logger(.{});

/// Drop-in default `std.Options.logFn` implementation.
pub const log = default.log;

/// Resolve a color policy from a previously detected ANSI capability.
pub fn resolveColor(policy: ColorPolicy, ansi_capable: bool) bool {
    return switch (policy) {
        .auto => ansi_capable,
        .always => true,
        .never => false,
    };
}

fn writeTimestamp(
    writer: *std.Io.Writer,
    unix_seconds: i64,
    use_color: bool,
    comptime style: chroma.Rendered,
    comptime reset: chroma.Rendered,
    comptime config: Config,
) std.Io.Writer.Error!void {
    const offset_seconds = @as(i64, config.utc_offset_minutes) * std.time.s_per_min;
    const datetime = DateTime.fromUnix(unix_seconds + offset_seconds);

    try writeRendered(writer, style, use_color);
    switch (config.layout.timestamp) {
        .none => unreachable,
        .time => try writer.print("{d:0>2}:{d:0>2}:{d:0>2}", .{
            datetime.hour,
            datetime.minute,
            datetime.second,
        }),
        .date_time => {
            try writeYear(writer, datetime.year);
            try writer.print("-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
                datetime.month,
                datetime.day,
                datetime.hour,
                datetime.minute,
                datetime.second,
            });
        },
    }
    if (style.ansi.len != 0) try writeRendered(writer, reset, use_color);
}

fn writeYear(writer: *std.Io.Writer, year: i64) std.Io.Writer.Error!void {
    if (year < 0) {
        try writer.writeByte('-');
        try writer.print("{d:0>4}", .{@as(u64, @intCast(-year))});
    } else {
        try writer.print("{d:0>4}", .{@as(u64, @intCast(year))});
    }
}

fn writeSeparator(writer: *std.Io.Writer, has_prefix: *bool, separator: []const u8) std.Io.Writer.Error!void {
    if (has_prefix.*) try writer.writeAll(separator);
    has_prefix.* = true;
}

fn writeStyled(
    writer: *std.Io.Writer,
    comptime style: chroma.Rendered,
    comptime reset: chroma.Rendered,
    text: []const u8,
    use_color: bool,
) std.Io.Writer.Error!void {
    try writeRendered(writer, style, use_color);
    try writer.writeAll(text);
    if (style.ansi.len != 0) try writeRendered(writer, reset, use_color);
}

fn writeRendered(writer: *std.Io.Writer, comptime rendered: chroma.Rendered, use_color: bool) std.Io.Writer.Error!void {
    try writer.writeAll(rendered.select(use_color));
}

fn styleFragment(comptime style: Style) chroma.Rendered {
    const formatter = chroma.Formatter(.{
        .styles = &.{.{ .name = "logger", .style = style }},
        .auto_reset = false,
    });
    return formatter.render("{#logger}");
}

fn levelStyle(comptime theme: Theme, comptime level: std.log.Level) chroma.Rendered {
    return styleFragment(switch (level) {
        .err => theme.err,
        .warn => theme.warn,
        .info => theme.info,
        .debug => theme.debug,
    });
}

fn levelLabel(comptime labels: Labels, comptime level: std.log.Level) []const u8 {
    return switch (level) {
        .err => labels.err,
        .warn => labels.warn,
        .info => labels.info,
        .debug => labels.debug,
    };
}

fn showScope(comptime mode: ScopeMode, comptime scope: @EnumLiteral()) bool {
    return switch (mode) {
        .never => false,
        .non_default => scope != .default,
        .always => true,
    };
}

fn validateConfig(comptime config: Config) void {
    if (config.utc_offset_minutes <= -24 * 60 or config.utc_offset_minutes >= 24 * 60) {
        @compileError("chroma-logger config: utc_offset_minutes must be between -1439 and 1439");
    }
    if (config.layout.level_width > 64) {
        @compileError("chroma-logger config: level_width cannot exceed 64");
    }

    validateLinePart("separator", config.layout.separator, true);
    validateLinePart("scope_open", config.layout.scope_open, true);
    validateLinePart("scope_close", config.layout.scope_close, true);
    validateLinePart("err label", config.labels.err, false);
    validateLinePart("warn label", config.labels.warn, false);
    validateLinePart("info label", config.labels.info, false);
    validateLinePart("debug label", config.labels.debug, false);
}

fn validateLinePart(comptime name: []const u8, comptime value: []const u8, comptime allow_empty: bool) void {
    if (!allow_empty and value.len == 0) {
        @compileError("chroma-logger config: " ++ name ++ " cannot be empty");
    }
    if (std.mem.indexOfAny(u8, value, "\r\n") != null) {
        @compileError("chroma-logger config: " ++ name ++ " cannot contain a newline");
    }
}

test {
    _ = @import("datetime.zig");
    _ = @import("tests.zig");
}
