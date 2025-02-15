const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Search = @import("search");
const Score = Search.Score;
const Winner = Search.Winner;

const Self = @This();
const Move = u8;

board: [9]i8,
player: u8,

pub fn init() Self {
    return .{ .board = [_]i8{0} ** 9, .player = 0 };
}

pub fn generateMoves(state: Self, allocator: Allocator) Allocator.Error![]Move {
    if (evaluate(state) != 0) {
        return allocator.alloc(u8, 0);
    }

    var moves = try std.ArrayList(u8).initCapacity(allocator, 9);
    defer moves.deinit();

    for (state.board, 0..) |cell, i| {
        if (cell == 0) {
            moves.appendAssumeCapacity(@intCast(i));
        }
    }

    return moves.toOwnedSlice();
}

pub fn applyMove(state: Self, move: Move) Self {
    var next_state = state;
    std.debug.assert(next_state.board[move] == 0);
    next_state.board[move] = if (state.player == 0) 1 else -1;
    next_state.player = if (state.player == 0) 1 else 0;
    return next_state;
}

pub fn getWinner(state: Self) ?Winner {
    if (evaluate(state) != 0) return .PreviousPlayer;
    for (state.board) |c| {
        if (c == 0) {
            return null;
        }
    }
    return .Draw;
}

pub fn evaluate(state: Self) Score {
    const sign: i8 = if (state.player == 0) 1 else -1;
    for (0..3) |i| {
        // row
        if (state.board[i * 3] != 0 and
            state.board[i * 3] == state.board[i * 3 + 1] and
            state.board[i * 3] == state.board[i * 3 + 2])
        {
            return @intCast(sign * state.board[i * 3]);
        }

        // column
        if (state.board[i] != 0 and
            state.board[i] == state.board[i + 3] and
            state.board[i] == state.board[i + 6])
        {
            return @intCast(sign * state.board[i]);
        }
    }

    if (state.board[0] != 0 and
        state.board[0] == state.board[4] and
        state.board[4] == state.board[8])
    {
        return @intCast(sign * state.board[0]);
    }

    if (state.board[2] != 0 and
        state.board[2] == state.board[4] and
        state.board[4] == state.board[6])
    {
        return @intCast(sign * state.board[2]);
    }

    return 0;
}

// test "initial position" {
//     const ttt = init();
//     const moves = try generateMoves(ttt, testing.allocator);
//     defer testing.allocator.free(moves);

//     try testing.expectEqual(9, moves.len);
//     try testing.expectEqual(0, evaluate(ttt));
// }

// test "apply move" {
//     inline for (0..9) |cell| {
//         const ttt = init();
//         const next = applyMove(ttt, @intCast(cell));
//         try testing.expectEqual(1, next.board[cell]);
//         try testing.expectEqual(0, next.player);
//         const moves = try generateMoves(next, testing.allocator);
//         defer testing.allocator.free(moves);
//         try testing.expectEqual(8, moves.len);
//     }
// }

// test "winning position" {
//     // every row
//     inline for (0..3) |row| {
//         var ttt = init();
//         ttt.board[row * 3 + 0] = 1;
//         ttt.board[row * 3 + 1] = 1;
//         ttt.board[row * 3 + 2] = 1;

//         const moves = try generateMoves(ttt, testing.allocator);
//         defer testing.allocator.free(moves);
//         try testing.expectEqual(0, moves.len);
//         try testing.expectEqual(1, evaluate(ttt));
//     }

//     // every column
//     inline for (0..3) |col| {
//         var ttt = init();
//         ttt.board[col + 0] = 1;
//         ttt.board[col + 3] = 1;
//         ttt.board[col + 6] = 1;

//         const moves = try generateMoves(ttt, testing.allocator);
//         defer testing.allocator.free(moves);
//         try testing.expectEqual(0, moves.len);
//         try testing.expectEqual(1, evaluate(ttt));
//     }

//     // main diagonal
//     {
//         var ttt = init();
//         ttt.board[0] = 1;
//         ttt.board[4] = 1;
//         ttt.board[8] = 1;

//         const moves = try generateMoves(ttt, testing.allocator);
//         defer testing.allocator.free(moves);
//         try testing.expectEqual(0, moves.len);
//         try testing.expectEqual(1, evaluate(ttt));
//     }

//     // anti diagonal
//     {
//         var ttt = init();
//         ttt.board[2] = 1;
//         ttt.board[4] = 1;
//         ttt.board[6] = 1;

//         const moves = try generateMoves(ttt, testing.allocator);
//         defer testing.allocator.free(moves);
//         try testing.expectEqual(0, moves.len);
//         try testing.expectEqual(1, evaluate(ttt));
//     }
// }

pub fn renderBoard(self: Self, stdout: std.fs.File) !void {
    var bw = std.io.bufferedWriter(stdout.writer());
    var writer = bw.writer();

    inline for (0..3) |i| {
        const r = i * 3;
        const c1 = renderCell(self.board[r], r);
        const c2 = renderCell(self.board[r + 1], r + 1);
        const c3 = renderCell(self.board[r + 2], r + 2);
        try writer.print("{c}|{c}|{c}\n", .{ c1, c2, c3 });
    }
    try bw.flush();
}

fn renderCell(player: i8, cell: u8) u8 {
    if (player == 0) {
        return '1' + cell;
    } else {
        return if (player == 1) 'X' else 'O';
    }
}

pub fn main() !void {
    const GameLoop = @import("common.zig").GameLoop;
    const game_loop = GameLoop(Self, "Tic-Tac-Toe", 10);
    try game_loop.mainLoop();
}
