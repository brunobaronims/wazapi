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
    pData: [*]wasapi.BYTE = undefined,
    flags: wasapi.DWORD = 0,

    pub fn init(source: *Source) ?Player {
        std.log.info("Initializing COM objects...", .{});
        hr = wasapi.CoInitializeEx(null, wasapi.COINIT_MULTITHREADED);
        if (wasapi.FAILED(hr)) {
            return null;
        }
        defer wasapi.CoUninitialize();

        var result: Player = .{};

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
        defer wasapi.safeRelease(result.pEnumerator);

        hr = result.pEnumerator.?.GetDefaultAudioEndpoint(
            wasapi.EDataFlow.eRender,
            wasapi.ERole.eConsole,
            @ptrCast(&result.pDevice),
        );
        if (wasapi.FAILED(hr)) {
            return null;
        }
        defer wasapi.safeRelease(result.pDevice);

        hr = result.pDevice.?.Activate(
            &wasapi.IID_IAudioClient,
            wasapi.CLSCTX_ALL,
            null,
            @ptrCast(&result.pAudioClient),
        );
        if (wasapi.FAILED(hr)) {
            return null;
        }
        defer wasapi.safeRelease(result.pAudioClient);

        hr = result.pAudioClient.?.GetMixFormat(@ptrCast(&result.pwfx));
        if (wasapi.FAILED(hr)) {
            return null;
        }
        defer wasapi.CoTaskMemFree(result.pwfx);

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

        source.setFormat(result.pwfx.?);

        hr = result.pAudioClient.?.GetBufferSize(&result.bufferFrameCount);
        if (wasapi.FAILED(hr)) {
            return null;
        }

        hr = result.pAudioClient.?.GetService(
            &wasapi.IID_IAudioRenderClient,
            @ptrCast(&result.pRenderClient),
        );
        if (wasapi.FAILED(hr)) {
            return null;
        }
        defer wasapi.safeRelease(result.pRenderClient);

        hr = result.pRenderClient.?.GetBuffer(result.bufferFrameCount, @ptrCast(&result.pData));
        if (wasapi.FAILED(hr)) {
            return null;
        }

        source.loadData(result.pData, result.bufferFrameCount);

        hr = result.pRenderClient.?.ReleaseBuffer(result.bufferFrameCount, result.flags);
        if (wasapi.FAILED(hr)) {
            return null;
        }

        result.hnsActualDuration = @divTrunc(
            @as(i64, wasapi.REFTIMES_PER_SEC) * @as(i64, result.bufferFrameCount),
            @as(i64, result.pwfx.?.nSamplesPerSec),
        );

        // Start playing
        hr = result.pAudioClient.?.Start();
        if (wasapi.FAILED(hr)) {
            return null;
        }

        std.log.info("Started playback!", .{});

        const sleep_ms = @as(
            u32,
            @intCast(@divTrunc(result.hnsActualDuration, wasapi.REFTIMES_PER_MILLISEC * 2)),
        );

        // Simple test loop - play for a bit
        var i: u32 = 0;
        while (i < 100) : (i += 1) {
            std.Thread.sleep(sleep_ms * std.time.ns_per_ms);

            var numFramesPadding: u32 = 0;
            hr = result.pAudioClient.?.GetCurrentPadding(&numFramesPadding);
            if (wasapi.FAILED(hr)) break;

            const numFramesAvailable = result.bufferFrameCount - numFramesPadding;

            if (numFramesAvailable > 0) {
                var pData: [*]u8 = undefined;
                hr = result.pRenderClient.?.GetBuffer(numFramesAvailable, @ptrCast(&pData));
                if (wasapi.FAILED(hr)) break;

                source.loadData(pData, numFramesAvailable);

                hr = result.pRenderClient.?.ReleaseBuffer(numFramesAvailable, 0);
                if (wasapi.FAILED(hr)) break;
            }
        }

        // Stop
        _ = result.pAudioClient.?.Stop();

        std.log.info("Success.", .{});

        return result;
    }
};

