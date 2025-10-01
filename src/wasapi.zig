// Low-level WASAPI bindings - internal use only
const std = @import("std");
const builtin = @import("builtin");

const windows = std.os.windows;

// Internal Windows types
pub const HRESULT = windows.HRESULT;
pub const REFERENCE_TIME = windows.LONGLONG;
pub const BYTE = windows.BYTE;
pub const UINT32 = u32;
pub const DWORD = windows.DWORD;
pub const WORD = windows.WORD;
pub const GUID = windows.GUID;
const ULONG = windows.ULONG;
const UINT = windows.UINT;
const LPWSTR = windows.LPWSTR;
const LPCWSTR = windows.LPCWSTR;
const LPVOID = windows.LPVOID;
const HANDLE = windows.HANDLE;

const WINAPI: std.builtin.CallingConvention = if (builtin.cpu.arch == .x86) .{ .x86_stdcall = .{} } else .c;

// COM constants
pub const COINIT_MULTITHREADED = 0x0;
pub const CLSCTX_ALL = 0x17;

pub const REFTIMES_PER_SEC = 10000000;
pub const REFTIMES_PER_MILLISEC = 10000;

// Out-only types we only need as opaque pointers for now:
const PROPVARIANT = opaque {};
const IPropertyStore = opaque {};

// SUCCEEDED/FAILED helpers
pub inline fn SUCCEEDED(hr: HRESULT) bool {
    return hr >= 0;
}
pub inline fn FAILED(hr: HRESULT) bool {
    return hr < 0;
}

pub inline fn safeRelease(ptr: anytype) void {
    if (ptr) |obj| {
        _ = obj.Release();
    }
}

// External COM functions
pub extern "ole32" fn CoInitializeEx(pvReserved: ?LPVOID, dwCoInit: DWORD) callconv(WINAPI) HRESULT;
pub extern "ole32" fn CoUninitialize() callconv(WINAPI) void;
pub extern "ole32" fn CoCreateInstance(rclsid: *const GUID, pUnkOuter: ?*anyopaque, dwClsContext: DWORD, riid: *const GUID, ppv: *?LPVOID) callconv(WINAPI) HRESULT;
pub extern "ole32" fn CoTaskMemFree(pv: ?LPVOID) callconv(WINAPI) void;

pub const WAVEFORMATEX = extern struct {
    wFormatTag: WORD,
    nChannels: WORD,
    nSamplesPerSec: DWORD,
    nAvgBytesPerSec: DWORD,
    nBlockAlign: WORD,
    wBitsPerSample: WORD,
    cbSize: WORD,
};

pub const WAVEFORMATEXTENSIBLE = extern struct {
    Format: WAVEFORMATEX,
    Samples: extern union {
        wValidBitsPerSample: WORD,
        wSamplesPerBlock: WORD,
        wReserved: WORD,
    },
    dwChannelMask: DWORD,
    SubFormat: GUID,
};

// Audio format constants
pub const WAVE_FORMAT_PCM = 1;
pub const WAVE_FORMAT_IEEE_FLOAT = 3;
pub const WAVE_FORMAT_EXTENSIBLE = 0xFFFE;

const DEVICE_STATE_ACTIVE = 0x1;
const DEVICE_STATE_DISABLED = 0x2;
const DEVICE_STATE_NOTPRESENT = 0x4;
const DEVICE_STATE_UNPLUGGED = 0x8;

// GUIDs - internal constants
pub const CLSID_MMDeviceEnumerator = GUID{
    .Data1 = 0xBCDE0395,
    .Data2 = 0xE52F,
    .Data3 = 0x467C,
    .Data4 = [8]u8{ 0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E },
};

pub const IID_IMMDeviceEnumerator = GUID{
    .Data1 = 0xA95664D2,
    .Data2 = 0x9614,
    .Data3 = 0x4F35,
    .Data4 = [8]u8{ 0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6 },
};

const IID_IMMDeviceCollection = GUID{
    .Data1 = 0x0BD7A18E,
    .Data2 = 0x7A1A,
    .Data3 = 0x44DB,
    .Data4 = [8]u8{ 0x83, 0x97, 0xCC, 0x53, 0x92, 0x38, 0x7B, 0x5E },
};

pub const IID_IAudioClient = GUID{
    .Data1 = 0x1CB9AD4C,
    .Data2 = 0xDBFA,
    .Data3 = 0x4c32,
    .Data4 = [8]u8{ 0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2 },
};

