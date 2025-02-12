const std = @import("std");
const Allocator = std.mem.Allocator;

pub usingnamespace @import("common.zig");
pub usingnamespace @import("minimax.zig");
pub usingnamespace @import("alphabeta.zig");
pub usingnamespace @import("negamax.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
