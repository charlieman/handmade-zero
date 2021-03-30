const std = @import("std");
usingnamespace std.os.windows;
const GetLastError = kernel32.GetLastError;

pub const GDI_ERROR = 0xFFFFFFFF;
pub const DIB_RGB_COLORS = 0;
pub const SRCCOPY = 0x00CC0020;
pub const BI_RGB = 0;
pub const HGDIOBJ = ?*c_void;

pub const PAINTSTRUCT = extern struct {
    hdc: ?HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]BYTE,
};
pub const HBITMAP = *opaque {};

pub const RGBQUAD = extern struct {
    rgbBlue: BYTE,
    rgbGreen: BYTE,
    rgbRed: BYTE,
    rgbReserved: BYTE,
};

pub const BITMAPINFOHEADER = extern struct {
    biSize: DWORD,
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD,
};

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
};

pub const VK_ESCAPE = 0x1B;
pub const VK_SPACE = 0x20;
pub const VK_LEFT = 0x25;
pub const VK_UP = 0x26;
pub const VK_RIGHT = 0x27;
pub const VK_DOWN = 0x28;
pub const VK_PRINT = 0x2A;
pub const VK_F4 = 0x73;

// TODO is simply changing HDC to HWND correct?
pub extern "user32" fn PatBlt(hdc: HWND, x: c_int, y: c_int, w: c_int, h: c_int, rop: DWORD) callconv(WINAPI) BOOL;
pub fn patBlt(hWnd: HWND, x: i32, y: i32, w: i32, h: i32, rop: u32) bool {
    return if (PatBlt(hWnd, x, y, w, h, rop) != 0) true else false;
}

pub extern "user32" fn BeginPaint(hWnd: HWND, lpPaint: *PAINTSTRUCT) callconv(WINAPI) ?HDC;
pub fn beginPaint(hWnd: HWND, lpPaint: *PAINTSTRUCT) ?HDC {
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
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn CreateDIBSection(hdc: HDC, pbmi: *BITMAPINFO, usage: c_uint, ppvBits: [*c]?*c_void, hSection: ?HANDLE, offset: DWORD) callconv(WINAPI) ?HBITMAP;
pub fn createDIBSection(hdc: HDC, pbmi: *BITMAPINFO, usage: c_uint, ppvBits: [*c]?*c_void, hSection: ?HANDLE, offset: DWORD) ?HBITMAP {
    return CreateDIBSection(hdc, pbmi, usage, ppvBits, hSection, offset);
}

// NOTE: Another way is to change lpBits to `?[*:0]const u32`
// Then I can use a slice instead of the slice's pointer
pub extern "user32" fn StretchDIBits(hdc: HDC, xDest: c_int, yDest: c_int, DestWidth: c_int, DestHeight: c_int, xSrc: c_int, ySrc: c_int, SrcWidth: c_int, SrcHeight: c_int, lpBits: ?*const c_void, lpbmi: *BITMAPINFO, iUsage: c_uint, rop: DWORD) callconv(WINAPI) c_int;
pub fn stretchDIBits(hdc: HDC, xDest: i32, yDest: i32, DestWidth: i32, DestHeight: i32, xSrc: i32, ySrc: i32, SrcWidth: i32, SrcHeight: i32, lpBits: ?*const c_void, lpbmi: *BITMAPINFO, iUsage: c_uint, rop: DWORD) !i32 {
    const r = StretchDIBits(hdc, xDest, yDest, DestWidth, DestHeight, xSrc, ySrc, SrcWidth, SrcHeight, lpBits, lpbmi, iUsage, rop);
    // TODO: check if we should really return an error if r == 0
    // if (r == 0) return error.SomeError;
    if (r == GDI_ERROR) return error.GdiError;
    return r;
}

pub extern "user32" fn DeleteObject(ho: ?LPVOID) callconv(WINAPI) BOOL;
pub fn deleteObject(ho: ?*c_void) bool {
    return if (DeleteObject(ho) != 0) true else false;
}

pub extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(WINAPI) ?HDC;
pub fn createCompatibleDC(hdc: ?HDC) ?HDC {
    return CreateCompatibleDC(hdc);
}
