const std = @import("std");
const audio = @import("root.zig");

pub fn main() !void {
    var source: audio.Source = .{};

    _ = audio.Player.init(&source).?;
}
