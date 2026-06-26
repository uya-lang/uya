const std = @import("std");
const zap = @import("zap");

const BENCH_PORT: u16 = 8876;

fn clamp_threads(value: usize) i16 {
    if (value == 0) {
        return 1;
    }

    const max_threads: usize = std.math.maxInt(i16);
    if (value > max_threads) {
        return std.math.maxInt(i16);
    }

    return @as(i16, @intCast(value));
}

fn parse_threads() i16 {
    const cpu_count = std.Thread.getCpuCount() catch 1;
    var threads: i16 = clamp_threads(cpu_count);
    var args = std.process.argsWithAllocator(std.heap.page_allocator) catch return threads;

    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--threads")) {
            if (args.next()) |value| {
                threads = clamp_threads(std.fmt.parseInt(usize, value, 10) catch 0);
            }
            continue;
        }

        if (std.mem.startsWith(u8, arg, "--threads=")) {
            const value = arg["--threads=".len..];
            threads = clamp_threads(std.fmt.parseInt(usize, value, 10) catch 0);
        }
    }

    return threads;
}

fn on_request(r: zap.Request) !void {
    r.sendBody("hello") catch return;
}

pub fn main() !void {
    const threads = parse_threads();
    var listener = zap.HttpListener.init(.{
        .port = BENCH_PORT,
        .on_request = on_request,
        .log = false,
        .max_clients = 100000,
    });

    try listener.listen();
    zap.start(.{
        .threads = threads,
        .workers = threads,
    });
}
