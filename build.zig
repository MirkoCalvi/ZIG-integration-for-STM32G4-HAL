const std = @import("std");
const Board = @import("src/boards/boardType.zig");
const Board_list = @import("src/boards/boardType.zig").Board_list;

pub fn build(b: *std.Build) !void {
    // Set target options, such as architecture and OS.
    const target = b.standardTargetOptions(.{});
    // Set optimization level (debug, release, etc.).
    const optimize = b.standardOptimizeOption(.{});

    //************************************************MAIN EXECUTABLE************************************************

    // Define the main executable with target architecture and optimization settings.
    var exe = b.addExecutable(.{
        .name = "Main",
        .root_source_file = b.path("./src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.linkSystemLibrary("c");
    exe.addIncludePath(b.path("src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver/Inc")); // HAL drivers relative path
    exe.addIncludePath(b.path("src/boards/STM32CubeG4/Drivers/CMSIS/Device/ST/STM32G4xx/Include")); //CMSIS relative path
    exe.addIncludePath(b.path("src/boards/STM32CubeG4/Drivers/CMSIS/Include")); //CMSIS arm/cm/sc relative path

    //exe.addDefine("STM32G441xx", "1"); // DEFINE HERE THE STM that you are using!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    //************************************************MODULE CREATION************************************************
    const board_mod = b.createModule(.{ .root_source_file = b.path("src/boards/boardType.zig") });

    //************************************************ENABLE OPTIONS************************************************
    //declaring option voices
    const board_choice_str = b.option([]const u8, "board", "wich board you chose") orelse "CPU"; //So -Dmenu ... is how you select your choice
    //enable option usage
    const board_options = b.addOptions();
    //add the specific option for board choice, it can be called by importing "board_options"
    board_options.addOption([]const u8, "board_choice", board_choice_str); // -> we are forced to pass a []const u8, enums give problems, see here for possible solution: https://ziggit.dev/t/unable-to-add-build-option-with-a-slice-of-enums/3867/2

    //std.debug.print("\n BUILD: board_choice_enum:{any} ", .{board_choice_str});

    //************************************************BOARD BUILD DEPENDENCIES************************************************
    //convert menu_choice_str into an enum for readability
    const board_choice_enum = Board.fromString(board_choice_str);

    switch (board_choice_enum) {
        Board_list.stm32g4xx => {
            //add_all_stm32g4xx_source_files(b, exe);
            try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/CMSIS/Device/ST/STM32G4xx/Source/Templates/arm");
            try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver/Src");
        },
        else => {
            //no import is needed
        },
    }
    //************************************************EXE DEPENDENCIES and OPTIONS************************************************
    exe.root_module.addImport("board", board_mod);

    //adding the options to the exe (aka main.zig)
    exe.root_module.addOptions("board_options", board_options);

    //************************************************INSTALLING AND RUNNING************************************************
    // Install the executable.
    b.installArtifact(exe);

    // Define the run command for the main executable.
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create a build step to run the application.
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}

// fn add_all_stm32g4xx_source_files(b: *std.Build, exe: *std.Build.Step.Compile) void {

//     //now just importing a few _hall for the example, must be imported all of them
//     exe.addCSourceFile(.{ .file = b.path(".src/boards/stm32g4xx-hal-driver/Src/stm32g4xx_hal.c"), .flags = &.{"-std=c99"} });
//     //..
//     exe.addCSourceFile(.{ .file = b.path(".src/boards/stm32g4xx-hal-driver/Src/stm32g4xx_hal_pwr.c"), .flags = &.{"-std=c99"} });
//     exe.addCSourceFile(.{ .file = b.path(".src/boards/stm32g4xx-hal-driver/Src/stm32g4xx_hal_comp.c"), .flags = &.{"-std=c99"} });
// }

fn addSourcesFromDir(b: *std.Build, exe: *std.Build.Step.Compile, dir_path: []const u8) !void {
    const fs = std.fs;
    const allocator = b.allocator;

    // Open the directory
    var dir = try fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    // Create an iterator to go through directory entries
    var it = dir.iterate();
    while (try it.next()) |entry| {
        const full_path = try fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
        defer allocator.free(full_path);

        if (entry.kind == .file) {
            if (std.mem.eql(u8, std.fs.path.extension(entry.name), ".c")) {
                exe.addCSourceFile(.{
                    .file = b.path(full_path),
                    .flags = &.{"-std=c99"},
                });
                std.debug.print("\n importing .c : {s}", .{full_path});
            } else if (std.mem.eql(u8, std.fs.path.extension(entry.name), ".s")) {
                exe.addAssemblyFile(b.path(full_path)); // Add assembly file
                std.debug.print("\n importing .s : {s}", .{full_path});
            }
        } else if (entry.kind == .directory) {
            // Recursively call this function for subdirectories
            try addSourcesFromDir(b, exe, full_path);
        }
    }
}
