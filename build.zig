const std = @import("std");
const Board = @import("src/boards/boardType.zig");
const Board_list = @import("src/boards/boardType.zig").Board_list;

pub fn build(b: *std.Build) !void {
    // Set target options, such as architecture and OS.
    const target = b.standardTargetOptions(.{});
    // const target = std.Target{
    //     .cpu = .{ .arch = .arm },
    //     .os = .none,
    //     .ofmt = .elf,
    //     .dynamic_linker = std.Target.DynamicLinker.init("/lib64/ld-linux-x86-64.so.2"),
    // };
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
    exe.addIncludePath(b.path("src/boards/STM32CubeG4/Drivers/CMSIS/Core/Include"));
    //exe.addLinkerArgs(&[_][]const u8{"-T/path/to/STM32CubeG4/linker_script.ld"});

    //************************************************MODULE CREATION************************************************
    //const board_mod = b.createModule(.{ .root_source_file = b.path("src/boards/boardType.zig") });

    //************************************************ENABLE OPTIONS************************************************
    //declaring option voices
    const board_choice_str = b.option([]const u8, "board", "wich board you chose") orelse "CPU"; //So -Dmenu ... is how you select your choice
    //enable option usage
    const board_options = b.addOptions();
    //add the specific option for board choice, it can be called by importing "board_options"
    board_options.addOption([]const u8, "board_choice", board_choice_str); // -> we are forced to pass a []const u8, enums give problems, see here for possible solution: https://ziggit.dev/t/unable-to-add-build-option-with-a-slice-of-enums/3867/2

    std.debug.print("\nBUILD: board_choice_enum: {s} ", .{board_choice_str});

    //************************************************BOARD BUILD DEPENDENCIES************************************************
    //convert menu_choice_str into an enum for readability
    //const board_choice_enum = Board.fromString(board_choice_str);

    //--- STM32CubeG4
    //--- STM32CubeG4 - drivers
    //--- STM32CubeG4 - drivers - BSP
    try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/BSP");

    //--- STM32CubeG4 - drivers - CMSIS
    try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/CMSIS");

    //--- STM32CubeG4 - drivers - STM32G4xx_HAL_Driver
    try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver");

    //try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver/Src");
    //try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver/Src");
    //try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/CMSIS/Device/ST/STM32G4xx/Source/Templates/arm");
    std.debug.print("\n   -------------------------------------------------------------------------------------------------------------", .{});
    std.debug.print("\n   -------------------------------------------------------------------------------------------------------------", .{});
    std.debug.print("\n   -------------------------------------------------------------------------------------------------------------", .{});

    //try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4");

    // switch (board_choice_enum) {
    //     Board_list.stm32g4xx => {
    //         //add_all_stm32g4xx_source_files(b, exe);
    //         // try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/CMSIS/Device/ST/STM32G4xx/Source/Templates/arm");
    //         // try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver/Src");
    //         // try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/CMSIS/Core/Include");
    //         try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4");
    //     },
    //     else => {
    //         //no import is needed
    //     },
    // }
    //************************************************EXE DEPENDENCIES and OPTIONS************************************************
    //exe.root_module.addImport("board", board_mod);

    //adding the options to the exe (aka main.zig)
    //exe.root_module.addOptions("board_options", board_options);

    //************************************************INSTALLING AND RUNNING************************************************
    // Install the executable.
    std.debug.print("\nBUILD: install artifact ", .{});
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

fn addSourcesFromDir(b: *std.Build, exe: *std.Build.Step.Compile, dir_path: []const u8) !void {
    std.debug.print("\nBUILD: addSourcesFromDir() {s}: ", .{dir_path});

    const fs = std.fs;
    const allocator = b.allocator;

    // Attempt to open the directory
    var dir = try fs.cwd().openDir(dir_path, .{ .iterate = true, .no_follow = true });
    defer dir.close();
    std.debug.print("\n     Directory: {any}", .{dir});

    // Create an iterator for directory entries
    var it = dir.iterate();
    //std.debug.print("\n     Iterator: {any}", .{it});

    while (true) {
        const next = it.next() catch |err| {
            if (err == error.EndOfStream) {
                break;
            } else return err;
        };
        if (next == null) return;
        const entry = next.?; // Unwrap the result if no error
        const full_path = try fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
        defer allocator.free(full_path);

        if (entry.kind == .file) {
            if (std.mem.eql(u8, std.fs.path.extension(entry.name), ".c")) {
                exe.addCSourceFile(.{
                    .file = b.path(full_path),
                    .flags = &.{
                        "-DLLVM_ENABLE_PROJECTS=clang",                  "-DCMAKE_CROSSCOMPILING=True ", "-DCMAKE_INSTALL_PREFIX=/opt/llvmv6m",
                        "-DLLVM_DEFAULT_TARGET_TRIPLE=armv6m-none-eabi", " -DLLVM_TARGET_ARCH=ARM",      " -DLLVM_TARGETS_TO_BUILD=ARM",
                    },
                });
                std.debug.print("\n     Added .c file: {s}", .{full_path});
            } else if (std.mem.eql(u8, std.fs.path.extension(entry.name), ".s")) {
                exe.addAssemblyFile(b.path(full_path));
                std.debug.print("\n     Added .s file: {s}", .{full_path});
            }
        } else if (entry.kind == .directory) {
            // Catch and log errors for subdirectory processing
            addSourcesFromDir(b, exe, full_path) catch |err| {
                std.debug.print("\n     Failed to process subdirectory {s}: {any}", .{ full_path, err });
            };
        }
    }
}
