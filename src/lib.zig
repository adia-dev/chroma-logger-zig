// TODO: make a private util function that is configurable that all other log function inherit from, LogBuilder sort of
// TODO: make it configurable, json file maybe ?? env variable would be great but comptime complicated

const std = @import("std");
const Time = @import("./time/time.zig").Time;
const chroma = @import("chroma");

pub fn timeBasedLog(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime message: []const u8, args: anytype) void {
    _ = scope;

    const timestamp = std.time.timestamp();
    const offset_in_seconds = 3600;
    // TODO: make the offset configurable
    const time = Time.from_unix_timestamp(timestamp + @as(i64, offset_in_seconds));

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();

    // TODO: search if it is possible to merge these into a single print call
    const formatted_timestamp = comptime chroma.format("{247}{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2} {reset}");
    nosuspend stderr.print(formatted_timestamp, .{ time.year, time.month, time.day, time.hour, time.minute, time.second }) catch return;
    nosuspend stderr.print("{s} ", .{level_to_string(level)}) catch return;
    const formatted_message = comptime chroma.format(message);
    nosuspend stderr.print(formatted_message ++ "\n", args) catch return;
}

pub fn defaultLog(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime message: []const u8, args: anytype) void {
    _ = level;
    _ = scope;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();

    const formatted_message = comptime chroma.format(message);
    nosuspend stderr.print(formatted_message ++ "\n", args) catch return;
}

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime message: []const u8, args: anytype) void {
    _ = scope;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();

    // TODO: search if it is possible to merge these into a single print call
    nosuspend stderr.print("{s} ", .{level_to_string(level)}) catch return;
    const formatted_message = comptime chroma.format(message);
    nosuspend stderr.print(formatted_message ++ "\n", args) catch return;
}

fn level_to_string(comptime level: std.log.Level) []const u8 {
    return switch (level) {
        .err => chroma.format("{red}ERROR{reset}"),
        .warn => chroma.format("{yellow}WARN{reset}"),
        .info => chroma.format("{blue}INFO{reset}"),
        .debug => chroma.format("{magenta}DEBUG{reset}"),
    };
}
