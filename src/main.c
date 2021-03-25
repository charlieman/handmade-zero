#include <windows.h>
#include <stdint.h>

#define internal static
#define local_persist static
#define global_variable static

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

global_variable BOOL Running;

global_variable BITMAPINFO BitmapInfo;
global_variable void *BitmapMemory;
global_variable int BitmapWidth;
global_variable int BitmapHeight;
global_variable int BytesPerPixel = 4;

internal void RenderWeirdGradient(int XOffset, int YOffset)
{
    int Width = BitmapWidth;
    int Pitch = Width * BytesPerPixel;
    uint8 *Row = (uint8 *)BitmapMemory;
    for (int Y = 0; Y < BitmapHeight; ++Y)
    {
        //uint32 *Pixel = (uint32 *)Row;
        uint32 *Pixel = (uint32 *)Row;
        for (int X = 0; X < BitmapWidth; ++X)
        {
            /*
            Pixel address    +0 +1 +2 +3
            Pixel in memory: 00 00 00 00
            RGB Order:       BB GG RR XX (little endian architecture)
            */
            uint8 Blue = X + XOffset;
            uint8 Green = Y + YOffset;
            *Pixel++ = ((Green << 8) | Blue);
        }
        Row += Pitch;
    }
}

internal void Win32ResizeDIBSection(int Width, int Height)
{
    if (BitmapMemory)
    {
        VirtualFree(BitmapMemory, 0, MEM_RELEASE);
    }
    BitmapWidth = Width;
    BitmapHeight = Height;

    BitmapInfo.bmiHeader.biSize = sizeof(BitmapInfo.bmiHeader);
    BitmapInfo.bmiHeader.biWidth = BitmapWidth;
    BitmapInfo.bmiHeader.biHeight = -BitmapHeight; // negative so we render top-down
    BitmapInfo.bmiHeader.biPlanes = 1;
    BitmapInfo.bmiHeader.biBitCount = 32;
    BitmapInfo.bmiHeader.biCompression = BI_RGB;

    int BitmapMemorySize = (Width * Height) * BytesPerPixel;
    BitmapMemory = VirtualAlloc(0, BitmapMemorySize, MEM_COMMIT, PAGE_READWRITE);
    RenderWeirdGradient(128, 0);
}

internal void Win32UpdateWindow(HDC hdc, RECT *WindowRect, int X, int Y, int Width, int Height)
{
    int WindowWidth = WindowRect->right - WindowRect->left;
    int WindowHeight = WindowRect->bottom - WindowRect->top;
    StretchDIBits(hdc,
                  0, 0, BitmapWidth, BitmapHeight,
                  0, 0, WindowWidth, WindowHeight,
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
        Running = 0;
    }
    break;

    case WM_DESTROY:
    {
        OutputDebugStringA("WM_DESTROY\n");
        Running = 0;
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

        RECT ClientRect;
        GetClientRect(Window, &ClientRect);

        Win32UpdateWindow(DeviceContext, &ClientRect, X, Y, W, H);
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
    int8 XOffset = 0;
    int8 YOffset = 0;
    Running = 1;
    while (Running)
    {
        MSG Message;
        while (PeekMessage(&Message, WindowHandle, 0, 0, PM_REMOVE))
        {
            if (Message.message == WM_QUIT)
            {
                Running = 0;
            }
            TranslateMessage(&Message);
            DispatchMessage(&Message);
        }
        RenderWeirdGradient(XOffset, YOffset);

        HDC DeviceContext = GetDC(WindowHandle);

        RECT ClientRect;
        GetClientRect(WindowHandle, &ClientRect);
        int Width = ClientRect.right - ClientRect.left;
        int Height = ClientRect.bottom - ClientRect.top;
        Win32UpdateWindow(DeviceContext, &ClientRect, 0, 0, Width, Height);
        ReleaseDC(WindowHandle, DeviceContext);

        ++XOffset;
        ++YOffset;
    }
    return 0;
}
