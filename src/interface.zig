pub const Score = i64;

pub fn SearchResult(comptime M: type) type {
    return struct {
        move: M,
        score: Score,
    };
}
