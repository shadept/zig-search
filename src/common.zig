const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Score = i64;

/// The result of playing a game to it's conclusion.
pub const Winner = enum {
    /// The last player to move.
    ///
    /// This is the most common since the player wins by performing the move and thus moving the player varible to the
    /// next player. Only after that, the game state is evaluated.
    PreviousPlayer,
    /// No winner
    Draw,
    /// Uncommon case where you can lose by making a move. (e.i. busting on Blackjack)
    CurrentPlayer, // Rare case
};

pub fn Game(comptime S: type, comptime M: type) type {
    return struct {
        const Self = @This();

        state: S,
        vtable: *const VTable,

        pub const VTable = struct {
            getWinner: *const fn (ctx: S) ?Winner,
            getPlayer: *const fn (ctx: S) ?u8,
            generateMoves: *const fn (ctx: S, allocator: Allocator) Allocator.Error![]M,
            applyMove: *const fn (ctx: S, move: M) Self,
            evaluate: *const fn (ctx: S) Score,
            renderBoard: *const fn (ctx: S, stdout: std.fs.File) anyerror!void,
        };

        /// If game is on terminal state, returns the Winner of the game, or if it was a draw. The winner (if any) is
        /// usually the player that played before the current one.
        pub fn getWinner(self: Self) ?Winner {
            return self.vtable.getWinner(self.state);
        }

        /// Returns the current player. If null, means the game will take an automatic or probabilistic (like drawing a card) action.
        pub fn getPlayer(self: Self) ?u8 {
            return self.vtable.getPlayer(self.state);
        }

        pub fn generateMoves(self: Self, allocator: Allocator) Allocator.Error![]M {
            return self.vtable.generateMoves(self.state, allocator);
        }

        pub fn applyMove(self: Self, move: M) Self {
            return self.vtable.applyMove(self.state, move);
        }

        pub fn evaluate(self: Self) Score {
            return self.vtable.evaluate(self.state);
        }

        pub fn renderBoard(self: Self, stdout: std.fs.File) anyerror!void {
            return self.vtable.renderBoard(self.state, stdout);
        }
    };
}

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
