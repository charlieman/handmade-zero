const std = @import("std");
const user32 = std.os.windows.user32;
const w = @import("windows.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;
// const c = @cImport({
//     @cInclude("windows.h");
//     @cInclude("wingdi.h");
// });

//Globals
var running = false;
var bitmapInfo: w.BITMAPINFO = std.mem.zeroes(w.BITMAPINFO);
var bitmapMemory: ?*c_void = undefined;
var bitmapHandle: ?w.HBITMAP = null;
var device_context: ?user32.HDC = null;

fn Win32ResizeDIBSection(width: i32, height: i32) void {
    if (bitmapHandle != null) {
        _ = w.DeleteObject(bitmapHandle);
    }
    if (device_context == null) {
        device_context = w.createCompatibleDC(null);
    }
    bitmapInfo = .{
        .bmiHeader = .{
            .biSize = @sizeOf(w.BITMAPINFOHEADER),
            .biWidth = width,
            .biHeight = height,
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = w.BI_RGB,
            .biSizeImage = 0,
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        },
        .bmiColors = undefined,
    };
    bitmapHandle = w.createDIBSection(device_context.?, &bitmapInfo, w.DIB_RGB_COLORS, &bitmapMemory, null, 0).?;
}

fn Win32UpdateWindow(hdc: user32.HDC, x: i32, y: i32, width: i32, height: i32) void {
    _ = w.stretchDIBits(hdc, x, y, width, height, x, y, width, height, &bitmapMemory, &bitmapInfo, w.DIB_RGB_COLORS, w.SRCCOPY) catch unreachable;
}

// Responds to Windows' calls into this app
// https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms633573(v=vs.85)
fn Win32MainWindowCallback(window_handle: user32.HWND, message: c_uint, wparam: usize, lparam: isize) callconv(.C) user32.LRESULT {
    const result: user32.LRESULT = 0;
    switch (message) {
        user32.WM_SIZE => {
            var clientRect: user32.RECT = undefined;
            _ = w.getClientRect(window_handle, &clientRect) catch unreachable;
            const width = clientRect.right - clientRect.left;
            const height = clientRect.bottom - clientRect.top;
            Win32ResizeDIBSection(width, height);
        },
        user32.WM_ACTIVATE => {
            std.debug.print("WM_ACTIVATE\n", .{});
        },
        user32.WM_CLOSE => {
            std.debug.print("WM_CLOSE\n", .{});
            running = false;
        },
        user32.WM_DESTROY => {
            std.debug.print("WM_DESTROY\n", .{});
            running = false;
        },
        user32.WM_PAINT => {
            var paint: w.PAINTSTRUCT = undefined;
            var context = w.beginPaint(window_handle, &paint).?;
            defer _ = w.endPaint(window_handle, &paint);

            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const width = paint.rcPaint.right - paint.rcPaint.left;
            const height = paint.rcPaint.bottom - paint.rcPaint.top;
            Win32UpdateWindow(context, x, y, width, height);
        },
        else => {
            return user32.defWindowProcW(window_handle, message, wparam, lparam);
        },
    }
    return result;
}

// Using wWinMain directly without main prevents you from linking libc,
// this hack let's you have both
pub fn main() !void {
    if (std.start.call_wWinMain() == 0) {
        return;
    } else {
        return error.ExitError;
    }
}

pub fn wWinMain(instance: user32.HINSTANCE, prev: ?user32.HINSTANCE, cmdLine: user32.PWSTR, cmdShow: c_int) c_int {
    const window_classname = L("HandmadeWindowClass");
    const window_title = L("Handmade Zero");

    var window_class: user32.WNDCLASSEXW = .{
        .lpfnWndProc = Win32MainWindowCallback,
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

    running = true;
    while (running) {
        var message: user32.MSG = undefined;
        if (user32.getMessageW(&message, handle, 0, 0)) |_| {
            _ = user32.translateMessage(&message);
            _ = user32.dispatchMessageW(&message);
        } else |err| {
            if (err != error.Quit) {
                std.debug.print("error getMessageW: {}", .{err});
                return 1;
            }
        }
    }
    return 0;
}
