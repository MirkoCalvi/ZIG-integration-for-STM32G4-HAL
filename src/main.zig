const std = @import("std");
const Board = @import("board");
const Board_options = @import("board_options"); //remember to import your options

// Import the C header file
const board_hal_lib = @cImport({
    @cInclude("stm32g4xx_hal.h");
    @cInclude("stdint.h");
});

pub fn main() !void {

    //HERE I SHOW HOW TO ACCESS AN "OPTION", see Menu_options in build.zig
    const my_board = Board.fromString(Board_options.board_choice);

    print_my_board(my_board);

    //calling init function
    board_hal_lib.HAL_Init();

    std.debug.print("\n \n", .{my_board});
}

pub inline fn print_my_board(my_board: Board.Board_list) void {
    std.debug.print("\n ----You chose {any} board!!!", .{my_board});
}
