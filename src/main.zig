const std = @import("std");
const user32 = std.os.windows.user32;

pub fn main() anyerror!void {
    //const message = try std.os.windows.sliceToPrefixedFileW("Hello");
    const message = "Hello";
    var wide_message: [100:0]u16 = [_:0]u16{0} ** 100;
    const i = std.unicode.utf8ToUtf16Le(wide_message[0..], message);
    _ = user32.MessageBoxW(null, wide_message[0..], wide_message[0..], user32.MB_OK | user32.MB_ICONINFORMATION);
}
