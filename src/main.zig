const std = @import("std");
const time = std.time;
const os = std.os;
const fs = std.fs;

const MILLISEC_IN_SEC: usize = 1000;
const SEC_IN_MIN: usize = 60;

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    const orig_attr = try os.tcgetattr(stdin.handle);
    enableRaw(stdin, orig_attr);
    defer {
        disableRaw(stdin, orig_attr);
        setCursor(stdout, Cursor.show);
    }

    setCursor(stdout, Cursor.hide);
    try stdout.writer().print("Tap `SPC` to find BPM\r\n", .{});
    try stdout.writer().print("Tap `q` to quit\r\n", .{});
    try stdout.writer().print("Tap `r` to reset counter\r\n", .{});

    var before: i64 = 0;
    var timer = [_]i64{-1} ** 10;
    var i: u8 = 0;
    while (true) {
        const c = stdin.reader().readByte() catch continue;

        switch (c) {
            ' ' => {
                i = (i + 1) % 10;
                const now = time.milliTimestamp();
                const delta = now - before;
                if (delta != now) {
                    timer[i] = delta;
                    try stdout.writer().print("\rBPM: {}", .{computeBPM(&timer)});
                } else {
                    try stdout.writer().print("\rBPM: {}", .{0});
                }

                before = now;
            },
            'r' => {
                eraseInLine(stdout, EIL.entire_line);
                try stdout.writer().print("\rBPM: {}", .{0});
                before = 0;
                resetTimer(&timer);
            },
            'q' => {
                try stdout.writer().print("\r\n", .{});
                break;
            },
            else => continue,
        }
    }
}

fn disableRaw(stdin: fs.File, orig_attr: os.termios) void {
    os.tcsetattr(stdin.handle, os.TCSA.FLUSH, orig_attr) catch return;
}

fn enableRaw(stdin: fs.File, orig_attr: os.termios) void {
    var raw = orig_attr;
    raw.iflag &= ~(os.system.BRKINT | os.system.ICRNL | os.system.INPCK | os.system.ISTRIP | os.system.IXON);
    raw.oflag &= ~(os.system.OPOST);
    raw.cflag |= (os.system.CS8);
    raw.lflag &= ~(os.system.ECHO | os.system.ICANON | os.system.IEXTEN | os.system.ISIG);
    raw.cc[os.system.V.MIN] = 0;
    raw.cc[os.system.V.TIME] = 1;
    os.tcsetattr(stdin.handle, os.TCSA.FLUSH, raw) catch return;
}

fn computeBPM(timer: *[10]i64) usize {
    var total: usize = 0;
    var count: usize = 0;
    for (timer) |val| {
        if (val > 0) {
            total += @intCast(usize, val);
            count += 1;
        }
    }
    return @divTrunc(MILLISEC_IN_SEC * SEC_IN_MIN * count, total);
}

const Cursor = enum { hide, show };

fn setCursor(stdout: fs.File, c: Cursor) void {
    switch (c) {
        Cursor.hide => stdout.writer().print("\x1b[?25l", .{}) catch {},
        Cursor.show => stdout.writer().print("\x1b[?25h", .{}) catch {},
    }
}

const EIL = enum { cursor_to_end, beg_to_cursor, entire_line };

fn eraseInLine(stdout: fs.File, e: EIL) void {
    // Erases part of the line. If n is 0 (or missing), clear from cursor to
    // the end of the line. If n is 1, clear from cursor to beginning of the
    // line. If n is 2, clear entire line. Cursor position does not change.
    switch (e) {
        EIL.cursor_to_end => stdout.writer().print("\x1b[0K", .{}) catch {},
        EIL.beg_to_cursor => stdout.writer().print("\x1b[1K", .{}) catch {},
        EIL.entire_line => stdout.writer().print("\x1b[2K", .{}) catch {},
    }
}

fn resetTimer(timer: *[10]i64) void {
    for (timer) |_, i| {
        timer[i] = -1;
    }
}
