const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Strategy(comptime S: type, comptime M: type) type {
    return struct {
        const Self = @This();

        ptr: *anyopaque,
        vtable: *const VTable,

        pub const VTable = struct {
            chooseMove: *const fn (ctx: *anyopaque, state: S) Allocator.Error!?M,
            setTimeout: *const fn (ctx: *anyopaque, timeout: usize) void,
            setMaxDepth: *const fn (ctx: *anyopaque, depth: usize) void,
        };

        pub fn chooseMove(self: *Self, state: S) Allocator.Error!?M {
            return self.vtable.chooseMove(self.ptr, state);
        }

        pub fn setTimeout(self: *Self, timeout: usize) void {
            self.vtable.setTimeout(self, timeout);
        }

        pub fn setMaxDepth(self: *Self, depth: usize) void {
            self.vtable.setMaxDepth(self, depth);
        }

        /// Not for public use. Intended for construction of strategies that do not support timeouts.
        pub fn noTimeout(_: *anyopaque, _: usize) void {}

        /// Not for public use. Intended for construction of strategies that do not support max depth.
        pub fn noMaxDepth(_: *anyopaque, _: usize) void {}
    };
}

pub const Score = i64;

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
