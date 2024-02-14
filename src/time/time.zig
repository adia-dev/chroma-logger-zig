const std = @import("std");
const math = std.math;

pub const Time = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,

    /// Converts a Unix timestamp to a Time struct.
    pub fn from_unix_timestamp(timestamp: i64) Time {
        const days = @divFloor(timestamp, 86400);
        const secondsInDay = @mod(timestamp, 86400);
        const yearInfo = get_year(days);
        const monthDayInfo = get_month_and_day(yearInfo.daysIntoYear, yearInfo.year);

        return Time{
            .year = yearInfo.year,
            .month = monthDayInfo.month,
            .day = monthDayInfo.day,
            .hour = @intCast(@divFloor(secondsInDay, 3600)),
            .minute = @intCast(@divFloor(@mod(secondsInDay, 3600), 60)),
            .second = @intCast(@mod(secondsInDay, 60)),
        };
    }
};

fn get_year(days: i64) struct { year: u16, daysIntoYear: i64 } {
    var year: u16 = 1970;
    var daysLeft: i64 = days;

    while (true) {
        const daysInYear: i64 = if (is_leap_year(year)) 366 else 365;
        if (daysLeft < daysInYear) break;
        daysLeft -= daysInYear;
        year += 1;
    }

    return .{ .year = year, .daysIntoYear = daysLeft };
}

fn get_month_and_day(daysIntoYear: i64, year: u16) struct { month: u8, day: u8 } {
    const daysInMonth = [_]u8{ 31, 28 + bool_to_int(is_leap_year(year)), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var month: u8 = 1;
    var daysLeft: i64 = daysIntoYear;

    while (true) {
        const daysThisMonth = daysInMonth[month - 1];
        if (daysLeft < daysThisMonth) break;
        daysLeft -= daysThisMonth;
        month += 1;
    }

    return .{ .month = month, .day = @intCast(daysLeft + 1) };
}

fn is_leap_year(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0;
}

fn bool_to_int(b: bool) u8 {
    return if (b) 1 else 0;
}