pub const IID_IAudioRenderClient = GUID{
    .Data1 = 0xF294ACFC,
    .Data2 = 0x3146,
    .Data3 = 0x4483,
    .Data4 = [8]u8{ 0xA7, 0xBF, 0xAD, 0xDC, 0xA7, 0xC2, 0x60, 0xE2 },
};

pub const KSDATAFORMAT_SUBTYPE_PCM = GUID{
    .Data1 = 0x00000001,
    .Data2 = 0x0000,
    .Data3 = 0x0010,
    .Data4 = [8]u8{ 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 },
};

pub const KSDATAFORMAT_SUBTYPE_IEEE_FLOAT = GUID{
    .Data1 = 0x00000003,
    .Data2 = 0x0000,
    .Data3 = 0x0010,
    .Data4 = [8]u8{ 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 },
};

// WASAPI enums
pub const EDataFlow = enum(c_int) {
    eRender = 0,
    eCapture = 1,
    eAll = 2,
};

pub const ERole = enum(c_int) {
    eConsole = 0,
    eMultimedia = 1,
    eCommunications = 2,
};

pub const AUDCLNT_SHAREMODE = enum(c_int) {
    AUDCLNT_SHAREMODE_SHARED = 0,
    AUDCLNT_SHAREMODE_EXCLUSIVE = 1,
};

pub const IMMDeviceEnumerator = extern struct {
    lpVtbl: *const IMMDeviceEnumeratorVtbl,

    inline fn QueryInterface(
        self: *IMMDeviceEnumerator,
        riid: *const GUID,
        out_ppv: *?*anyopaque,
    ) HRESULT {
        return self.lpVtbl.QueryInterface(self, riid, out_ppv);
    }
    inline fn AddRef(self: *IMMDeviceEnumerator) ULONG {
        return self.lpVtbl.AddRef(self);
    }
    inline fn Release(self: *IMMDeviceEnumerator) ULONG {
        return self.lpVtbl.Release(self);
    }
    pub inline fn EnumAudioEndpoints(
        self: *IMMDeviceEnumerator,
        dataFlow: EDataFlow,
        dwStateMask: DWORD,
        out_ppDevices: *?*IMMDeviceCollection,
    ) HRESULT {
        return self.lpVtbl.EnumAudioEndpoints(self, dataFlow, dwStateMask, out_ppDevices);
    }
    pub inline fn GetDefaultAudioEndpoint(
        self: *IMMDeviceEnumerator,
        dataFlow: EDataFlow,
        role: ERole,
        out_ppEndpoint: *?*IMMDevice,
    ) HRESULT {
        return self.lpVtbl.GetDefaultAudioEndpoint(self, dataFlow, role, out_ppEndpoint);
    }
    pub inline fn GetDevice(
        self: *IMMDeviceEnumerator,
        pwstrId: LPCWSTR,
        out_ppDevice: *?*IMMDevice,
    ) HRESULT {
        return self.lpVtbl.GetDevice(self, pwstrId, out_ppDevice);
    }
    inline fn RegisterEndpointNotificationCallback(
        self: *IMMDeviceEnumerator,
        pClient: *anyopaque,
    ) HRESULT {
        return self.lpVtbl.RegisterEndpointNotificationCallback(self, pClient);
    }
    inline fn UnregisterEndpointNotificationCallback(
        self: *IMMDeviceEnumerator,
        pClient: *anyopaque,
    ) HRESULT {
        return self.lpVtbl.UnregisterEndpointNotificationCallback(self, pClient);
    }
};

const IMMDeviceEnumeratorVtbl = extern struct {
    QueryInterface: *const fn (
        *IMMDeviceEnumerator,
        *const GUID,
        *?*anyopaque,
    ) callconv(WINAPI) HRESULT,
    AddRef: *const fn (*IMMDeviceEnumerator) callconv(WINAPI) ULONG,
    Release: *const fn (*IMMDeviceEnumerator) callconv(WINAPI) ULONG,

    EnumAudioEndpoints: *const fn (
        *IMMDeviceEnumerator,
        EDataFlow,
        DWORD,
        *?*IMMDeviceCollection,
    ) callconv(WINAPI) HRESULT,
    GetDefaultAudioEndpoint: *const fn (
        *IMMDeviceEnumerator,
        EDataFlow,
        ERole,
        *?*IMMDevice,
    ) callconv(WINAPI) HRESULT,
    GetDevice: *const fn (*IMMDeviceEnumerator, LPCWSTR, *?*IMMDevice) callconv(WINAPI) HRESULT,
    RegisterEndpointNotificationCallback: *const fn (
        *IMMDeviceEnumerator,
        *anyopaque,
    ) callconv(WINAPI) HRESULT,
    UnregisterEndpointNotificationCallback: *const fn (
        *IMMDeviceEnumerator,
        *anyopaque,
    ) callconv(WINAPI) HRESULT,
};

