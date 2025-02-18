const std = @import("std");
const Allocator = std.mem.Allocator;

const Search = @import("search");
const Game = Search.Game;
const Strategy = Search.Strategy;

pub fn GameLoop(comptime S: type, comptime title: []const u8, comptime max_depth: u8) type {
    return struct {
        /// Main function
        pub fn mainLoop(initial_state: Game(S, u8)) !void {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            const allocator = gpa.allocator();

            const stdout = std.io.getStdOut();
            const stdin = std.io.getStdIn();

            var players = [2]Player{ undefined, undefined };
            var current_player: usize = 0;

            // Initial questions
            try stdout.writeAll("Welcome to " ++ title ++ "\n");
            var num_humans: usize = 0;
            while (true) {
                try stdout.writeAll("How many humans players (0, 1 or 2)? ");
                const r = try readInt(stdin, usize, 10);
                if (0 <= r or r <= 2) {
                    num_humans = r;
                    break;
                }
            }

            for (0..num_humans) |i| {
                players[i] = Player.initHuman(stdout, stdin, allocator);
            }

            for (num_humans..2) |i| {
                while (true) {
                    try stdout.writer().print("Choose strategy for CPU {} (1: Minimax, 2: AlphaBeta, 3: Negamax): ", .{i});
                    const response = try readLine(stdin, allocator);
                    defer allocator.free(response);
                    if (response.len == 1) {
                        var strategy: Strategy(S, u8) = undefined;
                        switch (response[0]) {
                            '1' => {
                                var minimax = Search.Minimax(S, u8).init(allocator, max_depth);
                                strategy = minimax.strategy();
                            },
                            '2' => {
                                var alphabeta = Search.AlphaBeta(S, u8).init(allocator, max_depth);
                                strategy = alphabeta.strategy();
                            },
                            '3' => {
                                var negamax = Search.Negamax(S, u8).init(allocator, max_depth);
                                strategy = negamax.strategy();
                            },
                            else => continue,
                        }
                        players[i] = Player.initCpu(strategy);
                        break;
                    }
                }
            }

            if (num_humans == 1) {
                while (true) {
                    try stdout.writeAll("Do you want to play first? (y/n): ");
                    const response = try readLine(stdin, allocator);
                    defer allocator.free(response);
                    if (std.ascii.toLower(response[0]) == 'y') {
                        break;
                    } else if (std.ascii.toLower(response[0]) == 'n') {
                        std.mem.swap(Player, &players[0], &players[1]);
                        break;
                    }
                }
            }

            var game = initial_state;

            while (true) {
                try game.renderBoard(stdout);
                game = try players[current_player].play(game);
                current_player = if (current_player == 0) 1 else 0;
                const winner = game.getWinner() orelse continue;
                try game.renderBoard(stdout);
                switch (winner) {
                    .PreviousPlayer => try stdout.writeAll("You win\n"),
                    .Draw => try stdout.writeAll("Draw\n"),
                    .CurrentPlayer => try stdout.writeAll("You lose\n"),
                }
                break;
            }
        }

        const HumanPlayer = struct {
            stdout: std.fs.File,
            stdin: std.fs.File,
            allocator: Allocator,

            pub fn play(self: *HumanPlayer, game: Game(S, u8)) !Game(S, u8) {
                const valid_moves = try game.generateMoves(self.allocator);
                var move: u8 = 0;
                while (true) {
                    _ = try self.stdout.writeAll("Next move: ");
                    const num = readInt(self.stdin, u8, 10) catch continue;
                    if (num == 0) continue;
                    // TODO check if move is valid in agnistic way to the game
                    if (std.mem.indexOfScalar(u8, valid_moves, num - 1)) |i| {
                        move = valid_moves[i];
                        break;
                    }
                }

                return game.applyMove(move);
            }
        };

        const CpuPlayer = struct {
            strategy: Strategy(S, u8),

            pub fn play(self: *CpuPlayer, game: Game(S, u8)) !Game(S, u8) {
                var timer = try std.time.Timer.start();
                const result = try self.strategy.chooseMove(game.state);
                const elapsed: f64 = @floatFromInt(timer.read());
                std.debug.print("Time elapsed is: {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
                // std.debug.assert(game.board[res.move] == 0);
                const move = result orelse @panic("no moves??!");
                std.debug.print("Computer move: {}\n", .{move + 1});
                const next_state = game.applyMove(move);
                return next_state;
            }
        };

        const Player = union(enum) {
            human: HumanPlayer,
            cpu: CpuPlayer,

            pub fn initHuman(stdout: std.fs.File, stdin: anytype, allocator: Allocator) Player {
                return .{ .human = .{ .stdout = stdout, .stdin = stdin, .allocator = allocator } };
            }

            pub fn initCpu(strategy: Strategy(S, u8)) Player {
                return .{ .cpu = .{ .strategy = strategy } };
            }

            pub fn play(self: *Player, game: Game(S, u8)) !Game(S, u8) {
                return switch (self.*) {
                    inline else => |*impl| impl.play(game),
                };
            }
        };
    };
}

fn readLine(file: std.fs.File, allocator: Allocator) ![]u8 {
    const builtin = @import("builtin");
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 20);
    const reader = file.reader();
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

fn readInt(file: std.fs.File, comptime T: type, base: u8) anyerror!T {
    var buf: [20]u8 = undefined;
    const len = try file.read(&buf);
    if (len == buf.len) {
        std.debug.print("Input is too big!\n", .{});
        std.process.exit(1);
    }

    const line = std.mem.trimRight(u8, buf[0..len], "\r\n");
    return std.fmt.parseInt(T, line, base);
}
