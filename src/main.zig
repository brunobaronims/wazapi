const std = @import("std");
const audio = @import("root.zig");

pub fn main() !void {
    _ = audio.Player.init();
}