const IMMDeviceCollection = extern struct {
    lpVtbl: *const IMMDeviceCollectionVtbl,

    inline fn QueryInterface(
        self: *IMMDeviceCollection,
        riid: *const GUID,
        out_ppv: *?*anyopaque,
    ) HRESULT {
        return self.lpVtbl.QueryInterface(self, riid, out_ppv);
    }
    inline fn AddRef(self: *IMMDeviceCollection) ULONG {
        return self.lpVtbl.AddRef(self);
    }
    inline fn Release(self: *IMMDeviceCollection) ULONG {
        return self.lpVtbl.Release(self);
    }
    inline fn GetCount(self: *IMMDeviceCollection, pcDevices: *UINT) HRESULT {
        return self.lpVtbl.GetCount(self, pcDevices);
    }
    inline fn Item(self: *IMMDeviceCollection, nDevice: UINT, ppDevice: *?*IMMDevice) HRESULT {
        return self.lpVtbl.Item(self, nDevice, ppDevice);
    }
};

const IMMDeviceCollectionVtbl = extern struct {
    QueryInterface: *const fn (
        *IMMDeviceCollection,
        *const GUID,
        *?*anyopaque,
    ) callconv(WINAPI) HRESULT,
    AddRef: *const fn (*IMMDeviceCollection) callconv(WINAPI) ULONG,
    Release: *const fn (*IMMDeviceCollection) callconv(WINAPI) ULONG,

    GetCount: *const fn (*IMMDeviceCollection, *UINT) callconv(WINAPI) HRESULT,
    Item: *const fn (*IMMDeviceCollection, UINT, *?*IMMDevice) callconv(WINAPI) HRESULT,
};

pub const IMMDevice = extern struct {
    lpVtbl: *const IMMDeviceVtbl,

    inline fn QueryInterface(
        self: *IMMDevice,
        riid: *const GUID,
        out_ppv: *?*anyopaque,
    ) HRESULT {
        return self.lpVtbl.QueryInterface(self, riid, out_ppv);
    }
    inline fn AddRef(self: *IMMDevice) ULONG {
        return self.lpVtbl.AddRef(self);
    }
    inline fn Release(self: *IMMDevice) ULONG {
        return self.lpVtbl.Release(self);
    }
    pub inline fn Activate(
        self: *IMMDevice,
        iid: *const GUID,
        dwClsCtx: DWORD,
        activationParams: ?*PROPVARIANT,
        out_ppInterface: *?*anyopaque,
    ) HRESULT {
        return self.lpVtbl.Activate(self, iid, dwClsCtx, activationParams, out_ppInterface);
    }
    pub inline fn OpenPropertyStore(
        self: *IMMDevice,
        stgmAccess: DWORD,
        out_ppProperties: *?*IPropertyStore,
    ) HRESULT {
        return self.lpVtbl.OpenPropertyStore(self, stgmAccess, out_ppProperties);
    }
    pub inline fn GetId(self: *IMMDevice, out_ppstrId: *?LPWSTR) HRESULT {
        return self.lpVtbl.GetId(self, out_ppstrId);
    }
    pub inline fn GetState(self: *IMMDevice, out_pdwState: *DWORD) HRESULT {
        return self.lpVtbl.GetState(self, out_pdwState);
    }
};

const IMMDeviceVtbl = extern struct {
    QueryInterface: *const fn (
        *IMMDevice,
        *const GUID,
        *?*anyopaque,
    ) callconv(WINAPI) HRESULT,
    AddRef: *const fn (*IMMDevice) callconv(WINAPI) ULONG,
    Release: *const fn (*IMMDevice) callconv(WINAPI) ULONG,

    Activate: *const fn (
        *IMMDevice,
        *const GUID,
        DWORD,
        ?*PROPVARIANT,
        *?*anyopaque,
    ) callconv(WINAPI) HRESULT,
    OpenPropertyStore: *const fn (*IMMDevice, DWORD, *?*IPropertyStore) callconv(WINAPI) HRESULT,
    GetId: *const fn (*IMMDevice, *?LPWSTR) callconv(WINAPI) HRESULT,
    GetState: *const fn (*IMMDevice, *DWORD) callconv(WINAPI) HRESULT,
};

