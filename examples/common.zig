const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn GameLoop(comptime game: type) type {
    return struct {
        /// Main function
        pub fn mainLoop() !void {
            const AlphaBeta = @import("search").AlphaBeta;
            // const Minimax = @import("root.zig").Minimax;
            // const Negamax = @import("root.zig").Negamax;

            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            const allocator = gpa.allocator();

            var ttt = game.init();
            var algo = AlphaBeta(game, u8).init(allocator, 10);

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
                try game.renderBoard(stdout, ttt);
                if (num_players == 2 or ttt.player == human_player) {
                    ttt = try humanPlayer(ttt, stdout, stdin);
                } else {
                    ttt = try cpuPlayer(ttt, &algo);
                }

                if (ttt.isGameOver()) {
                    try game.renderBoard(stdout, ttt);
                    _ = try stdout.write("Game over\n");
                    break;
                }
            }
        }

        fn humanPlayer(ttt: game, stdout: anytype, stdin: anytype) !game {
            var move: u8 = 0;
            while (true) {
                _ = try stdout.write("Next move: ");
                move = try readInt(stdin, u8, 10) - 1;
                if (move < ttt.board.len and ttt.board[move] == 0)
                    break;
            }

            return ttt.applyMove(move);
        }

        fn cpuPlayer(ttt: game, algo: anytype) !game {
            var timer = try std.time.Timer.start();
            const result = try algo.search(ttt);
            const elapsed: f64 = @floatFromInt(timer.read());
            std.debug.print("Time elapsed is: {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
            if (result) |res| {
                std.debug.assert(ttt.board[res.move] == 0);
                std.debug.print("Computer move: {}\n", .{res.move + 1});
                const next_state = ttt.applyMove(res.move);
                return next_state;
            } else {
                std.debug.print("No moves??\n", .{});
                return ttt;
            }
        }
    };
}

fn readLine(reader: anytype, allocator: Allocator) ![]u8 {
    const builtin = @import("builtin");
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
