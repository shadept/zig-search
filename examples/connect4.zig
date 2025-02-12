const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Search = @import("search");
const Score = Search.Score;

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
    var ret = self;
    var mask = ret.boards[0] | ret.boards[1];
    ret.boards[ret.player] ^= mask;
    mask |= mask + bottomMask(@intCast(move));
    ret.boards[ret.player] ^= mask;
    ret.player = ret.player ^ 1;
    return ret;
}

fn fourInARow(board: u64) bool {
    const directions = [_]comptime_int{ 1, 6, 7, 8 };
    inline for (directions) |dir| {
        const bb = board & (board >> dir);
        if (bb & (bb >> (2 * dir)) != 0) return true;
    }
    return false;
}

pub fn isGameOver(self: Self) bool {
    const board = self.boards[0] | self.boards[1];
    const top_row = comptime topMask(0) | topMask(1) | topMask(2) | topMask(3) | topMask(4) | topMask(5) | topMask(6);
    if (board & top_row == top_row) return true;
    return fourInARow(self.boards[0]) or fourInARow(self.boards[1]);
}

const ALIGMENTS_COUNTS = [49]Score{
    3, 4,  5,  5,  4,  3, 0,
    4, 6,  8,  8,  6,  4, 0,
    5, 8,  11, 11, 8,  5, 0,
    7, 10, 13, 13, 10, 7, 0,
    5, 8,  11, 11, 8,  5, 0,
    4, 6,  8,  8,  6,  4, 0,
    3, 4,  5,  5,  4,  3, 0,
};

pub fn evaluate(self: Self) Score {
    const current_player_board = self.boards[self.player];
    if (fourInARow(current_player_board)) {
        return 1000;
    }

    const opponent_board = self.boards[self.player ^ 1];
    if (fourInARow(opponent_board)) {
        return -1000;
    }

    var score: Score = 0;
    var bits = current_player_board;
    while (bits != 0) {
        const index = @ctz(bits);
        bits &= bits - 1;
        score += ALIGMENTS_COUNTS[index];
    }

    bits = opponent_board;
    while (bits != 0) {
        const index = @ctz(bits);
        bits &= bits - 1;
        score -= ALIGMENTS_COUNTS[index];
    }

    return score;
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
            if ((self.boards[0] >> (c * (height + 1) + r) & 1) == 1) {
                try color.setColor(writer, Color.yellow);
                try writer.print("O", .{});
                try color.setColor(writer, Color.reset);
                try writer.print("|", .{});
            } else if ((self.boards[1] >> (c * (height + 1) + r) & 1) == 1) {
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

// Added tests
test "init initializes empty board" {
    const game = Self.init();
    try testing.expectEqual(game.boards[0], 0);
    try testing.expectEqual(game.boards[1], 0);
    try testing.expectEqual(game.player, 0);
}

test "generateMoves returns all columns when empty" {
    const game = Self.init();
    const moves = try game.generateMoves(testing.allocator);
    defer testing.allocator.free(moves);
    try testing.expectEqual(moves.len, width);
    for (0..width) |i| try testing.expectEqual(moves[i], i);
}

test "generateMoves excludes full columns" {
    var game = Self.init();
    // Fill column 3 completely
    game = playSequence(game, .{ 3, 3, 3, 3, 3, 3 });
    const moves = try game.generateMoves(testing.allocator);
    defer testing.allocator.free(moves);
    try testing.expectEqual(moves.len, width - 1);
    for (moves) |m| try testing.expect(m != 3);
}

test "applyMove updates board and alternates player" {
    var game = Self.init();
    // First move in column 2
    game = game.applyMove(2);
    try testing.expectEqual(game.player, 1);
    try testing.expect(game.boards[0] == bottomMask(2));

    // Second move in column 5
    game = game.applyMove(5);
    try testing.expectEqual(game.player, 0);
    try testing.expect(game.boards[1] == bottomMask(5));
}

test "fourInARow detects horizontal win" {
    // horizontal win in column 4
    const board = bottomMask(0) |
        bottomMask(1) |
        bottomMask(2) |
        bottomMask(3);
    try testing.expect(fourInARow(board));
}

test "fourInARow detects vertical win" {
    // Vertical win in column 4
    const board = bottomMask(4) |
        (bottomMask(4) << 1) |
        (bottomMask(4) << 2) |
        (bottomMask(4) << 3);
    try testing.expect(fourInARow(board));
}

test "fourInARow detects diagonal win (positive slope)" {
    // Diagonal from (0,0) to (3,3)
    const b = bottomMask(0) | // column 0, row 0
        (bottomMask(1) << 1) | // column 1, row 1
        (bottomMask(2) << 2) | // column 2, row 2
        (bottomMask(3) << 3); // column 3, row 3
    try testing.expect(fourInARow(b));
}

test "fourInARow returns false for three in row" {
    // Three horizontal pieces
    const board = bottomMask(0) | bottomMask(1) | bottomMask(2);
    try testing.expect(!fourInARow(board));
}

test "evaluate detects immediate win" {
    var game = Self.init();
    // Create winning position for current player
    game = playSequence(game, .{ 0, 1, 0, 1, 0, 1, 0 });
    game.player = 0; // set player back to previous ones
    try testing.expectEqual(game.evaluate(), 1000);
}

test "evaluate detects opponent win" {
    var game = Self.init();
    // Opponent creates winning position
    game = playSequence(game, .{ 0, 0, 1, 1, 2, 2, 3 });
    try testing.expectEqual(game.evaluate(), -1000);
}

test "isGameOver detects filled board" {
    var game = Self.init();
    // Create full board (draw scenario)
    const moves = .{ 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 2, 3, 4, 5, 4, 5, 4, 5, 4, 5, 4, 5, 4, 5, 6, 6, 6, 6, 6, 6 };
    game = playSequence(game, moves);
    try testing.expect(game.isGameOver());
}

fn playSequence(game: Self, move_sequence: anytype) Self {
    var ret = game;
    inline for (std.meta.fields(@TypeOf(move_sequence))) |field| {
        const move = @field(move_sequence, field.name);
        ret = ret.applyMove(move);
    }
    return ret;
}
