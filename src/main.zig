const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const TicTacToe = @import("examples/tictactoe.zig");
const AlphaBeta = @import("root.zig").AlphaBeta;
const Minimax = @import("root.zig").Minimax;
const Negamax = @import("root.zig").Negamax;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var ttt = TicTacToe.init();
    var algo = Minimax(TicTacToe, u8).init(allocator, 10);

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    // Initial questions
    try stdout.print("Welcome to Tic-Tac-Toe\n", .{});
    var num_players: i8 = -1;
    while (true) {
        try stdout.print("How many humans players (0, 1 or 2)? ", .{});
        num_players = try readInt(stdin, i8, 10);
        if (0 <= num_players or num_players <= 2)
            break;
    }

    var human_player: i8 = 0;
    if (num_players == 1) {
        while (true) {
            try stdout.print("Do you want to play first? (y/n): ", .{});

            const response = try readLine(stdin, allocator);
            defer allocator.free(response);

            if (std.ascii.toLower(response[0]) == 'y') {
                human_player = 1;
                break;
            } else if (std.ascii.toLower(response[0]) == 'n') {
                human_player = -1;
                break;
            }
        }
    }

    while (true) {
        try renderBoard(stdout, ttt);
        if (num_players == 2 or ttt.player == human_player) {
            ttt = try humanPlayer(ttt, stdout, stdin);
        } else {
            ttt = try cpuPlayer(ttt, &algo);
        }

        if (ttt.isGameOver()) {
            try renderBoard(stdout, ttt);
            _ = try stdout.write("Game over\n");
            break;
        }
    }
}

fn humanPlayer(ttt: TicTacToe, stdout: anytype, stdin: anytype) !TicTacToe {
    var move: u8 = 0;
    while (true) {
        _ = try stdout.write("Next move: ");
        move = try readInt(stdin, u8, 10) - 1;
        if (move < ttt.board.len and ttt.board[move] == 0)
            break;
    }

    return ttt.applyMove(move);
}

fn cpuPlayer(ttt: TicTacToe, algo: anytype) !TicTacToe {
    const result = try algo.search(ttt);
    if (result) |res| {
        std.debug.assert(ttt.board[res.move] == 0);
        std.debug.print("Computer move: {}\n", .{res.move + 1});
        return ttt.applyMove(res.move);
    } else {
        std.debug.print("No moves??\n", .{});
        return ttt;
    }
}

fn readLine(reader: anytype, allocator: Allocator) ![]u8 {
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 20);
    reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| switch (err) {
        error.EndOfStream => return err,
        else => unreachable,
    };
    if (builtin.os.tag == .windows) {
        if (buffer.getLastOrNull()) |ch| {
            if (ch == '\r') {
                _ = buffer.pop();
            }
        }
    }
    return buffer.toOwnedSlice();
}

fn readInt(reader: anytype, comptime T: type, base: u8) (@TypeOf(reader).Error || std.fmt.ParseIntError)!T {
    var buf: [20]u8 = undefined;
    const len = try reader.read(&buf);
    if (len == buf.len) {
        std.debug.print("Input is too big!\n", .{});
        std.process.exit(1);
    }

    const line = std.mem.trimRight(u8, buf[0..len], "\r\n");
    return std.fmt.parseInt(T, line, base);
}

fn renderBoard(stdout: anytype, ttt: TicTacToe) !void {
    var bw = std.io.bufferedWriter(stdout);
    var writer = bw.writer();

    inline for (0..3) |i| {
        const r = i * 3;
        const c1 = renderCell(ttt.board[r], r);
        const c2 = renderCell(ttt.board[r + 1], r + 1);
        const c3 = renderCell(ttt.board[r + 2], r + 2);
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
