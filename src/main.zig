const std = @import("std");

pub fn main() void {}

// const c = @cImport({
//     @cDefine("USE_HAL_DRIVER", {});
//     @cDefine("STM32G431xx", {});
//     @cDefine("__PROGRAM_START", {}); //bug: https://github.com/ziglang/zig/issues/19687
//     @cInclude("stm32g431xx.h");
// });

// export fn zig_entrypoint() void {
//     while (true) {
//         c.HAL_GPIO_WritePin(c.LD2_GPIO_Port, c.LD2_Pin, c.GPIO_PIN_RESET);
//         c.HAL_Delay(200);
//         c.HAL_GPIO_WritePin(c.LD2_GPIO_Port, c.LD2_Pin, c.GPIO_PIN_SET);
//         c.HAL_Delay(500);
//     }

//     unreachable;
// }
