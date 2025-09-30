const std = @import("std");
const wasapi = @import("wasapi.zig");

pub const Player = struct {
    const hnsRequestedDuration: wasapi.REFERENCE_TIME = wasapi.REFTIMES_PER_SEC;
    var hr: wasapi.HRESULT = 0;

    hnsActualDuration: wasapi.REFERENCE_TIME = 0,
    pEnumerator: ?*wasapi.IMMDeviceEnumerator = null,
    pDevice: ?*wasapi.IMMDevice = null,
    pAudioClient: ?*wasapi.IAudioClient = null,
    pRenderClient: ?*wasapi.IAudioRenderClient = null,
    pwfx: ?*wasapi.WAVEFORMATEX = null,
    bufferFrameCount: wasapi.UINT32 = 0,
    numFramesAvailable: wasapi.UINT32 = 0,
    numFramesPadding: wasapi.UINT32 = 0,
    pData: *wasapi.BYTE = undefined,
    flags: wasapi.DWORD = 0,

    const Self = @This();

    pub fn init() ?Self {
        std.log.info("Initializing COM...", .{});
        hr = wasapi.CoInitializeEx(null, wasapi.COINIT_MULTITHREADED);
        if (wasapi.FAILED(hr)) {
            return null;
        }
        defer wasapi.CoUninitialize();
        std.log.info("Success.", .{});

        var result: Self = .{};

        std.log.info("Creating DeviceEnumerator...", .{});
        hr = wasapi.CoCreateInstance(
            &wasapi.CLSID_MMDeviceEnumerator,
            null,
            wasapi.CLSCTX_ALL,
            &wasapi.IID_IMMDeviceEnumerator,
            @ptrCast(&result.pEnumerator),
        );
        if (wasapi.FAILED(hr)) {
            return null;
        }
        std.log.info("Success.", .{});

        std.log.info("Getting DefaultAudioEndpoint...", .{});
        hr = result.pEnumerator.?.GetDefaultAudioEndpoint(
            wasapi.EDataFlow.eRender,
            wasapi.ERole.eConsole,
            @ptrCast(&result.pDevice),
        );
        if (wasapi.FAILED(hr)) {
            return null;
        }
        std.log.info("Success.", .{});

        std.log.info("Activating AudioClient...", .{});
        hr = result.pDevice.?.Activate(
            &wasapi.IID_IAudioClient,
            wasapi.CLSCTX_ALL,
            null,
            @ptrCast(&result.pAudioClient),
        );
        if (wasapi.FAILED(hr)) {
            return null;
        }
        std.log.info("Success.", .{});

        std.log.info("Getting MixFormat...", .{});
        hr = result.pAudioClient.?.GetMixFormat(@ptrCast(&result.pwfx));
        if (wasapi.FAILED(hr)) {
            return null;
        }
        std.log.info("Success.", .{});

        std.log.info("Initializing AudioClient...", .{});
        hr = result.pAudioClient.?.Initialize(
            wasapi.AUDCLNT_SHAREMODE.AUDCLNT_SHAREMODE_SHARED,
            0,
            hnsRequestedDuration,
            0,
            result.pwfx.?,
            null,
        );
        if (wasapi.FAILED(hr)) {
            return null;
        }
        std.log.info("Success.", .{});

        std.log.info("Getting AudioRenderClient...", .{});
        hr = result.pAudioClient.?.GetService(
            &wasapi.IID_IAudioRenderClient,
            @ptrCast(&result.pRenderClient),
        );
        if (wasapi.FAILED(hr)) {
            return null;
        }
        std.log.info("Success.", .{});

        return result;
    }
};
