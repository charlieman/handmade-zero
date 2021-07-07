const std = @import("std");

pub const GameOffscreenBuffer = struct {
    memory: *?[:0]c_uint,
    width: i32,
    height: i32,
    pitch: usize,
};

pub const GameSoundOutputBuffer = struct {
    samples: *[]i16,
    samplesPerSecond: u32,
    sampleCount: i32,
};

fn GameOutputSound(soundBuffer: *GameSoundOutputBuffer, toneHz: u32) void {
    const S = struct {
        var tSine: f32 = 0;
    };
    const toneVolume: i16 = 2000;
    const wavePeriod: f32 = @intToFloat(f32, soundBuffer.samplesPerSecond / toneHz);

    var byteIndex: usize = 0;
    var sampleIndex: u32 = 0;
    while (sampleIndex < soundBuffer.sampleCount) : (sampleIndex += 1) {
        const sineValue: f32 = @sin(S.tSine);
        const sampleValue: i16 = @floatToInt(i16, sineValue * @intToFloat(f32, toneVolume));
        soundBuffer.samples.*[byteIndex] = sampleValue;
        byteIndex += 1;
        soundBuffer.samples.*[byteIndex] = sampleValue;
        byteIndex += 1;

        S.tSine += 2 * std.math.pi / wavePeriod;
    }
}

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

pub fn GameUpdateAndRender(buffer: *GameOffscreenBuffer, blueOffset: i32, greenOffset: i32, soundBuffer: *GameSoundOutputBuffer, toneHz: u32) void {
    // TODO: Allow sample offsets for more robust platform options
    GameOutputSound(soundBuffer, toneHz);
    RenderWeirdGradient(buffer, blueOffset, greenOffset);
}
