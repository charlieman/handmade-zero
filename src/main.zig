const std = @import("std");
const user32 = std.os.windows.user32;
const w = @import("windows.zig");
const windows = std.os.windows;
const L = std.unicode.utf8ToUtf16LeStringLiteral;
// const c = @cImport({
//     @cInclude("windows.h");
//     @cInclude("wingdi.h");
// });
const allocator = std.heap.page_allocator;

//Globals
var running = false;
var bitmapInfo: w.BITMAPINFO = std.mem.zeroes(w.BITMAPINFO);
var BitmapMemory: ?*c_void = @import("std").mem.zeroes(?*c_void);
//var bitmapMemory: ?[]u8 = null;
var bitmapWidth: i32 = undefined;
var bitmapHeight: i32 = undefined;
const bytesPerPixel = 4;

var sent: i32 = 20;
fn RenderWeirdGradient(xOffset: i32, yOffset: i32) void {
    const width = bitmapWidth;
    const pitch = width * bytesPerPixel;

    // TODO: This is directly translated from C, how to do it in Zig?
    //var i: usize = 0;
    var Row: [*c]u8 = @ptrCast([*c]u8, @alignCast(@alignOf(u8), BitmapMemory));
    var y: i32 = 0;
    while (y < bitmapHeight) : (y += 1) {
        var Pixel: [*c]u32 = @ptrCast([*c]u32, @alignCast(@alignOf(u32), Row));
        var x: i32 = 0;
        while (x < bitmapWidth) : (x += 1) {
            // const b = @bitCast(u8, @truncate(i8, x));
            // const g = @bitCast(u8, @truncate(i8, y));
            // bitmapMemory.?[i] = b;
            // bitmapMemory.?[i+1] = g;
            // bitmapMemory.?[i+2] = 0;
            // bitmapMemory.?[i+3] = 0;
            // i += bytesPerPixel;
            var blue: u8 = @bitCast(u8, @truncate(i8, x + xOffset));
            var green: u8 = @bitCast(u8, @truncate(i8, y + xOffset));
            Pixel.?.* = (@intCast(u32, green) << 8) | blue;
            Pixel += 1;
        }
        Row += @bitCast(usize, @intCast(isize, pitch));
    }
}

fn Win32ResizeDIBSection(width: i32, height: i32) void {
    // if (bitmapMemory != null) {
    //     allocator.free(bitmapMemory.?);
    //     bitmapMemory = null;
    // }
    if (BitmapMemory != null) {
        _ = windows.VirtualFree(BitmapMemory.?, 0, windows.MEM_RELEASE);
    }
    bitmapWidth = width;
    bitmapHeight = height;

    bitmapInfo.bmiHeader.biSize = @sizeOf(w.BITMAPINFOHEADER);
    bitmapInfo.bmiHeader.biWidth = width;
    bitmapInfo.bmiHeader.biHeight = -height;
    bitmapInfo.bmiHeader.biPlanes = 1;
    bitmapInfo.bmiHeader.biBitCount = 32;
    bitmapInfo.bmiHeader.biCompression = w.BI_RGB;

    const bitmapMemorySize: usize = @intCast(usize, width * height * bytesPerPixel);
    //bitmapMemory = allocator.alloc(u8, bitmapMemorySize) catch unreachable;
    if (bitmapMemorySize == 0) {
        // window is minimized
        BitmapMemory = null;
        return;
    }
    BitmapMemory = windows.VirtualAlloc(null, bitmapMemorySize, windows.MEM_COMMIT | windows.MEM_RESERVE, windows.PAGE_READWRITE) catch unreachable;

    // TODO: clear to black?
}

fn Win32UpdateWindow(hdc: user32.HDC, windowRect: *user32.RECT, x: i32, y: i32, width: i32, height: i32) void {
    //_ = w.stretchDIBits(hdc, x, y, width, height, x, y, width, height, &bitmapMemory, &bitmapInfo, w.DIB_RGB_COLORS, w.SRCCOPY) catch unreachable;
    const windowindowsidth = windowRect.right - windowRect.left;
    const windowHeight = windowRect.bottom - windowRect.top;
    _ = w.stretchDIBits(hdc, 0, 0, bitmapWidth, bitmapHeight, 0, 0, windowindowsidth, windowHeight, BitmapMemory, &bitmapInfo, w.DIB_RGB_COLORS, w.SRCCOPY) catch unreachable;
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
            // TODO: screen goes black while resizing.
            // calling RenderWeirdGradient fixes this but
            // we would have to make the offsets global
            // RenderWeirdGradient(0,0);
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
            Win32UpdateWindow(context, &paint.rcPaint, x, y, width, height);
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
    var xOffset:i8 = 0;
    var yOffset:i8 = 0;
    while (running) {
        var message: user32.MSG = undefined;
        while (user32.peekMessageW(&message, handle, 0, 0, user32.PM_REMOVE)) |more_messages| {
            if (!more_messages)  break;
            if (message.message == user32.WM_QUIT) {
                running = false;
            }
            _ = user32.translateMessage(&message);
            _ = user32.dispatchMessageW(&message);
        } else |err| {
            std.debug.print("error getMessageW: {}", .{err});
            return 1;
        }
        RenderWeirdGradient(xOffset, yOffset);

        const device_context = user32.getDC(handle) catch unreachable;
        defer _ = user32.ReleaseDC(handle, device_context);

        var clientRect: user32.RECT = undefined;
        _ = w.getClientRect(handle, &clientRect) catch unreachable;
        const windowWidth = clientRect.right - clientRect.left;
        const windowHeight = clientRect.bottom - clientRect.top;

        Win32UpdateWindow(device_context, &clientRect, 0, 0, windowWidth, windowHeight);
        xOffset +%= 1;
        yOffset +%= 1;
    }
    return 0;
}
