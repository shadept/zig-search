const std = @import("std");
const Allocator = std.mem.Allocator;

pub usingnamespace @import("minimax.zig");
pub usingnamespace @import("alphabeta.zig");
pub usingnamespace @import("negamax.zig");

const TopLevel = @This();

pub fn Search(comptime S: type, comptime M: type) type {
    return union(enum) {
        minimax: TopLevel.Minimax(S, M),
        alphaBeta: TopLevel.AlphaBeta(S, M),
        negamax: TopLevel.Negamax(S, M),

        pub const SearchResult = @import("interface.zig").SearchResult(M);

        pub fn search(self: Search, state: S) Allocator.Error!?SearchResult {
            switch (self) {
                inline else => |impl| return impl.search(state),
            }
        }
    };
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
