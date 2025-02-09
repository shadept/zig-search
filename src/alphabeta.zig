const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn AlphaBeta(comptime S: type, comptime M: type) type {
    return AlphaBetaInternal(S, M, S, false);
}

fn AlphaBetaInternal(
    comptime S: type,
    comptime M: type,
    comptime Context: type,
    comptime use_tracing: bool,
) type {
    return struct {
        const Self = @This();

        max_depth: usize,
        ctx: Context,
        allocator: Allocator,

        const Score = i64;
        const MinScore = std.math.minInt(Score) + 1;
        const MaxScore = std.math.maxInt(Score);

        const Diagnostics = struct {
            nodes: usize = 0,
        };

        pub const SearchResult = @import("interface.zig").SearchResult(M);

        pub fn init(allocator: Allocator, max_depth: usize) Self {
            return Self{
                .max_depth = max_depth,
                .ctx = undefined,
                .allocator = allocator,
            };
        }

        pub fn search(self: Self, state: S) Allocator.Error!?SearchResult {
            const moves = try Context.generateMoves(state, self.allocator);
            defer self.allocator.free(moves);

            if (moves.len == 0) {
                return null;
            }

            var best_move: M = undefined;
            var best_score: Score = MinScore;
            for (moves) |move| {
                const next_state = Context.applyMove(state, move);
                const score = try self.searchInternal(next_state, self.max_depth, MinScore, MaxScore, false);
                if (score > best_score) {
                    best_score = score;
                    best_move = move;
                }
            }
            return .{ .move = best_move, .score = best_score };
        }

        fn searchInternal(self: Self, state: S, depth: usize, alpha: Score, beta: Score, is_maximizing: bool) Allocator.Error!Score {
            const moves = try Context.generateMoves(state, self.allocator);
            defer self.allocator.free(moves);

            if (depth == 0 or moves.len == 0) {
                const sign: Score = if (is_maximizing) 1 else -1;
                return sign * Context.evaluate(state);
            }

            // TODO sort moves

            var a = alpha;
            var b = beta;
            var value: Score = if (is_maximizing) MinScore else MaxScore;
            for (moves) |move| {
                self.trace(depth, "considering move: {}\n", .{move});
                const next_state = Context.applyMove(state, move);
                const branch_score = try self.searchInternal(next_state, depth - 1, a, b, !is_maximizing);
                if (is_maximizing) {
                    value = @max(value, branch_score);
                    a = @max(a, value);
                } else {
                    value = @min(value, branch_score);
                    b = @min(b, value);
                }
                if (b <= a) {
                    break;
                }
                self.trace(depth, "current best: {}\n", .{value});
            }
            return value;
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

// test "search tic-tac-toe" {
//     const TicTacToe = @import("examples/tictactoe.zig");
//     const minimax = AlphaBeta(TicTacToe, u8).init(std.testing.allocator, 10);
//     const state = TicTacToe.init();
//     const result = try minimax.search(state);
//     try testing.expectEqual(0, result.?.score);
// }

// test "obvious win" {
//     const TicTacToe = @import("examples/tictactoe.zig");
//     const alphabeta = AlphaBeta(TicTacToe, u8).init(std.testing.allocator, 10);
//     const state = TicTacToe{ .board = [_]i8{ 1, 1, -1, 0, -1, -1, 1, 0, 0 }, .player = 1 };
//     const result = try alphabeta.search(state);
//     try testing.expectEqual(3, result.?.move);
// }
