const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Score = i64;

pub fn SearchResult(comptime M: type) type {
    return struct {
        move: M,
        score: Score,
    };
}

pub fn StateSortContext(comptime S: type, comptime M: type, comptime Context: type) type {
    return struct {
        pub const StateWithEval = struct { state: S, move: M, score: Score };
        const Self = @This();

        state: S,
        allocator: Allocator,

        pub fn init(state: S, allocator: Allocator) Self {
            return .{ .state = state, .allocator = allocator };
        }

        /// Applies moves to self.state and returns an owned slice to the new states, sorted by their evaluation.
        pub fn applyAndSort(self: Self, moves: []M) Allocator.Error![]StateWithEval {
            const next = try self.allocator.alloc(StateWithEval, moves.len);
            for (next, moves) |*n, m| {
                n.*.state = Context.applyMove(self.state, m);
                n.*.move = m;
                n.*.score = Context.evaluate(n.*.state);
            }

            std.mem.sort(StateWithEval, next, self, lessThan);
            return next;
        }

        fn lessThan(_: @This(), lhs: StateWithEval, rhs: StateWithEval) bool {
            return lhs.score < rhs.score;
        }
    };
}
