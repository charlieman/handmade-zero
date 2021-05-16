const std = @import("std");
usingnamespace std.os.windows;
const DynLib = std.DynLib;

pub const ERROR_DEVICE_NOT_CONNECTED = 1167;
pub const XUSER_MAX_COUNT = 4;

pub const XINPUT_GAMEPAD = extern struct {
    wButtons: WORD,
    bLeftTrigger: BYTE,
    bRightTrigger: BYTE,
    sThumbLX: SHORT,
    sThumbLY: SHORT,
    sThumbRX: SHORT,
    sThumbRY: SHORT,

    // TODO: we could use this to check the buttons state here
    // const Self = @This();
    // pub fn APressed(self: Self) bool {
    //     return self.wButtons & GAMEPAD_A != 0;
    // }
};

pub const XINPUT_STATE = extern struct {
    dwPacketNumber: DWORD,
    Gamepad: XINPUT_GAMEPAD,
};

pub const XINPUT_VIBRATION = extern struct {
    wLeftMotorSpeed: WORD,
    wRightMotorSpeed: WORD,
};

pub const GAMEPAD_DPAD_UP = 0x0001;
pub const GAMEPAD_DPAD_DOWN = 0x0002;
pub const GAMEPAD_DPAD_LEFT = 0x0004;
pub const GAMEPAD_DPAD_RIGHT = 0x0008;
pub const GAMEPAD_START = 0x0010;
pub const GAMEPAD_BACK = 0x0020;
pub const GAMEPAD_LEFT_THUMB = 0x0040;
pub const GAMEPAD_RIGHT_THUMB = 0x0080;
pub const GAMEPAD_LEFT_SHOULDER = 0x0100;
pub const GAMEPAD_RIGHT_SHOULDER = 0x0200;
pub const GAMEPAD_A = 0x1000;
pub const GAMEPAD_B = 0x2000;
pub const GAMEPAD_X = 0x4000;
pub const GAMEPAD_Y = 0x8000;
pub const GAMEPAD_LEFT_THUMB_DEADZONE = 7849;
pub const GAMEPAD_RIGHT_THUMB_DEADZONE = 8689;
pub const GAMEPAD_TRIGGER_THRESHOLD = 30;

fn dummy_x_input_get_state(dwUserIndex: DWORD, pState: [*c]XINPUT_STATE) DWORD {
    return ERROR_DEVICE_NOT_CONNECTED;
}

fn dummy_x_input_set_state(dwUserIndex: DWORD, pVibration: [*c]const XINPUT_VIBRATION) DWORD {
    return ERROR_DEVICE_NOT_CONNECTED;
}

const x_input_get_state = fn (dwUserIndex: DWORD, pState: [*c]XINPUT_STATE) DWORD;
const x_input_set_state = fn (dwUserIndex: DWORD, pVibration: [*c]const XINPUT_VIBRATION) DWORD;

pub var xInputGetState = dummy_x_input_get_state;
pub var xInputSetState = dummy_x_input_set_state;

pub fn win32LoadXinput() void {
    var xinput_lib = DynLib.open("xinput1_4.dll") catch DynLib.open("xinput9_1_0.dll") catch DynLib.open("xinput1_3.dll") catch return;

    if (xinput_lib.lookup(x_input_get_state, "XInputGetState")) |func| {
        xInputGetState = func;
    }
    if (xinput_lib.lookup(x_input_set_state, "XInputSetState")) |func| {
        xInputSetState = func;
    }
}

const ERROR_SUCCESS = 0;

// TODO: should we return the controllerState instead of asking for one?
pub fn getState(controllerIndex: u32, controllerState: *XINPUT_STATE) !void {
    const r = xInputGetState(controllerIndex, controllerState);
    if (r == ERROR_SUCCESS) return;
    return switch (r) {
        ERROR_DEVICE_NOT_CONNECTED => error.DeviceNotConnected,
        else => unexpectedError(@intToEnum(Win32Error, @truncate(u16, r))),
    };
}

pub fn setState(controllerIndex: u32, vibration: *const XINPUT_VIBRATION) !void {
    const r = xInputSetState(controllerIndex, vibration);
    if (r == ERROR_SUCCESS) return;
    return switch (r) {
        ERROR_DEVICE_NOT_CONNECTED => error.DeviceNotConnected,
        else => unexpectedError(@intToEnum(Win32Error, @truncate(u16, r))),
    };
}
