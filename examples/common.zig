const std = @import("std");
const Allocator = std.mem.Allocator;

const Search = @import("search");
const Algorithm = Search.Algorithm;

pub fn GameLoop(comptime Context: type, comptime title: []const u8, comptime max_depth: u8) type {
    return struct {
        /// Main function
        pub fn mainLoop() !void {
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
                    try stdout.writer().print("Choose algorithm for CPU {} (1: Minimax, 2: AlphaBeta, 3: Negamax): ", .{i});
                    const response = try readLine(stdin, allocator);
                    defer allocator.free(response);
                    if (response.len == 1) {
                        const algo: Algorithm(Context, u8) = switch (response[0]) {
                            '1' => .{ .minimax = Search.Minimax(Context, u8).init(allocator, max_depth) },
                            '2' => .{ .alphaBeta = Search.AlphaBeta(Context, u8).init(allocator, max_depth) },
                            '3' => .{ .negamax = Search.Negamax(Context, u8).init(allocator, max_depth) },
                            else => continue,
                        };
                        players[i] = Player.initCpu(algo);
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

            var game = Context.init();

            while (true) {
                try game.renderBoard(stdout);
                game = try players[current_player].play(game);
                current_player = if (current_player == 0) 1 else 0;
                if (game.isGameOver()) {
                    try game.renderBoard(stdout);
                    _ = try stdout.writeAll("Game over\n");
                    break;
                }
            }
        }

        const HumanPlayer = struct {
            stdout: std.fs.File,
            stdin: std.fs.File,
            allocator: Allocator,

            pub fn play(self: HumanPlayer, game: Context) !Context {
                const valid_moves = try Context.generateMoves(game, self.allocator);
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
            algo: Algorithm(Context, u8),

            pub fn play(self: CpuPlayer, game: Context) !Context {
                var timer = try std.time.Timer.start();
                const result = try self.algo.search(game);
                const elapsed: f64 = @floatFromInt(timer.read());
                std.debug.print("Time elapsed is: {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
                if (result) |res| {
                    // std.debug.assert(game.board[res.move] == 0);
                    std.debug.print("Computer move: {}\n", .{res.move + 1});
                    const next_state = game.applyMove(res.move);
                    return next_state;
                } else {
                    std.debug.print("No moves??\n", .{});
                    return game;
                }
            }
        };

        const Player = union(enum) {
            human: HumanPlayer,
            cpu: CpuPlayer,

            pub fn initHuman(stdout: std.fs.File, stdin: anytype, allocator: Allocator) Player {
                return .{ .human = .{ .stdout = stdout, .stdin = stdin, .allocator = allocator } };
            }

            pub fn initCpu(algo: Algorithm(Context, u8)) Player {
                return .{ .cpu = .{ .algo = algo } };
            }

            pub fn play(self: Player, game: Context) !Context {
                return switch (self) {
                    inline else => |impl| impl.play(game),
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
