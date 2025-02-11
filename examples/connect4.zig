const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Self = @This();
const Move = u8;

const width = 7;
const height = 6;

comptime {
    if (width > 10) @compileError("Boards's width must be less than 10");
    if (width * (height + 1) > 64) @compileError("Board does not fit in 64bit bitboard");
}

/// Bitboard for each player, organized as follows:
/// x  x  x  x  x  x  x
/// 5 12 19 26 33 40 47
/// 4 11 18 25 32 39 46
/// 3 10 17 24 31 38 45
/// 2  9 16 23 30 37 44
/// 1  8 15 22 29 36 43
/// 0  7 14 21 28 35 42
/// Xs indicate if a column is full and helps calculating aligments (4 in a row)
boards: [2]u64,
player: u8,

pub fn init() Self {
    return .{ .boards = .{ 0, 0 }, .player = 0 };
}

pub fn generateMoves(self: Self, allocator: Allocator) Allocator.Error![]Move {
    var moves = try std.ArrayList(Move).initCapacity(allocator, width);
    defer moves.deinit();

    const mask = self.boards[0] | self.boards[1];
    for (0..width) |i| {
        const col: u6 = @intCast(i);
        if (mask & topMask(col) == 0) {
            moves.appendAssumeCapacity(col);
        }
    }

    return moves.toOwnedSlice();
}

fn topMask(col: u6) u64 {
    return (@as(u64, 1) << (height - 1)) << col * (height + 1);
}

fn bottomMask(col: u6) u64 {
    return @as(u64, 1) << col * (height + 1);
}

/// Apply the given move, assuming it is valid.
pub fn applyMove(self: Self, move: Move) Self {
    std.debug.assert(0 <= move and move <= 6);
    var mask = self.boards[0] | self.boards[1];
    var next = self;
    const current_position = &next.boards[self.player];

    current_position.* ^= mask;
    mask |= mask + bottomMask(@intCast(move));
    current_position.* ^= mask;

    next.player = if (self.player == 0) 1 else 0;
    return next;
}

pub fn isGameOver(self: Self) bool {
    const board = self.boards[0] | self.boards[1];
    const top_row = comptime topMask(0) | topMask(1) | topMask(2) | topMask(3) | topMask(4) | topMask(5) | topMask(6);
    if (board & top_row == top_row) return true;
    return fourInARow(self.boards[0]) or fourInARow(self.boards[1]);
}

fn fourInARow(board: u64) bool {
    const directions = [_]comptime_int{ 1, 6, 7, 8 };
    inline for (directions) |dir| {
        const bb = board & (board >> dir);
        if (bb & (bb >> (2 * dir)) != 0) return true;
    }

    return false;
}

const FOUR_IN_A_ROW_COUNTS = [49]u8{
    3, 4,  5,  5,  4,  3, 0,
    4, 6,  8,  8,  6,  4, 0,
    5, 8,  11, 11, 8,  5, 0,
    7, 10, 13, 13, 10, 7, 0,
    5, 8,  11, 11, 8,  5, 0,
    4, 6,  8,  8,  6,  4, 0,
    3, 4,  5,  5,  4,  3, 0,
};

pub fn evaluate(self: Self) i64 {
    const current_player_board = self.boards[self.player];
    const opponent_board = self.boards[if (self.player == 0) 1 else 0];

    if (fourInARow(current_player_board)) {
        return 1000;
    } else if (fourInARow(opponent_board)) {
        return -1000;
    }

    const BitSet = std.bit_set.IntegerBitSet(64);
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
        try testing.expectEqual(1, next.boards[0] >> c);
    }
}

// test "last row" {
//     var state = init();
//     state.boards[0] = 0b0000000_0001000_0100011_1001100_0110011_1010011;
//     state.boards[1] = ~(state.boards[0] | TOP_ROW);

//     const moves = try generateMoves(state, testing.allocator);
//     defer testing.allocator.free(moves);

//     try testing.expectEqual(7, moves.len);
// }

test "no more moves" {
    var state = init();
    state.boards[0] = 0b1110111_0001000_0100011_1001100_0110011_1010011;
    state.boards[1] = ~state.boards[0];

    const moves = try generateMoves(state, testing.allocator);
    defer testing.allocator.free(moves);

    try testing.expectEqual(0, moves.len);
}

