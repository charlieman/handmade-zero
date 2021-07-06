const std = @import("std");
usingnamespace std.os.windows;
const DynLib = std.DynLib;
const zeroes = std.mem.zeroes;
const c = @cImport({
    @cInclude("dsound.h");
});

pub const DSBPLAY_LOOPING = 0x00000001;
pub const DirectSoundCreate = fn (pcGuidDevice: ?*c.GUID, ppDS: **IDirectSound, pUnkOuter: ?*c.IUnknown) HRESULT;

pub const IID = GUID;
pub const IDirectSoundVtbl = extern struct {
    QueryInterface: ?fn (*IDirectSound, *const IID, *LPVOID) callconv(.C) HRESULT,
    AddRef: ?fn (*IDirectSound) callconv(.C) ULONG,
    Release: ?fn (*IDirectSound) callconv(.C) ULONG,
    CreateSoundBuffer: ?fn (*IDirectSound, *const c.DSBUFFERDESC, **c.IDirectSoundBuffer, ?*c.IUnknown) callconv(.C) HRESULT,
    GetCaps: ?fn (*IDirectSound, *c.DSCAPS) callconv(.C) HRESULT,
    DuplicateSoundBuffer: ?fn (*IDirectSound, *c.IDirectSoundBuffer, **c.IDirectSoundBuffer) callconv(.C) HRESULT,
    SetCooperativeLevel: ?fn (*IDirectSound, HWND, DWORD) callconv(.C) HRESULT,
    Compact: ?fn (*IDirectSound) callconv(.C) HRESULT,
    GetSpeakerConfig: ?fn (*IDirectSound, LPDWORD) callconv(.C) HRESULT,
    SetSpeakerConfig: ?fn (*IDirectSound, DWORD) callconv(.C) HRESULT,
    Initialize: ?fn (*IDirectSound, *const GUID) callconv(.C) HRESULT,
};
pub const IDirectSound = extern struct {
    lpVtbl: *IDirectSoundVtbl,
};

pub inline fn succeeded(result: HRESULT) bool {
    return result >= 0;
}

pub var GlobalSoundBuffer: *c.IDirectSoundBuffer = undefined;

pub fn IDirectSoundBuffer_Play(p: *c.IDirectSoundBuffer, dwReserved1: c_ulong, dwReserved2: c_ulong, dwFlags: c_ulong) !void {
    const r = p.*.lpVtbl.*.Play.?(p, dwReserved1, dwReserved2, dwFlags);
    if (succeeded(r)) {
        return;
    }
    std.debug.print("IDirectSoundBuffer_Play Error: {}\n", .{r});
    return error.DirectSoundError;
}

pub inline fn IDirectSoundBuffer_Lock(p: anytype, a: anytype, b: anytype, c_: anytype, d: anytype, e: anytype, f: anytype, g: anytype) !void {
    const r = p.*.lpVtbl.*.Lock.?(p, a, b, c_, d, e, f, g);
    if (succeeded(r)) {
        return;
    }
    std.debug.print("IDirectSoundBuffer_Lock Error: {}\n", .{r});
    return error.DirectSoundError;
}
pub inline fn IDirectSoundBuffer_Unlock(a: anytype, b: anytype, c_: anytype, d: anytype) !void {
    const r = GlobalSoundBuffer.*.lpVtbl.*.Unlock.?(GlobalSoundBuffer, a, b, c_, d);
    if (succeeded(r)) {
        return;
    }
    std.debug.print("IDirectSoundBuffer_Unock Error: {}\n", .{r});
    return error.DirectSoundError;
}

pub inline fn IDirectSoundBuffer_GetCurrentPosition(a: anytype, b: anytype) !void {
    const r = GlobalSoundBuffer.*.lpVtbl.*.GetCurrentPosition.?(GlobalSoundBuffer, a, b);
    if (succeeded(r)) {
        return;
    }
    std.debug.print("IDirectSoundBuffer_GetCurrentPosition Error: {}\n", .{r});
    return error.DirectSoundError;
}

pub const win32_sound_output = struct {
    samplesPerSecond: u32,
    bytesPerSample: u32,
    soundBufferSize: DWORD,
    toneHz: u32,
    toneVolume: i32,
    wavePeriod: u32,
    runningSampleIndex: u32,
    tSine: f32,
    latencySampleCount: u32,
};

