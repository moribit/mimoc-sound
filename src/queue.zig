const std = @import("std");
// Exactly one producer and one consumer. Never overwrite unread slots.
pub fn Queue(comptime T: type, comptime capacity: usize) type {
    return struct {
        slots: [capacity]T = undefined,
        read_index: std.atomic.Value(u32) = .init(0),
        write_index: std.atomic.Value(u32) = .init(0),
        pub fn push(q: *@This(), v: T) bool {
            const w = q.write_index.load(.monotonic);
            if (w -% q.read_index.load(.acquire) >= capacity) return false;
            q.slots[w % capacity] = v;
            q.write_index.store(w +% 1, .release);
            return true;
        }
        pub fn pop(q: *@This()) ?T {
            const r = q.read_index.load(.monotonic);
            if (r == q.write_index.load(.acquire)) return null;
            const v = q.slots[r % capacity];
            q.read_index.store(r +% 1, .release);
            return v;
        }
    };
}
test "bounded FIFO" {
    var q: Queue(u32, 2) = .{};
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expect(!q.push(3));
    try std.testing.expectEqual(@as(?u32, 1), q.pop());
    try std.testing.expectEqual(@as(?u32, 2), q.pop());
    try std.testing.expect(q.pop() == null);
}