test "4 in a row" {
    var state = init();

    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0001111;
    var res = fourInARow(state.boards[0]);
    try testing.expectEqual(true, res);

    state.boards[0] = 0b0011110_0000000_0000000_0000000_0000000_0000000;
    res = fourInARow(state.boards[0]);
    try testing.expectEqual(true, res);

    state.boards[0] = 0b0000000_0000000_0001000_0001000_0001000_0001000;
    res = fourInARow(state.boards[0]);
    try testing.expectEqual(true, res);

    state.boards[0] = 0b0000000_0000000_0000001_0000010_0000100_0001000;
    res = fourInARow(state.boards[0]);
    try testing.expectEqual(true, res);

    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    res = fourInARow(state.boards[0]);
    try testing.expectEqual(false, res);

    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000011_1100000;
    res = fourInARow(state.boards[0]);
    try testing.expectEqual(false, res);

    state.boards[0] = 0b0000000_0000000_0000000_0010000_0101000_1000101;
    res = fourInARow(state.boards[0]);
    try testing.expectEqual(false, res);
}

test "isGameOver" {
    var state = init();
    try testing.expectEqual(false, state.isGameOver());

    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    try testing.expectEqual(false, state.isGameOver());

    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0001111;
    try testing.expectEqual(true, state.isGameOver());

    state.boards[0] = 0b1110111_0001000_0100011_1001100_0110011_1010011;
    state.boards[1] = ~state.boards[0];
    try testing.expectEqual(true, state.isGameOver());

    state.boards[0] = 0b0000000_0000000_0001000_0001000_0010000_0111000;
    state.boards[1] = 0b0000000_0000000_0000000_0010000_0101000_1000101;
    try testing.expectEqual(false, state.isGameOver());
}

test "evaluate initial position" {
    const state = init();
    const score = evaluate(state);
    try testing.expectEqual(0, score);
}

test "evaluate winning position" {
    var state = init();
    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0001111;
    var score = evaluate(state);
    try testing.expectEqual(1000, score);

    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    state.boards[1] = 0b0000000_0000000_0000000_0000000_0000000_0001111;
    score = evaluate(state);
    try testing.expectEqual(-1000, score);
}

test "evaluate threats" {
    var state = init();
    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0000110;
    state.boards[1] = 0b0000000_0000000_0000000_0000000_0000000_0001001;
    var score = evaluate(state);
    try testing.expectEqual(-1, score);

    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0000110;
    state.boards[1] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    score = evaluate(state);
    try testing.expectEqual(9, score);

    state.boards[0] = 0b0000000_0000000_0000000_0000000_0000000_0000000;
    state.boards[1] = 0b0000000_0000000_0000000_0000000_0000000_0001001;
    score = evaluate(state);
    try testing.expectEqual(-10, score);
}

pub fn renderBoard(self: Self, stdout: std.fs.File) !void {
    const tty = std.io.tty;
    const Color = tty.Color;

    const color = tty.detectConfig(stdout);
    var bw = std.io.bufferedWriter(stdout.writer());
    var writer = bw.writer();

    inline for (0..height) |i| {
        const r: u8 = (5 - i);
        try writer.print("{c} |", .{'A' + r});
        inline for (0..width) |c| {
            const p1 = (self.boards[0] >> (c * (height + 1) + r) & 1) == 1;
            const p2 = (self.boards[1] >> (c * (height + 1) + r) & 1) == 1;
            if (p1) {
                try color.setColor(writer, Color.yellow);
                try writer.print("O", .{});
                try color.setColor(writer, Color.reset);
                try writer.print("|", .{});
            } else if (p2) {
                try color.setColor(writer, Color.red);
                try writer.print("X", .{});
                try color.setColor(writer, Color.reset);
                try writer.print("|", .{});
            } else {
                try writer.print("_|", .{});
            }
        }
        try writer.print("\n", .{});
    }
    try writer.print("   1 2 3 4 5 6 7\n", .{});
    try bw.flush();
}

pub fn main() !void {
    const GameLoop = @import("common.zig").GameLoop;
    const game_loop = GameLoop(Self, "Connect 4", 6);
    try game_loop.mainLoop();
}