pub const IAudioClient = extern struct {
    lpVtbl: *const IAudioClientVtbl,

    inline fn QueryInterface(
        self: *IAudioClient,
        riid: *const GUID,
        out_ppv: *?*anyopaque,
    ) HRESULT {
        return self.lpVtbl.QueryInterface(self, riid, out_ppv);
    }
    inline fn AddRef(self: *IAudioClient) ULONG {
        return self.lpVtbl.AddRef(self);
    }
    inline fn Release(self: *IAudioClient) ULONG {
        return self.lpVtbl.Release(self);
    }
    pub inline fn Initialize(
        self: *IAudioClient,
        shareMode: AUDCLNT_SHAREMODE,
        streamFlags: DWORD,
        bufferDuration: REFERENCE_TIME,
        periodicity: REFERENCE_TIME,
        format: *const WAVEFORMATEX,
        audioSessionGuid: ?*const GUID,
    ) HRESULT {
        return self.lpVtbl.Initialize(
            self,
            shareMode,
            streamFlags,
            bufferDuration,
            periodicity,
            format,
            audioSessionGuid,
        );
    }
    pub inline fn GetBufferSize(self: *IAudioClient, out_numFrames: *UINT32) HRESULT {
        return self.lpVtbl.GetBUfferSize(self, out_numFrames);
    }
    inline fn GetStreamLatency(self: *IAudioClient, out_latency: *REFERENCE_TIME) HRESULT {
        return self.lpVtbl.GetStreamLatency(self, out_latency);
    }
    pub inline fn GetCurrentPadding(self: *IAudioClient, out_padding: *UINT32) HRESULT {
        return self.lpVtbl.GetCurrentPadding(self, out_padding);
    }
    inline fn IsFormatSupported(
        self: *IAudioClient,
        shareMode: AUDCLNT_SHAREMODE,
        format: *const WAVEFORMATEX,
        closestMatch: *?*WAVEFORMATEX,
    ) HRESULT {
        return self.lpVtbl.IsFormatSupported(self, shareMode, format, closestMatch);
    }
    pub inline fn GetMixFormat(self: *IAudioClient, out_format: *?*WAVEFORMATEX) HRESULT {
        return self.lpVtbl.GetMixFormat(self, out_format);
    }
    inline fn GetDevicePeriod(
        self: *IAudioClient,
        defaultDevicePeriod: ?*REFERENCE_TIME,
        minimumDevicePeriod: ?*REFERENCE_TIME,
    ) HRESULT {
        return self.lpVtbl.GetDevicePeriod(self, defaultDevicePeriod, minimumDevicePeriod);
    }
    pub inline fn Start(self: *IAudioClient) HRESULT {
        return self.lpVtbl.Start(self);
    }
    pub inline fn Stop(self: *IAudioClient) HRESULT {
        return self.lpVtbl.Stop(self);
    }
    inline fn Reset(self: *IAudioClient) HRESULT {
        return self.lpVtbl.Reset(self);
    }
    inline fn SetEventHandle(self: *IAudioClient, eventHandle: HANDLE) HRESULT {
        return self.lpVtbl.SetEventHandle(self, eventHandle);
    }
    pub inline fn GetService(self: *IAudioClient, riid: *const GUID, ppv: *?*anyopaque) HRESULT {
        return self.lpVtbl.GetService(self, riid, ppv);
    }
};

