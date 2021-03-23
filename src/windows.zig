const std = @import("std");
const windows = std.os.windows;
const GetLastError = windows.kernel32.GetLastError;
usingnamespace std.os.windows;

pub const PAINTSTRUCT = extern struct {
    hdc: ?HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]BYTE,
};

pub extern "user32" fn PatBlt(hdc: HWND, x: c_int, y: c_int, w: c_int, h: c_int, rop: DWORD) callconv(WINAPI) BOOL;
pub fn patBlt(hWnd: HWND, x: i32, y: i32, w: i32, h: i32, rop: u32) bool {
    return if (PatBlt(hWnd, x, y, w, h, rop) != 0) true else false;
}

pub extern "user32" fn BeginPaint(hWnd: HWND, lpPaint: *PAINTSTRUCT) callconv(WINAPI) ?HWND;
pub fn beginPaint(hWnd: HWND, lpPaint: *PAINTSTRUCT) ?HWND {
    return BeginPaint(hWnd, lpPaint);
}

pub extern "user32" fn EndPaint(hWnd: HWND, lpPaint: *PAINTSTRUCT) callconv(WINAPI) BOOL;
pub fn endPaint(hWnd: HWND, lpPaint: *PAINTSTRUCT) bool {
    return if (EndPaint(hWnd, lpPaint) != 0) true else false;
}

pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(WINAPI) BOOL;
pub fn getClientRect(hWnd: HWND, lpRect: *RECT) !void {
    const r = GetClientRect(hWnd, lpRect);
    if (r != 0) return;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}
