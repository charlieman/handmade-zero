#include <windows.h>

#define internal static
#define local_persist static
#define global_variable static

global_variable BOOL Running;

global_variable BITMAPINFO BitmapInfo;
global_variable void *BitmapMemory;
global_variable HBITMAP BitmapHandle;
global_variable HDC BitmapDeviceContext;

internal void Win32ResizeDIBSection(int Width, int Height)
{
    if (BitmapHandle)
    {
        DeleteObject(BitmapHandle);
    }
    if (!BitmapDeviceContext)
    {
        BitmapDeviceContext = CreateCompatibleDC(0);
    }
    BitmapInfo.bmiHeader.biSize = sizeof(BitmapInfo.bmiHeader);
    BitmapInfo.bmiHeader.biWidth = Width;
    BitmapInfo.bmiHeader.biHeight = Height;
    BitmapInfo.bmiHeader.biPlanes = 1;
    BitmapInfo.bmiHeader.biBitCount = 32;
    BitmapInfo.bmiHeader.biCompression = BI_RGB;

    BitmapHandle = CreateDIBSection(BitmapDeviceContext, &BitmapInfo, DIB_RGB_COLORS, &BitmapMemory, 0, 0);
}

internal void Win32UpdateWindow(HDC hdc, int X, int Y, int Width, int Height)
{
    StretchDIBits(hdc,
                  X, Y, Width, Height,
                  X, Y, Width, Height,
                  BitmapMemory, &BitmapInfo,
                  DIB_RGB_COLORS, SRCCOPY);
}

LRESULT CALLBACK MainWindowCallback(HWND Window, UINT Message, WPARAM WParam, LPARAM LParam)
{
    LRESULT Result = 0;
    switch (Message)
    {
    case WM_SIZE:
    {
        RECT ClientRect;
        GetClientRect(Window, &ClientRect);
        int Width = ClientRect.right - ClientRect.left;
        int Height = ClientRect.bottom - ClientRect.top;
        Win32ResizeDIBSection(Width, Height);
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
        int X = Paint.rcPaint.left;
        int Y = Paint.rcPaint.top;
        int W = Paint.rcPaint.right - Paint.rcPaint.left;
        int H = Paint.rcPaint.bottom - Paint.rcPaint.top;

        Win32UpdateWindow(DeviceContext, X, Y, W, H);
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
    WNDCLASS WindowClass = {0};
    WindowClass.lpfnWndProc = MainWindowCallback;
    WindowClass.hInstance = Instance;
    WindowClass.lpszClassName = L"HandMadeWindowClass";

    if (RegisterClassA(&WindowClass) == 0)
    {
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
            OutputDebugStringA("MessageResult <= 0\n");
            break;
        }
    }
    return 0;
}
