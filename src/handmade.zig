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

pub const GameButtonState = struct {
    halfTransitionCounter: u32,
    endedDown: bool,
};

pub const GameButtons = struct {
    up: GameButtonState,
    down: GameButtonState,
    left: GameButtonState,
    right: GameButtonState,
    leftShoulder: GameButtonState,
    rightShoulder: GameButtonState,
};

pub const GameControllerInput = struct {
    isAnalog: bool,

    startX: f32,
    startY: f32,

    minX: f32,
    minY: f32,

    maxX: f32,
    maxY: f32,

    endX: f32,
    endY: f32,

    buttons: GameButtons,
};

pub const GameInput = struct {
    controllers: [4]GameControllerInput,
};

fn GameOutputSound(soundBuffer: *GameSoundOutputBuffer, toneHz: u32) void {
    const S = struct {
        var tSine: f32 = 0;
    };
    const toneVolume: f32 = 2000;
    const wavePeriod: f32 = @intToFloat(f32, soundBuffer.samplesPerSecond / toneHz);

    var byteIndex: usize = 0;
    var sampleIndex: u32 = 0;
    while (sampleIndex < soundBuffer.sampleCount) : (sampleIndex += 1) {
        const sineValue: f32 = @sin(S.tSine);
        const sampleValue: i16 = @floatToInt(i16, sineValue * toneVolume);
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

pub fn GameUpdateAndRender(input: *GameInput, buffer: *GameOffscreenBuffer, soundBuffer: *GameSoundOutputBuffer) void {
    const S = struct {
        var toneHz: u32 = 256; // Approximation to 261.62 Hz which is middle C
        var blueOffset: i32 = 0;
        var greenOffset: i32 = 0;
    };

    var controller0 = input.controllers[0];
    if (controller0.buttons.up.endedDown) {
        S.greenOffset += 1;
    }
    if (controller0.isAnalog) {
        S.blueOffset += @floatToInt(i32, 4 * controller0.endX);
        S.toneHz = @intCast(u32, 256 + @floatToInt(i32, 128 * controller0.endY));
    }

    // TODO: Allow sample offsets for more robust platform options
    GameOutputSound(soundBuffer, S.toneHz);
    RenderWeirdGradient(buffer, S.blueOffset, S.greenOffset);
}
