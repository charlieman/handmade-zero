const std = @import("std");
usingnamespace std.os.windows;
const DynLib = std.DynLib;
const zeroes = std.mem.zeroes;
const c = @cImport({
    @cInclude("dsound.h");
});

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

fn succeeded(result: HRESULT) callconv(.Inline) bool {
    return result >= 0;
}

pub fn win32InitDSound(window: HWND, samplesPerSecond: u32, bufferSize: i32) void {
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
                .dwBufferBytes = @intCast(c_ulong, bufferSize),
                .dwReserved = 0,
                .lpwfxFormat = &waveFormat,
                .guid3DAlgorithm = zeroes(c.GUID),
            };
            var secondaryBuffer: *c.IDirectSoundBuffer = undefined;
            var resSec = directSound.*.lpVtbl.*.CreateSoundBuffer.?(directSound, &secondBufferDesc, &secondaryBuffer, null);
            if (succeeded(resSec)) {
                std.debug.print("CreateSoundBuffer SecondaryBuffer success\n", .{});
            } else {
                std.debug.print("Error CreateSoundBuffer SecondaryBuffer: {}\n", .{resSec});
            }
        } else {
            std.debug.print("Error DirectSoundCreate: {}\n", .{res});
        }
    }
}
