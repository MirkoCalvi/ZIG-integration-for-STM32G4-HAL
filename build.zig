const std = @import("std");
const Board = @import("src/boards/boardType.zig");
const Board_list = @import("src/boards/boardType.zig").Board_list;

// "cortex_m4": [
//     "loop_align",
//     "no_branch_predictor",
//     "slowfpvfmx",
//     "slowfpvmlx",
//     "use_misched",
//     "v7em"
//    ],

pub fn build(b: *std.Build) !void {
    // Set target options, such as architecture and OS.

    const target = b.resolveTargetQuery(
        .{
            .cpu_arch = .thumb,
            .os_tag = .freestanding,
            .abi = .eabi,
            .cpu_model = std.Target.Query.CpuModel{ .explicit = &std.Target.arm.cpu.cortex_m4 },
            // Note that "fp_armv8d16sp" is the same instruction set as "fpv5-sp-d16", so LLVM only has the former
            // https://github.com/llvm/llvm-project/issues/95053
            .cpu_features_add = std.Target.arm.featureSet(
                &[_]std.Target.arm.Feature{
                    std.Target.arm.Feature.fp_armv8d16sp,
                    std.Target.arm.Feature.loop_align,
                    std.Target.arm.Feature.no_branch_predictor,
                    std.Target.arm.Feature.slowfpvfmx,
                    std.Target.arm.Feature.slowfpvmlx,
                    std.Target.arm.Feature.use_misched,
                    std.Target.arm.Feature.v7em,
                },
            ),
        },
    );
    const optimize = b.standardOptimizeOption(.{});

    //************************************************MAIN EXECUTABLE************************************************
    const executable_name = "dumboard";
    // Define the main executable with target architecture and optimization settings.
    var exe = b.addExecutable(.{
        .name = executable_name ++ ".elf",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("./src/main.zig"),
        .link_libc = false,
        .linkage = .static,
        .single_threaded = true,
    });

    // Try to find arm-none-eabi-gcc program at a user specified path, or PATH variable if none provided
    const arm_gcc_pgm = if (b.option([]const u8, "armgcc", "Path to arm-none-eabi-gcc compiler")) |arm_gcc_path|
        b.findProgram(&.{"arm-none-eabi-gcc"}, &.{arm_gcc_path}) catch {
            std.log.err("Couldn't find arm-none-eabi-gcc at provided path: {s}\n", .{arm_gcc_path});
            unreachable;
        }
    else
        b.findProgram(&.{"arm-none-eabi-gcc"}, &.{}) catch {
            std.log.err("Couldn't find arm-none-eabi-gcc in PATH, try manually providing the path to this executable with -Darmgcc=[path]\n", .{});
            unreachable;
        };
    std.debug.print("\nBUILD MSG -> your arm-none-eabi-gcc should be located at {s}", .{arm_gcc_pgm});

    //  Use gcc-arm-none-eabi to figure out where library paths are

    const path_hard = "/lib/arm-none-eabi/newlib/thumb/v7e-m/nofp"; //contains a lot of useful libraries .a like: "m, sys, g_nano, c++ ..."
    const path_gcc_hard = "/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m/nofp"; //contains "crtbegin.o  crtend.o  crtfastmath.o  crti.o  crtn.o "
    const path_include_header = "/lib/arm-none-eabi/include"; //contains all necessary headers for arm-none-eabi

    exe.addLibraryPath(.{ .cwd_relative = path_hard });
    exe.addLibraryPath(.{ .cwd_relative = path_gcc_hard });

    exe.addSystemIncludePath(.{ .cwd_relative = path_include_header });

    exe.linkSystemLibrary("c_nano");
    exe.linkSystemLibrary("m");

    exe.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crt0.o", .{path_hard}) });
    exe.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crti.o", .{path_gcc_hard}) });
    exe.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crtbegin.o", .{path_gcc_hard}) });
    exe.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crtend.o", .{path_gcc_hard}) });
    exe.addObjectFile(.{ .cwd_relative = b.fmt("{s}/crtn.o", .{path_gcc_hard}) });

    // Normal Include Paths
    exe.addIncludePath(b.path("Core/Inc")); //to change
    exe.addIncludePath(b.path("src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver/Inc"));
    exe.addIncludePath(b.path("src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver/Inc/Legacy"));
    exe.addIncludePath(b.path("src/boards/STM32CubeG4/Drivers/CMSIS/Device/ST/STM32G4xx/Include"));
    exe.addIncludePath(b.path("src/boards/STM32CubeG4/Drivers/CMSIS/Include"));

    // Startup file, it will depend on the target
    exe.addAssemblyFile(b.path("src/boards/STM32CubeG4/Drivers/CMSIS/Device/ST/STM32G4xx/Source/Templates/arm/startup_stm32g431xx.s"));

    //************************************************BOARD BUILD DEPENDENCIES************************************************
    //--- STM32CubeG4 - Drivers - STM32G4xx_HAL_Driver
    try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/STM32G4xx_HAL_Driver/Src");

    //--- STM32CubeG4 - Drivers - CMSIS - ST - STM32G4xx - Source - Templates
    try addSourcesFromDir(b, exe, "src/boards/STM32CubeG4/Drivers/CMSIS/Device/ST/STM32G4xx/Source/Templates");

    exe.link_gc_sections = true;
    exe.link_data_sections = true;
    exe.link_function_sections = true;
    exe.setLinkerScriptPath(b.path("src/Core/STM32G431xx_FLASH.ld"));

    std.debug.print("\n   -------------------------------------------------------------------------------------------------------------", .{});
    std.debug.print("\n   -------------------------------------------------------------------------------------------------------------", .{});
    std.debug.print("\n   -------------------------------------------------------------------------------------------------------------", .{});

    //************************************************INSTALLING AND RUNNING************************************************
    // Install the executable.
    std.debug.print("\nBUILD: install artifact ", .{});
    b.installArtifact(exe);

    // Produce .bin file from .elf
    const bin = b.addObjCopy(exe.getEmittedBin(), .{
        .format = .bin,
    });
    bin.step.dependOn(&exe.step);
    const copy_bin = b.addInstallBinFile(bin.getOutput(), executable_name ++ ".bin");
    b.default_step.dependOn(&copy_bin.step);

    // Produce .hex file from .elf
    const hex = b.addObjCopy(exe.getEmittedBin(), .{
        .format = .hex,
    });
    hex.step.dependOn(&exe.step);
    const copy_hex = b.addInstallBinFile(hex.getOutput(), executable_name ++ ".hex");
    b.default_step.dependOn(&copy_hex.step);

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
                        "-Og",
                        "-std=gnu17",
                        "-DUSE_HAL_DRIVER",
                        "-DSTM32G431xx",
                    },
                });
                std.debug.print("\n     Added .c file: {s}", .{full_path});
            }
            //  else if (std.mem.eql(u8, std.fs.path.extension(entry.name), ".s")) {
            //     exe.addAssemblyFile(b.path(full_path));
            //     std.debug.print("\n     Added .s file: {s}", .{full_path});
            // }
        }
    }
}