pub const Source = struct {
    sample_rate: u32 = 0,
    channels: u16 = 0,
    bits_per_sample: u16 = 0,
    format_tag: u16 = 0,
    is_float: bool = false,
    phase: f32 = 0.0,
    frequency: f32 = 440.0,

    fn guidsEqual(a: wasapi.GUID, b: wasapi.GUID) bool {
        if (a.Data1 != b.Data1) return false;
        if (a.Data2 != b.Data2) return false;
        if (a.Data3 != b.Data3) return false;

        // Compare Data4 directly
        for (a.Data4, b.Data4) |byte_a, byte_b| {
            if (byte_a != byte_b) return false;
        }
        return true;
    }

    pub fn setFormat(self: *Source, pwfx: *wasapi.WAVEFORMATEX) void {
        self.sample_rate = pwfx.nSamplesPerSec;
        self.channels = pwfx.nChannels;
        self.bits_per_sample = pwfx.wBitsPerSample;
        self.format_tag = pwfx.wFormatTag;

        if (pwfx.wFormatTag == wasapi.WAVE_FORMAT_EXTENSIBLE) {
            // Read GUID from correct offset (24 bytes)
            const base_ptr = @as([*]const u8, @ptrCast(pwfx));
            const guid_ptr = @as(*const wasapi.GUID, @ptrCast(@alignCast(base_ptr + 24)));

            // Check the SubFormat GUID to determine actual format
            if (guidsEqual(guid_ptr.*, wasapi.KSDATAFORMAT_SUBTYPE_IEEE_FLOAT)) {
                self.is_float = true;
                std.log.info("Format: IEEE Float (via EXTENSIBLE)", .{});
            } else if (guidsEqual(guid_ptr.*, wasapi.KSDATAFORMAT_SUBTYPE_PCM)) {
                self.is_float = false;
                std.log.info("Format: PCM (via EXTENSIBLE)", .{});
            } else {
                std.log.warn("Unknown SubFormat GUID", .{});
            }
        } else if (pwfx.wFormatTag == wasapi.WAVE_FORMAT_IEEE_FLOAT) {
            self.is_float = true;
            std.log.info("Format: IEEE Float (direct)", .{});
        } else if (pwfx.wFormatTag == wasapi.WAVE_FORMAT_PCM) {
            self.is_float = false;
            std.log.info("Format: PCM (direct)", .{});
        }

        std.log.info("Audio format: {}Hz, {} channels, {} bits, format_tag={}", .{
            self.sample_rate,
            self.channels,
            self.bits_per_sample,
            self.format_tag,
        });
    }

    pub fn loadData(self: *Source, buffer: [*]u8, frame_count: u32) void {
        const phase_increment = self.frequency / @as(f32, @floatFromInt(self.sample_rate));

        // Check actual format using is_float flag
        if (self.is_float and self.bits_per_sample == 32) {
            // 32-bit float
            const samples = @as([*]f32, @ptrCast(@alignCast(buffer)));
            const total_samples = frame_count * self.channels;

            var i: u32 = 0;
            while (i < total_samples) : (i += 1) {
                const sample = @sin(self.phase * 2.0 * std.math.pi) * 0.3;
                samples[i] = sample;

                if (i % self.channels == self.channels - 1) {
                    self.phase += phase_increment;
                    if (self.phase >= 1.0) self.phase -= 1.0;
                }
            }
        } else if (!self.is_float and self.bits_per_sample == 16) {
            // 16-bit PCM
            const samples = @as([*]i16, @ptrCast(@alignCast(buffer)));
            const total_samples = frame_count * self.channels;

            var i: u32 = 0;
            while (i < total_samples) : (i += 1) {
                const sample = @sin(self.phase * 2.0 * std.math.pi) * 0.3;
                samples[i] = @intFromFloat(sample * 32767.0);

                if (i % self.channels == self.channels - 1) {
                    self.phase += phase_increment;
                    if (self.phase >= 1.0) self.phase -= 1.0;
                }
            }
        } else {
            std.log.err("Unsupported format: {} bits, float={}", .{
                self.bits_per_sample,
                self.is_float,
            });
        }
    }
};
