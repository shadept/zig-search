const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const C = @import("common.zig");
const Score = C.Score;

pub fn Minimax(comptime S: type, comptime M: type) type {
    return MinimaxInternal(S, M, S, false);
}

fn MinimaxInternal(
    comptime S: type,
    comptime M: type,
    comptime Context: type,
    comptime use_tracing: bool,
) type {
    return struct {
        const Self = @This();

        max_depth: usize,
        allocator: Allocator,

        const MinScore = std.math.minInt(Score) + 1;
        const MaxScore = std.math.maxInt(Score);
        const Strategy = C.Strategy(S, M);

        const Diagnostics = struct {
            nodes: usize = 0,
        };

        pub fn init(allocator: Allocator, max_depth: usize) Self {
            return Self{
                .max_depth = max_depth,
                .allocator = allocator,
            };
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
            const moves = try Context.generateMoves(state, self.allocator);
            defer self.allocator.free(moves);

            if (moves.len == 0) {
                return null;
            }

            var best_move: ?M = null;
            var best_score: Score = MinScore;
            for (moves) |move| {
                self.trace(0, "considering move: {}\n", .{move});
                const next_state = Context.applyMove(state, move);
                const score = try self.searchInternal(next_state, self.max_depth - 1, false);
                if (score > best_score) {
                    best_score = score;
                    best_move = move;
                    self.trace(0, "new best move: {} | score: {}\n", .{ best_move, best_score });
                }
            }
            return best_move;
        }

        fn searchInternal(self: Self, state: S, depth: usize, is_maximizing: bool) Allocator.Error!Score {
            self.trace(depth, "searchInternal: depth: {} is_maximizing: {}\n", .{ depth, is_maximizing });
            const moves = try Context.generateMoves(state, self.allocator);
            defer self.allocator.free(moves);

            if (depth == 0 or moves.len == 0) {
                const sign: Score = if (is_maximizing) 1 else -1;
                return sign * Context.evaluate(state);
            }

            const ctx = C.StateSortContext(S, M, Context).init(state, self.allocator);
            const next_states = try ctx.applyAndSort(moves);
            defer self.allocator.free(next_states);

            var best: Score = if (is_maximizing) MinScore else MaxScore;
            for (next_states) |next| {
                self.trace(depth, "considering move: {}\n", .{next.move});
                const branch_score = try self.searchInternal(next.state, depth - 1, !is_maximizing);
                best = if (is_maximizing) @max(best, branch_score) else @min(best, branch_score);
                self.trace(depth, "current best: {}\n", .{best});
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

// test "search tic-tac-toe" {
//     const TicTacToe = @import("examples/tictactoe.zig");
//     const minimax = Minimax(TicTacToe, u8).init(std.testing.allocator, 10);
//     const state = TicTacToe.init();
//     const result = try minimax.search(state);
//     try testing.expectEqual(0, result.?.score);
// }

// test "obvious win" {
//     const TicTacToe = @import("examples/tictactoe.zig");
//     const minimax = Minimax(TicTacToe, u8).init(std.testing.allocator, 10);
//     const state = TicTacToe{ .board = [_]i8{ 1, 1, -1, 0, -1, -1, 1, 0, 0 }, .player = 1 };
//     const result = try minimax.search(state);
//     try testing.expectEqual(3, result.?.move);
// }
