const std = @import("std");

pub const Board_list = enum {
    stm32g4xx,
    none,
    surfBoard,
};

pub fn fromString(value: []const u8) Board_list {
    if (std.mem.eql(u8, value, "stm32g4xx")) {
        return Board_list.stm32g4xx;
    } else if (std.mem.eql(u8, value, "surfBoard")) {
        return Board_list.surfBoard;
    } else {
        return Board_list.none;
    }
}
