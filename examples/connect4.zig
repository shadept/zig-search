const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Self = @This();
const Move = u8;

/// Bitboard for each player, organized as follows:
/// 35 36 37 38 39 40 41
/// 28 29 30 31 32 33 34
/// 21 22 23 24 25 26 27
/// 14 15 16 17 18 19 20
///  7  8  9 10 11 12 13
///  0  1  2  3  4  5  6
board: [2]u42,
player: u8,

/// A bitmask for the top row of the board.
const TOP_ROW: u42 = 0b1111111_0000000_0000000_0000000_0000000_0000000;
const TOP_ROW_SHIFT: u6 = 35;

pub fn init() Self {
    return .{ .board = [_]u42{ 0, 0 }, .player = 0 };
}

pub fn generateMoves(self: Self, allocator: Allocator) Allocator.Error![]Move {
    const board = self.board[0] | self.board[1];
    const top_row = (board & TOP_ROW) >> TOP_ROW_SHIFT;

    if (top_row == 0b1111111) {
        return allocator.alloc(Move, 0);
    }

    var moves = try std.ArrayList(Move).initCapacity(allocator, 7 - @popCount(top_row));
    defer moves.deinit();

    for (0..7) |i| {
        const c: u6 = @intCast(i);
        if ((top_row >> c) & 1 == 0) {
            moves.appendAssumeCapacity(@intCast(c));
        }
    }

    return moves.toOwnedSlice();
}

/// Apply the given move, assuming it is valid.
pub fn applyMove(self: Self, move: Move) Self {
    var next_state = self;
    const board = &next_state.board[next_state.player];
    var row_mask: u42 = 0b1111111;
    var row_shift: u6 = 0;
    for (0..6) |_| {
        const row = (board.* & row_mask) >> row_shift;
        if (row & (@as(u42, 1) << @intCast(move)) == 0) {
            board.* |= @as(u42, 1) << @intCast(row_shift + move);
            break;
        }

        row_mask = row_mask << 7;
        row_shift += 7;
    }
    next_state.player = if (next_state.player == 0) 1 else 0;
    return next_state;
}

pub fn isGameOver(self: Self) bool {
    const board = self.board[0] | self.board[1];
    const top_row = (board & TOP_ROW) >> TOP_ROW_SHIFT;
    if (top_row == 0b1111111) return true;
    return fourInARow(self.board[0]) or fourInARow(self.board[1]);
}

fn fourInARow(board: u42) bool {
    // Vertical and diagonals checks
    const directions = [_]comptime_int{ 7, 6, 8 };
    inline for (directions) |dir| {
        const bb = board & (board >> dir);
        if (bb & (bb >> (2 * dir)) != 0) return true;
    }

    // Horizontal check with row mask
    const row_mask: u42 = 0b1111111;
    inline for (0..6) |row| {
        const row_board = (board >> (row * 7)) & row_mask;
        const bb = row_board & (row_board >> 1);
        if ((bb & (bb >> 2)) != 0) return true;
    }

    return false;
}

const FOUR_IN_A_ROW_COUNTS = [42]u8{
    3, 4, 5,  7,  5,  4, 3,
    4, 6, 8,  10, 8,  6, 4,
    5, 8, 11, 13, 11, 8, 5,
    5, 8, 11, 13, 11, 8, 5,
    4, 6, 8,  10, 8,  6, 4,
    3, 4, 5,  7,  5,  4, 3,
};

pub fn evaluate(self: Self) i64 {
    const current_player_board = self.board[self.player];
    const opponent_board = self.board[if (self.player == 0) 1 else 0];

    if (fourInARow(current_player_board)) {
        return 1000;
    } else if (fourInARow(opponent_board)) {
        return -1000;
    }

    const BitSet = std.bit_set.IntegerBitSet(42);
    var score: i64 = 0;

    var current_player_iter = (BitSet{ .mask = current_player_board }).iterator(.{});
    while (current_player_iter.next()) |i| {
        score += @intCast(FOUR_IN_A_ROW_COUNTS[i]);
    }

    var opponent_iter = (BitSet{ .mask = opponent_board }).iterator(.{});
    while (opponent_iter.next()) |i| {
        score -= @intCast(FOUR_IN_A_ROW_COUNTS[i]);
    }

    return score;
}

