const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const C = @import("common.zig");
const Score = C.Score;

pub fn Negamax(comptime S: type, comptime M: type) type {
    return NegamaxInternal(S, M, S, true, false, false);
}

pub fn NegamaxWithTransposition(comptime S: type, comptime M: type) type {
    return NegamaxInternal(S, M, S, true, true, false);
}

/// Negamax algorithm with alpha-beta pruning and transposition table.
///
fn NegamaxInternal(
    comptime S: type,
    comptime M: type,
    /// A namespace that provides these functions:
    /// * `pub fn generateMoves(self, S, Allocator) Allocator.Error![]M`
    /// * `pub fn applyMove(self, S, M) S`
    /// * `pub fn evaluate(self, S) Score`
    comptime Context: type,
    comptime use_transposition: bool,
    comptime use_diagnostics: bool,
    comptime use_tracing: bool,
) type {
    return struct {
        const Self = @This();

        max_depth: usize,
        transposition_table: TranspositionTable,
        diagnostics: Diagnostics,
        allocator: std.mem.Allocator,

        const GenMovesFn = fn (S, Allocator) Allocator.Error![]M;
        const ApplyMoveFn = fn (S, M) S;
        const EvalFn = fn (S) Score;
        const MinScore = std.math.minInt(Score) + 1;
        const MaxScore = std.math.maxInt(Score);
        const Strategy = C.Strategy(S, M);

        const TranspositionEntry = struct {
            depth: usize,
            flag: enum(u2) {
                Exact,
                LowerBound,
                UpperBound,
            },
            score: Score,
        };

        const TranspositionTable = if (use_transposition) b: {
            break :b std.AutoArrayHashMap(S, TranspositionEntry);
        } else void;

        const Diagnostics = if (use_diagnostics) struct { nodes: usize = 0, transpositions: usize = 0 } else void;

        pub fn init(allocator: Allocator, max_depth: usize) Self {
            return Self{
                .max_depth = max_depth,
                .transposition_table = if (use_transposition) TranspositionTable.init(allocator) else {},
                .diagnostics = if (use_diagnostics) Diagnostics{} else {},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (use_transposition) {
                self.transposition_table.deinit();
            }
        }

        pub fn strategy(self: *Self) Strategy {
            const impl = struct {
                pub fn chooseMove(ctx: *anyopaque, state: S) Allocator.Error!?M {
                    const s: *Self = @ptrCast(@alignCast(ctx));
                    return s.search(state);
                }
            };
            return .{
                .ptr = self,
                .vtable = &.{
                    .chooseMove = impl.chooseMove,
                    .setTimeout = Strategy.noTimeout,
                    .setMaxDepth = Strategy.noMaxDepth,
                },
            };
        }

        pub fn search(self: *Self, state: S) Allocator.Error!?M {
            if (self.max_depth == 0) {
                return null;
            }

            const moves = try Context.generateMoves(state, self.allocator);
            defer self.allocator.free(moves);

            if (moves.len == 0) {
                return null;
            }

            var best_move: M = moves[0];
            var best_score: Score = MinScore;
            for (moves) |move| {
                self.trace(0, "\tconsidering move: {}", .{move});
                const next_state = Context.applyMove(state, move);
                const score = -(try self.searchInternal(next_state, self.max_depth, MinScore, -best_score));
                self.trace(0, " | score: {}\n", .{score});
                if (score > best_score) {
                    best_score = score;
                    best_move = move;
                    self.trace(0, "\tnew best move: {} | score: {}\n", .{ best_move, best_score });
                }
            }
            return best_move;
        }

        fn searchInternal(self: *Self, state: S, depth: usize, alphaImut: Score, betaImut: Score) Allocator.Error!Score {
            var alpha = alphaImut;
            var beta = betaImut;

            if (use_diagnostics) {
                self.diagnostics.nodes += 1;
            }

            if (comptime use_transposition) {
                if (self.transposition_table.get(state)) |entry| {
                    if (use_diagnostics) {
                        self.diagnostics.transpositions += 1;
                    }
                    if (entry.depth >= depth) {
                        switch (entry.flag) {
                            .Exact => return entry.score,
                            .LowerBound => alpha = @max(alpha, entry.score),
                            .UpperBound => beta = @min(beta, entry.score),
                        }
                        if (alpha >= beta) {
                            return entry.score;
                        }
                    }
                }
            }

            if (Context.getWinner(state)) |_| {
                return MaxScore;
            }

            if (depth == 0) {
                return Context.evaluate(state);
            }

            const moves = try Context.generateMoves(state, self.allocator);
            defer self.allocator.free(moves);

            const ctx = C.StateSortContext(S, M, Context).init(state, self.allocator);
            const next_states = try ctx.applyAndSort(moves);
            defer self.allocator.free(next_states);

            var best: Score = MinScore;
            for (next_states) |next| {
                self.trace(depth, "considering move: {}\n", .{next.move});
                const value = -(try self.searchInternal(next.state, depth - 1, -beta, -alpha));
                best = @max(best, value);
                alpha = @max(alpha, value);
                if (alpha >= beta) {
                    break;
                }
            }

            if (comptime use_transposition) {
                const entry = (try self.transposition_table.getOrPut(state)).value_ptr;
                entry.score = best;
                if (best <= alphaImut) {
                    entry.flag = .UpperBound;
                } else if (best >= beta) {
                    entry.flag = .LowerBound;
                } else {
                    entry.flag = .Exact;
                }
                entry.depth = depth;
            }

            return best;
        }

        fn trace(self: Self, depth: usize, comptime fmt: []const u8, args: anytype) void {
            if (use_tracing) {
                const indent = self.max_depth - depth;
                for (0..indent) |_| {
                    std.debug.print("  ", .{});
                }
                std.debug.print(fmt, args);
            }
        }
    };
}

test "Negamax is smaller than negamaxWithTransposition" {
    const S = u8;
    const M = u8;
    try testing.expect(@sizeOf(Negamax(S, M)) < @sizeOf(NegamaxWithTransposition(S, M)));
}

// test "search tic-tac-toe" {
//     const TicTacToe = @import("examples/tictactoe.zig");
//     var negamax = NegamaxWithTransposition(TicTacToe, u8).init(std.testing.allocator, 10);
//     defer negamax.deinit();
//     const state = TicTacToe.init();
//     const result = try negamax.search(state);
//     try testing.expectEqual(0, result.?.score);
// }

// test "obvious win" {
//     const TicTacToe = @import("examples/tictactoe.zig");
//     var negamax = Negamax(TicTacToe, u8).init(std.testing.allocator, 10);
//     defer negamax.deinit();
//     const state = TicTacToe{ .board = [_]i8{ 1, 1, -1, 0, -1, -1, 1, 0, 0 }, .player = 1 };
//     const result = try negamax.search(state);
//     try testing.expectEqual(3, result.?.move);
// }
