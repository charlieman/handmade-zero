const std = @import("std");
const user32 = std.os.windows.user32;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn main() anyerror!void {
    const message = L("Hello World");
    const title = L("Hello");
    _ = user32.MessageBoxW(null, message, title, user32.MB_OK | user32.MB_ICONINFORMATION);
}
