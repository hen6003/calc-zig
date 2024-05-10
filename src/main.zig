const std = @import("std");

const State = enum {
    default,
    number,
};

pub fn main() !void {
    const stdin_file = std.io.getStdIn().reader();
    var br = std.io.bufferedReader(stdin_file);
    const stdin = br.reader();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stderr_file = std.io.getStdOut().writer();
    var bwe = std.io.bufferedWriter(stderr_file);
    const stderr = bwe.writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var stack = std.ArrayList(f32).init(allocator);

    while (true) {
        try stdout.print("> ", .{});
        try bw.flush();

        const input = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 1028) orelse {
            // If EOF then a newline isn't printed
            try stdout.print("\n", .{});
            try bw.flush();
            return; // End of data so exit program
        };
        defer allocator.free(input);

        var start: usize = 0;
        var state = State.default;

        for (input, 0..) |char, current| {
            if (std.ascii.isDigit(char) or char == '.' or (state == .number and char == 'e')) {
                if (state == .default) {
                    start = current;
                    state = .number;
                }
            } else {
                if (state == .number) {
                    const number = std.fmt.parseFloat(f32, input[start..current]) catch |err| blk: {
                        try stderr.print("Invalid number {s} ({})\n", .{ input[start..current], err });
                        try bwe.flush();
                        break :blk null;
                    };
                    if (number) |n| {
                        try stack.append(n);
                    }
                    state = .default;
                }

                const value = switch (char) {
                    '+' => stack.pop() + stack.pop(),
                    '-' => blk: {
                        const rhs = stack.pop();
                        const lhs = stack.pop();
                        break :blk lhs - rhs;
                    },
                    '*' => stack.pop() * stack.pop(),
                    '/' => blk: {
                        const rhs = stack.pop();
                        const lhs = stack.pop();
                        break :blk lhs / rhs;
                    },
                    '^' => blk: {
                        const rhs = stack.pop();
                        const lhs = stack.pop();
                        break :blk std.math.pow(f32, lhs, rhs);
                    },
                    'c' => blk: {
                        stack.clearAndFree();
                        break :blk null;
                    },
                    ' ' => null,
                    'q' => return,
                    0xC => blk: {
                        try stdout.print("\x1b[2J\x1b[H", .{});
                        try bw.flush();

                        break :blk null;
                    },
                    else => blk: {
                        if (std.ascii.isPrint(char)) {
                            try stderr.print("Unknown operator {c}\n", .{char});
                        } else {
                            try stderr.print("Unknown operator 0x{x}\n", .{char});
                        }
                        try bwe.flush();
                        break :blk null;
                    },
                };

                if (value) |v| {
                    try stack.append(v);
                }
            }
        }

        if (state == .number) {
            const number = std.fmt.parseFloat(f32, input[start..]) catch |err| blk: {
                try stderr.print("Invalid number {s} ({})\n", .{ input[start..], err });
                try bwe.flush();
                break :blk null;
            };
            if (number) |n| {
                try stack.append(n);
            }
            state = .default;
        }

        try stdout.print("\t[", .{});

        for (stack.items, 0..) |item, i| {
            if (i != stack.items.len - 1) {
                try stdout.print("{}, ", .{item});
            } else {
                try stdout.print("{}", .{item});
            }
        }

        try stdout.print("]\n", .{});
        try bw.flush();
    }
}
