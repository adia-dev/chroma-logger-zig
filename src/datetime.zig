const std = @import("std");

pub const DateTime = struct {
    year: i64,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,

    /// Convert Unix seconds to a Gregorian UTC date and time.
    pub fn fromUnix(seconds: i64) DateTime {
        const days = @divFloor(seconds, std.time.s_per_day);
        const seconds_in_day = @mod(seconds, std.time.s_per_day);
        const date = civilFromDays(days);

        return .{
            .year = date.year,
            .month = date.month,
            .day = date.day,
            .hour = @intCast(@divFloor(seconds_in_day, std.time.s_per_hour)),
            .minute = @intCast(@divFloor(@mod(seconds_in_day, std.time.s_per_hour), std.time.s_per_min)),
            .second = @intCast(@mod(seconds_in_day, std.time.s_per_min)),
        };
    }
};

const Date = struct {
    year: i64,
    month: u8,
    day: u8,
};

// Gregorian calendar conversion adapted from Howard Hinnant's civil calendar
// algorithm. Floor division keeps dates before the Unix epoch correct.
fn civilFromDays(days_since_epoch: i64) Date {
    const shifted = days_since_epoch + 719_468;
    const era = @divFloor(shifted, 146_097);
    const day_of_era = shifted - era * 146_097;
    const year_of_era = @divFloor(
        day_of_era - @divFloor(day_of_era, 1_460) + @divFloor(day_of_era, 36_524) - @divFloor(day_of_era, 146_096),
        365,
    );
    var year = year_of_era + era * 400;
    const day_of_year = day_of_era - (365 * year_of_era + @divFloor(year_of_era, 4) - @divFloor(year_of_era, 100));
    const month_prime = @divFloor(5 * day_of_year + 2, 153);
    const day = day_of_year - @divFloor(153 * month_prime + 2, 5) + 1;
    const month = month_prime + (if (month_prime < 10) @as(i64, 3) else -9);
    year += if (month <= 2) 1 else 0;

    return .{
        .year = year,
        .month = @intCast(month),
        .day = @intCast(day),
    };
}

test "DateTime converts the Unix epoch" {
    try std.testing.expectEqual(DateTime{
        .year = 1970,
        .month = 1,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
    }, DateTime.fromUnix(0));
}

test "DateTime converts leap days and time of day" {
    try std.testing.expectEqual(DateTime{
        .year = 2024,
        .month = 2,
        .day = 29,
        .hour = 12,
        .minute = 34,
        .second = 56,
    }, DateTime.fromUnix(1_709_210_096));
}

test "DateTime supports dates before the Unix epoch" {
    try std.testing.expectEqual(DateTime{
        .year = 1969,
        .month = 12,
        .day = 31,
        .hour = 23,
        .minute = 59,
        .second = 59,
    }, DateTime.fromUnix(-1));
}

test "DateTime preserves the full Unix timestamp year range" {
    try std.testing.expect(DateTime.fromUnix(std.math.maxInt(i64)).year > 292_000_000_000);
    try std.testing.expect(DateTime.fromUnix(std.math.minInt(i64)).year < -292_000_000_000);
}
