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

const OffscreenBuffer = struct {
    info: w.BITMAPINFO = std.mem.zeroes(w.BITMAPINFO),
    memory: ?*c_void = null,
    width: i32 = undefined,
    height: i32 = undefined,
    bytesPerPixel: usize = undefined,
    pitch: usize = undefined,
};

//Globals
var running = false;
var backBuffer: OffscreenBuffer = .{
    .bytesPerPixel = 4,
};

fn RenderWeirdGradient(buffer: *OffscreenBuffer, xOffset: i32, yOffset: i32) void {
    // TODO: This is directly translated from C, how to do it in Zig?
    var row: [*c]u8 = @ptrCast([*c]u8, @alignCast(@alignOf(u8), buffer.memory));
    var y: i32 = 0;
    while (y < buffer.height) : (y += 1) {
        var pixel: [*c]u32 = @ptrCast([*c]u32, @alignCast(@alignOf(u32), row));
        var x: i32 = 0;
        while (x < buffer.width) : (x += 1) {
            var blue: u8 = @bitCast(u8, @truncate(i8, x + xOffset));
            var green: u8 = @bitCast(u8, @truncate(i8, y + xOffset));
            pixel.?.* = (@intCast(u32, green) << 8) | blue;
            pixel += 1;
        }
        row += buffer.pitch;
    }
}

const WindowSize = struct {
    width: i32,
    height: i32,
};

fn Win32GetWindowSize(window: user32.HWND) WindowSize {
    var clientRect: user32.RECT = undefined;
    _ = w.getClientRect(window, &clientRect) catch unreachable;
    const width = clientRect.right - clientRect.left;
    const height = clientRect.bottom - clientRect.top;
    return .{ .width = width, .height = height };
}

fn Win32ResizeDIBSection(buffer: *OffscreenBuffer, width: i32, height: i32) void {
    if (buffer.memory != null) {
        _ = windows.VirtualFree(buffer.memory.?, 0, windows.MEM_RELEASE);
        buffer.memory = null;
    }
    buffer.width = width;
    buffer.height = height;
    buffer.bytesPerPixel = 4;
    buffer.pitch = @as(usize, @bitCast(u32, width)) * buffer.bytesPerPixel;

    buffer.info.bmiHeader.biSize = @sizeOf(w.BITMAPINFOHEADER);
    buffer.info.bmiHeader.biWidth = width;
    buffer.info.bmiHeader.biHeight = -height;
    buffer.info.bmiHeader.biPlanes = 1;
    buffer.info.bmiHeader.biBitCount = 32;
    buffer.info.bmiHeader.biCompression = w.BI_RGB;

    const bitmapMemorySize: usize = @intCast(usize, width * height) * buffer.bytesPerPixel;
    if (bitmapMemorySize != 0) {
        // bitmapMemorySize is 0 when the window is minimized
        buffer.memory = windows.VirtualAlloc(null, bitmapMemorySize, windows.MEM_COMMIT | windows.MEM_RESERVE, windows.PAGE_READWRITE) catch unreachable;
    }
    // TODO: clear to black?
}

fn Win32UpdateWindow(hdc: user32.HDC, windowWidth: i32, windowHeight: i32, buffer: *OffscreenBuffer, x: i32, y: i32, width: i32, height: i32) void {
    _ = w.stretchDIBits(hdc, 0, 0, buffer.width, buffer.height, 0, 0, windowWidth, windowHeight, buffer.memory, &buffer.info, w.DIB_RGB_COLORS, w.SRCCOPY) catch unreachable;
}

// Responds to Windows' calls into this app
// https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms633573(v=vs.85)
fn Win32MainWindowCallback(window: user32.HWND, message: c_uint, wparam: usize, lparam: isize) callconv(.C) user32.LRESULT {
    const result: user32.LRESULT = 0;
    switch (message) {
        user32.WM_SIZE => {
            const windowSize = Win32GetWindowSize(window);
            Win32ResizeDIBSection(&backBuffer, windowSize.width, windowSize.height);
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
            var context = w.beginPaint(window, &paint).?;
            defer _ = w.endPaint(window, &paint);

            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const width = paint.rcPaint.right - paint.rcPaint.left;
            const height = paint.rcPaint.bottom - paint.rcPaint.top;

            const windowSize = Win32GetWindowSize(window);
            Win32UpdateWindow(context, windowSize.width, windowSize.height, &backBuffer, x, y, width, height);
        },
        else => {
            return user32.defWindowProcW(window, message, wparam, lparam);
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
    const window_title = L("Handmade Zero");

    var windowClass: user32.WNDCLASSEXW = .{
        .lpfnWndProc = Win32MainWindowCallback,
        .hInstance = instance,
        .lpszClassName = L("HandmadeWindowClass"),
        .style = 0,
        .lpszMenuName = null,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .hIconSm = null,
    };
    const registeredClass = user32.registerClassExW(&windowClass) catch |err| {
        std.debug.print("error registerClassExW: {}", .{err});
        return 1;
    };

    var window = user32.createWindowExW(user32.CS_OWNDC | user32.CS_HREDRAW | user32.CS_VREDRAW, windowClass.lpszClassName, window_title, user32.WS_OVERLAPPEDWINDOW | user32.WS_VISIBLE, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, null, null, instance, null) catch |err| {
        std.debug.print("error createWindowExW: {}", .{err});
        return 1;
    };

    running = true;
    var xOffset: i8 = 0;
    var yOffset: i8 = 0;
    while (running) {
        var message: user32.MSG = undefined;
        while (user32.peekMessageW(&message, window, 0, 0, user32.PM_REMOVE)) |moreMessages| {
            if (!moreMessages) break;
            if (message.message == user32.WM_QUIT) {
                running = false;
            }
            _ = user32.translateMessage(&message);
            _ = user32.dispatchMessageW(&message);
        } else |err| {
            std.debug.print("error getMessageW: {}", .{err});
            return 1;
        }
        RenderWeirdGradient(&backBuffer, xOffset, yOffset);

        const deviceContext = user32.getDC(window) catch unreachable;
        defer _ = user32.ReleaseDC(window, deviceContext);

        const windowSize = Win32GetWindowSize(window);
        Win32UpdateWindow(deviceContext, windowSize.width, windowSize.height, &backBuffer, 0, 0, windowSize.width, windowSize.height);
        xOffset +%= 1;
        yOffset +%= 1;
    }
    return 0;
}
