const std = @import("std");
const builtin = std.builtin;
const win32_handmade = @import("win32_handmade.zig");

const platform = switch (builtin.os.tag) {
    .windows => win32_handmade,
    else => struct {},
};

pub fn main() !void {
    try platform.main();
}
