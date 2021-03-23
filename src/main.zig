const std = @import("std");
const user32 = std.os.windows.user32;
const w = @import("windows.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;
const c = @cImport({
    @cInclude("windows.h");
});

// hack to let the main loop know it should close the window
var close_message = false;

// Responds to Windows' calls into this app
// https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms633573(v=vs.85)
fn MainWindowCallback(window_handle: user32.HWND, message: c_uint, wparam: usize, lparam: isize) callconv(.C) user32.LRESULT {
    const result: user32.LRESULT = 0;
    switch (message) {
        user32.WM_SIZE => {
            std.debug.print("WM_SIZE\n", .{});
        },
        user32.WM_ACTIVATE => {
            std.debug.print("WM_ACTIVATE\n", .{});
        },
        user32.WM_CLOSE => {
            std.debug.print("WM_CLOSE\n", .{});
            close_message = true;
        },
        user32.WM_DESTROY => {
            std.debug.print("WM_DESTROY\n", .{});
            close_message = true;
        },
        user32.WM_PAINT => {
            var paint: w.PAINTSTRUCT = undefined;
            var context = w.beginPaint(window_handle, &paint).?;
            defer _ = w.endPaint(window_handle, &paint);

            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const width = paint.rcPaint.right - paint.rcPaint.left;
            const height = paint.rcPaint.bottom - paint.rcPaint.top;
            const half_width = @divFloor(width, 2);

            _ = w.patBlt(context, x, y, half_width, height, c.WHITENESS);
            _ = w.patBlt(context, x + half_width, y, half_width, height, c.BLACKNESS);
        },
        else => {
            return user32.defWindowProcW(window_handle, message, wparam, lparam);
        },
    }
    return result;
}

pub fn main() !void {
    _ = std.start.call_wWinMain();
}

// replaces main, but you don't have to link libc in build.zig
pub fn wWinMain(instance: user32.HINSTANCE, prev: ?user32.HINSTANCE, cmdLine: user32.PWSTR, cmdShow: c_int) c_int {

    const window_classname = L("HandmadeWindowClass");
    const window_title = L("Handmade Zero");

    var window_class: user32.WNDCLASSEXW = .{
        .lpfnWndProc = MainWindowCallback,
        .hInstance = instance,
        .lpszClassName = window_classname,
        .style = 0,
        .lpszMenuName = null,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .hIconSm = null,
    };
    const registered_class = user32.registerClassExW(&window_class) catch |err| {
        std.debug.print("error registerClassExW: {}", .{err});
        return 1;
    };

    var handle = user32.createWindowExW(user32.CS_OWNDC | user32.CS_HREDRAW | user32.CS_VREDRAW, window_class.lpszClassName, window_title, user32.WS_OVERLAPPEDWINDOW | user32.WS_VISIBLE, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, null, null, instance, null) catch |err| {
        std.debug.print("error createWindowExW: {}", .{err});
        return 1;
    };

    var message: user32.MSG = undefined;
    while (user32.getMessageW(&message, handle, 0, 0)) |_| {
        if (close_message) {
            return 0;
        }
        _ = user32.translateMessage(&message);
        _ = user32.dispatchMessageW(&message);
    } else |err| {
        if (err == error.Quit) {
            return 0;
        }
        std.debug.print("error getMessageW: {}", .{err});
        return 1;
    }

    return 0;
}
