const std = @import("std");
const user32 = std.os.windows.user32;
const L = std.unicode.utf8ToUtf16LeStringLiteral;
// const c = @cImport({
//     @cInclude("windows.h");
// });

// hack to let the main loop know it should close the window
var close_message = false;

// Responds to Windows' calls into this app
// https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms633573(v=vs.85)
fn MainWindowCallback(window_handle: user32.HWND, message: c_uint, wparam: usize, lparam: isize) callconv(.C) user32.LRESULT {
    // std.debug.print("callback: {any}, {x:4}, {x:4}, {x:4}\n", .{ window_handle, message, wparam, lparam });
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
            // var paint: c.LPPAINTSTRUCT = undefined;
            // var context = BeginPaint(window_handle, &paint);
            // const rect = paint.rcPaint;
            // const x = @as(c_int, rect.left);
            // const y = @as(c_int, rect.top);
            // const width = @as(c_int, rect.right - rect.left);
            // const height = @as(c_int, rect.bottom - rect.top);
            // c.PatBlt(context, rect.left, rect.top, width, height, .c.WHITENESS);
            // c.EndPaint(window_handle, &paint);
        },
        else => {
            return user32.defWindowProcW(window_handle, message, wparam, lparam);
        },
    }
    return result;
}

// replaces main, but you don't have to link libc in build.zig
pub fn wWinMain(instance: user32.HINSTANCE, prev: ?user32.HINSTANCE, cmdLine: user32.PWSTR, cmdShow: c_int) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;
    defer {
        const leaked = gpa.deinit();
        if (leaked) std.debug.print("Leaked!", .{});
    }

    const window_classname = L("HandmadeClass");
    const window_title = L("Handmade");

    var window_class: user32.WNDCLASSEXW = .{
        .style = 0,
        .lpszClassName = window_classname,
        .lpszMenuName = window_title,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpfnWndProc = MainWindowCallback,
        .hInstance = instance,
        .hIconSm = null,
    };
    const registered_class = user32.registerClassExW(&window_class) catch |err| {
        std.debug.print("error registerClassExW: {}", .{err});
        return 1;
    };

    var handle = user32.createWindowExW(0, window_class.lpszClassName, window_title, user32.WS_OVERLAPPEDWINDOW | user32.WS_VISIBLE, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, null, null, instance, null) catch |err| {
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
        // main loop?
    } else |err| {
        if (err == error.Quit) {
            return 0;
        }
        std.debug.print("error getMessageW: {}", .{err});
        return 1;
    }

    return 0;
}

fn helloworld() !void {
    const message = L("Hello World");
    const title = L("Hello");
    _ = user32.MessageBoxW(null, message, title, user32.MB_OK | user32.MB_ICONINFORMATION);
}