const IAudioClientVtbl = extern struct {
    QueryInterface: *const fn (
        *IAudioClient,
        *const GUID,
        *?*anyopaque,
    ) callconv(WINAPI) HRESULT,
    AddRef: *const fn (*IAudioClient) callconv(WINAPI) ULONG,
    Release: *const fn (*IAudioClient) callconv(WINAPI) ULONG,
    Initialize: *const fn (
        *IAudioClient,
        AUDCLNT_SHAREMODE,
        DWORD,
        REFERENCE_TIME,
        REFERENCE_TIME,
        *const WAVEFORMATEX,
        ?*const GUID,
    ) callconv(WINAPI) HRESULT,
    GetBUfferSize: *const fn (
        *IAudioClient,
        *UINT32,
    ) callconv(WINAPI) HRESULT,
    GetStreamLatency: *const fn (
        *IAudioClient,
        *REFERENCE_TIME,
    ) callconv(WINAPI) HRESULT,
    GetCurrentPadding: *const fn (*IAudioClient, *UINT32) callconv(WINAPI) HRESULT,
    IsFormatSupported: *const fn (
        *IAudioClient,
        AUDCLNT_SHAREMODE,
        *const WAVEFORMATEX,
        *?*WAVEFORMATEX,
    ) callconv(WINAPI) HRESULT,
    GetMixFormat: *const fn (*IAudioClient, *?*WAVEFORMATEX) callconv(WINAPI) HRESULT,
    GetDevicePeriod: *const fn (*IAudioClient, ?*REFERENCE_TIME, ?*REFERENCE_TIME) callconv(WINAPI) HRESULT,
    Start: *const fn (*IAudioClient) callconv(WINAPI) HRESULT,
    Stop: *const fn (*IAudioClient) callconv(WINAPI) HRESULT,
    Reset: *const fn (*IAudioClient) callconv(WINAPI) HRESULT,
    SetEventHandle: *const fn (*IAudioClient, HANDLE) callconv(WINAPI) HRESULT,
    GetService: *const fn (
        *IAudioClient,
        *const GUID,
        *?*anyopaque,
    ) callconv(WINAPI) HRESULT,
};

pub const IAudioRenderClient = extern struct {
    lpVtbl: *const IAudioRenderClientVtbl,

    inline fn QueryInterface(
        self: *IAudioRenderClient,
        riid: *const GUID,
        out_ppv: *?*anyopaque,
    ) HRESULT {
        return self.lpVtbl.QueryInterface(self, riid, out_ppv);
    }
    inline fn AddRef(self: *IAudioRenderClient) ULONG {
        return self.lpVtbl.AddRef(self);
    }
    inline fn Release(self: *IAudioRenderClient) ULONG {
        return self.lpVtbl.Release(self);
    }

    pub inline fn GetBuffer(
        self: *IAudioRenderClient,
        NumFramesRequested: UINT32,
        ppData: *[*]BYTE,
    ) HRESULT {
        return self.lpVtbl.GetBuffer(self, NumFramesRequested, ppData);
    }
    pub inline fn ReleaseBuffer(
        self: *IAudioRenderClient,
        NumFramesWritten: UINT32,
        dwFlags: DWORD,
    ) HRESULT {
        return self.lpVtbl.ReleaseBuffer(self, NumFramesWritten, dwFlags);
    }
};

const IAudioRenderClientVtbl = extern struct {
    QueryInterface: *const fn (
        *IAudioRenderClient,
        *const GUID,
        *?*anyopaque,
    ) callconv(WINAPI) HRESULT,
    AddRef: *const fn (*IAudioRenderClient) callconv(WINAPI) ULONG,
    Release: *const fn (*IAudioRenderClient) callconv(WINAPI) ULONG,

    GetBuffer: *const fn (*IAudioRenderClient, UINT32, *[*]BYTE) callconv(WINAPI) HRESULT,
    ReleaseBuffer: *const fn (*IAudioRenderClient, UINT32, DWORD) callconv(WINAPI) HRESULT,
};

test "expect COM to initialize" {
    try std.testing.expect(SUCCEEDED(CoInitializeEx(null, COINIT_MULTITHREADED)));
    CoUninitialize();
}

test "expect enumerator instance to be created" {
    const hr = CoInitializeEx(null, COINIT_MULTITHREADED);
    try std.testing.expect(SUCCEEDED(hr));
    defer CoUninitialize();

    var device_enumerator: ?*IMMDeviceEnumerator = null;
    try std.testing.expect(SUCCEEDED(CoCreateInstance(
        &CLSID_MMDeviceEnumerator,
        null,
        CLSCTX_ALL,
        &IID_IMMDeviceEnumerator,
        @ptrCast(&device_enumerator),
    )));
}

test "expect to get default device from enumerator" {
    std.testing.log_level = .debug;

    var hr = CoInitializeEx(null, COINIT_MULTITHREADED);
    try std.testing.expect(SUCCEEDED(hr));
    defer CoUninitialize();

    var device_enumerator: ?*IMMDeviceEnumerator = null;
    try std.testing.expect(SUCCEEDED(CoCreateInstance(
        &CLSID_MMDeviceEnumerator,
        null,
        CLSCTX_ALL,
        &IID_IMMDeviceEnumerator,
        @ptrCast(&device_enumerator),
    )));

    const e = device_enumerator.?;

    var device: ?*IMMDevice = null;
    hr = e.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eConsole, @ptrCast(&device));
    try std.testing.expect(SUCCEEDED(hr));
}
