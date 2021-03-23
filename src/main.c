#include <windows.h>
#include <stdio.h>

LRESULT CALLBACK MainWindowCallback(HWND Window, UINT Message, WPARAM WParam, LPARAM LParam)
{
    LRESULT Result = 0;
    switch (Message)
    {
    case WM_SIZE:
    {
        OutputDebugStringA("WM_SIZE\n");
    }
    break;

    case WM_ACTIVATEAPP:
    {
        OutputDebugStringA("WM_ACTIVATEAPP\n");
    }
    break;

    case WM_CLOSE:
    {
        OutputDebugStringA("WM_CLOSE\n");
        PostQuitMessage(0);
    }
    break;

    case WM_DESTROY:
    {
        OutputDebugStringA("WM_DESTROY\n");
        exit(0);
    }
    break;

    case WM_PAINT:
    {
        PAINTSTRUCT Paint;
        HDC DeviceContext = BeginPaint(Window, &Paint);
        LONG X = Paint.rcPaint.left;
        LONG Y = Paint.rcPaint.top;
        LONG W = Paint.rcPaint.right - Paint.rcPaint.left;
        LONG H = Paint.rcPaint.bottom - Paint.rcPaint.top;
        LONG HalfWidth = W / 2;

        PatBlt(DeviceContext, X, Y, HalfWidth, H, WHITENESS);
        PatBlt(DeviceContext, X + HalfWidth, Y, HalfWidth, H, BLACKNESS);
        EndPaint(Window, &Paint);
    }
    break;

    default:
    {
        // todo
        Result = DefWindowProcW(Window, Message, WParam, LParam);
    }
    break;
    }
    return Result;
}

int CALLBACK WinMain(
    HINSTANCE Instance,
    HINSTANCE PrevInstance,
    LPSTR CommandLine,
    int ShowCode)
{
    puts("Hello world from puts\n");
    OutputDebugStringA("hello from OutputDebugStringA\n");
    WNDCLASS WindowClass = {0};
    WindowClass.lpfnWndProc = MainWindowCallback;
    WindowClass.hInstance = Instance;
    WindowClass.lpszClassName = L"HandMadeWindowClass";

    if (RegisterClassA(&WindowClass) == 0)
    {
        puts("RegisterClassA == 0\n");
        OutputDebugStringA("RegisterClassA == 0\n");
        return 1;
    }
    HWND WindowHandle = CreateWindowExA(
        CS_OWNDC | CS_HREDRAW | CS_VREDRAW,
        WindowClass.lpszClassName, L"Handmade hero",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        0, 0,
        Instance, 0);
    if (WindowHandle == 0)
    {
        puts("WindowHandle == 0\n");
        OutputDebugStringA("WindowHandle == 0\n");
        return 2;
    }
    MSG Message;
    for (;;)
    {
        BOOL MessageResult = GetMessageA(&Message, WindowHandle, 0, 0);
        if (MessageResult > 0)
        {
            TranslateMessage(&Message);
            DispatchMessage(&Message);
        }
        else
        {
            puts("MessageResult <= 0\n");
            OutputDebugStringA("MessageResult <= 0\n");
            break;
        }
    }
    return 0;
}
