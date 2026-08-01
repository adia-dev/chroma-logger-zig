const std = @import("std");
const chroma_logger = @import("chroma-logger");

const DemoLogger = chroma_logger.Logger(@import("logger.zon"));
const api_log = std.log.scoped(.api);
const worker_log = std.log.scoped(.worker);

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = DemoLogger.log,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    std.log.info("{#brand}CHROMA LOGGER 0.2 RC{#reset}  live demo", .{});
    try pause(io, 550);

    std.log.debug("Loaded typed configuration at {#value}comptime{#reset}", .{});
    try pause(io, 400);

    api_log.info("Listening on {#value}http://127.0.0.1:8080{#reset}", .{});
    try pause(io, 450);

    worker_log.debug("Discovered {#value}{d}{#reset} queued jobs", .{4});
    try pause(io, 400);

    worker_log.warn("Cache is cold; the first build may be slower", .{});
    try pause(io, 500);

    inline for (.{ 25, 50, 75, 100 }) |progress| {
        worker_log.info("Processing assets {#muted}··········{#reset} {#value}{d}%{#reset}", .{progress});
        try pause(io, 280);
    }

    api_log.err("Health check timed out after {#value}{d}ms{#reset}", .{750});
    try pause(io, 550);

    api_log.warn("Retrying with the fallback transport", .{});
    try pause(io, 500);

    api_log.info("{#success}✓ Service recovered{#reset} in {#value}{d}ms{#reset}", .{128});
    try pause(io, 500);

    std.log.info("{#success}✓ Demo complete{#reset} — ANSI and plain output were generated at comptime", .{});
}

fn pause(io: std.Io, milliseconds: i64) !void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}

test "demo logger configuration compiles" {
    try std.testing.expect(chroma_logger.resolveColor(.always, false));
}