pub fn win32InitDSound(window: HWND, samplesPerSecond: u32, bufferSize: DWORD) void {
    var dsound_lib = DynLib.open("dsound.dll") catch return;

    if (dsound_lib.lookup(DirectSoundCreate, "DirectSoundCreate")) |directSoundCreate| {
        var directSound: *IDirectSound = undefined;
        var res = directSoundCreate(null, &directSound, null);
        if (succeeded(res)) {
            const nChannels = 2;
            const wBitsPerSample = 16;
            const nBlockAlign = @truncate(c_ushort, @divTrunc(nChannels * wBitsPerSample, 8));
            var waveFormat: c.WAVEFORMATEX = .{
                .wFormatTag = c.WAVE_FORMAT_PCM,
                .nChannels = nChannels,
                .nSamplesPerSec = samplesPerSecond,
                .nAvgBytesPerSec = nBlockAlign * samplesPerSecond,
                .nBlockAlign = nBlockAlign,
                .wBitsPerSample = wBitsPerSample,
                .cbSize = 0,
            };

            if (succeeded(directSound.*.lpVtbl.*.SetCooperativeLevel.?(directSound, window, c.DSSCL_PRIORITY))) {
                const bufferDescription: c.DSBUFFERDESC = .{
                    .dwSize = @sizeOf(c.DSBUFFERDESC),
                    .dwFlags = c.DSBCAPS_PRIMARYBUFFER,
                    .dwBufferBytes = 0,
                    .dwReserved = 0,
                    .lpwfxFormat = null,
                    .guid3DAlgorithm = zeroes(c.GUID),
                };
                var primaryBuffer: *c.IDirectSoundBuffer = undefined;
                if (succeeded(directSound.*.lpVtbl.*.CreateSoundBuffer.?(directSound, &bufferDescription, &primaryBuffer, null))) {
                    const result = primaryBuffer.*.lpVtbl.*.SetFormat.?(primaryBuffer, &waveFormat);
                    if (succeeded(result)) {
                        std.debug.print("Primary  buffer format was set\n", .{});
                    } else {
                        std.debug.print("Primary  buffer format error {}\n", .{result});
                    }
                }
            }

            const secondBufferDesc: c.DSBUFFERDESC = .{
                .dwSize = @sizeOf(c.DSBUFFERDESC),
                .dwFlags = 0,
                .dwBufferBytes = bufferSize,
                .dwReserved = 0,
                .lpwfxFormat = &waveFormat,
                .guid3DAlgorithm = zeroes(c.GUID),
            };
            var resSec = directSound.*.lpVtbl.*.CreateSoundBuffer.?(directSound, &secondBufferDesc, &GlobalSoundBuffer, null);
            if (succeeded(resSec)) {
                std.debug.print("CreateSoundBuffer GlobalSoundBuffer success\n", .{});
            } else {
                std.debug.print("Error CreateSoundBuffer GlobalSoundBuffer: {}\n", .{resSec});
            }
        } else {
            std.debug.print("Error DirectSoundCreate: {}\n", .{res});
        }
    }
}
var first = true;
pub fn win32FillSoundBuffer(soundOutput: *win32_sound_output, lockOffset: DWORD, bytesToWrite: DWORD) !void {
    var Region1: ?*c_void = undefined;
    var Region1Size: u32 = undefined;
    var Region2: ?*c_void = undefined;
    var Region2Size: u32 = undefined;

    if (bytesToWrite == 0) return;

    if (IDirectSoundBuffer_Lock(GlobalSoundBuffer, lockOffset, bytesToWrite, &Region1, &Region1Size, &Region2, &Region2Size, 0)) {
        const Region1SampleCount = Region1Size / soundOutput.bytesPerSample;
        var sampleOut = @ptrCast([*c]i16, @alignCast(@alignOf(i16), Region1));
        var sampleIndex: u32 = 0;
        while (sampleIndex < Region1SampleCount) : (sampleIndex +%= 1) {
            const sineValue: f32 = @sin(soundOutput.tSine);
            const sampleValue: i16 = @floatToInt(i16, sineValue * @intToFloat(f32, soundOutput.toneVolume));
            sampleOut.* = sampleValue;
            sampleOut += 1;
            sampleOut.* = sampleValue;
            sampleOut += 1;

            soundOutput.tSine += 2 * std.math.pi / @intToFloat(f32, soundOutput.wavePeriod);
            soundOutput.runningSampleIndex +%= 1;
        }
        first = false;

        const Region2SampleCount = Region2Size / soundOutput.bytesPerSample;
        sampleOut = @ptrCast([*c]i16, @alignCast(@alignOf(i16), Region2));
        sampleIndex = 0;
        while (sampleIndex < Region2SampleCount) : (sampleIndex +%= 1) {
            const sineValue: f32 = @sin(soundOutput.tSine);
            const sampleValue: i16 = @floatToInt(i16, sineValue * @intToFloat(f32, soundOutput.toneVolume));
            sampleOut.* = sampleValue;
            sampleOut += 1;
            sampleOut.* = sampleValue;
            sampleOut += 1;

            soundOutput.tSine += 2 * std.math.pi / @intToFloat(f32, soundOutput.wavePeriod);
            soundOutput.runningSampleIndex +%= 1;
        }

        IDirectSoundBuffer_Unlock(Region1, Region1Size, Region2, Region2Size) catch {};
    } else |_| {}
}
