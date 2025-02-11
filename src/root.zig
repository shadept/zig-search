const std = @import("std");
const Allocator = std.mem.Allocator;

pub usingnamespace @import("minimax.zig");
pub usingnamespace @import("alphabeta.zig");
pub usingnamespace @import("negamax.zig");

const Search = @This();
const SearchResult = @import("common.zig").SearchResult;

pub fn Algorithm(comptime S: type, comptime M: type) type {
    return union(enum) {
        const Self = @This();

        minimax: Search.Minimax(S, M),
        alphaBeta: Search.AlphaBeta(S, M),
        negamax: Search.Negamax(S, M),

        pub fn search(self: Self, state: S) Allocator.Error!?SearchResult(M) {
            switch (self) {
                inline else => |impl| return @TypeOf(impl).search(@constCast(&impl), state),
            }
        }
    };
}

test {
    std.testing.refAllDeclsRecursive(Search);
}
