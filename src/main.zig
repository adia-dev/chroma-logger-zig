const std = @import("std");
const Logger = @import("lib.zig");
const chroma = @import("chroma");

const User = struct {
    name: []const u8,
    level: u8 = 0,

    pub fn format(self: User, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try std.fmt.format(writer, "User {{ name: {s}, level: {d} }}", .{ self.name, self.level });
    }

    pub fn levelUp(self: *User) void {
        self.level = @addWithOverflow(self.level, 1)[0];
    }
};

pub const std_options: std.Options = .{ .log_level = .debug, .logFn = Logger.log };

pub fn main() !void {
    // Debug log - typically used for detailed information useful for debugging
    std.log.debug("Debugging the application start process", .{});

    // Info log - generally useful information to log (service start-up, configuration assumptions, etc.)
    std.log.info("Application {green}successfully{reset} started", .{});

    // Warn log - something unexpected happened, but the application is still running as expected
    std.log.warn("The configuration file 'config.json' was not found, using defaults", .{});

    // Error log - a serious problem that indicates the application might not be able to continue running
    std.log.err("Failed to connect to the database, terminating application", .{});

    var alice = User{ .name = "Alice", .level = 1 };
    var bob = User{ .name = "Bob", .level = 2 };
    const users = [_]*User{ &alice, &bob };

    std.log.info("{}", .{alice});

    std.log.info("{}", .{bob});

    const one_second_in_nano = 1_000_000_000;

    while (bob.level < 10) {
        for (users) |user| {
            user.levelUp();
            std.log.debug("UP +1: {}", .{user});
        }
        std.time.sleep(one_second_in_nano); // Sleep for 1 second

        if (bob.level == 9) {
            std.log.warn("{221}{s} is about to reach level 10 soon !", .{bob.name});
        } else if (bob.level == 10) {
            std.log.info("{cyan}{s} reached level 10 !", .{bob.name});
        }
    }
}
