pub const GameOffscreenBuffer = struct {
    memory: *?[:0]c_uint,
    width: i32,
    height: i32,
    pitch: usize,
};

fn RenderWeirdGradient(buffer: *GameOffscreenBuffer, xOffset: i32, yOffset: i32) void {
    var row: usize = 0;
    var y: i32 = 0;
    while (y < buffer.height) : (y += 1) {
        var pixel: usize = row;
        var x: i32 = 0;
        while (x < buffer.width) : (x += 1) {
            var blue: u8 = @bitCast(u8, @truncate(i8, x + xOffset));
            var green: u8 = @bitCast(u8, @truncate(i8, y + yOffset));
            buffer.memory.*.?[pixel] = (@intCast(c_uint, green) << 8) | blue;
            pixel += 1;
        }
        row += buffer.pitch;
    }
}

pub fn GameUpdateAndRender(buffer: *GameOffscreenBuffer, blueOffset: i32, greenOffset: i32) void {
    RenderWeirdGradient(buffer, blueOffset, greenOffset);
}
