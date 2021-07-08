const std = @import("std");
const user32 = std.os.windows.user32;
const w = @import("windows.zig");
const xinput = @import("xinput.zig");
const dsound = @import("dsound.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;
// const c = @cImport({
//     @cInclude("windows.h");
//     @cInclude("wingdi.h");
//     @cInclude("xinput.h");
// });
var allocator: *std.mem.Allocator = undefined;
//const allocator = std.heap.page_allocator;
//const allocator = std.testing.allocator;

const GameInput = @import("handmade.zig").GameInput;
const GameOffscreenBuffer = @import("handmade.zig").GameOffscreenBuffer;
const GameButtonState = @import("handmade.zig").GameButtonState;
const GameSoundOutputBuffer = @import("handmade.zig").GameSoundOutputBuffer;
const GameUpdateAndRender = @import("handmade.zig").GameUpdateAndRender;

const OffscreenBuffer = struct {
    info: w.BITMAPINFO = std.mem.zeroes(w.BITMAPINFO),
    memory: ?[:0]c_uint = null,
    width: i32 = undefined,
    height: i32 = undefined,
    bytesPerPixel: usize = undefined,
    pitch: usize = undefined,
};

//Globals
var running = false;
var backBuffer: OffscreenBuffer = .{
    .bytesPerPixel = 4,
};

const WindowSize = struct {
    width: i32,
    height: i32,
};

fn Win32GetWindowSize(window: user32.HWND) WindowSize {
    var clientRect: user32.RECT = undefined;
    _ = w.getClientRect(window, &clientRect) catch unreachable;
    const width = clientRect.right - clientRect.left;
    const height = clientRect.bottom - clientRect.top;
    return .{ .width = width, .height = height };
}

fn Win32ResizeDIBSection(buffer: *OffscreenBuffer, width: i32, height: i32) void {
    if (buffer.memory != null) {
        allocator.free(buffer.memory.?);
        buffer.memory = null;
    }
    buffer.width = width;
    buffer.height = height;
    buffer.bytesPerPixel = 4;
    buffer.pitch = @intCast(usize, width);

    buffer.info.bmiHeader.biSize = @sizeOf(w.BITMAPINFOHEADER);
    buffer.info.bmiHeader.biWidth = width;
    buffer.info.bmiHeader.biHeight = -height; // Negative for top-down drawing
    buffer.info.bmiHeader.biPlanes = 1;
    buffer.info.bmiHeader.biBitCount = 32;
    buffer.info.bmiHeader.biCompression = w.BI_RGB;

    const bitmapSize: usize = @intCast(usize, width * height);
    if (bitmapSize != 0) {
        // bitmapSize is 0 when the window is minimized
        buffer.memory = allocator.allocWithOptions(c_uint, bitmapSize, null, 0) catch unreachable;
    }
    // TODO: clear to black?
}

fn Win32UpdateWindow(hdc: user32.HDC, windowWidth: i32, windowHeight: i32, buffer: *OffscreenBuffer, x: i32, y: i32, width: i32, height: i32) void {
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    // TODO: Aspect ratio correction
    _ = w.stretchDIBits(hdc, 0, 0, windowWidth, windowHeight, 0, 0, buffer.width, buffer.height, buffer.memory.?.ptr, &buffer.info, w.DIB_RGB_COLORS, w.SRCCOPY) catch unreachable;
}

// Responds to Windows' calls into this app
// https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms633573(v=vs.85)
fn Win32MainWindowCallback(window: user32.HWND, message: c_uint, wparam: usize, lparam: isize) callconv(.C) user32.LRESULT {
    const result: user32.LRESULT = 0;
    switch (message) {
        user32.WM_SIZE => {
            // const windowSize = Win32GetWindowSize(window);
            // Win32ResizeDIBSection(&backBuffer, windowSize.width, windowSize.height);
            // TODO: screen goes black while resizing.
            // calling RenderWeirdGradient fixes this but
            // we would have to make the offsets global
            // RenderWeirdGradient(0,0);
        },
        user32.WM_ACTIVATE => {
            std.debug.print("WM_ACTIVATE\n", .{});
        },
        user32.WM_CLOSE => {
            std.debug.print("WM_CLOSE\n", .{});
            running = false;
        },
        user32.WM_DESTROY => {
            std.debug.print("WM_DESTROY\n", .{});
            running = false;
        },
        user32.WM_SYSKEYDOWN, user32.WM_SYSKEYUP, user32.WM_KEYDOWN, user32.WM_KEYUP => {
            const vKCode = @truncate(u8, wparam);
            const altDown = (lparam & (1 << 29)) != 0;
            const wasDown = (lparam & (1 << 30)) != 0;
            const isDown = (lparam & (1 << 31)) == 0;
            const justPressed = isDown and !wasDown;
            //const justReleased = !isDown and wasDown;
            switch (vKCode) {
                'W' => std.debug.print("W\n", .{}),
                'A' => std.debug.print("A\n", .{}),
                'S' => std.debug.print("S\n", .{}),
                'D' => std.debug.print("D\n", .{}),
                'Q' => std.debug.print("Q\n", .{}),
                'E' => std.debug.print("E\n", .{}),
                '1' => std.debug.print("1\n", .{}),
                '2' => std.debug.print("2\n", .{}),
                '3' => std.debug.print("3\n", .{}),
                '4' => std.debug.print("4\n", .{}),
                '5' => std.debug.print("5\n", .{}),
                w.VK_ESCAPE => {
                    std.debug.print("Esc ", .{});
                    if (isDown) {
                        std.debug.print("IsDown ", .{});
                    }
                    if (wasDown) {
                        std.debug.print("Was Down", .{});
                    }
                    std.debug.print("\n", .{});
                },
                w.VK_SPACE => std.debug.print("Spacebar\n", .{}),
                w.VK_LEFT => std.debug.print("LEFT\n", .{}),
                w.VK_UP => std.debug.print("UP\n", .{}),
                w.VK_RIGHT => std.debug.print("RIGHT\n", .{}),
                w.VK_DOWN => std.debug.print("DOWN\n", .{}),
                w.VK_PRINT => std.debug.print("PRINT\n", .{}),
                w.VK_F4 => {
                    if (altDown and justPressed) {
                        running = false;
                    }
                },
                else => {},
            }
        },
        user32.WM_PAINT => {
            var paint: w.PAINTSTRUCT = undefined;
            var context = w.beginPaint(window, &paint).?;
            defer _ = w.endPaint(window, &paint);

            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const width = paint.rcPaint.right - paint.rcPaint.left;
            const height = paint.rcPaint.bottom - paint.rcPaint.top;

            const windowSize = Win32GetWindowSize(window);
            Win32UpdateWindow(context, windowSize.width, windowSize.height, &backBuffer, x, y, width, height);
        },
        else => {
            return user32.defWindowProcW(window, message, wparam, lparam);
        },
    }
    return result;
}

fn win32FillSoundBuffer(soundOutput: *dsound.win32_sound_output, lockOffset: w.DWORD, bytesToWrite: w.DWORD, sourceBuffer: *GameSoundOutputBuffer) !void {
    var Region1: ?*c_void = undefined;
    var Region1Size: u32 = undefined;
    var Region2: ?*c_void = undefined;
    var Region2Size: u32 = undefined;

    if (bytesToWrite == 0) return;

    if (dsound.IDirectSoundBuffer_Lock(dsound.GlobalSoundBuffer, lockOffset, bytesToWrite, &Region1, &Region1Size, &Region2, &Region2Size, 0)) {
        var sourceIndex: usize = 0;

        const Region1SampleCount = Region1Size / soundOutput.bytesPerSample;
        var destSample = @ptrCast([*c]i16, @alignCast(@alignOf(i16), Region1));
        var sampleIndex: u32 = 0;

        while (sampleIndex < Region1SampleCount) : (sampleIndex +%= 1) {
            destSample.* = sourceBuffer.samples.*[sourceIndex];
            destSample += 1;
            sourceIndex += 1;
            destSample.* = sourceBuffer.samples.*[sourceIndex];
            destSample += 1;
            sourceIndex += 1;
            soundOutput.runningSampleIndex +%= 1;
        }

        const Region2SampleCount = Region2Size / soundOutput.bytesPerSample;
        destSample = @ptrCast([*c]i16, @alignCast(@alignOf(i16), Region2));
        sampleIndex = 0;
        while (sampleIndex < Region2SampleCount) : (sampleIndex +%= 1) {
            destSample.* = sourceBuffer.samples.*[sourceIndex];
            destSample += 1;
            sourceIndex += 1;
            destSample.* = sourceBuffer.samples.*[sourceIndex];
            destSample += 1;
            sourceIndex += 1;
            soundOutput.runningSampleIndex +%= 1;
        }

        dsound.IDirectSoundBuffer_Unlock(Region1, Region1Size, Region2, Region2Size) catch {};
    } else |_| {}
}

fn win32ClearSoundBuffer(soundOutput: *dsound.win32_sound_output) void {
    var Region1: ?*c_void = undefined;
    var Region1Size: u32 = undefined;
    var Region2: ?*c_void = undefined;
    var Region2Size: u32 = undefined;
    if (dsound.IDirectSoundBuffer_Lock(dsound.GlobalSoundBuffer, 0, soundOutput.soundBufferSize, &Region1, &Region1Size, &Region2, &Region2Size, 0)) {
        const Region1SampleCount = Region1Size / soundOutput.bytesPerSample;
        var destSample = @ptrCast([*c]i16, @alignCast(@alignOf(i16), Region1));
        var sampleIndex: u32 = 0;
        while (sampleIndex < Region1SampleCount) : (sampleIndex +%= 1) {
            destSample.* = 0;
            destSample += 1;
            destSample.* = 0;
            destSample += 1;
        }

        const Region2SampleCount = Region2Size / soundOutput.bytesPerSample;
        destSample = @ptrCast([*c]i16, @alignCast(@alignOf(i16), Region2));
        sampleIndex = 0;
        while (sampleIndex < Region2SampleCount) : (sampleIndex +%= 1) {
            destSample.* = 0;
            destSample += 1;
            destSample.* = 0;
            destSample += 1;
        }

        dsound.IDirectSoundBuffer_Unlock(Region1, Region1Size, Region2, Region2Size) catch {};
    } else |_| {}
}

fn Win32ProcessXInputDigitalButton(xinputButtonState: w.DWORD, oldState: *GameButtonState, buttonBit: w.DWORD, newState: *GameButtonState) void {
    newState.endedDown = (xinputButtonState & buttonBit) == buttonBit;
    newState.halfTransitionCounter = if (oldState.endedDown != newState.endedDown) 1 else 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit()) catch @panic("leak");
    allocator = &gpa.allocator;

    const instance = @ptrCast(user32.HINSTANCE, w.kernel32.GetModuleHandleW(null).?);
    var counterPerSecond = w.QueryPerformanceFrequency();
    xinput.win32LoadXinput();

    Win32ResizeDIBSection(&backBuffer, 1280, 720);
    defer Win32ResizeDIBSection(&backBuffer, 0, 0); // Frees the backBuffer.memory at the end

    const window_title = L("Handmade Zero");

    var windowClass: user32.WNDCLASSEXW = .{
        .lpfnWndProc = Win32MainWindowCallback,
        .hInstance = instance,
        .lpszClassName = L("HandmadeWindowClass"),
        .style = user32.CS_HREDRAW | user32.CS_VREDRAW | user32.CS_OWNDC,
        .lpszMenuName = null,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .hIconSm = null,
    };
    _ = user32.registerClassExW(&windowClass) catch |err| {
        std.debug.print("error registerClassExW: {}", .{err});
        return err;
    };

    var window = user32.createWindowExW(0, windowClass.lpszClassName, window_title, user32.WS_OVERLAPPEDWINDOW | user32.WS_VISIBLE, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, user32.CW_USEDEFAULT, null, null, instance, null) catch |err| {
        std.debug.print("error createWindowExW: {}", .{err});
        return err;
    };
    // CS_OWNDC in windowClass.style lets us keep the deviceContext forever
    const deviceContext = user32.getDC(window) catch unreachable;
    //defer _ = user32.ReleaseDC(window, deviceContext);

    // Sound Stuff

    var soundOutput = blk: {
        const samplesPerSecond = 48000;
        const bytesPerSample = @sizeOf(u16) * 2;
        break :blk dsound.win32_sound_output{
            .samplesPerSecond = samplesPerSecond,
            .bytesPerSample = bytesPerSample,
            .soundBufferSize = samplesPerSecond * bytesPerSample,
            .runningSampleIndex = 0,
            .latencySampleCount = samplesPerSecond / 15,
        };
    };

    dsound.win32InitDSound(window, soundOutput.samplesPerSecond, soundOutput.soundBufferSize);
    win32ClearSoundBuffer(&soundOutput);
    dsound.IDirectSoundBuffer_Play(dsound.GlobalSoundBuffer, 0, 0, dsound.DSBPLAY_LOOPING) catch {};

    var samples: []i16 = try allocator.alloc(i16, soundOutput.soundBufferSize);
    defer allocator.free(samples);

    var inputs: [2]GameInput = .{ std.mem.zeroes(GameInput), std.mem.zeroes(GameInput) };
    var newInput: *GameInput = &inputs[1];
    var oldInput: *GameInput = &inputs[0];

    //var lastCycleCounter = w.__rdtsc();
    var lastCounter = w.QueryPerformanceCounter();
    running = true;
    while (running) {
        var message: user32.MSG = undefined;
        while (user32.peekMessageW(&message, window, 0, 0, user32.PM_REMOVE)) |moreMessages| {
            if (!moreMessages) break;
            if (message.message == user32.WM_QUIT) {
                running = false;
            }
            _ = user32.translateMessage(&message);
            _ = user32.dispatchMessageW(&message);
        } else |err| {
            std.debug.print("error getMessageW: {}", .{err});
            return err;
        }
        // Controller

        var maxControllerCount = std.math.min(xinput.XUSER_MAX_COUNT, newInput.controllers.len);
        var controllerIndex: u32 = 0;
        while (controllerIndex < maxControllerCount) : (controllerIndex += 1) {
            var oldController = &oldInput.controllers[@as(usize, controllerIndex)];
            var newController = &newInput.controllers[@as(usize, controllerIndex)];

            var controllerState: xinput.XINPUT_STATE = undefined;
            if (xinput.getState(controllerIndex, &controllerState)) {
                const Pad = controllerState.Gamepad;
                // const Up: bool = Pad.wButtons & xinput.GAMEPAD_DPAD_UP != 0;
                // const Down: bool = Pad.wButtons & xinput.GAMEPAD_DPAD_DOWN != 0;
                // const Left: bool = Pad.wButtons & xinput.GAMEPAD_DPAD_LEFT != 0;
                // const Right: bool = Pad.wButtons & xinput.GAMEPAD_DPAD_RIGHT != 0;
                // const Start: bool = Pad.wButtons & xinput.GAMEPAD_START != 0;
                // const Back: bool = Pad.wButtons & xinput.GAMEPAD_BACK != 0;
                // const LeftShoulder: bool = Pad.wButtons & xinput.GAMEPAD_LEFT_SHOULDER != 0;
                // const RightShoulder: bool = Pad.wButtons & xinput.GAMEPAD_RIGHT_SHOULDER != 0;
                // const AButton: bool = Pad.wButtons & xinput.GAMEPAD_A != 0;
                // const BButton: bool = Pad.wButtons & xinput.GAMEPAD_B != 0;
                // const XButton: bool = Pad.wButtons & xinput.GAMEPAD_X != 0;
                // const YButton: bool = Pad.wButtons & xinput.GAMEPAD_Y != 0;

                Win32ProcessXInputDigitalButton(Pad.wButtons, &oldController.buttons.up, xinput.GAMEPAD_DPAD_UP, &newController.buttons.up);
                Win32ProcessXInputDigitalButton(Pad.wButtons, &oldController.buttons.down, xinput.GAMEPAD_DPAD_DOWN, &newController.buttons.down);
                Win32ProcessXInputDigitalButton(Pad.wButtons, &oldController.buttons.left, xinput.GAMEPAD_DPAD_LEFT, &newController.buttons.left);
                Win32ProcessXInputDigitalButton(Pad.wButtons, &oldController.buttons.right, xinput.GAMEPAD_DPAD_RIGHT, &newController.buttons.right);
                Win32ProcessXInputDigitalButton(Pad.wButtons, &oldController.buttons.leftShoulder, xinput.GAMEPAD_START, &newController.buttons.leftShoulder);
                Win32ProcessXInputDigitalButton(Pad.wButtons, &oldController.buttons.rightShoulder, xinput.GAMEPAD_BACK, &newController.buttons.rightShoulder);

                newController.isAnalog = true;
                newController.startX = oldController.endX;
                newController.startY = oldController.endY;
                // CHECK, it seems the max left is -32767 and not -32768
                const leftStickX: f32 = if (Pad.sThumbLX < 0) (@intToFloat(f32, Pad.sThumbLX) / 32767) else (@intToFloat(f32, Pad.sThumbLX) / 32767);
                const leftStickY: f32 = if (Pad.sThumbLY < 0) (@intToFloat(f32, Pad.sThumbLY) / 32767) else (@intToFloat(f32, Pad.sThumbLY) / 32767);
                newController.minX = leftStickX;
                newController.maxX = leftStickX;
                newController.endX = leftStickX;
                newController.minY = leftStickY;
                newController.maxY = leftStickY;
                newController.endY = leftStickY;

                // TODO: deadzone
            } else |_| {
                // Controller not available
            }
        }

        // Sound stuff
        var PlayCursor: w.DWORD = undefined;
        var WriteCursor: w.DWORD = undefined;
        var lockOffset: w.DWORD = undefined;
        var targetCursor: w.DWORD = undefined;
        var bytesToWrite: w.DWORD = undefined;
        var soundIsValid = false;
        if (dsound.IDirectSoundBuffer_GetCurrentPosition(&PlayCursor, &WriteCursor)) {
            lockOffset = (soundOutput.runningSampleIndex * soundOutput.bytesPerSample) % soundOutput.soundBufferSize;
            targetCursor = (PlayCursor + (soundOutput.latencySampleCount * soundOutput.bytesPerSample)) % soundOutput.soundBufferSize;
            bytesToWrite = blk: {
                if (lockOffset == targetCursor) {
                    break :blk 0;
                } else if (lockOffset > targetCursor) {
                    break :blk soundOutput.soundBufferSize - lockOffset + targetCursor;
                } else {
                    break :blk targetCursor - lockOffset;
                }
            };
            soundIsValid = true;
        } else |_| {}

        var soundBuffer: GameSoundOutputBuffer = .{
            .samplesPerSecond = soundOutput.samplesPerSecond,
            .sampleCount = @divTrunc(@intCast(i32, bytesToWrite), @intCast(i32, soundOutput.bytesPerSample)),
            .samples = &samples,
        };

        var buffer: GameOffscreenBuffer = .{
            .memory = &backBuffer.memory,
            .width = backBuffer.width,
            .height = backBuffer.height,
            .pitch = backBuffer.pitch,
        };

        GameUpdateAndRender(newInput, &buffer, &soundBuffer);

        if (soundIsValid) {
            win32FillSoundBuffer(&soundOutput, lockOffset, bytesToWrite, &soundBuffer) catch {};
        } else |_| {}

        const windowSize = Win32GetWindowSize(window);
        Win32UpdateWindow(deviceContext, windowSize.width, windowSize.height, &backBuffer, 0, 0, windowSize.width, windowSize.height);

        // var currentCycleCounter = w.__rdtsc();
        var currentCounter = w.QueryPerformanceCounter();
        var counterElapsed = currentCounter - lastCounter;
        // var cycleElapsed = currentCycleCounter - lastCycleCounter;
        var msPerFrame = 1000 * counterElapsed / counterPerSecond;
        var fps = counterPerSecond / counterElapsed;
        //var mcpf = cycleElapsed / (1000 * 1000);
        if (false) {
            std.debug.print("ms/f: {d}, fps: {d}, mc/f: {d}\n", .{ msPerFrame, fps, 0 });
        }
        lastCounter = currentCounter;
        // lastCycleCounter = currentCycleCounter;

        var temp = oldInput;
        oldInput = newInput;
        newInput = temp;
    }
}