test "initial position" {
    const state = init();
    const moves = try generateMoves(state, testing.allocator);
    defer testing.allocator.free(moves);

    try testing.expectEqual(7, moves.len);
    inline for (0..7) |i| {
        try testing.expectEqual(i, moves[i]);
    }
}

test "apply move from initial position" {
    inline for (0..7) |i| {
        const c: u6 = @intCast(i);
        const state = init();
        const next = applyMove(state, c);
        try testing.expectEqual(1, next.player);
        try testing.expectEqual(1, next.board[0] >> c);
    }
}

test "last row" {
    var state = init();
    state.board[0] = 0b0000000_0001000_0100011_1001100_0110011_1010011;
    state.board[1] = ~(state.board[0] | TOP_ROW);

    const moves = try generateMoves(state, testing.allocator);
    defer testing.allocator.free(moves);

    try testing.expectEqual(7, moves.len);
}

test "no more moves" {
    var state = init();
    state.board[0] = 0b1110111_0001000_0100011_1001100_0110011_1010011;
    state.board[1] = ~state.board[0];

    const moves = try generateMoves(state, testing.allocator);
    defer testing.allocator.free(moves);

    try testing.expectEqual(0, moves.len);
}

test "4 in a row" {
    var state = init();

    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0001111;
    var res = fourInARow(state.board[0]);
    try testing.expectEqual(true, res);

    state.board[0] = 0b0011110_0000000_0000000_0000000_0000000_0000000;
    res = fourInARow(state.board[0]);
    try testing.expectEqual(true, res);

    state.board[0] = 0b0000000_0000000_0001000_0001000_0001000_0001000;
    res = fourInARow(state.board[0]);
    try testing.expectEqual(true, res);

    state.board[0] = 0b0000000_0000000_0000001_0000010_0000100_0001000;
    res = fourInARow(state.board[0]);
    try testing.expectEqual(true, res);

    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    res = fourInARow(state.board[0]);
    try testing.expectEqual(false, res);

    state.board[0] = 0b0000000_0000000_0000000_0000000_0000011_1100000;
    res = fourInARow(state.board[0]);
    try testing.expectEqual(false, res);
}

test "isGameOver" {
    var state = init();
    try testing.expectEqual(false, state.isGameOver());

    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    try testing.expectEqual(false, state.isGameOver());

    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0001111;
    try testing.expectEqual(true, state.isGameOver());

    state.board[0] = 0b1110111_0001000_0100011_1001100_0110011_1010011;
    state.board[1] = ~state.board[0];
    try testing.expectEqual(true, state.isGameOver());
}

test "evaluate initial position" {
    const state = init();
    const score = evaluate(state);
    try testing.expectEqual(0, score);
}

test "evaluate winning position" {
    var state = init();
    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0001111;
    var score = evaluate(state);
    try testing.expectEqual(1000, score);

    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    state.board[1] = 0b0000000_0000000_0000000_0000000_0000000_0001111;
    score = evaluate(state);
    try testing.expectEqual(-1000, score);
}

test "evaluate threats" {
    var state = init();
    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0000110;
    state.board[1] = 0b0000000_0000000_0000000_0000000_0000000_0001001;
    var score = evaluate(state);
    try testing.expectEqual(-1, score);

    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0000110;
    state.board[1] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    score = evaluate(state);
    try testing.expectEqual(9, score);

    state.board[0] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    state.board[1] = 0b0000000_0000000_0000000_0000000_0000000_0001001;
    score = evaluate(state);
    try testing.expectEqual(-10, score);
}
