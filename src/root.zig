const std = @import("std");

pub usingnamespace @import("alphabeta.zig");
pub usingnamespace @import("minimax.zig");
pub usingnamespace @import("negamax.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
