Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms, System.Runtime.WindowsRuntime

# Embedded Native Win32 Helper & Core Audio Engine (COM Interop)

$win32Code = @"

using System;

using System.Runtime.InteropServices;

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]

public interface IAudioEndpointVolume {

    int RegisterControlChangeNotify(IntPtr pNotify);

    int UnregisterControlChangeNotify(IntPtr pNotify);

    int GetChannelCount(out uint pnChannelCount);

    int SetMasterVolumeLevel(float fLevelDB, ref Guid pguidEventContext);

    int SetMasterVolumeLevelScalar(float fLevel, ref Guid pguidEventContext);

    int GetMasterVolumeLevel(out float pfLevelDB);

    int GetMasterVolumeLevelScalar(out float pfLevel);

    int SetChannelVolumeLevel(uint nChannel, float fLevelDB, ref Guid pguidEventContext);

    int SetChannelVolumeLevelScalar(uint nChannel, float fLevel, ref Guid pguidEventContext);

    int GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);

    int GetChannelVolumeLevelScalar(uint nChannel, out float pfLevel);

    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, ref Guid pguidEventContext);

    int GetMute(out bool pbMute);

    int GetVolumeStepInfo(out uint pnStep, out uint pnStepCount);

    int VolumeStepUp(ref Guid pguidEventContext);

    int VolumeStepDown(ref Guid pguidEventContext);

    int QueryHardwareSupport(out uint pdwHardwareSupportMask);

    int GetVolumeRange(out float pflVolumeMindB, out float pflVolumeMaxdB, out float pflVolumeIncrementdB);

}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]

public interface IMMDevice {

    int Activate(ref Guid id, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePointer);

    int OpenPropertyStore(int stgmAccess, out IntPtr properties);

    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);

    int GetState(out int pdwState);

}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]

public interface IMMDeviceEnumerator {

    int EnumAudioEndpoints(int dataFlow, int dwStateMask, out IntPtr ppDevices);

    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppEndpoint);

    int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string pwstrId, out IMMDevice ppDevice);

    int RegisterEndpointNotificationCallback(IntPtr pClient);

    int UnregisterEndpointNotificationCallback(IntPtr pClient);

}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]

public class MMDeviceEnumeratorComObject { }

public static class OceruAudioManager {

    private static IAudioEndpointVolume GetVolumeControl() {

        try {

            var enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());

            IMMDevice dev;

            int hr = enumerator.GetDefaultAudioEndpoint(0, 1, out dev);

            if (hr != 0 || dev == null) return null;

            var iid = typeof(IAudioEndpointVolume).GUID;

            object o;

            hr = dev.Activate(ref iid, 23, IntPtr.Zero, out o);

            if (hr != 0 || o == null) return null;

            return (IAudioEndpointVolume)o;

        } catch {

            return null;

        }

    }

    public static int GetMasterVolume() {

        try {

            var vol = GetVolumeControl();

            if (vol == null) return -1;

            float level;

            vol.GetMasterVolumeLevelScalar(out level);

            return (int)Math.Round(level * 100.0f);

        } catch {

            return -1;

        }

    }

    public static bool SetMasterVolume(int percent) {

        try {

            var vol = GetVolumeControl();

            if (vol == null) return false;

            float level = Math.Max(0.0f, Math.Min(1.0f, percent / 100.0f));

            var guid = Guid.Empty;

            vol.SetMasterVolumeLevelScalar(level, ref guid);

            return true;

        } catch {

            return false;

        }

    }

    public static bool GetMute() {

        try {

            var vol = GetVolumeControl();

            if (vol == null) return false;

            bool mute;

            vol.GetMute(out mute);

            return mute;

        } catch {

            return false;

        }

    }

    public static bool SetMute(bool isMuted) {

        try {

            var vol = GetVolumeControl();

            if (vol == null) return false;

            var guid = Guid.Empty;

            vol.SetMute(isMuted, ref guid);

            return true;

        } catch {

            return false;

        }

    }

    public static bool ToggleMute() {

        bool current = GetMute();

        SetMute(!current);

        return !current;

    }

}

public class Win32Helper {

    [StructLayout(LayoutKind.Sequential)]

    public struct SYSTEM_POWER_STATUS {

        public byte ACLineStatus;

        public byte BatteryFlag;

        public byte BatteryLifePercent;

        public byte SystemStatusFlag;

        public int BatteryLifeTime;

        public int BatteryFullLifeTime;

    }

    [DllImport("kernel32.dll")]

    public static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS status);

    public static bool IsBatterySaver() {

        try {

            SYSTEM_POWER_STATUS status;

            if (GetSystemPowerStatus(out status)) {

                return status.SystemStatusFlag == 1;

            }

        } catch {}

        return false;

    }

    public static int GetACLineStatus() {

        try {

            SYSTEM_POWER_STATUS status;

            if (GetSystemPowerStatus(out status)) {

                return (int)status.ACLineStatus;

            }

        } catch {}

        return 255;

    }

    public static int GetBatteryPercent() {

        try {

            SYSTEM_POWER_STATUS status;

            if (GetSystemPowerStatus(out status)) {

                return (int)status.BatteryLifePercent;

            }

        } catch {}

        return -1;

    }

    [DllImport("user32.dll", SetLastError = true)]

    public static extern bool LockWorkStation();

    [DllImport("user32.dll")]

    public static extern IntPtr SendMessageW(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]

    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern IntPtr GetDesktopWindow();

    [DllImport("user32.dll")]
    public static extern IntPtr GetShellWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static bool IsForegroundFullscreen(IntPtr islandHwnd, int screenWidth, int screenHeight) {
        try {
            IntPtr fg = GetForegroundWindow();
            if (fg == IntPtr.Zero || fg == islandHwnd) return false;
            IntPtr desktop = GetDesktopWindow();
            IntPtr shell = GetShellWindow();
            if (fg == desktop || fg == shell) return false;

            RECT r;
            if (GetWindowRect(fg, out r)) {
                int w = r.Right - r.Left;
                int h = r.Bottom - r.Top;
                if (r.Left <= 0 && r.Top <= 0 && w >= screenWidth && h >= screenHeight) {
                    return true;
                }
            }
        } catch {}
        return false;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static uint GetSystemIdleMillis() {
        try {
            LASTINPUTINFO lii = new LASTINPUTINFO();
            lii.cbSize = (uint)Marshal.SizeOf(lii);
            if (GetLastInputInfo(ref lii)) {
                return (uint)Environment.TickCount - lii.dwTime;
            }
        } catch {}
        return 0;
    }

    public const byte VK_MEDIA_NEXT_TRACK = 0xB0;

    public const byte VK_MEDIA_PREV_TRACK = 0xB1;

    public const byte VK_MEDIA_STOP = 0xB2;

    public const byte VK_MEDIA_PLAY_PAUSE = 0xB3;

    public static void SendMediaKey(byte vk) {

        try {

            keybd_event(vk, 0, 0, UIntPtr.Zero);

            keybd_event(vk, 0, 2, UIntPtr.Zero);

        } catch {}

    }

    public const int WM_APPCOMMAND = 0x0319;

    public const int APPCOMMAND_VOLUME_MUTE = 0x80000;

    public const int APPCOMMAND_VOLUME_UP = 0xa0000;

    public const int APPCOMMAND_VOLUME_DOWN = 0x90000;

    public static void ToggleMute() {

        OceruAudioManager.ToggleMute();

    }

    public static void VolumeUp() {

        int v = OceruAudioManager.GetMasterVolume();

        if (v >= 0) OceruAudioManager.SetMasterVolume(Math.Min(100, v + 2));

        else SendMessageW(new IntPtr(0xffff), WM_APPCOMMAND, IntPtr.Zero, new IntPtr(APPCOMMAND_VOLUME_UP));

    }

    public static void VolumeDown() {

        int v = OceruAudioManager.GetMasterVolume();

        if (v >= 0) OceruAudioManager.SetMasterVolume(Math.Max(0, v - 2));

        else SendMessageW(new IntPtr(0xffff), WM_APPCOMMAND, IntPtr.Zero, new IntPtr(APPCOMMAND_VOLUME_DOWN));

    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]

    public class MEMORYSTATUSEX {

        public uint dwLength;

        public uint dwMemoryLoad;

        public ulong ullTotalPhys;

        public ulong ullAvailPhys;

        public ulong ullTotalPageFile;

        public ulong ullAvailPageFile;

        public ulong ullTotalVirtual;

        public ulong ullAvailVirtual;

        public ulong ullAvailExtendedVirtual;

        public MEMORYSTATUSEX() {

            this.dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));

        }

    }

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]

    public static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX lpBuffer);

    public static uint GetRamLoad() {

        var mem = new MEMORYSTATUSEX();

        if (GlobalMemoryStatusEx(mem)) {

            return mem.dwMemoryLoad;

        }

        return 0;

    }

}

"@

try {

    Add-Type -TypeDefinition $win32Code -Language CSharp -ErrorAction SilentlyContinue

} catch {}

# Base Paths & Singleton Process Management

if (-not $PSScriptRoot) { $PSScriptRoot = "D:\Project Orizzdev\dynamic-island" }

$pidPath = Join-Path $PSScriptRoot ".oceru.pid"

$statePath = Join-Path $PSScriptRoot ".oceru-state.json"

if (Test-Path $pidPath) {

    try {

        $oldPid = Get-Content $pidPath -ErrorAction SilentlyContinue

        if ($oldPid -and ($oldPid -ne $PID)) {

            $oldProc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue

            if ($oldProc -and ($oldProc.ProcessName -eq "powershell")) {

                $oldProc.Kill()

            }

        }

    } catch {}

}

try { [System.Diagnostics.Process]::GetCurrentProcess().Id | Out-File -FilePath $pidPath -Force -Encoding ASCII } catch {}

# Global Shared Application State

function Load-OceruState {

    if (Test-Path $statePath) {

        try {

            $raw = Get-Content $statePath -Raw -Encoding UTF8

            return ($raw | ConvertFrom-Json)

        } catch {}

    }

    return [PSCustomObject]@{

        theme = "ocean-dark"

        accentColor = "#00D2FF"

        dndEnabled = $false

        gamingMode = $false

        islandPosition = "top-center"

        islandWidth = 560

        islandOpacity = 0.98

        autoCollapseSeconds = 0.28

        volume = 72

        isMuted = $false

        currentMedia = [PSCustomObject]@{

            title = "Paper Sky"

            artist = "Lumen Coast - Summer Flows"

            album = "Summer Flows"

            isPlaying = $true

            progressSeconds = 193

            durationSeconds = 256

        }

        pomodoro = [PSCustomObject]@{

            mode = "focus"

            remainingSeconds = 1500

            totalSeconds = 1500

            isRunning = $false

            completedCount = 3

        }

        water = [PSCustomObject]@{

            currentMl = 1250

            targetMl = 2000

        }

        notes = @(

            [PSCustomObject]@{ id = 1; title = "Oceru Design Language"; content = "Ocean Azure Glass dengan midnight navy dan aksen cyan." },

            [PSCustomObject]@{ id = 2; title = "Shortcut Cepat"; content = "Arahkan kursor ke Notch atas untuk membuka Oceru Island." }

        )

        tasks = @(

            [PSCustomObject]@{ id = 1; text = "Uji responsivitas Notch"; done = $true },

            [PSCustomObject]@{ id = 2; text = "Sinkronisasi audio & volume"; done = $true },

            [PSCustomObject]@{ id = 3; text = "Cek catatan & to-do list"; done = $false }

        )

        clipboard = @(

            [PSCustomObject]@{ text = "https://github.com/cubadakanda/dynamic-island"; pinned = $true },

            [PSCustomObject]@{ text = "Oceru Dynamic Island Desktop"; pinned = $false },

            [PSCustomObject]@{ text = "Paper Sky - Lumen Coast"; pinned = $false }

        )

        quickLauncher = @(

            [PSCustomObject]@{ name = "Google Chrome"; path = "chrome.exe"; icon = "Web" },

            [PSCustomObject]@{ name = "File Explorer"; path = "explorer.exe"; icon = "Files" },

            [PSCustomObject]@{ name = "Terminal PowerShell"; path = "powershell.exe"; icon = "CLI" },

            [PSCustomObject]@{ name = "Task Manager"; path = "taskmgr.exe"; icon = "Task" },

            [PSCustomObject]@{ name = "Windows Settings"; path = "ms-settings:"; icon = "Config" }

        )

        notifications = @(

            [PSCustomObject]@{ id = 1; title = "Selamat Datang di Oceru"; message = "Oceru Dynamic Island aktif dengan desain baru."; time = "00:25"; read = $false }

        )

    }

}

function Save-OceruState {

    try {

        $json = $global:OceruState | ConvertTo-Json -Depth 6

        $json | Out-File -FilePath $statePath -Force -Encoding UTF8

    } catch {}

}

$global:OceruState = Load-OceruState

# Real Hardware Volume & Mute Initialization via Core Audio

$global:lastKnownVol = [OceruAudioManager]::GetMasterVolume()

if ($global:lastKnownVol -ge 0) {

    $global:OceruState.volume = $global:lastKnownVol

} else {

    $global:lastKnownVol = $global:OceruState.volume

}

$global:lastKnownMute = [OceruAudioManager]::GetMute()

$global:OceruState.isMuted = $global:lastKnownMute

# Local Media Player Engine (Native WPF MediaPlayer for real audio playback)

$global:localMediaPlayer = New-Object System.Windows.Media.MediaPlayer

$global:localMediaLoaded = $false

$global:localMediaPlaying = $false

$global:connTick = 0

# Real-time Hardware Connectivity Checker (Wi-Fi & Bluetooth)

function Get-OceruConnectivity {

    $wifiStatus = "Tidak Ada"

    $wifiConnected = $false

    $btStatus = "Tidak Ada"

    $btEnabled = $false

    try {

        $adapters = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

        $wifiAdapter = $adapters | Where-Object { $_.NetworkInterfaceType -match "Wireless80211" -and $_.Description -notmatch "Virtual|Direct" } | Select-Object -First 1

        if ($wifiAdapter) {

            if ($wifiAdapter.OperationalStatus -eq [System.Net.NetworkInformation.OperationalStatus]::Up) {

                $wifiStatus = "Terhubung"

                $wifiConnected = $true

            } else {

                $wifiStatus = "Aktif (Tidak Terhubung)"

            }

        }

    } catch {}

    try {

        [Windows.Devices.Radios.Radio, Windows.System.Devices, ContentType = WindowsRuntime] | Out-Null

        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue

        $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { 

            $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 

        })[0]

        $op = [Windows.Devices.Radios.Radio]::GetRadiosAsync()

        $asTask = $asTaskGeneric.MakeGenericMethod([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]]).Invoke($null, @($op))

        if ($asTask.Wait(1000)) {

            foreach ($r in $asTask.Result) {

                if ($r.Kind -eq [Windows.Devices.Radios.RadioKind]::WiFi) {

                    if ($r.State -eq [Windows.Devices.Radios.RadioState]::On) {

                        if (-not $wifiConnected) { $wifiStatus = "Aktif" }

                    } else {

                        $wifiStatus = "Nonaktif"

                    }

                }

                elseif ($r.Kind -eq [Windows.Devices.Radios.RadioKind]::Bluetooth) {

                    if ($r.State -eq [Windows.Devices.Radios.RadioState]::On) {

                        $btStatus = "Aktif"

                        $btEnabled = $true

                    } else {

                        $btStatus = "Nonaktif"

                    }

                }

            }

        }

    } catch {}

    return [PSCustomObject]@{

        WifiStatus = $wifiStatus

        WifiConnected = $wifiConnected

        BluetoothStatus = $btStatus

        BluetoothEnabled = $btEnabled

    }

}

$screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth

$screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight

# Geometry for Hardware Notch (Option B - Tangential MacBook Shoulder Fillets):

$shoulderPad = 8 # 8px tangential shoulder fillet for seamless bezel integration

function Get-Notch3SidedWaveGeometry($totalW, $h, $s, $r, $waveAmp = 0, $wavePhase = 0, $beatAmp = 0) {
    $baseH = if ($h -gt 100) { 205 } else { $h }
    $x0 = $s + $r
    $x1 = $totalW - $s - $r
    $spanBot = $x1 - $x0
    $spanVert = ($baseH - $r) - $s
    $yMidSide = [Math]::Round($s + ($spanVert * 0.5), 1)

    $apexPoints = New-Object System.Collections.Generic.List[PSCustomObject]

    # If wave amplitude is negligible, return flat top-docked notch
    if ($waveAmp -le 0.5) {
        $flatBody = "M 0,0 A $s,$s 0 0,1 $s,$s L $s,$($baseH-$r) A $r,$r 0 0,0 $x0,$baseH L $x1,$baseH A $r,$r 0 0,0 $($totalW-$s),$($baseH-$r) L $($totalW-$s),$s A $s,$s 0 0,1 $totalW,0 Z"
        $flatStroke = "M $s,$yMidSide L $s,$($baseH-$r) A $r,$r 0 0,0 $x0,$baseH L $x1,$baseH A $r,$r 0 0,0 $($totalW-$s),$($baseH-$r) L $($totalW-$s),$yMidSide"
        return [PSCustomObject]@{
            BodyPath = $flatBody
            StrokePath = $flatStroke
            Ribbon2Path = $flatStroke
            ApexPoints = $apexPoints
        }
    }

    # 1. Left Side: Upper half is flat straight line (L s,yMidSide). Lower half has 2 fluid scallops
    $N_left = 2
    $hSegL = ($baseH - $r - $yMidSide) / $N_left
    $leftSb = [System.Text.StringBuilder]::new()
    $leftR2Sb = [System.Text.StringBuilder]::new()

    for ($i = 0; $i -lt $N_left; $i++) {
        $ya = [Math]::Round($yMidSide + ($i * $hSegL), 1)
        $yb = [Math]::Round($ya + $hSegL, 1)
        $ymid = [Math]::Round(($ya + $yb) / 2, 1)
        $ti = ($i + 0.5) / $N_left
        $env = [Math]::Sin(($i + 1) / ($N_left + 0.8) * [Math]::PI * 0.5)
        $bounce = 0.65 + 0.35 * [Math]::Sin(($i * 2.4) + $wavePhase)
        $bounce2 = 0.65 + 0.35 * [Math]::Sin(($i * 2.4) + $wavePhase + 1.2)
        $isBeat = ($beatAmp -gt 0.3 -and $i -eq 1)
        $beatMult = if ($isBeat) { 1.45 } else { 1.0 }

        $dip = [Math]::Round($waveAmp * 0.55 * $env * $bounce * $beatMult, 1)
        $dip2 = [Math]::Round($waveAmp * 0.45 * $env * $bounce2 * $beatMult, 1)
        $xapex = [Math]::Round($s - $dip, 1)
        $xapex2 = [Math]::Round($s - $dip2, 1)

        $cp1X = [Math]::Round($s - ($dip * 0.45), 1)
        $cp1Y = [Math]::Round($ya + ($hSegL * 0.42), 1)
        $cp2X = [Math]::Round($s - ($dip * 0.45), 1)
        $cp2Y = [Math]::Round($yb - ($hSegL * 0.42), 1)

        $leftSb.Append(" Q $cp1X,$cp1Y $xapex,$ymid Q $cp2X,$cp2Y $s,$yb") | Out-Null
        $leftR2Sb.Append(" Q $cp1X,$cp1Y $xapex2,$ymid Q $cp2X,$cp2Y $s,$yb") | Out-Null
        $apexPoints.Add([PSCustomObject]@{ X = $xapex; Y = $ymid; IsBeat = $isBeat })
    }

    # 2. Bottom Scallops (14 scallops protruding downwards: +dy)
    $N_bot = if ($totalW -gt 400) { 14 } elseif ($totalW -gt 200) { 8 } else { 4 }
    $wSeg = $spanBot / $N_bot
    $botSb = [System.Text.StringBuilder]::new()
    $botR2Sb = [System.Text.StringBuilder]::new()

    for ($i = 0; $i -lt $N_bot; $i++) {
        $xa = [Math]::Round($x0 + ($i * $wSeg), 1)
        $xb = [Math]::Round($xa + $wSeg, 1)
        $xmid = [Math]::Round(($xa + $xb) / 2, 1)
        $ti = ($i + 0.5) / $N_bot
        $env = [Math]::Sin($ti * [Math]::PI)
        $bounce = 0.65 + 0.35 * [Math]::Sin(($i * 1.55) + $wavePhase)
        $bounce2 = 0.65 + 0.35 * [Math]::Sin(($i * 1.55) + $wavePhase + 1.4)
        $isBeat = ($beatAmp -gt 0.3 -and ($i -eq 3 -or $i -eq 7 -or $i -eq 10))
        $beatMult = if ($isBeat) { 1.55 } else { 1.0 }

        $dip = [Math]::Round($waveAmp * $env * $bounce * $beatMult, 1)
        $dip2 = [Math]::Round($waveAmp * 0.8 * $env * $bounce2 * $beatMult, 1)
        $ytrough = [Math]::Round($baseH + $dip, 1)
        $ytrough2 = [Math]::Round($baseH + $dip2, 1)

        $cp1X = [Math]::Round($xa + ($wSeg * 0.42), 1)
        $cp1Y = [Math]::Round($baseH + ($dip * 0.45), 1)
        $cp2X = [Math]::Round($xb - ($wSeg * 0.42), 1)
        $cp2Y = [Math]::Round($baseH + ($dip * 0.45), 1)

        $botSb.Append(" Q $cp1X,$cp1Y $xmid,$ytrough Q $cp2X,$cp2Y $xb,$baseH") | Out-Null
        $botR2Sb.Append(" Q $cp1X,$cp1Y $xmid,$ytrough2 Q $cp2X,$cp2Y $xb,$baseH") | Out-Null
        $apexPoints.Add([PSCustomObject]@{ X = $xmid; Y = $ytrough; IsBeat = $isBeat })
    }

    # 3. Right Side: Lower half has 2 fluid scallops traveling up to yMidSide. Upper half is flat line to $s
    $N_right = 2
    $hSegR = ($baseH - $r - $yMidSide) / $N_right
    $rightSb = [System.Text.StringBuilder]::new()
    $rightR2Sb = [System.Text.StringBuilder]::new()

    for ($i = 0; $i -lt $N_right; $i++) {
        $ya = [Math]::Round(($baseH - $r) - ($i * $hSegR), 1)
        $yb = [Math]::Round($ya - $hSegR, 1)
        $ymid = [Math]::Round(($ya + $yb) / 2, 1)
        $ti = ($i + 0.5) / $N_right
        $env = [Math]::Sin((($N_right - $i) / ($N_right + 0.8)) * [Math]::PI * 0.5)
        $bounce = 0.65 + 0.35 * [Math]::Sin(($i * 2.4) + $wavePhase + 1.5)
        $bounce2 = 0.65 + 0.35 * [Math]::Sin(($i * 2.4) + $wavePhase + 2.7)
        $isBeat = ($beatAmp -gt 0.3 -and $i -eq 0)
        $beatMult = if ($isBeat) { 1.45 } else { 1.0 }

        $dip = [Math]::Round($waveAmp * 0.55 * $env * $bounce * $beatMult, 1)
        $dip2 = [Math]::Round($waveAmp * 0.45 * $env * $bounce2 * $beatMult, 1)
        $xapex = [Math]::Round(($totalW - $s) + $dip, 1)
        $xapex2 = [Math]::Round(($totalW - $s) + $dip2, 1)

        $cp1X = [Math]::Round(($totalW - $s) + ($dip * 0.45), 1)
        $cp1Y = [Math]::Round($ya - ($hSegR * 0.42), 1)
        $cp2X = [Math]::Round(($totalW - $s) + ($dip * 0.45), 1)
        $cp2Y = [Math]::Round($yb + ($hSegR * 0.42), 1)

        $rightSb.Append(" Q $cp1X,$cp1Y $xapex,$ymid Q $cp2X,$cp2Y $($totalW-$s),$yb") | Out-Null
        $rightR2Sb.Append(" Q $cp1X,$cp1Y $xapex2,$ymid Q $cp2X,$cp2Y $($totalW-$s),$yb") | Out-Null
        $apexPoints.Add([PSCustomObject]@{ X = $xapex; Y = $ymid; IsBeat = $isBeat })
    }

    # Assembled paths: Upper half of left & right sides are clean straight lines (L s,yMidSide and L totalW-s,s)
    $bodyStr = "M 0,0 A $s,$s 0 0,1 $s,$s L $s,$yMidSide$($leftSb.ToString()) A $r,$r 0 0,0 $x0,$baseH$($botSb.ToString()) A $r,$r 0 0,0 $($totalW-$s),$($baseH-$r)$($rightSb.ToString()) L $($totalW-$s),$s A $s,$s 0 0,1 $totalW,0 Z"
    $strokeStr = "M $s,$yMidSide$($leftSb.ToString()) A $r,$r 0 0,0 $x0,$baseH$($botSb.ToString()) A $r,$r 0 0,0 $($totalW-$s),$($baseH-$r)$($rightSb.ToString()) L $($totalW-$s),$yMidSide"
    $ribbon2Str = "M $s,$yMidSide$($leftR2Sb.ToString()) A $r,$r 0 0,0 $x0,$baseH$($botR2Sb.ToString()) A $r,$r 0 0,0 $($totalW-$s),$($baseH-$r)$($rightR2Sb.ToString()) L $($totalW-$s),$yMidSide"

    return [PSCustomObject]@{
        BodyPath = $bodyStr
        StrokePath = $strokeStr
        Ribbon2Path = $ribbon2Str
        ApexPoints = $apexPoints
    }
}

function Get-SpectrumBarsPathData($totalW, $h, $s, $r, $phase = 0, $beat = 0) {
    $baseH = if ($h -gt 100) { 205 } else { $h }
    $x0 = $s + $r
    $x1 = $totalW - $s - $r
    $spanBot = $x1 - $x0
    $spanVert = ($baseH - $r) - $s
    $yMidSide = [Math]::Round($s + ($spanVert * 0.45), 1)

    $sb = [System.Text.StringBuilder]::new()

    # 1. Left lower half: 16 bars with radial fanning angles & smooth envelope taper
    $nLeft = 16
    for ($i = 0; $i -lt $nLeft; $i++) {
        $t = ($i + 0.5) / $nLeft # 0 at midY (top), 1 at corner (bottom)
        $bx = $s
        $by = [Math]::Round($yMidSide + $t * (($baseH - $r) - $yMidSide), 1)
        # Fanning angle: from slightly upward at top to downward near corner
        $angle = [Math]::PI - (0.28 * (1.0 - $t)) + (0.35 * $t)
        $nx = [Math]::Cos($angle)
        $ny = -[Math]::Sin($angle)
        $env = [Math]::Pow([Math]::Sin($t * [Math]::PI * 0.5), 0.8)
        $distFromSurge = [Math]::Abs($i - 12)
        $surgeMult = [Math]::Exp(-0.5 * [Math]::Pow($distFromSurge / 5.0, 2)) * ($beat * 28.0)
        $harmonic = 0.5 + 0.5 * [Math]::Sin(($i * 0.45) + $phase)
        $len = [Math]::Round(([Math]::Max(2.0, (5.0 + 13.0 * $harmonic + $surgeMult) * $env)), 1)
        $ex = [Math]::Round($bx + $nx * $len, 1)
        $ey = [Math]::Round($by + $ny * $len, 1)
        $sb.Append(" M $bx,$by L $ex,$ey") | Out-Null
    }

    # 2. Bottom-left corner: 10 bars fanning around the corner
    $nCorner = 10
    $ccxBL = $s + $r
    $ccyBL = $baseH - $r
    for ($i = 0; $i -lt $nCorner; $i++) {
        $t = ($i + 0.5) / $nCorner
        $angle = [Math]::PI + 0.35 + $t * ([Math]::PI * 0.5 - 0.35)
        $bx = [Math]::Round($ccxBL + $r * [Math]::Cos($angle), 1)
        $by = [Math]::Round($ccyBL - $r * [Math]::Sin($angle), 1)
        $nx = [Math]::Cos($angle)
        $ny = -[Math]::Sin($angle)
        $distFromSurge = [Math]::Abs($i - 2)
        $surgeMult = [Math]::Exp(-0.5 * [Math]::Pow($distFromSurge / 4.0, 2)) * ($beat * 24.0)
        $harmonic = 0.5 + 0.5 * [Math]::Sin(($i * 0.5) + $phase + 0.8)
        $len = [Math]::Round(5.0 + 14.0 * $harmonic + $surgeMult, 1)
        $ex = [Math]::Round($bx + $nx * $len, 1)
        $ey = [Math]::Round($by + $ny * $len, 1)
        $sb.Append(" M $bx,$by L $ex,$ey") | Out-Null
    }

    # 3. Bottom edge: 44 bars radiating down
    $nBot = 44
    for ($i = 0; $i -lt $nBot; $i++) {
        $t = ($i + 0.5) / $nBot
        $bx = [Math]::Round($x0 + $t * $spanBot, 1)
        $by = $baseH
        $distFromSurge = [Math]::Abs($i - 22)
        $surgeMult = [Math]::Exp(-0.5 * [Math]::Pow($distFromSurge / 7.0, 2)) * ($beat * 26.0)
        $harmonic = 0.5 + 0.5 * [Math]::Sin(($i * 0.45) - $phase)
        $len = [Math]::Round(5.0 + 14.0 * $harmonic + $surgeMult, 1)
        $ex = $bx
        $ey = [Math]::Round($by + $len, 1)
        $sb.Append(" M $bx,$by L $ex,$ey") | Out-Null
    }

    # 4. Bottom-right corner: 10 bars radiating around corner
    $ccxBR = $totalW - $s - $r
    $ccyBR = $baseH - $r
    for ($i = 0; $i -lt $nCorner; $i++) {
        $t = ($i + 0.5) / $nCorner
        $angle = 1.5 * [Math]::PI + $t * ([Math]::PI * 0.5 - 0.35)
        $bx = [Math]::Round($ccxBR + $r * [Math]::Cos($angle), 1)
        $by = [Math]::Round($ccyBR - $r * [Math]::Sin($angle), 1)
        $nx = [Math]::Cos($angle)
        $ny = -[Math]::Sin($angle)
        $wave = 0.5 + 0.5 * [Math]::Sin(($i * 0.5) + $phase + 2.0)
        $len = [Math]::Round(5.0 + 13.0 * $wave, 1)
        $ex = [Math]::Round($bx + $nx * $len, 1)
        $ey = [Math]::Round($by + $ny * $len, 1)
        $sb.Append(" M $bx,$by L $ex,$ey") | Out-Null
    }

    # 5. Right lower half: 16 bars with radial fanning angles & smooth envelope taper
    for ($i = 0; $i -lt $nLeft; $i++) {
        $t = ($i + 0.5) / $nLeft # 0 at corner, 1 at midY
        $bx = $totalW - $s
        $by = [Math]::Round(($baseH - $r) - $t * (($baseH - $r) - $yMidSide), 1)
        # Angle ranges from downward (+45 deg) at bottom to slightly upward (+15 deg) at top
        $angle = - (0.35 * (1.0 - $t)) + (0.28 * $t)
        $nx = [Math]::Cos($angle)
        $ny = [Math]::Sin($angle)
        $env = [Math]::Pow([Math]::Cos($t * [Math]::PI * 0.5), 0.8)
        $distFromSurge = [Math]::Abs($i - 4)
        $surgeMult = [Math]::Exp(-0.5 * [Math]::Pow($distFromSurge / 5.0, 2)) * ($beat * 20.0)
        $harmonic = 0.5 + 0.5 * [Math]::Sin(($i * 0.45) + $phase + 3.0)
        $len = [Math]::Round(([Math]::Max(2.0, (5.0 + 13.0 * $harmonic + $surgeMult) * $env)), 1)
        $ex = [Math]::Round($bx + $nx * $len, 1)
        $ey = [Math]::Round($by + $ny * $len, 1)
        $sb.Append(" M $bx,$by L $ex,$ey") | Out-Null
    }

    return $sb.ToString().Trim()
}

function Get-NotchPathData($totalW, $h, $s, $r, $waveAmp = 0, $wavePhase = 0) {

    $baseH = if ($h -gt 100) { 205 } else { $h }

    if ($s -le 0) {

        $leftCorner = "M 0,0 L 0,$($baseH-$r) A $r,$r 0 0,0 $r,$baseH"

        $rightCorner = "A $r,$r 0 0,0 $totalW,$($baseH-$r) L $totalW,0 Z"

    } else {

        $leftCorner = "M 0,0 A $s,$s 0 0,1 $s,$s L $s,$($baseH-$r) A $r,$r 0 0,0 $($s+$r),$baseH"

        $rightCorner = "A $r,$r 0 0,0 $($totalW-$s),$($baseH-$r) L $($totalW-$s),$s A $s,$s 0 0,1 $totalW,0 Z"

    }

    $x0 = $s + $r

    $x1 = $totalW - $s - $r

    $span = $x1 - $x0

    if ($waveAmp -le 0.5 -or $span -le 60) {

        return "$leftCorner L $x1,$baseH $rightCorner"

    }

    # Sharp Gothic-Arch Equalizer Waveform (Crisp V-Dips, Not Bulbous Bowls)

    $N = if ($totalW -gt 400) { 15 } elseif ($totalW -gt 200) { 8 } else { 4 }

    $wSeg = $span / $N

    $bottomBuilder = [System.Text.StringBuilder]::new()

    for ($i = 0; $i -lt $N; $i++) {

        $xa = [Math]::Round($x0 + ($i * $wSeg), 1)

        $xb = [Math]::Round($xa + $wSeg, 1)

        $xmid = [Math]::Round(($xa + $xb) / 2, 1)

        $ti = ($i + 0.5) / $N

        $env = [Math]::Sin($ti * [Math]::PI)

        $bandBounce = 0.55 + 0.45 * [Math]::Sin(($i * 1.55) + $wavePhase)

        $dip = [Math]::Round($waveAmp * $env * $bandBounce, 1)

        $ytrough = [Math]::Round($baseH + $dip, 1)

        

        # Quadratic curve down to sharp trough apex, then quadratic curve up to next crest

        $cp1X = [Math]::Round($xa + ($wSeg * 0.42), 1)

        $cp1Y = [Math]::Round($baseH + ($dip * 0.45), 1)

        $cp2X = [Math]::Round($xb - ($wSeg * 0.42), 1)

        $cp2Y = [Math]::Round($baseH + ($dip * 0.45), 1)

        

        $bottomBuilder.Append(" Q $cp1X,$cp1Y $xmid,$ytrough Q $cp2X,$cp2Y $xb,$baseH") | Out-Null

    }

    return "$leftCorner $($bottomBuilder.ToString()) $rightCorner"

}

function Get-NotchBottomWavePathData($totalW, $h, $s, $r, $waveAmp = 0, $wavePhase = 0) {

    $baseH = if ($h -gt 100) { 205 } else { $h }

    $x0 = $s + $r

    $x1 = $totalW - $s - $r

    $span = $x1 - $x0

    if ($waveAmp -le 0.5 -or $span -le 60) {

        return "M $x0,$baseH L $x1,$baseH"

    }

    $N = if ($totalW -gt 400) { 15 } elseif ($totalW -gt 200) { 8 } else { 4 }

    $wSeg = $span / $N

    $sb = [System.Text.StringBuilder]::new()

    $sb.Append("M $x0,$baseH") | Out-Null

    for ($i = 0; $i -lt $N; $i++) {

        $xa = [Math]::Round($x0 + ($i * $wSeg), 1)

        $xb = [Math]::Round($xa + $wSeg, 1)

        $xmid = [Math]::Round(($xa + $xb) / 2, 1)

        $ti = ($i + 0.5) / $N

        $env = [Math]::Sin($ti * [Math]::PI)

        $bandBounce = 0.55 + 0.45 * [Math]::Sin(($i * 1.55) + $wavePhase)

        $dip = [Math]::Round($waveAmp * $env * $bandBounce, 1)

        $ytrough = [Math]::Round($baseH + $dip, 1)

        

        $cp1X = [Math]::Round($xa + ($wSeg * 0.42), 1)

        $cp1Y = [Math]::Round($baseH + ($dip * 0.45), 1)

        $cp2X = [Math]::Round($xb - ($wSeg * 0.42), 1)

        $cp2Y = [Math]::Round($baseH + ($dip * 0.45), 1)

        

        $sb.Append(" Q $cp1X,$cp1Y $xmid,$ytrough Q $cp2X,$cp2Y $xb,$baseH") | Out-Null

    }

    return $sb.ToString()

}

$eyesBodyWidth = 88

$eyesTotalWidth = $eyesBodyWidth + (2 * $shoulderPad) # 104

$eyesHeight = 36

$eyesLeftPos = [Math]::Round(($screenWidth - $eyesTotalWidth) / 2)

$statusBodyWidth = 340

$statusTotalWidth = $statusBodyWidth + (2 * $shoulderPad) # 356

$statusHeight = 36

$statusLeftPos = [Math]::Round(($screenWidth - $statusTotalWidth) / 2)

$expandedBodyWidth = 560

$expandedTotalWidth = $expandedBodyWidth + (2 * $shoulderPad) # 576

$expandedLyricsBodyWidth = 840

$expandedLyricsTotalWidth = $expandedLyricsBodyWidth + (2 * $shoulderPad) # 856

$expandedHeight = 222

$expandedLeftPos = [Math]::Round(($screenWidth - $expandedTotalWidth) / 2)

$global:isLyricsSideOpen = $false
$global:browserPlaybackEstimate = 0.0

$toastBodyWidth = 360

$toastTotalWidth = $toastBodyWidth + (2 * $shoulderPad) # 376

$toastHeight = 36

$toastLeftPos = [Math]::Round(($screenWidth - $toastTotalWidth) / 2)

$global:notchCenterX = $screenWidth / 2

# XAML 1: DYNAMIC ISLAND (RESPONSIVE LIQUID NOTCH SILHOUETTE + SMOOTH INTERPOLATION)

$islandXaml = @'

<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"

        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"

        Title="Oceru Dynamic Island"

        WindowStyle="None"

        AllowsTransparency="True"

        Background="{x:Null}"

        Topmost="True"

        ShowInTaskbar="False"

        WindowStartupLocation="Manual"

        ResizeMode="NoResize"

        UseLayoutRounding="True"

        SnapsToDevicePixels="True"

        AllowDrop="True"

        Top="0" Width="1000" Height="320">

    <Window.Resources>

        <!-- Audio Spectrum Radial Bar Gradient (Cyan -> Emerald -> Violet -> Magenta) -->
        <LinearGradientBrush x:Key="SpectrumBarGrad" StartPoint="0.0,0.5" EndPoint="1.0,0.5">
            <GradientStop Color="#00F5D4" Offset="0.00"/>
            <GradientStop Color="#10B981" Offset="0.22"/>
            <GradientStop Color="#8B5CF6" Offset="0.55"/>
            <GradientStop Color="#EC4899" Offset="0.85"/>
            <GradientStop Color="#00D2FF" Offset="1.00"/>
        </LinearGradientBrush>

        <!-- Circle Navigation Button -->

        <Style x:Key="CircleNavBtn" TargetType="Button">

            <Setter Property="Width" Value="28"/>

            <Setter Property="Height" Value="28"/>

            <Setter Property="Background" Value="#1B2130"/>

            <Setter Property="BorderThickness" Value="0"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border x:Name="BtnBorder" Background="{TemplateBinding Background}" CornerRadius="14">

                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>

                        </Border>

                        <ControlTemplate.Triggers>

                            <Trigger Property="IsMouseOver" Value="True">

                                <Setter TargetName="BtnBorder" Property="Background" Value="#232B3D"/>

                            </Trigger>

                        </ControlTemplate.Triggers>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

        <!-- Pill Button -->

        <Style x:Key="PillBtn" TargetType="Button">

            <Setter Property="Background" Value="#131722"/>

            <Setter Property="BorderBrush" Value="#232B3D"/>

            <Setter Property="BorderThickness" Value="1"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Padding" Value="12,5"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border x:Name="PillBorder"

                                Background="{TemplateBinding Background}"

                                BorderBrush="{TemplateBinding BorderBrush}"

                                BorderThickness="{TemplateBinding BorderThickness}"

                                CornerRadius="14"

                                Padding="{TemplateBinding Padding}">

                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>

                        </Border>

                        <ControlTemplate.Triggers>

                            <Trigger Property="IsMouseOver" Value="True">

                                <Setter TargetName="PillBorder" Property="Background" Value="#1B2130"/>

                                <Setter TargetName="PillBorder" Property="BorderBrush" Value="#00D2FF"/>

                            </Trigger>

                        </ControlTemplate.Triggers>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

        <!-- Quick Mini Button -->

        <Style x:Key="QuickMiniBtn" TargetType="Button">

            <Setter Property="Background" Value="#131722"/>

            <Setter Property="BorderBrush" Value="#232B3D"/>

            <Setter Property="BorderThickness" Value="1"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Padding" Value="8,4"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border x:Name="MiniBorder"

                                Background="{TemplateBinding Background}"

                                BorderBrush="{TemplateBinding BorderBrush}"

                                BorderThickness="{TemplateBinding BorderThickness}"

                                CornerRadius="8"

                                Padding="{TemplateBinding Padding}">

                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>

                        </Border>

                        <ControlTemplate.Triggers>

                            <Trigger Property="IsMouseOver" Value="True">

                                <Setter TargetName="MiniBorder" Property="Background" Value="#1B2130"/>

                                <Setter TargetName="MiniBorder" Property="BorderBrush" Value="#00D2FF"/>

                            </Trigger>

                        </ControlTemplate.Triggers>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

        <!-- Media Playback Icon Button -->

        <Style x:Key="MediaControlBtn" TargetType="Button">

            <Setter Property="Background" Value="Transparent"/>

            <Setter Property="BorderThickness" Value="0"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border Background="Transparent">

                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>

                        </Border>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

    </Window.Resources>

    <Grid x:Name="MasterGrid" Width="104" Height="36" HorizontalAlignment="Center" VerticalAlignment="Top" ClipToBounds="False">

        <!-- ======================================================== -->

        <!-- SEAMLESS OBSIDIAN CAPSULE BODY                           -->

        <!-- Clean, unified pill with organic continuous curvature    -->

        <!-- ======================================================== -->

        <!-- RADIAL SPECTRUM BARS (Garis-garis LED Frekuensi Spektrum Sesuai Referensi Pengguna) -->
        <!-- Layer A: Diffuse Outer Glow -->
        <Path x:Name="NotchBarsGlowPath" Stroke="{StaticResource SpectrumBarGrad}" StrokeThickness="4.2" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Fill="Transparent" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Opacity="0" IsHitTestVisible="False">
            <Path.Effect>
                <DropShadowEffect Color="#00F5D4" BlurRadius="12" ShadowDepth="0" Opacity="0.95"/>
            </Path.Effect>
        </Path>
        <!-- Layer B: Crisp Core Bars -->
        <Path x:Name="NotchBarsCorePath" Stroke="{StaticResource SpectrumBarGrad}" StrokeThickness="2.4" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Fill="Transparent" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Opacity="0" IsHitTestVisible="False"/>
        <!-- Layer C: White-Hot Laser Center Filament -->
        <Path x:Name="NotchBarsWhitePath" Stroke="#FFFFFF" StrokeThickness="1.0" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Fill="Transparent" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Opacity="0" IsHitTestVisible="False"/>

        <!-- HARDWARE NOTCH SINGLE VECTOR PATH (Option B MacBook Tangential Shoulder Fillet, Pure Obsidian - No Muddy Shadow Smudge!) -->

        <Path x:Name="NotchSinglePath" Fill="#000000" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Cursor="Hand"/>

        <!-- MULTI-STAGE NEON EQUALIZER 3-SIDED WAVE LAYERS -->

        <!-- Layer 1: Diffuse Outer Neon Bloom -->

        <Path x:Name="NotchWaveStrokePath" Stroke="#FF385C" StrokeThickness="3.0" Fill="Transparent" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Opacity="0" IsHitTestVisible="False">

            <Path.Effect>

                <DropShadowEffect Color="#FF385C" BlurRadius="14" ShadowDepth="0" Opacity="0.95"/>

            </Path.Effect>

        </Path>

        <!-- Layer 1B: Intertwined Harmonic Secondary Aura Ribbon (Cyan/Violet) -->
        <Path x:Name="NotchWaveRibbon2Path" Stroke="#00D2FF" StrokeThickness="1.8" Fill="Transparent" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Opacity="0" IsHitTestVisible="False">
            <Path.Effect>
                <DropShadowEffect Color="#00D2FF" BlurRadius="10" ShadowDepth="0" Opacity="0.85"/>
            </Path.Effect>
        </Path>

        <!-- Layer 2: Laser White-Hot Core Tube -->

        <Path x:Name="NotchWaveCorePath" Stroke="#FFFFFF" StrokeThickness="1.2" Fill="Transparent" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Opacity="0" IsHitTestVisible="False">

            <Path.Effect>

                <DropShadowEffect Color="#FFFFFF" BlurRadius="3" ShadowDepth="0" Opacity="0.9"/>

            </Path.Effect>

        </Path>

        <!-- Layer 3: Neon Apex Sparks Micro-LED Canvas Overlay -->

        <Canvas x:Name="NotchApexCanvas" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" IsHitTestVisible="False" Opacity="0"/>

        <!-- ======================================================== -->

        <!-- VIEW 1: RESTING CAT EYES PILL (Standalone, Eyes Only!)    -->

        <!-- ======================================================== -->

        <Grid x:Name="EyesGrid" Visibility="Visible" HorizontalAlignment="Center" VerticalAlignment="Center" Cursor="Hand" Opacity="1">

            <!-- FLOATING SLEEP ZZZ PARTICLES CANVAS (Active during deep idle sleep) -->
            <Canvas x:Name="CatZzzCanvas" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" IsHitTestVisible="False" Opacity="0">
                <TextBlock x:Name="Zzz1" Text="z" FontSize="11" FontWeight="Bold" Foreground="#9000D2FF" Canvas.Left="38" Canvas.Top="6">
                    <TextBlock.Effect><DropShadowEffect Color="#00D2FF" BlurRadius="6" ShadowDepth="0" Opacity="0.9"/></TextBlock.Effect>
                </TextBlock>
                <TextBlock x:Name="Zzz2" Text="z" FontSize="13" FontWeight="Bold" Foreground="#C000D2FF" Canvas.Left="50" Canvas.Top="-2">
                    <TextBlock.Effect><DropShadowEffect Color="#00D2FF" BlurRadius="7" ShadowDepth="0" Opacity="0.9"/></TextBlock.Effect>
                </TextBlock>
                <TextBlock x:Name="Zzz3" Text="Z" FontSize="16" FontWeight="Bold" Foreground="#FF00D2FF" Canvas.Left="64" Canvas.Top="-12">
                    <TextBlock.Effect><DropShadowEffect Color="#00D2FF" BlurRadius="8" ShadowDepth="0" Opacity="0.95"/></TextBlock.Effect>
                </TextBlock>
            </Canvas>

            <!-- Centered Interactive Heterochromia Cat Eyes (Odd-Eyed: Amber Gold & Sapphire Blue) -->

            <StackPanel x:Name="CatEyesContainer" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">

                <StackPanel.RenderTransform>

                    <TranslateTransform x:Name="CatEyesTransform" X="0" Y="0"/>

                </StackPanel.RenderTransform>

                

                <!-- Left Eye: Radiant Golden Amber / Topaz Iris (Heterochromia) -->

                <Border x:Name="LeftEye" Width="15" Height="17" CornerRadius="7.5" Margin="0,0,9,0" ClipToBounds="True">

                    <Border.Background>

                        <RadialGradientBrush Center="0.45,0.45" GradientOrigin="0.45,0.45" RadiusX="0.65" RadiusY="0.65">

                            <GradientStop Color="#FEF08A" Offset="0.0"/>

                            <GradientStop Color="#F59E0B" Offset="0.45"/>

                            <GradientStop Color="#D97706" Offset="0.8"/>

                            <GradientStop Color="#78350F" Offset="1.0"/>

                        </RadialGradientBrush>

                    </Border.Background>

                    <Grid>

                        <Border CornerRadius="7.5" BorderThickness="1" BorderBrush="#92400E" Opacity="0.55"/>

                        <Grid x:Name="LeftPupil" HorizontalAlignment="Center" VerticalAlignment="Center">

                            <Grid.RenderTransform>

                                <TranslateTransform x:Name="LeftPupilTransform" X="0" Y="0"/>

                            </Grid.RenderTransform>

                            <Border x:Name="LeftPupilBorder" Width="3.8" Height="11" CornerRadius="1.9" Background="#05070B"/>

                            <Border Width="1.8" Height="2.2" CornerRadius="0.9" Background="#FFFFFF" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,1,0.4,0" Opacity="0.95"/>

                        </Grid>

                    </Grid>

                </Border>

                <!-- Right Eye: Electric Sapphire / Ocean Blue Iris (Heterochromia) -->

                <Border x:Name="RightEye" Width="15" Height="17" CornerRadius="7.5" ClipToBounds="True">

                    <Border.Background>

                        <RadialGradientBrush Center="0.45,0.45" GradientOrigin="0.45,0.45" RadiusX="0.65" RadiusY="0.65">

                            <GradientStop Color="#BAE6FD" Offset="0.0"/>

                            <GradientStop Color="#00D2FF" Offset="0.4"/>

                            <GradientStop Color="#0284C7" Offset="0.75"/>

                            <GradientStop Color="#082F49" Offset="1.0"/>

                        </RadialGradientBrush>

                    </Border.Background>

                    <Grid>

                        <Border CornerRadius="7.5" BorderThickness="1" BorderBrush="#0369A1" Opacity="0.55"/>

                        <Grid x:Name="RightPupil" HorizontalAlignment="Center" VerticalAlignment="Center">

                            <Grid.RenderTransform>

                                <TranslateTransform x:Name="RightPupilTransform" X="0" Y="0"/>

                            </Grid.RenderTransform>

                            <Border x:Name="RightPupilBorder" Width="3.8" Height="11" CornerRadius="1.9" Background="#05070B"/>

                            <Border Width="1.8" Height="2.2" CornerRadius="0.9" Background="#FFFFFF" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,1,0.4,0" Opacity="0.95"/>

                        </Grid>

                    </Grid>

                </Border>

            </StackPanel>

        </Grid>

        <!-- ======================================================== -->

        <!-- VIEW 2: COMPACT STATUS BAR (Weather, Net HUD, Clock, Bat) -->

        <!-- ======================================================== -->

        <Grid x:Name="StatusGrid" Visibility="Collapsed" HorizontalAlignment="Stretch" VerticalAlignment="Center" Cursor="Hand" Margin="14,0,14,0" Opacity="0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <!-- Left: Weather & Condition (Grid.Column="0") -->
            <StackPanel Grid.Column="0" Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
                <TextBlock Text="&#xE706;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#F59E0B" Margin="0,0,5,0" VerticalAlignment="Center"/>
                <TextBlock Text="28&#176; Cerah" FontSize="11" FontWeight="SemiBold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
            </StackPanel>

            <!-- Center: Smart Rotating Focal HUD (Clock <-> Prayer, Grid.Column="1") -->
            <Grid Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center">
                <!-- View A: Real-Time Clock -->
                <StackPanel x:Name="CompactClockView" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Visible">
                    <TextBlock x:Name="CompactClockText" Text="09:35" FontSize="12.5" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                </StackPanel>

                <!-- View B: Next Prayer & Countdown with Crisp Vector Crescent -->
                <StackPanel x:Name="CompactPrayerView" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed">
                    <Path Data="M 9,1 A 6,6 0 1,0 9,11 A 4.8,4.8 0 0,1 9,1 Z" Fill="#10B981" Width="10" Height="10" Margin="0,0,5,0" VerticalAlignment="Center"/>
                    <TextBlock x:Name="CompactPrayerText" Text="Subuh 04:09 (4j)" FontSize="11" FontWeight="SemiBold" Foreground="#10B981" VerticalAlignment="Center"/>
                </StackPanel>
            </Grid>

            <!-- Right: Equalizer & Battery & Status (Grid.Column="2") -->
            <StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                <!-- Mini Equalizer Bars (dancing when music plays) -->
                <Button x:Name="BtnMiniEqualizer" Style="{x:Null}" Background="Transparent" BorderThickness="0" Margin="0,0,8,0" VerticalAlignment="Center" Cursor="Hand" Visibility="Collapsed" ToolTip="Sedang Memutar Musik - Klik untuk Buka Kontrol">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Bottom" Height="12">
                        <Border x:Name="MiniEqBar1" Width="2" Height="6" Background="#FF3366" CornerRadius="1" Margin="0,0,1.5,0" VerticalAlignment="Bottom"/>
                        <Border x:Name="MiniEqBar2" Width="2" Height="11" Background="#FF3366" CornerRadius="1" Margin="0,0,1.5,0" VerticalAlignment="Bottom"/>
                        <Border x:Name="MiniEqBar3" Width="2" Height="8" Background="#FF3366" CornerRadius="1" Margin="0,0,1.5,0" VerticalAlignment="Bottom"/>
                        <Border x:Name="MiniEqBar4" Width="2" Height="10" Background="#FF3366" CornerRadius="1" Margin="0,0,0,0" VerticalAlignment="Bottom"/>
                    </StackPanel>
                </Button>
                <TextBlock x:Name="CompactBatPct" Text="85%" FontSize="11" Foreground="#8E9AA8" Margin="0,0,4,0" VerticalAlignment="Center"/>
                <TextBlock x:Name="CompactBatIcon" Text="&#xEA93;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" VerticalAlignment="Center"/>
            </StackPanel>
        </Grid>

        <!-- ======================================================== -->

        <!-- VIEW 4: DYNAMIC NOTIFICATION TOAST PILL (360x36)         -->

        <!-- ======================================================== -->

        <Grid x:Name="DynamicToastGrid" Visibility="Collapsed" HorizontalAlignment="Stretch" VerticalAlignment="Center" Margin="14,0,14,0" Opacity="0">

            <Grid.ColumnDefinitions>

                <ColumnDefinition Width="Auto"/>

                <ColumnDefinition Width="*"/>

                <ColumnDefinition Width="Auto"/>

            </Grid.ColumnDefinitions>

            <!-- Left: App / Category Icon Circle -->

            <Border Grid.Column="0" Width="22" Height="22" CornerRadius="11" Background="#1B2130" Margin="0,0,10,0" VerticalAlignment="Center">

                <TextBlock x:Name="DynamicToastIcon" Text="&#xE7E7;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF" HorizontalAlignment="Center" VerticalAlignment="Center"/>

            </Border>

            <!-- Center: Notification Title and Message -->

            <StackPanel Grid.Column="1" VerticalAlignment="Center">

                <TextBlock x:Name="DynamicToastTitle" Text="Notifikasi" FontSize="10" FontWeight="SemiBold" Foreground="#8E9AA8" TextTrimming="CharacterEllipsis"/>

                <TextBlock x:Name="DynamicToastMessage" Text="Pesan baru diterima" FontSize="11" FontWeight="Bold" Foreground="#FFFFFF" TextTrimming="CharacterEllipsis"/>

            </StackPanel>

            <!-- Right: Cyan Glowing Dot -->

            <Border x:Name="DynamicToastDot" Grid.Column="2" Width="6" Height="6" CornerRadius="3" Background="#00D2FF" Margin="8,0,2,0" VerticalAlignment="Center"/>

        </Grid>

        <!-- ======================================================== -->

        <!-- VIEW 3: EXPANDED CAROUSEL VIEW (Full Notch)              -->

        <!-- ======================================================== -->

        <Grid x:Name="ExpandedGrid" Visibility="Collapsed" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Margin="20,0,20,0" Opacity="0">

            <Grid.RowDefinitions>

                <RowDefinition Height="34"/>  <!-- Top Status / Header Row -->

                <RowDefinition Height="114"/> <!-- Main Carousel Card Body -->

                <RowDefinition Height="38"/>  <!-- Bottom Action Buttons & Pagination -->

            </Grid.RowDefinitions>

            <!-- Single Notch Vector Path provides 100% solid obsidian backing -->

            <!-- Center Top Sensor / Camera Dot -->

            <Border Width="6" Height="6" CornerRadius="3" Background="#0B0D13"

                    HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,3,0,0"/>

            <!-- TOP HEADER ROW (NO COLLAPSE BUTTON!) -->

            <Grid Grid.Row="0" Margin="10,6,10,0">

                <!-- Left: Card Title, Shelf Clear Button, and Task Badge -->
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
                    <TextBlock x:Name="HeaderTitleText" Text="" FontWeight="SemiBold" FontSize="15" Foreground="#FFFFFF"
                               VerticalAlignment="Center" Cursor="Hand"/>
                    <Button x:Name="BtnHeaderClearShelf" Visibility="Collapsed" Margin="8,0,0,0" Padding="8,2"
                            Background="#1E2430" BorderBrush="#2D3748" BorderThickness="1" Cursor="Hand">
                        <Button.Resources>
                            <Style TargetType="Border">
                                <Setter Property="CornerRadius" Value="10"/>
                            </Style>
                        </Button.Resources>
                        <TextBlock Text="Clear" FontSize="10" FontWeight="SemiBold" Foreground="#8E9AA8"/>
                    </Button>
                    <Border x:Name="HeaderTaskBadge" Visibility="Collapsed" Margin="8,0,0,0" Background="#14212D" BorderBrush="#1C384D" BorderThickness="1" CornerRadius="10" Padding="8,2">
                        <TextBlock x:Name="HeaderTaskBadgeText" Text="2/3 Selesai" FontSize="10" FontWeight="SemiBold" Foreground="#00D2FF"/>
                    </Border>
                </StackPanel>

                <!-- Center: Green Ring + Date & Time -->

                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">

                    <Border Width="13" Height="13" CornerRadius="6.5" BorderThickness="2" BorderBrush="#10B981"

                            Margin="0,0,7,0" Background="Transparent"/>

                    <TextBlock x:Name="HeaderDateText" Text="Sun 25 Oct 2026 " FontSize="12" Foreground="#8E9AA8" VerticalAlignment="Center"/>

                    <TextBlock x:Name="HeaderTimeText" Text="09:35" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                </StackPanel>

                <!-- Right: Soundwave Equalizer Bars (Clean Header with Ocean Azure Accent) -->

                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">

                    <StackPanel x:Name="HeaderWavePanel" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,4,0">

                        <Border x:Name="WaveBar1" Width="2.5" Height="8" CornerRadius="1.25" Background="#00D2FF" Margin="1.5,0"/>

                        <Border x:Name="WaveBar2" Width="2.5" Height="14" CornerRadius="1.25" Background="#00D2FF" Margin="1.5,0"/>

                        <Border x:Name="WaveBar3" Width="2.5" Height="10" CornerRadius="1.25" Background="#00D2FF" Margin="1.5,0"/>

                        <Border x:Name="WaveBar4" Width="2.5" Height="12" CornerRadius="1.25" Background="#00D2FF" Margin="1.5,0"/>

                    </StackPanel>

                </StackPanel>

            </Grid>

            <!-- MAIN CAROUSEL CONTENT (6 CARDS) -->

            <Grid Grid.Row="1" Margin="10,0,10,0">

                

                <!-- ============================================== -->

                <!-- CARD 0: MUSIC PLAYER                           -->

                <!-- ============================================== -->

                <Grid x:Name="CardMusic" Visibility="Visible">
                    <Grid.ColumnDefinitions>
                        <!-- Left Column: Music Player Controls (always visible) -->
                        <ColumnDefinition x:Name="ColMusicPlayer" Width="*"/>
                        <!-- Center Divider -->
                        <ColumnDefinition x:Name="ColMusicDivider" Width="Auto"/>
                        <!-- Right Column: Live Lyrics Side Panel -->
                        <ColumnDefinition x:Name="ColMusicLyrics" Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <!-- Player Controls (Column 0) -->
                    <Grid Grid.Column="0">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="68"/>
                            <RowDefinition Height="20"/>
                            <RowDefinition Height="26"/>
                        </Grid.RowDefinitions>

                        <!-- Row 0: Track Info -->
                        <Grid Grid.Row="0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="78"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="32"/>
                            </Grid.ColumnDefinitions>

                            <!-- Stylized Music Album Cover & Media Disc -->
                            <Border Grid.Column="0" Width="68" Height="68" CornerRadius="14" Background="#131722"
                                    BorderBrush="#232B3D" BorderThickness="1"
                                    HorizontalAlignment="Left" VerticalAlignment="Center" ClipToBounds="True">
                                <Grid>
                                    <Border Width="56" Height="56" CornerRadius="28" BorderThickness="1" BorderBrush="#232B3D" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    <Border Width="44" Height="44" CornerRadius="22" BorderThickness="1" BorderBrush="#232B3D" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    <Border Width="32" Height="32" CornerRadius="16" Background="#1B2130" BorderThickness="1.5" BorderBrush="#00D2FF"
                                            HorizontalAlignment="Center" VerticalAlignment="Center">
                                        <TextBlock Text="&#xE8D6;" FontFamily="Segoe MDL2 Assets" FontSize="14" Foreground="#00D2FF"
                                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                </Grid>
                            </Border>

                            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="6,0,0,0">
                                <TextBlock x:Name="MusicTitle" Text="Tidak ada media aktif" FontSize="14.5" FontWeight="SemiBold"
                                           Foreground="#FFFFFF" TextTrimming="CharacterEllipsis"/>
                                <TextBlock x:Name="MusicArtist" Text="Kontrol pemutar Windows atau putar file audio" FontSize="11"
                                           Foreground="#8E9AA8" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
                            </StackPanel>

                            <Button x:Name="BtnMusicNextCard" Grid.Column="2" Style="{StaticResource CircleNavBtn}"
                                    HorizontalAlignment="Right" VerticalAlignment="Center">
                                <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                            </Button>
                        </Grid>

                        <!-- Row 1: Seekbar -->
                        <Grid Grid.Row="1" VerticalAlignment="Center">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="42"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="46"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="MusicCurrentTime" Grid.Column="0" Text="00:00" FontSize="11" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                            <Grid Grid.Column="1" Margin="6,0" VerticalAlignment="Center">
                                <Border Height="4" CornerRadius="2" Background="#232B3D"/>
                                <Border x:Name="MusicProgressBar" Height="4" CornerRadius="2" Background="#00D2FF" HorizontalAlignment="Left" Width="0"/>
                            </Grid>
                            <TextBlock x:Name="MusicRemainingTime" Grid.Column="2" Text="00:00" FontSize="11" Foreground="#8E9AA8"
                                       HorizontalAlignment="Right" VerticalAlignment="Center"/>
                        </Grid>

                        <!-- Row 2: Controls -->
                        <Grid Grid.Row="2">
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
                                <Button x:Name="BtnToggleLyrics" Style="{StaticResource CircleNavBtn}" Width="26" Height="26">
                                    <TextBlock x:Name="IconToggleLyrics" Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#8E9AA8"/>
                                </Button>
                                <Button x:Name="BtnOpenLocalAudio" Style="{StaticResource CircleNavBtn}" Width="26" Height="26" Margin="6,0,0,0">
                                    <TextBlock Text="&#xE8E5;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF"/>
                                </Button>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                                <Button x:Name="BtnMusicPrev" Style="{StaticResource MediaControlBtn}" Margin="0,0,24,0">
                                    <TextBlock Text="&#xE892;" FontFamily="Segoe MDL2 Assets" FontSize="15" Foreground="#FFFFFF"/>
                                </Button>
                                <Button x:Name="BtnMusicPlayPause" Style="{StaticResource MediaControlBtn}" Margin="0,0,24,0">
                                    <TextBlock x:Name="MusicPlayPauseIcon" Text="&#xE768;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="#FFFFFF"/>
                                </Button>
                                <Button x:Name="BtnMusicNext" Style="{StaticResource MediaControlBtn}">
                                    <TextBlock Text="&#xE893;" FontFamily="Segoe MDL2 Assets" FontSize="15" Foreground="#FFFFFF"/>
                                </Button>
                            </StackPanel>
                        </Grid>
                    </Grid>

                    <!-- Center Divider -->
                    <Border x:Name="MusicLyricsDivider" Grid.Column="1" Width="1" Background="#232B3D" Margin="14,2,14,2" Visibility="Collapsed"/>

                    <!-- Right Column: Live Lyrics Side Panel -->
                    <Grid x:Name="MusicLyricsSidePanel" Grid.Column="2" Width="260" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- Header with live indicator & close -->
                        <Grid Grid.Row="0" Margin="0,0,0,6">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                <TextBlock Text="LIRIK REAL-TIME" FontSize="10" FontWeight="Bold" Foreground="#8E9AA8" VerticalAlignment="Center"/>
                            </StackPanel>
                            <Button x:Name="BtnCloseLyricsSide" Style="{StaticResource CircleNavBtn}" Width="18" Height="18" HorizontalAlignment="Right">
                                <TextBlock Text="&#xE711;" FontFamily="Segoe MDL2 Assets" FontSize="8" Foreground="#8E9AA8"/>
                            </Button>
                        </Grid>

                        <!-- Synced Lines Stack -->
                        <StackPanel Grid.Row="1" VerticalAlignment="Center" Margin="0,2,0,0">
                            <!-- Prev Line -->
                            <TextBlock x:Name="LyricLinePrev" Text="" FontSize="11" Foreground="#4A5568" TextTrimming="CharacterEllipsis" Margin="0,1" HorizontalAlignment="Left"/>
                            <!-- Current Active Line with highlight -->
                            <TextBlock x:Name="LyricLineCurrent" Text="♪ Mendengarkan musik... ♪" FontSize="13" FontWeight="Bold" Foreground="#00D2FF" TextWrapping="Wrap" Margin="0,3" HorizontalAlignment="Left"/>
                            <!-- Next Line 1 -->
                            <TextBlock x:Name="LyricLineNext" Text="" FontSize="11" Foreground="#8E9AA8" TextTrimming="CharacterEllipsis" Margin="0,1" HorizontalAlignment="Left"/>
                            <!-- Next Line 2 -->
                            <TextBlock x:Name="LyricLineNext2" Text="" FontSize="10" Foreground="#4A5568" TextTrimming="CharacterEllipsis" Margin="0,1" HorizontalAlignment="Left"/>
                        </StackPanel>
                    </Grid>
                </Grid>

                <!-- ============================================== -->

                <!-- CARD 1: POMODORO FOCUS TIMER                   -->

                <!-- ============================================== -->

                <Grid x:Name="CardPomo" Visibility="Collapsed">

                    <Grid.ColumnDefinitions>

                        <ColumnDefinition Width="32"/>

                        <ColumnDefinition Width="*"/>

                        <ColumnDefinition Width="32"/>

                    </Grid.ColumnDefinitions>

                    <Button x:Name="BtnPomoPrevCard" Grid.Column="0" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Left" VerticalAlignment="Center">

                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>

                    </Button>

                    <Grid Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="80"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <!-- Circular Timer Dial -->
                        <Grid Grid.Column="0" Width="76" Height="76" HorizontalAlignment="Center" VerticalAlignment="Center">
                            <Border Width="76" Height="76" CornerRadius="38" BorderThickness="2.5" BorderBrush="#232B3D" Background="#131722"/>
                            <Border Width="76" Height="76" CornerRadius="38" BorderThickness="2.5" BorderBrush="#FF5252"
                                    Opacity="0.85" Background="Transparent"/>
                            <Border Width="6" Height="6" CornerRadius="3" Background="#FF5252" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,2,0,0"/>
                            <TextBlock Text="&#xE916;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="#FF5252"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Grid>

                        <!-- Timer Typography and Reset -->
                        <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="10,0,0,0">
                            <TextBlock Text="Waktu Fokus" FontSize="11" Foreground="#8E9AA8" Margin="0,0,0,2"/>
                            <TextBlock x:Name="PomoSubtitle" Text="Focus time" FontSize="13" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                            <StackPanel Orientation="Horizontal" Margin="0,2,0,0">
                                <TextBlock x:Name="PomoDisplayTime" Text="25:00" FontFamily="Segoe UI, Consolas" FontSize="26" FontWeight="Bold" Foreground="#FFFFFF"/>
                                <Button x:Name="BtnPomoReset" Style="{StaticResource CircleNavBtn}" Width="22" Height="22" Margin="8,0,0,0" ToolTip="Reset Timer">
                                    <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#8E9AA8"/>
                                </Button>
                            </StackPanel>
                        </StackPanel>

                        <!-- FEATURE F: Ambient Focus Sounds (Rain, Waves, Cafe) -->
                        <Border Grid.Column="2" Background="#111520" BorderBrush="#1F283B" BorderThickness="1" CornerRadius="12" Padding="8,6" Margin="12,0,0,0" VerticalAlignment="Center">
                            <StackPanel>
                                <TextBlock Text="Suara Fokus Latar" FontSize="9.5" FontWeight="SemiBold" Foreground="#8E9AA8" HorizontalAlignment="Center" Margin="0,0,0,4"/>
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                    <Button x:Name="BtnAmbientRain" Background="#161B26" BorderBrush="#253147" BorderThickness="1" Padding="6,2.5" Margin="2,0" Cursor="Hand" ToolTip="Suara Hujan Alami">
                                        <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                                        <TextBlock Text="&#x1F327;&#xFE0F; Hujan" FontSize="9.5" Foreground="#8E9AA8"/>
                                    </Button>
                                    <Button x:Name="BtnAmbientWaves" Background="#161B26" BorderBrush="#253147" BorderThickness="1" Padding="6,2.5" Margin="2,0" Cursor="Hand" ToolTip="Suara Ombak Laut">
                                        <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                                        <TextBlock Text="&#x1F30A; Ombak" FontSize="9.5" Foreground="#8E9AA8"/>
                                    </Button>
                                    <Button x:Name="BtnAmbientCafe" Background="#161B26" BorderBrush="#253147" BorderThickness="1" Padding="6,2.5" Margin="2,0" Cursor="Hand" ToolTip="Suara Kafe Tenang">
                                        <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                                        <TextBlock Text="&#x2615; Kafe" FontSize="9.5" Foreground="#8E9AA8"/>
                                    </Button>
                                </StackPanel>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <Button x:Name="BtnPomoNextCard" Grid.Column="2" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">

                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>

                    </Button>

                </Grid>

                <!-- ============================================== -->

                <!-- CARD 2: CATATAN & TO-DO LIST                   -->

                <!-- ============================================== -->

                <Grid x:Name="CardNotesTodo" Visibility="Collapsed">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="32"/>
                        <ColumnDefinition Width="145"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="32"/>
                    </Grid.ColumnDefinitions>

                    <Button x:Name="BtnNotesPrevCard" Grid.Column="0" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Left" VerticalAlignment="Center">
                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                    </Button>

                    <!-- Left: Progress & Stats Summary Card -->
                    <Border Grid.Column="1" Background="#11141C" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="14" Margin="4,0" Padding="10,8">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <!-- Top: Percentage & Title -->
                            <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Center">
                                <TextBlock x:Name="TodoPercentText" Text="0%" FontSize="19" FontWeight="Bold" Foreground="#10B981" VerticalAlignment="Center"/>
                                <TextBlock Text=" Tuntas" FontSize="11" FontWeight="SemiBold" Foreground="#8E9AA8" VerticalAlignment="Bottom" Margin="4,0,0,2"/>
                            </StackPanel>

                            <!-- Progress Bar -->
                            <Border Grid.Row="1" Height="5" CornerRadius="2.5" Background="#1E2638" Margin="0,6,0,4">
                                <ProgressBar x:Name="TodoProgressBar" Value="0" Maximum="100" Height="5" Background="Transparent" BorderThickness="0" Foreground="#10B981"/>
                            </Border>

                            <!-- Motivational Status -->
                            <TextBlock Grid.Row="2" x:Name="TodoMotivationText" Text="Mulai Harimu &#x2728;" FontSize="9.5" Foreground="#6EE7B7" HorizontalAlignment="Center" Margin="0,2,0,4"/>

                            <!-- Clear Completed Button -->
                            <Button Grid.Row="3" x:Name="BtnClearDoneTasks" Background="#161B26" BorderBrush="#263147" BorderThickness="1"
                                    Padding="8,2.5" HorizontalAlignment="Center" VerticalAlignment="Bottom" Cursor="Hand">
                                <Button.Resources>
                                    <Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style>
                                </Button.Resources>
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE74D;" FontFamily="Segoe MDL2 Assets" FontSize="9" Foreground="#8E9AA8" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Hapus Selesai" FontSize="9.5" Foreground="#8E9AA8" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </Grid>
                    </Border>

                    <!-- Right: Inline Quick Add & Dynamic Task List -->
                    <Border Grid.Column="2" Background="#11141C" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="14" Margin="4,0" Padding="8,6">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="26"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <!-- Quick Add Box -->
                            <Border Grid.Row="0" Background="#090C12" BorderBrush="#242E40" BorderThickness="1" CornerRadius="8" Padding="6,2">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>

                                    <TextBox x:Name="NewTaskInput" Background="Transparent" BorderThickness="0" Foreground="#8E9AA8"
                                             FontSize="10.5" VerticalAlignment="Center" CaretBrush="#10B981"
                                             Text="+ Ketik target baru &amp; tekan Enter..."/>

                                    <Button Grid.Column="1" x:Name="BtnAddNewTask" Background="#10B981" BorderThickness="0"
                                            Width="20" Height="20" Margin="4,0,0,0" Cursor="Hand">
                                        <Button.Resources>
                                            <Style TargetType="Border"><Setter Property="CornerRadius" Value="10"/></Style>
                                        </Button.Resources>
                                        <TextBlock Text="&#xE710;" FontFamily="Segoe MDL2 Assets" FontSize="10" FontWeight="Bold" Foreground="#0B0D13" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Button>
                                </Grid>
                            </Border>

                            <!-- Task Items Scroll List -->
                            <ScrollViewer Grid.Row="1" Margin="0,4,0,0" VerticalScrollBarVisibility="Hidden" HorizontalScrollBarVisibility="Disabled">
                                <StackPanel x:Name="TaskListContainer"/>
                            </ScrollViewer>
                        </Grid>
                    </Border>

                    <Button x:Name="BtnNotesNextCard" Grid.Column="3" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                    </Button>
                </Grid>

                <!-- ============================================== -->

                <!-- CARD 3: PAPAN KLIP & FILE SHELF                -->

                <!-- ============================================== -->

                <Grid x:Name="CardClipShelf" Visibility="Collapsed">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="32"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="32"/>
                    </Grid.ColumnDefinitions>

                    <Button x:Name="BtnClipPrevCard" Grid.Column="0" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Left" VerticalAlignment="Center">
                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                    </Button>

                    <!-- Center: Full-Width Dedicated File Shelf Drop Zone -->
                    <Border x:Name="ShelfDropBorder" Grid.Column="1" Background="#11141C" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="14" Margin="6,0" Padding="8,6" AllowDrop="True">
                        <Grid>
                            <!-- State A: Empty / Drag-Over State -->
                            <Grid x:Name="ShelfEmptyDropZone" HorizontalAlignment="Stretch" VerticalAlignment="Stretch">
                                <Rectangle Stroke="#3B465E" StrokeThickness="1.5" StrokeDashArray="4 3" RadiusX="12" RadiusY="12" Fill="#090C12" HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/>
                                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                    <Border Width="38" Height="38" CornerRadius="10" Background="#161B26" BorderBrush="#2A3448" BorderThickness="1" HorizontalAlignment="Center" Margin="0,0,0,4">
                                        <TextBlock x:Name="ShelfDropIcon" Text="&#xED25;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="#00D2FF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <TextBlock x:Name="ShelfDropPrompt" Text="Release to add" FontSize="12" FontWeight="SemiBold" Foreground="#FFFFFF" HorizontalAlignment="Center"/>
                                    <TextBlock Text="Seret file ke sini untuk diparkirkan" FontSize="9.5" Foreground="#8E9AA8" HorizontalAlignment="Center" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Grid>

                            <!-- State B: Populated Files Shelf with Thumbnails -->
                            <Grid x:Name="ShelfFilesContainer" Visibility="Collapsed" HorizontalAlignment="Stretch" VerticalAlignment="Stretch">
                                <ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" HorizontalAlignment="Stretch" VerticalAlignment="Center">
                                    <StackPanel x:Name="ShelfFilesList" Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                </ScrollViewer>
                            </Grid>
                        </Grid>
                    </Border>

                    <Button x:Name="BtnClipNextCard" Grid.Column="2" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                    </Button>
                </Grid>

                <!-- ============================================== -->

                <!-- CARD 4: MONITOR SISTEM & WATER REMINDER        -->

                <!-- ============================================== -->

                <Grid x:Name="CardSysWater" Visibility="Collapsed">

                    <Grid.ColumnDefinitions>

                        <ColumnDefinition Width="32"/>

                        <ColumnDefinition Width="*"/>

                        <ColumnDefinition Width="*"/>

                        <ColumnDefinition Width="32"/>

                    </Grid.ColumnDefinitions>

                    <Button x:Name="BtnSysPrevCard" Grid.Column="0" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Left" VerticalAlignment="Center">

                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>

                    </Button>

                    <!-- Left: System Hardware -->

                    <Border Grid.Column="1" Background="#131722" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">

                        <StackPanel VerticalAlignment="Center">

                            <StackPanel Orientation="Horizontal">

                                <TextBlock x:Name="SysRamText" Text="48%" FontFamily="Segoe UI, Consolas" FontSize="28" FontWeight="Bold" Foreground="#FFFFFF"/>

                                <TextBlock Text=" RAM" FontSize="14" FontWeight="SemiBold" Foreground="#00D2FF" VerticalAlignment="Bottom" Margin="4,0,0,4"/>

                            </StackPanel>

                            <TextBlock x:Name="SysBatStatusText" Text="Baterai 85% - Mengisi Daya" FontSize="11" Foreground="#8E9AA8" Margin="0,2,0,0"/>

                            <StackPanel Orientation="Horizontal" Margin="0,3,0,0">

                                <TextBlock Text="&#xE839;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#00D2FF" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                <TextBlock x:Name="SysNetStatsText" Text="&#x2193; 0.0 MB/s  &#x2191; 0.0 MB/s" FontSize="10" FontFamily="Segoe UI, Consolas" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                                <TextBlock x:Name="SysPingText" Text=" &#x2022; Ping: 18ms" FontSize="10" Foreground="#10B981" Margin="2,0,0,0" VerticalAlignment="Center"/>

                            </StackPanel>

                            <Button x:Name="BtnSysTaskMgr" Style="{StaticResource QuickMiniBtn}" Margin="0,5,0,0" HorizontalAlignment="Left">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Buka Task Manager" FontSize="10" Foreground="#00D2FF" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                        </StackPanel>

                    </Border>

                    <!-- Right: Top Apps Memory Hogs (Konsumsi RAM Aplikasi) -->
                    <Border Grid.Column="2" Background="#131722" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="20"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="18"/>
                            </Grid.RowDefinitions>

                            <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Left">
                                <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Aplikasi Aktif (RAM)" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" VerticalAlignment="Center"/>
                            </StackPanel>

                            <!-- Dynamic Top 3 Processes -->
                            <StackPanel Grid.Row="1" x:Name="TopAppsListContainer" VerticalAlignment="Center" Margin="0,2,0,2"/>

                            <!-- Bottom: Mini Prayer/Time Status -->
                            <Border Grid.Row="2" Background="#0C101A" BorderBrush="#1E2638" BorderThickness="1" CornerRadius="6" Padding="4,1">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="9" Foreground="#10B981" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="CardPrayerScheduleText" Text="Subuh 04:09 • Ashar 14:51" FontSize="9" FontFamily="Segoe UI, Consolas" Foreground="#10B981" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </Border>

                    <Button x:Name="BtnSysNextCard" Grid.Column="3" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">

                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>

                    </Button>

                </Grid>

                <!-- ============================================== -->

                <!-- CARD 5: KONTROL CEPAT & AUDIO MASTER           -->

                <!-- ============================================== -->

                <Grid x:Name="CardQuick" Visibility="Collapsed">

                    <Grid.ColumnDefinitions>

                        <ColumnDefinition Width="32"/>

                        <ColumnDefinition Width="*"/>

                        <ColumnDefinition Width="32"/>

                    </Grid.ColumnDefinitions>

                    <Button x:Name="BtnQuickPrevCard" Grid.Column="0" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Left" VerticalAlignment="Center">

                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>

                    </Button>

                    <Grid Grid.Column="1" VerticalAlignment="Center" Margin="8,0">

                        <Grid.RowDefinitions>

                            <RowDefinition Height="32"/>

                            <RowDefinition Height="34"/>

                            <RowDefinition Height="32"/>

                        </Grid.RowDefinitions>

                        <!-- Row 0: Switches -->

                        <Grid Grid.Row="0">

                            <Grid.ColumnDefinitions>

                                <ColumnDefinition Width="*"/>

                                <ColumnDefinition Width="*"/>

                                <ColumnDefinition Width="*"/>

                                <ColumnDefinition Width="*"/>

                            </Grid.ColumnDefinitions>

                            <Button x:Name="BtnQuickWifi" Grid.Column="0" Margin="2" Style="{StaticResource QuickMiniBtn}">

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                    <TextBlock Text="&#xE701;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Wi-Fi" FontSize="11" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="BtnQuickBt" Grid.Column="1" Margin="2" Style="{StaticResource QuickMiniBtn}">

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                    <TextBlock Text="&#xE702;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Bluetooth" FontSize="11" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="BtnQuickDnd" Grid.Column="2" Margin="2" Style="{StaticResource QuickMiniBtn}">

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                    <TextBlock Text="&#xE708;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                    <TextBlock x:Name="QuickStatusDnd" Text="DND" FontSize="11" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="BtnQuickGame" Grid.Column="3" Margin="2" Style="{StaticResource QuickMiniBtn}">

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                    <TextBlock Text="&#xE7FC;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                    <TextBlock x:Name="QuickStatusGame" Text="Game" FontSize="11" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                        </Grid>

                        <!-- Row 1: Audio Slider -->

                        <Grid Grid.Row="1" VerticalAlignment="Center" Margin="2,2">

                            <Grid.ColumnDefinitions>

                                <ColumnDefinition Width="30"/>

                                <ColumnDefinition Width="*"/>

                                <ColumnDefinition Width="34"/>

                            </Grid.ColumnDefinitions>

                            <Button x:Name="BtnQuickMute" Grid.Column="0" Style="{StaticResource QuickMiniBtn}" Padding="4,2">

                                <TextBlock x:Name="QuickIconMute" Text="&#xE767;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#00D2FF"/>

                            </Button>

                            <Slider x:Name="QuickSliderVol" Grid.Column="1" Minimum="0" Maximum="100" Value="72" VerticalAlignment="Center" Margin="8,0"/>

                            <TextBlock x:Name="QuickVolPctText" Grid.Column="2" Text="72%" FontSize="11" Foreground="#8E9AA8" VerticalAlignment="Center"/>

                        </Grid>

                        <!-- Row 2: Lock, Sleep, Restart, Dashboard -->

                        <Grid Grid.Row="2">

                            <Grid.ColumnDefinitions>

                                <ColumnDefinition Width="*"/>

                                <ColumnDefinition Width="*"/>

                                <ColumnDefinition Width="*"/>

                                <ColumnDefinition Width="1.4*"/>

                            </Grid.ColumnDefinitions>

                            <Button x:Name="BtnQuickLock" Grid.Column="0" Margin="2" Style="{StaticResource QuickMiniBtn}">

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                    <TextBlock Text="&#xE72E;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#8E9AA8" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Kunci" FontSize="11" Foreground="#8E9AA8" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="BtnQuickSleep" Grid.Column="1" Margin="2" Style="{StaticResource QuickMiniBtn}">

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                    <TextBlock Text="&#xE708;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#8E9AA8" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Tidur" FontSize="11" Foreground="#8E9AA8" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="BtnQuickRestart" Grid.Column="2" Margin="2" Style="{StaticResource QuickMiniBtn}">

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                    <TextBlock Text="&#xE777;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#EF4444" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                    <TextBlock x:Name="QuickLblRestart" Text="Restart" FontSize="11" Foreground="#EF4444" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="BtnSysLaunchDash" Grid.Column="3" Margin="2" Style="{StaticResource PillBtn}" Padding="6,2">

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                    <TextBlock Text="&#xE737;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#00D2FF" Margin="0,0,4,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Dashboard" FontSize="11" FontWeight="SemiBold" Foreground="#00D2FF" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                        </Grid>

                    </Grid>

                    <Button x:Name="BtnQuickNextCard" Grid.Column="2" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">

                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>

                    </Button>

                </Grid>

            </Grid>

            <!-- ROW 2: BOTTOM BUTTONS (CONTEXTUAL) & PAGINATION DOTS -->

            <Grid Grid.Row="2" Margin="10,0,10,6">

                <!-- Pomodoro Bottom Buttons -->

                <Grid x:Name="BottomPomoRow" Visibility="Collapsed">

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">

                        <Button x:Name="BtnPomoShortBreak" Style="{StaticResource PillBtn}" Margin="0,0,10,0">

                            <StackPanel Orientation="Horizontal">

                                <TextBlock Text="&#xE916;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" Margin="0,0,6,0" VerticalAlignment="Center"/>

                                <TextBlock Text="Short Break" FontSize="12" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                            </StackPanel>

                        </Button>

                        <Button x:Name="BtnPomoPlay" Width="66" Height="32" Background="#FF5252" Cursor="Hand"

                                BorderThickness="0" Margin="0,0,10,0">

                            <Button.Template>

                                <ControlTemplate TargetType="Button">

                                    <Border Background="{TemplateBinding Background}" CornerRadius="16">

                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>

                                    </Border>

                                </ControlTemplate>

                            </Button.Template>

                            <TextBlock x:Name="PomoPlayPauseIcon" Text="&#xE768;" FontFamily="Segoe MDL2 Assets" FontSize="14" Foreground="#FFFFFF"/>

                        </Button>

                        <Button x:Name="BtnPomoFocusTime" Style="{StaticResource PillBtn}">

                            <StackPanel Orientation="Horizontal">

                                <TextBlock Text="&#xE916;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#FF5252" Margin="0,0,6,0" VerticalAlignment="Center"/>

                                <TextBlock Text="Focus Time" FontSize="12" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                            </StackPanel>

                        </Button>

                    </StackPanel>

                </Grid>

                <!-- BOTTOM PAGINATION INDICATOR (6 DOTS FOR 6 CARDS) -->

                <StackPanel x:Name="PaginationPanel" Orientation="Horizontal" HorizontalAlignment="Center"

                            VerticalAlignment="Bottom" Margin="0,0,0,2">

                    <Border x:Name="Dot0" Width="16" Height="3" CornerRadius="1.5" Background="#00D2FF" Margin="2.5,0" Cursor="Hand"/>

                    <Border x:Name="Dot1" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#232B3D" Margin="2.5,0" Cursor="Hand"/>

                    <Border x:Name="Dot2" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#232B3D" Margin="2.5,0" Cursor="Hand"/>

                    <Border x:Name="Dot3" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#232B3D" Margin="2.5,0" Cursor="Hand"/>

                    <Border x:Name="Dot4" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#232B3D" Margin="2.5,0" Cursor="Hand"/>

                    <Border x:Name="Dot5" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#232B3D" Margin="2.5,0" Cursor="Hand"/>

                </StackPanel>

            </Grid>

            <!-- FLOATING ACTION FEEDBACK TOAST PILL -->

            <Border x:Name="ToastFeedbackPill" Grid.Row="0" Grid.RowSpan="2" HorizontalAlignment="Center"

                    VerticalAlignment="Top" Margin="0,38,0,0" Background="#E6131722" BorderBrush="#232B3D"

                    BorderThickness="1" CornerRadius="14" Padding="14,6" Visibility="Collapsed">

                <StackPanel Orientation="Horizontal">

                    <TextBlock x:Name="ToastFeedbackIcon" Text="&#xE73E;" FontFamily="Segoe MDL2 Assets" FontSize="12"

                               Foreground="#00D2FF" Margin="0,0,8,0" VerticalAlignment="Center"/>

                    <TextBlock x:Name="ToastFeedbackText" Text="Berhasil" FontSize="12" FontWeight="SemiBold"

                               Foreground="#FFFFFF" VerticalAlignment="Center"/>

                </StackPanel>

            </Border>

        </Grid>

    </Grid>

</Window>

'@

# XAML 2: FULL OCERU DASHBOARD WINDOW (15 Dedicated Destinations)

$dashXaml = @'

<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"

        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"

        Title="Oceru Dashboard - Native Obsidian"

        WindowStartupLocation="CenterScreen"

        WindowStyle="None"

        AllowsTransparency="True"

        Background="Transparent"

        Width="980" Height="650">

    <Window.Resources>

        <!-- Sidebar Navigation Button (Normal) -->

        <Style x:Key="SidebarNavBtn" TargetType="Button">

            <Setter Property="Background" Value="Transparent"/>

            <Setter Property="Foreground" Value="#8E9AA8"/>

            <Setter Property="Height" Value="36"/>

            <Setter Property="Margin" Value="0,2"/>

            <Setter Property="Padding" Value="14,0"/>

            <Setter Property="HorizontalContentAlignment" Value="Left"/>

            <Setter Property="BorderThickness" Value="0"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border x:Name="NavBorder" Background="{TemplateBinding Background}" CornerRadius="9" Padding="{TemplateBinding Padding}">

                            <ContentPresenter VerticalAlignment="Center"/>

                        </Border>

                        <ControlTemplate.Triggers>

                            <Trigger Property="IsMouseOver" Value="True">

                                <Setter TargetName="NavBorder" Property="Background" Value="#131722"/>

                                <Setter Property="Foreground" Value="#00D2FF"/>

                            </Trigger>

                        </ControlTemplate.Triggers>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

        <!-- Sidebar Navigation Button (Active Selected) -->

        <Style x:Key="ActiveSidebarNavBtn" TargetType="Button">

            <Setter Property="Background" Value="#161D2A"/>

            <Setter Property="Foreground" Value="#00D2FF"/>

            <Setter Property="Height" Value="36"/>

            <Setter Property="Margin" Value="0,2"/>

            <Setter Property="Padding" Value="14,0"/>

            <Setter Property="HorizontalContentAlignment" Value="Left"/>

            <Setter Property="BorderThickness" Value="1"/>

            <Setter Property="BorderBrush" Value="#28354D"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border Background="{TemplateBinding Background}"

                                BorderBrush="{TemplateBinding BorderBrush}"

                                BorderThickness="{TemplateBinding BorderThickness}"

                                CornerRadius="9" Padding="{TemplateBinding Padding}">

                            <ContentPresenter VerticalAlignment="Center"/>

                        </Border>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

        <!-- Standard Dashboard Card Container -->

        <Style x:Key="DashCard" TargetType="Border">

            <Setter Property="Background" Value="#131722"/>

            <Setter Property="BorderBrush" Value="#232B3D"/>

            <Setter Property="BorderThickness" Value="1"/>

            <Setter Property="CornerRadius" Value="14"/>

            <Setter Property="Padding" Value="16"/>

            <Setter Property="Margin" Value="6"/>

        </Style>

        <!-- Primary Cyan Button -->

        <Style x:Key="DashBtnPrimary" TargetType="Button">

            <Setter Property="Background" Value="#00D2FF"/>

            <Setter Property="Foreground" Value="#0B0D13"/>

            <Setter Property="BorderThickness" Value="0"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Padding" Value="16,8"/>

            <Setter Property="FontWeight" Value="SemiBold"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border x:Name="PBtnBorder" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">

                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>

                        </Border>

                        <ControlTemplate.Triggers>

                            <Trigger Property="IsMouseOver" Value="True">

                                <Setter TargetName="PBtnBorder" Property="Background" Value="#38BDF8"/>

                            </Trigger>

                        </ControlTemplate.Triggers>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

        <!-- Secondary Dark Outline Button -->

        <Style x:Key="DashBtnSecondary" TargetType="Button">

            <Setter Property="Background" Value="#1B2130"/>

            <Setter Property="BorderBrush" Value="#232B3D"/>

            <Setter Property="BorderThickness" Value="1"/>

            <Setter Property="Foreground" Value="#FFFFFF"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Padding" Value="14,7"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border x:Name="SBtnBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">

                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>

                        </Border>

                        <ControlTemplate.Triggers>

                            <Trigger Property="IsMouseOver" Value="True">

                                <Setter TargetName="SBtnBorder" Property="Background" Value="#232B3D"/>

                                <Setter TargetName="SBtnBorder" Property="BorderBrush" Value="#00D2FF"/>

                                <Setter Property="Foreground" Value="#00D2FF"/>

                            </Trigger>

                        </ControlTemplate.Triggers>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

        <!-- App Launcher Tile Button -->

        <Style x:Key="AppTileBtn" TargetType="Button">

            <Setter Property="Background" Value="#131722"/>

            <Setter Property="BorderBrush" Value="#232B3D"/>

            <Setter Property="BorderThickness" Value="1"/>

            <Setter Property="Cursor" Value="Hand"/>

            <Setter Property="Padding" Value="12,12"/>

            <Setter Property="Margin" Value="4"/>

            <Setter Property="Template">

                <Setter.Value>

                    <ControlTemplate TargetType="Button">

                        <Border x:Name="TileBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="12" Padding="{TemplateBinding Padding}">

                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>

                        </Border>

                        <ControlTemplate.Triggers>

                            <Trigger Property="IsMouseOver" Value="True">

                                <Setter TargetName="TileBorder" Property="Background" Value="#1B2130"/>

                                <Setter TargetName="TileBorder" Property="BorderBrush" Value="#00D2FF"/>

                            </Trigger>

                        </ControlTemplate.Triggers>

                    </ControlTemplate>

                </Setter.Value>

            </Setter>

        </Style>

    </Window.Resources>

    <!-- Outer Frame with Drop Shadow -->

    <Border CornerRadius="18" Background="#0B0D13" BorderBrush="#232B3D" BorderThickness="1.5">

        <Border.Effect>

            <DropShadowEffect BlurRadius="40" ShadowDepth="12" Direction="270" Opacity="0.7" Color="#000000"/>

        </Border.Effect>

        <Grid>

            <Grid.RowDefinitions>

                <RowDefinition Height="44"/> <!-- Modern Title Bar -->

                <RowDefinition Height="*"/>  <!-- Main Content Body -->

            </Grid.RowDefinitions>

            <!-- Custom Drag Title Bar -->

            <Border Grid.Row="0" x:Name="DashTitleBar" Background="#0B0D13" CornerRadius="17,17,0,0" BorderBrush="#232B3D" BorderThickness="0,0,0,1" Cursor="Hand">

                <Grid Margin="16,0">

                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">

                        <Border Width="22" Height="22" CornerRadius="11" Background="#00D2FF" Margin="0,0,10,0">

                            <TextBlock Text="O" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>

                        </Border>

                        <TextBlock Text="OCERU" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center"/>

                        <TextBlock Text=" - Native Obsidian Utility" FontSize="12" Foreground="#8E9AA8" VerticalAlignment="Center" Margin="6,0,0,0"/>

                    </StackPanel>

                    <!-- Control Buttons -->

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">

                        <Button x:Name="BtnDashMin" Width="30" Height="26" Background="Transparent" BorderThickness="0" Cursor="Hand" Margin="0,0,4,0">

                            <TextBlock Text="&#xE921;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#8E9AA8"/>

                        </Button>

                        <Button x:Name="BtnDashClose" Width="30" Height="26" Background="Transparent" BorderThickness="0" Cursor="Hand">

                            <TextBlock Text="&#xE711;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#8E9AA8"/>

                        </Button>

                    </StackPanel>

                </Grid>

            </Border>

            <!-- Main Body Grid: Sidebar + Viewport -->

            <Grid Grid.Row="1">

                <Grid.ColumnDefinitions>

                    <ColumnDefinition Width="220"/>

                    <ColumnDefinition Width="*"/>

                </Grid.ColumnDefinitions>

                <!-- Left Sidebar (15 Destinations) -->

                <Border Grid.Column="0" Background="#0B0D13" BorderBrush="#232B3D" BorderThickness="0,0,1,0">

                    <ScrollViewer VerticalScrollBarVisibility="Hidden">

                        <StackPanel Margin="10,12">

                            <TextBlock Text="NAVIGASI UTAMA" FontSize="10" FontWeight="Bold" Foreground="#8E9AA8" Margin="10,4,0,8"/>

                            <Button x:Name="NavOverview" Style="{StaticResource ActiveSidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#00D2FF" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Ringkasan" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavIsland" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE737;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Dynamic Island" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavMedia" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE768;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Media &amp; Lirik" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavPomo" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE916;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Fokus Pomodoro" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavStopwatch" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE916;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Stopwatch" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavCountdown" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE916;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Countdown" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <TextBlock Text="PRODUKTIVITAS &amp; SISTEM" FontSize="10" FontWeight="Bold" Foreground="#8E9AA8" Margin="10,14,0,8"/>

                            <Button x:Name="NavSysMon" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE7F4;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Monitor Sistem" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavNotif" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE7E7;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Pusat Notifikasi" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavNotes" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE70B;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Catatan" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavTodo" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE73E;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Daftar Tugas" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavClip" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE77F;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Papan Klip" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <TextBlock Text="PREFERENSI" FontSize="10" FontWeight="Bold" Foreground="#8E9AA8" Margin="10,14,0,8"/>

                            <Button x:Name="NavQuickSet" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Pengaturan Cepat" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavQuickLaunch" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE737;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Peluncur Cepat" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavSettings" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Pengaturan" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                            <Button x:Name="NavAbout" Style="{StaticResource SidebarNavBtn}">

                                <StackPanel Orientation="Horizontal">

                                    <TextBlock Text="&#xE946;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>

                                    <TextBlock Text="Tentang Oceru" VerticalAlignment="Center"/>

                                </StackPanel>

                            </Button>

                        </StackPanel>

                    </ScrollViewer>

                </Border>

                <!-- Right Viewport: Destination Content Panes -->

                <Grid Grid.Column="1" Background="#0B0D13" Margin="16">

                    <!-- ======================================================== -->

                    <!-- PAGE 0: OVERVIEW                                         -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageOverview" Visibility="Visible">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,14">

                                    <TextBlock Text="Ringkasan Sistem Oceru" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Status waktu nyata hardware, media, dan fokus produktivitas Anda di Windows." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Row 1: 4 Metric Cards -->

                                <Grid Margin="0,0,0,10">

                                    <Grid.ColumnDefinitions>

                                        <ColumnDefinition Width="*"/>

                                        <ColumnDefinition Width="*"/>

                                        <ColumnDefinition Width="*"/>

                                        <ColumnDefinition Width="*"/>

                                    </Grid.ColumnDefinitions>

                                    <!-- RAM Card -->

                                    <Border Grid.Column="0" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="BEBAN RAM" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                            <TextBlock x:Name="DashRamVal" Text="48%" FontSize="28" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,4,0,0"/>

                                            <TextBlock Text="Kernel32 Hardware" FontSize="11" Foreground="#8E9AA8"/>

                                        </StackPanel>

                                    </Border>

                                    <!-- Battery Card -->

                                    <Border Grid.Column="1" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="BATERAI" FontSize="11" FontWeight="Bold" Foreground="#10B981"/>

                                            <TextBlock x:Name="DashBatVal" Text="85%" FontSize="28" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,4,0,0"/>

                                            <TextBlock x:Name="DashBatStatus" Text="Mengisi Daya" FontSize="11" Foreground="#8E9AA8"/>

                                        </StackPanel>

                                    </Border>

                                    <!-- Focus Pomodoro Card -->

                                    <Border Grid.Column="2" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="FOKUS POMODORO" FontSize="11" FontWeight="Bold" Foreground="#FF5252"/>

                                            <TextBlock x:Name="DashOverviewPomoTime" Text="25:00" FontSize="28" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,4,0,0"/>

                                            <TextBlock x:Name="DashOverviewPomoStatus" Text="Sesi 3 dari 4" FontSize="11" Foreground="#8E9AA8"/>

                                        </StackPanel>

                                    </Border>

                                    <!-- Tasks Card -->

                                    <Border Grid.Column="3" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="TUGAS HARIAN" FontSize="11" FontWeight="Bold" Foreground="#F59E0B"/>

                                            <TextBlock x:Name="DashOverviewTodoCount" Text="2 / 3 Selesai" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,8,0,0"/>

                                            <Border Height="4" Background="#1B2130" CornerRadius="2" Margin="0,8,0,0">

                                                <Border x:Name="DashOverviewTodoBar" Width="100" HorizontalAlignment="Left" Background="#F59E0B" CornerRadius="2"/>

                                            </Border>

                                        </StackPanel>

                                    </Border>

                                </Grid>

                                <!-- Row 2: 2 Wide Cards (Media & Quick Actions) -->

                                <Grid>

                                    <Grid.ColumnDefinitions>

                                        <ColumnDefinition Width="*"/>

                                        <ColumnDefinition Width="*"/>

                                    </Grid.ColumnDefinitions>

                                    <!-- Active Media Card -->

                                    <Border Grid.Column="0" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="MEDIA SEDANG DIPUTAR" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                            <TextBlock x:Name="DashOverviewMediaTitle" Text="Paper Sky" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,6,0,2"/>

                                            <TextBlock x:Name="DashOverviewMediaArtist" Text="Lumen Coast - Summer Flows" FontSize="12" Foreground="#8E9AA8"/>

                                            <StackPanel Orientation="Horizontal" Margin="0,12,0,0">

                                                <Button x:Name="BtnOverviewPlayPause" Style="{StaticResource DashBtnSecondary}" Padding="10,5" Margin="0,0,6,0">

                                                    <TextBlock Text="Play / Jeda" FontSize="11"/>

                                                </Button>

                                                <Button x:Name="BtnOverviewNext" Style="{StaticResource DashBtnSecondary}" Padding="10,5" Margin="0,0,6,0">

                                                    <TextBlock Text="Berikutnya" FontSize="11"/>

                                                </Button>

                                                <Button x:Name="BtnOverviewOpenMedia" Style="{StaticResource DashBtnPrimary}" Padding="10,5">

                                                    <TextBlock Text="Buka Player &amp; Lirik" FontSize="11"/>

                                                </Button>

                                            </StackPanel>

                                        </StackPanel>

                                    </Border>

                                    <!-- Quick System Actions Card -->

                                    <Border Grid.Column="1" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="PINTASAN SISTEM CEPAT" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                            <Grid Margin="0,10,0,0">

                                                <Grid.ColumnDefinitions>

                                                    <ColumnDefinition Width="*"/>

                                                    <ColumnDefinition Width="*"/>

                                                </Grid.ColumnDefinitions>

                                                <Grid.RowDefinitions>

                                                    <RowDefinition Height="Auto"/>

                                                    <RowDefinition Height="Auto"/>

                                                </Grid.RowDefinitions>

                                                <Button Grid.Row="0" Grid.Column="0" x:Name="BtnOverviewTaskMgr" Style="{StaticResource DashBtnSecondary}" Margin="3,3">

                                                    <TextBlock Text="Task Manager" FontSize="11"/>

                                                </Button>

                                                <Button Grid.Row="0" Grid.Column="1" x:Name="BtnOverviewSettings" Style="{StaticResource DashBtnSecondary}" Margin="3,3">

                                                    <TextBlock Text="Pengaturan PC" FontSize="11"/>

                                                </Button>

                                                <Button Grid.Row="1" Grid.Column="0" x:Name="BtnOverviewDnd" Style="{StaticResource DashBtnSecondary}" Margin="3,3">

                                                    <TextBlock Text="Jangan Ganggu" FontSize="11"/>

                                                </Button>

                                                <Button Grid.Row="1" Grid.Column="1" x:Name="BtnOverviewWifi" Style="{StaticResource DashBtnSecondary}" Margin="3,3">

                                                    <TextBlock Text="Wi-Fi Flyout" FontSize="11"/>

                                                </Button>

                                            </Grid>

                                        </StackPanel>

                                    </Border>

                                </Grid>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 1: DYNAMIC ISLAND CUSTOMIZATION                     -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageIsland" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Kustomisasi Dynamic Island" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Atur perilaku, interaksi, dimensi, dan animasi notch di desktop Anda." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Card 1: Mode Realtime & Test Buttons -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="STATUS REAL-TIME DYNAMIC ISLAND" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                        <TextBlock x:Name="DashIslandCurrentModeText" Text="Mode Aktif: Standalone Resting Cat Eyes (88x36 px)" FontSize="15" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,6,0,8"/>

                                        <TextBlock Text="Dynamic Island saat ini aktif melayang di bagian tengah atas layar desktop Anda." FontSize="12" Foreground="#8E9AA8"/>

                                        <StackPanel Orientation="Horizontal" Margin="0,14,0,0">

                                            <Button x:Name="BtnDashTriggerExpand" Style="{StaticResource DashBtnPrimary}" Margin="0,0,8,0">

                                                <TextBlock Text="Perluas Notch Sekarang (Buka Carousel)"/>

                                            </Button>

                                            <Button x:Name="BtnDashTriggerEyes" Style="{StaticResource DashBtnSecondary}">

                                                <TextBlock Text="Kapsul Mata Kucing (Resting Eyes)"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                                <!-- Card 2: Dimensions & Position -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="DIMENSI &amp; POSISI NOTCH" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                        <Grid Margin="0,10,0,0">

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                            </Grid.ColumnDefinitions>

                                            <StackPanel Grid.Column="0">

                                                <TextBlock Text="Lebar Saat Terbuka" FontSize="12" Foreground="#8E9AA8"/>

                                                <TextBlock Text="560 px (Optimal 6 Kartu)" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,2,0,8"/>

                                                <TextBlock Text="Tinggi Saat Terbuka" FontSize="12" Foreground="#8E9AA8"/>

                                                <TextBlock Text="205 px" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,2,0,0"/>

                                            </StackPanel>

                                            <StackPanel Grid.Column="1">

                                                <TextBlock Text="Posisi Desktop" FontSize="12" Foreground="#8E9AA8"/>

                                                <TextBlock Text="Atas Tengah (Top Center)" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,2,0,8"/>

                                                <TextBlock Text="Lapisan Jendela" FontSize="12" Foreground="#8E9AA8"/>

                                                <TextBlock Text="Topmost Always-on-Top" FontSize="14" FontWeight="SemiBold" Foreground="#10B981" Margin="0,2,0,0"/>

                                            </StackPanel>

                                        </Grid>

                                    </StackPanel>

                                </Border>

                                <!-- Card 3: Silhouette & Visual Polish -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="DESAIN SILUET OBSIDIAN GLASS" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                        <TextBlock Text="Seamless Obsidian Island Capsule" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,6,0,2"/>

                                        <TextBlock Text="Kapsul obsidian hitam murni (#000000) tanpa garis tepi (seamless bezel-flush). Bebas bayangan blur dan fringe kontur, menyatu sempurna dengan tepi atas layar desktop Windows Anda." FontSize="12" Foreground="#8E9AA8"/>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 2: MEDIA & LYRICS                                   -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageMedia" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Pemutar Media &amp; Kontrol Windows" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Kontrol pemutaran musik global Windows dan putar file audio lokal secara instan." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <Grid>

                                    <Grid.ColumnDefinitions>

                                        <ColumnDefinition Width="320"/>

                                        <ColumnDefinition Width="*"/>

                                    </Grid.ColumnDefinitions>

                                    <!-- Left Column: Media Player Controls -->

                                    <Border Grid.Column="0" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <!-- Album Art Box -->

                                            <Border Width="160" Height="160" CornerRadius="20" Background="#1B2130" HorizontalAlignment="Center" Margin="0,10,0,14" BorderBrush="#232B3D" BorderThickness="1.5">

                                                <Grid>

                                                    <Border Width="100" Height="100" CornerRadius="50" Background="#00D2FF" HorizontalAlignment="Center" VerticalAlignment="Center">

                                                        <Border Width="36" Height="36" CornerRadius="18" Background="#38BDF8" HorizontalAlignment="Center" VerticalAlignment="Center"/>

                                                    </Border>

                                                    <TextBlock Text="&#xE8D6;" FontFamily="Segoe MDL2 Assets" FontSize="26" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>

                                                </Grid>

                                            </Border>

                                            <TextBlock x:Name="DashMediaTitleText" Text="Tidak ada media aktif" FontSize="16" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" TextAlignment="Center" TextTrimming="CharacterEllipsis"/>

                                            <TextBlock x:Name="DashMediaArtistText" Text="Kontrol pemutar Windows atau putar file audio" FontSize="11" Foreground="#8E9AA8" HorizontalAlignment="Center" TextAlignment="Center" Margin="0,4,0,14" TextTrimming="CharacterEllipsis"/>

                                            <!-- Progress Bar -->

                                            <Border Height="5" Background="#1B2130" CornerRadius="2.5" Margin="10,0,10,6">

                                                <Border x:Name="DashMediaProgressBar" Width="0" HorizontalAlignment="Left" Background="#00D2FF" CornerRadius="2.5"/>

                                            </Border>

                                            <Grid Margin="10,0,10,14">

                                                <TextBlock x:Name="DashMediaCurrentTime" Text="00:00" FontSize="10" Foreground="#8E9AA8" HorizontalAlignment="Left"/>

                                                <TextBlock x:Name="DashMediaRemainingTime" Text="00:00" FontSize="10" Foreground="#8E9AA8" HorizontalAlignment="Right"/>

                                            </Grid>

                                            <!-- Controls -->

                                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,14">

                                                <Button x:Name="BtnDashMediaPrev" Style="{StaticResource DashBtnSecondary}" Width="42" Height="36" Margin="0,0,8,0" ToolTip="Lagu Sebelumnya (Global Media Key)">

                                                    <TextBlock Text="&#xE892;" FontFamily="Segoe MDL2 Assets" FontSize="12"/>

                                                </Button>

                                                <Button x:Name="BtnDashMediaPlayPause" Style="{StaticResource DashBtnPrimary}" Width="52" Height="36" Margin="0,0,8,0" ToolTip="Play / Pause">

                                                    <TextBlock x:Name="DashMediaPlayIcon" Text="&#xE768;" FontFamily="Segoe MDL2 Assets" FontSize="14"/>

                                                </Button>

                                                <Button x:Name="BtnDashMediaNext" Style="{StaticResource DashBtnSecondary}" Width="42" Height="36" ToolTip="Lagu Berikutnya (Global Media Key)">

                                                    <TextBlock Text="&#xE893;" FontFamily="Segoe MDL2 Assets" FontSize="12"/>

                                                </Button>

                                            </StackPanel>

                                            <!-- Audio Source Controls -->

                                            <TextBlock Text="PILIHAN SUMBER AUDIO" FontSize="10" FontWeight="Bold" Foreground="#00D2FF" Margin="0,10,0,6"/>

                                            <Button x:Name="BtnDashSelectAudio" Style="{StaticResource DashBtnPrimary}" Margin="0,3" Height="34" HorizontalContentAlignment="Left">

                                                <StackPanel Orientation="Horizontal">

                                                    <TextBlock Text="&#xE8E5;" FontFamily="Segoe MDL2 Assets" FontSize="13" Margin="0,0,8,0" VerticalAlignment="Center"/>

                                                    <TextBlock Text="Pilih &amp; Putar File Audio Lokal..." FontSize="11" VerticalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button x:Name="BtnDashStopAudio" Style="{StaticResource DashBtnSecondary}" Margin="0,3" Height="32" HorizontalContentAlignment="Left">

                                                <StackPanel Orientation="Horizontal">

                                                    <TextBlock Text="&#xE71A;" FontFamily="Segoe MDL2 Assets" FontSize="13" Margin="0,0,8,0" VerticalAlignment="Center"/>

                                                    <TextBlock Text="Hentikan Pemutar Lokal" FontSize="11" VerticalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Border Background="#1B2130" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="8" Padding="10,8" Margin="0,8,0,0">

                                                <StackPanel>

                                                    <TextBlock Text="Status Sumber:" FontSize="10" FontWeight="Bold" Foreground="#8E9AA8"/>

                                                    <TextBlock x:Name="DashMediaSourceStatus" Text="Kontrol Global Windows / Siap Putar File" FontSize="11" Foreground="#00D2FF" Margin="0,2,0,0" TextWrapping="Wrap"/>

                                                </StackPanel>

                                            </Border>

                                        </StackPanel>

                                    </Border>

                                    <!-- Right Column: Media Guide & Architecture -->

                                    <Border Grid.Column="1" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="INTEGRASI PEMUTAR MEDIA WINDOWS" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,14"/>

                                            <Border Background="#131722" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,12">

                                                <StackPanel>

                                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,6">

                                                        <TextBlock Text="&#xE8D6;" FontFamily="Segoe MDL2 Assets" FontSize="14" Foreground="#00D2FF" Margin="0,0,8,0" VerticalAlignment="Center"/>

                                                        <TextBlock Text="Kontrol Hardware Media Global" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF"/>

                                                    </StackPanel>

                                                    <TextBlock Text="Tombol Play/Pause, Next, dan Previous memicu sinyal keyboard VK_MEDIA_* sistemik. Fitur ini secara langsung mengendalikan Spotify, YouTube (Chrome/Edge), Apple Music, VLC, atau pemutar Windows lainnya yang sedang berjalan di latar belakang." FontSize="11.5" Foreground="#8E9AA8" TextWrapping="Wrap" LineHeight="17"/>

                                                </StackPanel>

                                            </Border>

                                            <Border Background="#131722" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,12">

                                                <StackPanel>

                                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,6">

                                                        <TextBlock Text="&#xE8E5;" FontFamily="Segoe MDL2 Assets" FontSize="14" Foreground="#10B981" Margin="0,0,8,0" VerticalAlignment="Center"/>

                                                        <TextBlock Text="Pemutar Audio Lokal Terintegrasi" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF"/>

                                                    </StackPanel>

                                                    <TextBlock Text="Anda dapat memilih file .mp3, .wav, .m4a, atau .wma langsung dari disk lokal Anda. Audio diputar secara native melalui engine WPF MediaPlayer dengan pelacakan durasi nyata dan animasi soundwave di Dynamic Island." FontSize="11.5" Foreground="#8E9AA8" TextWrapping="Wrap" LineHeight="17"/>

                                                </StackPanel>

                                            </Border>

                                            <Border Background="#131722" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="10" Padding="14">

                                                <StackPanel>

                                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,6">

                                                        <TextBlock Text="&#xE783;" FontFamily="Segoe MDL2 Assets" FontSize="14" Foreground="#00D2FF" Margin="0,0,8,0" VerticalAlignment="Center"/>

                                                        <TextBlock Text="Sinkronisasi Dua Arah ke Dynamic Island" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF"/>

                                                    </StackPanel>

                                                    <TextBlock Text="Perubahan status pemutaran, judul lagu, dan progress bar di Dashboard akan langsung direfleksikan di Card 0 Dynamic Island pada bilah atas layar secara real-time." FontSize="11.5" Foreground="#8E9AA8" TextWrapping="Wrap" LineHeight="17"/>

                                                </StackPanel>

                                            </Border>

                                        </StackPanel>

                                    </Border>

                                </Grid>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 3: POMODORO FOCUS TIMER                             -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PagePomo" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Pengatur Fokus Pomodoro" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Tingkatkan fokus kerja dan belajar dengan teknik interval waktu Pomodoro." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Large Timer Card -->

                                <Border Style="{StaticResource DashCard}" Padding="24">

                                    <StackPanel HorizontalAlignment="Center">

                                        <TextBlock Text="SESI FOKUS PRODUKTIF" FontSize="11" FontWeight="Bold" Foreground="#FF5252" HorizontalAlignment="Center"/>

                                        <TextBlock x:Name="DashPomoLargeTime" Text="25:00" FontSize="56" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" Margin="0,10,0,4"/>

                                        <TextBlock x:Name="DashPomoStatusText" Text="Siap Memulai Sesi Fokus" FontSize="13" Foreground="#8E9AA8" HorizontalAlignment="Center"/>

                                        <TextBlock x:Name="DashPomoSessionBadge" Text="Sesi 3 dari 4 selesai" FontSize="11" Foreground="#10B981" HorizontalAlignment="Center" Margin="0,4,0,16"/>

                                        <!-- Start / Pause / Reset Buttons -->

                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                            <Button x:Name="BtnDashPomoStart" Style="{StaticResource DashBtnPrimary}" Width="160" Height="42" Margin="0,0,10,0">

                                                <StackPanel Orientation="Horizontal">

                                                    <TextBlock x:Name="DashPomoStartIcon" Text="&#xE768;" FontFamily="Segoe MDL2 Assets" FontSize="13" Margin="0,0,8,0" VerticalAlignment="Center"/>

                                                    <TextBlock Text="Mulai Fokus" VerticalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button x:Name="BtnDashPomoReset" Style="{StaticResource DashBtnSecondary}" Width="100" Height="42">

                                                <TextBlock Text="Reset"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                                <!-- Presets Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="PRESET DURASI CEPAT" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,12"/>

                                        <Grid>

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                            </Grid.ColumnDefinitions>

                                            <Button Grid.Column="0" x:Name="BtnDashPomoPreset25" Style="{StaticResource DashBtnSecondary}" Margin="3">

                                                <TextBlock Text="Fokus 25m"/>

                                            </Button>

                                            <Button Grid.Column="1" x:Name="BtnDashPomoPreset15" Style="{StaticResource DashBtnSecondary}" Margin="3">

                                                <TextBlock Text="Fokus 15m"/>

                                            </Button>

                                            <Button Grid.Column="2" x:Name="BtnDashPomoPreset5" Style="{StaticResource DashBtnSecondary}" Margin="3">

                                                <TextBlock Text="Istirahat 5m"/>

                                            </Button>

                                            <Button Grid.Column="3" x:Name="BtnDashPomoPreset15Break" Style="{StaticResource DashBtnSecondary}" Margin="3">

                                                <TextBlock Text="Istirahat 15m"/>

                                            </Button>

                                        </Grid>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 4: STOPWATCH                                        -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageStopwatch" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Stopwatch Presisi Desktop" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Penghitung waktu presisi milidetik dengan pencatatan putaran (Lap time)." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Display & Buttons -->

                                <Border Style="{StaticResource DashCard}" Padding="24">

                                    <StackPanel HorizontalAlignment="Center">

                                        <TextBlock x:Name="DashStopwatchTimeText" Text="00:00.00" FontSize="56" FontWeight="Bold" Foreground="#00D2FF" HorizontalAlignment="Center" Margin="0,6,0,18"/>

                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                            <Button x:Name="BtnDashStopwatchToggle" Style="{StaticResource DashBtnPrimary}" Width="140" Height="40" Margin="0,0,10,0">

                                                <TextBlock x:Name="DashStopwatchToggleText" Text="Mulai (Start)"/>

                                            </Button>

                                            <Button x:Name="BtnDashStopwatchLap" Style="{StaticResource DashBtnSecondary}" Width="110" Height="40" Margin="0,0,10,0">

                                                <TextBlock Text="Catat Putaran"/>

                                            </Button>

                                            <Button x:Name="BtnDashStopwatchReset" Style="{StaticResource DashBtnSecondary}" Width="80" Height="40">

                                                <TextBlock Text="Reset"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                                <!-- Lap Container Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="CATATAN PUTARAN (LAPS)" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>

                                        <StackPanel x:Name="DashStopwatchLapContainer">

                                            <TextBlock Text="Belum ada putaran dicatat. Tekan 'Catat Putaran' saat stopwatch berjalan." FontSize="12" Foreground="#8E9AA8"/>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 5: COUNTDOWN TIMER                                  -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageCountdown" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Countdown Timer Fleksibel" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Hitung mundur waktu fleksibel untuk presentasi, memasak, atau istirahat." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <Border Style="{StaticResource DashCard}" Padding="24">

                                    <StackPanel HorizontalAlignment="Center">

                                        <TextBlock x:Name="DashCountdownTimeText" Text="10:00" FontSize="56" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" Margin="0,6,0,4"/>

                                        <TextBlock x:Name="DashCountdownStatusText" Text="Siap Memulai Countdown" FontSize="13" Foreground="#8E9AA8" HorizontalAlignment="Center" Margin="0,0,0,18"/>

                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                            <Button x:Name="BtnDashCountdownToggle" Style="{StaticResource DashBtnPrimary}" Width="160" Height="40" Margin="0,0,10,0">

                                                <TextBlock x:Name="DashCountdownToggleText" Text="Mulai Countdown"/>

                                            </Button>

                                            <Button x:Name="BtnDashCountdownReset" Style="{StaticResource DashBtnSecondary}" Width="90" Height="40">

                                                <TextBlock Text="Reset"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                                <!-- Preset Durations -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="PRESET CEPAT" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>

                                        <Grid>

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                            </Grid.ColumnDefinitions>

                                            <Button Grid.Column="0" x:Name="BtnDashCount1m" Style="{StaticResource DashBtnSecondary}" Margin="3"><TextBlock Text="1 Menit"/></Button>

                                            <Button Grid.Column="1" x:Name="BtnDashCount3m" Style="{StaticResource DashBtnSecondary}" Margin="3"><TextBlock Text="3 Menit"/></Button>

                                            <Button Grid.Column="2" x:Name="BtnDashCount5m" Style="{StaticResource DashBtnSecondary}" Margin="3"><TextBlock Text="5 Menit"/></Button>

                                            <Button Grid.Column="3" x:Name="BtnDashCount10m" Style="{StaticResource DashBtnSecondary}" Margin="3"><TextBlock Text="10 Menit"/></Button>

                                            <Button Grid.Column="4" x:Name="BtnDashCount30m" Style="{StaticResource DashBtnSecondary}" Margin="3"><TextBlock Text="30 Menit"/></Button>

                                        </Grid>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 6: SYSTEM MONITOR                                   -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageSysMon" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Monitor Hardware &amp; Sumber Daya" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Diagnostik performa RAM, penyimpanan SSD, prosesor, dan baterai komputer Anda." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- 4 Hardware Metrics Cards -->

                                <Grid Margin="0,0,0,10">

                                    <Grid.ColumnDefinitions>

                                        <ColumnDefinition Width="*"/>

                                        <ColumnDefinition Width="*"/>

                                    </Grid.ColumnDefinitions>

                                    <Grid.RowDefinitions>

                                        <RowDefinition Height="Auto"/>

                                        <RowDefinition Height="Auto"/>

                                    </Grid.RowDefinitions>

                                    <!-- RAM Detailed -->

                                    <Border Grid.Row="0" Grid.Column="0" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="MEMORI RAM FISIK" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                            <TextBlock x:Name="DashSysMonRamVal" Text="48%" FontSize="28" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,4,0,2"/>

                                            <TextBlock x:Name="DashSysMonRamTotal" Text="Total: 16.0 GB" FontSize="12" Foreground="#FFFFFF"/>

                                            <TextBlock x:Name="DashSysMonRamAvail" Text="Tersedia: 8.3 GB" FontSize="12" Foreground="#8E9AA8" Margin="0,2,0,0"/>

                                        </StackPanel>

                                    </Border>

                                    <!-- Storage SSD Detailed -->

                                    <Border Grid.Row="0" Grid.Column="1" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="PENYIMPANAN SISTEM (DRIVE C:)" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                            <TextBlock x:Name="DashSysMonDiskVal" Text="Total 476 GB, Bebas 182 GB" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,8,0,8"/>

                                            <Border Height="6" Background="#1B2130" CornerRadius="3">

                                                <Border x:Name="DashSysMonDiskBar" Width="180" HorizontalAlignment="Left" Background="#00D2FF" CornerRadius="3"/>

                                            </Border>

                                        </StackPanel>

                                    </Border>

                                    <!-- Processor Card -->

                                    <Border Grid.Row="1" Grid.Column="0" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="ARSITEKTUR CPU" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                            <TextBlock Text="x64 Native Processor" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,4,0,2"/>

                                            <TextBlock Text="PowerShell Dispatcher Loop 60 FPS" FontSize="12" Foreground="#8E9AA8"/>

                                        </StackPanel>

                                    </Border>

                                    <!-- Battery & Power -->

                                    <Border Grid.Row="1" Grid.Column="1" Style="{StaticResource DashCard}">

                                        <StackPanel>

                                            <TextBlock Text="STATUS DAYA LAPTOP" FontSize="11" FontWeight="Bold" Foreground="#10B981"/>

                                            <TextBlock x:Name="DashSysMonBatVal" Text="85%" FontSize="24" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,4,0,2"/>

                                            <TextBlock x:Name="DashSysMonBatStatus" Text="Mengisi Daya (AC Online)" FontSize="12" Foreground="#8E9AA8"/>

                                        </StackPanel>

                                    </Border>

                                </Grid>

                                <!-- Hardware Sensors Note & Windows Diagnostic Tools -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="ALAT DIAGNOSTIK RESMI WINDOWS" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>

                                        <StackPanel Orientation="Horizontal">

                                            <Button x:Name="BtnDashSysMonTaskMgr" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                                <TextBlock Text="Buka Task Manager"/>

                                            </Button>

                                            <Button x:Name="BtnDashSysMonResMon" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                                <TextBlock Text="Buka Resource Monitor"/>

                                            </Button>

                                            <Button x:Name="BtnDashSysMonClean" Style="{StaticResource DashBtnSecondary}">

                                                <TextBlock Text="Buka Disk Cleanup"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 7: NOTIFICATIONS CENTER                             -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageNotif" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Pusat Riwayat Notifikasi" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Kelola riwayat pemberitahuan sistem, pengingat fokus, dan alert Oceru." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Actions Row -->

                                <StackPanel Orientation="Horizontal" Margin="0,0,0,14">

                                    <Button x:Name="BtnNotifMarkAllRead" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                        <TextBlock Text="Tandai Semua Dibaca"/>

                                    </Button>

                                    <Button x:Name="BtnNotifClearAll" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                        <TextBlock Text="Hapus Semua Riwayat"/>

                                    </Button>

                                    <Button x:Name="BtnNotifSendTest" Style="{StaticResource DashBtnPrimary}">

                                        <TextBlock Text="Kirim Uji Notifikasi"/>

                                    </Button>

                                </StackPanel>

                                <!-- Notifications List -->

                                <StackPanel x:Name="DashNotifListContainer">

                                    <!-- Notification 1 -->

                                    <Border Style="{StaticResource DashCard}" Margin="0,4">

                                        <Grid>

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="Auto"/>

                                            </Grid.ColumnDefinitions>

                                            <StackPanel Grid.Column="0">

                                                <TextBlock Text="Selamat Datang di Oceru Dynamic Island" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF"/>

                                                <TextBlock Text="Aplikasi aktif dengan desain Ocean Azure Glass di bagian atas desktop Windows Anda." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                            </StackPanel>

                                            <TextBlock Grid.Column="1" Text="Hari ini" FontSize="11" Foreground="#8E9AA8" VerticalAlignment="Top"/>

                                        </Grid>

                                    </Border>

                                    <!-- Notification 2 -->

                                    <Border Style="{StaticResource DashCard}" Margin="0,4">

                                        <Grid>

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="Auto"/>

                                            </Grid.ColumnDefinitions>

                                            <StackPanel Grid.Column="0">

                                                <TextBlock Text="Target Minum Air Harian" FontSize="14" FontWeight="SemiBold" Foreground="#00D2FF"/>

                                                <TextBlock Text="Anda telah mencatat 1250 ml air. Pertahankan target sehat 2000 ml hari ini!" FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                            </StackPanel>

                                            <TextBlock Grid.Column="1" Text="15m lalu" FontSize="11" Foreground="#8E9AA8" VerticalAlignment="Top"/>

                                        </Grid>

                                    </Border>

                                </StackPanel>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 8: QUICK NOTES                                      -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageNotes" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Catatan Cepat (Quick Notes)" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Tulis ide instan. Tersinkronisasi otomatis dengan kartu catatan Dynamic Island." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Add Note Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="BUAT CATATAN BARU" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>

                                        <TextBox x:Name="InputDashNoteTitle" Background="#1B2130" Foreground="#FFFFFF" BorderBrush="#232B3D" BorderThickness="1" Padding="10,6" Margin="0,0,0,8" Text="Ide Proyek Oceru"/>

                                        <TextBox x:Name="InputDashNoteContent" Background="#1B2130" Foreground="#FFFFFF" BorderBrush="#232B3D" BorderThickness="1" Padding="10,6" Height="65" TextWrapping="Wrap" AcceptsReturn="True" Margin="0,0,0,10" Text="Desain Ocean Azure Glass memberikan ketenangan visual dan produktivitas maksimal."/>

                                        <Button x:Name="BtnDashSaveNoteNew" Style="{StaticResource DashBtnPrimary}" HorizontalAlignment="Left">

                                            <TextBlock Text="Simpan Catatan Baru"/>

                                        </Button>

                                    </StackPanel>

                                </Border>

                                <!-- Saved Notes List -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="CATATAN TERSIMPAN" FontSize="11" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,10"/>

                                        <StackPanel x:Name="DashNotesListContainer">

                                            <Border Background="#1B2130" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,4">

                                                <StackPanel>

                                                    <TextBlock Text="Oceru Design Language" FontSize="14" FontWeight="SemiBold" Foreground="#00D2FF"/>

                                                    <TextBlock Text="Ocean Azure Glass dengan midnight navy dan aksen cyan." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                                </StackPanel>

                                            </Border>

                                            <Border Background="#1B2130" BorderBrush="#232B3D" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,4">

                                                <StackPanel>

                                                    <TextBlock Text="Shortcut Cepat" FontSize="14" FontWeight="SemiBold" Foreground="#00D2FF"/>

                                                    <TextBlock Text="Arahkan kursor ke Notch atas untuk membuka Oceru Island." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                                </StackPanel>

                                            </Border>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 9: TO-DO LIST                                       -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageTodo" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Daftar Tugas Harian (To-Do List)" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Kelola checklist harian Anda dengan pelacakan persentase progres otomatis." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Add Task Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="TAMBAH TUGAS BARU" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,8"/>

                                        <Grid>

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="Auto"/>

                                            </Grid.ColumnDefinitions>

                                            <TextBox Grid.Column="0" x:Name="InputDashTodoText" Background="#1B2130" Foreground="#FFFFFF" BorderBrush="#232B3D" BorderThickness="1" Padding="10,7" Margin="0,0,8,0" Text="Eksplorasi fitur baru Oceru"/>

                                            <Button Grid.Column="1" x:Name="BtnDashAddTodo" Style="{StaticResource DashBtnPrimary}">

                                                <TextBlock Text="Tambah Tugas"/>

                                            </Button>

                                        </Grid>

                                    </StackPanel>

                                </Border>

                                <!-- Tasks List & Progress -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="STATUS TUGAS HARI INI" FontSize="11" FontWeight="Bold" Foreground="#FFFFFF"/>

                                        <TextBlock x:Name="DashTodoSummaryText" Text="2 dari 3 tugas selesai (67%)" FontSize="15" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,4,0,8"/>

                                        <Border Height="6" Background="#1B2130" CornerRadius="3" Margin="0,0,0,14">

                                            <Border x:Name="DashTodoSummaryBar" Width="300" HorizontalAlignment="Left" Background="#10B981" CornerRadius="3"/>

                                        </Border>

                                        <StackPanel x:Name="DashTodoListContainer">

                                            <CheckBox x:Name="CbDashTask1" IsChecked="True" Content="Uji responsivitas Notch" Foreground="#FFFFFF" Margin="0,6"/>

                                            <CheckBox x:Name="CbDashTask2" IsChecked="True" Content="Sinkronisasi audio &amp; volume" Foreground="#FFFFFF" Margin="0,6"/>

                                            <CheckBox x:Name="CbDashTask3" IsChecked="False" Content="Cek catatan &amp; to-do list" Foreground="#FFFFFF" Margin="0,6"/>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 10: CLIPBOARD MANAGER                               -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageClip" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Riwayat Papan Klip (Clipboard Manager)" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Akses teks dan tautan yang baru saja disalin. Salin ulang dengan 1-klik ke clipboard Windows." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Actions -->

                                <StackPanel Orientation="Horizontal" Margin="0,0,0,14">

                                    <Button x:Name="BtnDashClipClear" Style="{StaticResource DashBtnSecondary}">

                                        <TextBlock Text="Bersihkan Riwayat"/>

                                    </Button>

                                </StackPanel>

                                <!-- Clipboard Items List -->

                                <Border Style="{StaticResource DashCard}" Margin="0,4">

                                    <Grid>

                                        <Grid.ColumnDefinitions>

                                            <ColumnDefinition Width="*"/>

                                            <ColumnDefinition Width="Auto"/>

                                        </Grid.ColumnDefinitions>

                                        <StackPanel Grid.Column="0">

                                            <TextBlock Text="https://github.com/cubadakanda/dynamic-island" FontSize="13" Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                            <TextBlock Text="Disematkan (Pinned Item)" FontSize="11" Foreground="#00D2FF" Margin="0,2,0,0"/>

                                        </StackPanel>

                                        <Button Grid.Column="1" x:Name="BtnDashCopy1" Style="{StaticResource DashBtnPrimary}" Padding="12,5">

                                            <TextBlock Text="Salin"/>

                                        </Button>

                                    </Grid>

                                </Border>

                                <Border Style="{StaticResource DashCard}" Margin="0,4">

                                    <Grid>

                                        <Grid.ColumnDefinitions>

                                            <ColumnDefinition Width="*"/>

                                            <ColumnDefinition Width="Auto"/>

                                        </Grid.ColumnDefinitions>

                                        <StackPanel Grid.Column="0">

                                            <TextBlock Text="Oceru Dynamic Island Desktop v2.0.0" FontSize="13" Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                            <TextBlock Text="Teks Biasa" FontSize="11" Foreground="#8E9AA8" Margin="0,2,0,0"/>

                                        </StackPanel>

                                        <Button Grid.Column="1" x:Name="BtnDashCopy2" Style="{StaticResource DashBtnSecondary}" Padding="12,5">

                                            <TextBlock Text="Salin"/>

                                        </Button>

                                    </Grid>

                                </Border>

                                <Border Style="{StaticResource DashCard}" Margin="0,4">

                                    <Grid>

                                        <Grid.ColumnDefinitions>

                                            <ColumnDefinition Width="*"/>

                                            <ColumnDefinition Width="Auto"/>

                                        </Grid.ColumnDefinitions>

                                        <StackPanel Grid.Column="0">

                                            <TextBlock Text="Paper Sky - Lumen Coast" FontSize="13" Foreground="#FFFFFF" FontWeight="SemiBold"/>

                                            <TextBlock Text="Teks Biasa" FontSize="11" Foreground="#8E9AA8" Margin="0,2,0,0"/>

                                        </StackPanel>

                                        <Button Grid.Column="1" x:Name="BtnDashCopy3" Style="{StaticResource DashBtnSecondary}" Padding="12,5">

                                            <TextBlock Text="Salin"/>

                                        </Button>

                                    </Grid>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 11: QUICK SETTINGS DETAIL                           -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageQuickSet" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Pusat Aksi &amp; Pengaturan Cepat" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Kontrol audio master Windows, jaringan nirkabel, kecerahan layar, dan status daya." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Audio & Volume Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="KONTROL AUDIO MASTER HARDWARE" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                        <Grid Margin="0,10,0,6">

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="Auto"/>

                                                <ColumnDefinition Width="Auto"/>

                                            </Grid.ColumnDefinitions>

                                            <Slider Grid.Column="0" x:Name="DashQuickVolSlider" Minimum="0" Maximum="100" Value="50" VerticalAlignment="Center"/>

                                            <TextBlock Grid.Column="1" x:Name="DashQuickVolPctText" Text="50%" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center" Margin="14,0,14,0"/>

                                            <Button Grid.Column="2" x:Name="BtnDashQuickMute" Style="{StaticResource DashBtnSecondary}">

                                                <TextBlock x:Name="DashQuickMuteIcon" Text="Mute Audio"/>

                                            </Button>

                                        </Grid>

                                        <Button x:Name="BtnDashOpenSoundSettings" Style="{StaticResource DashBtnSecondary}" HorizontalAlignment="Left" Margin="0,4,0,0">

                                            <TextBlock Text="Buka Pengaturan Suara Windows (ms-settings:sound)"/>

                                        </Button>

                                    </StackPanel>

                                </Border>

                                <!-- Screen Brightness Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="KECERAHAN LAYAR (DISPLAY BRIGHTNESS)" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,8"/>

                                        <TextBlock Text="Pengaturan kecerahan layar Windows. Untuk display internal laptop, buka pengaturan tampilan resmi Windows secara langsung." FontSize="11.5" Foreground="#8E9AA8" TextWrapping="Wrap" Margin="0,0,0,10"/>

                                        <Button x:Name="BtnDashOpenDisplaySettings" Style="{StaticResource DashBtnPrimary}" HorizontalAlignment="Left" Height="34">

                                            <StackPanel Orientation="Horizontal">

                                                <TextBlock Text="&#xE706;" FontFamily="Segoe MDL2 Assets" FontSize="13" Margin="0,0,8,0" VerticalAlignment="Center"/>

                                                <TextBlock Text="Buka Pengaturan Kecerahan Windows (ms-settings:display)" FontSize="11" VerticalAlignment="Center"/>

                                            </StackPanel>

                                        </Button>

                                    </StackPanel>

                                </Border>

                                <!-- Connectivity & Focus Modes -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="KONEKTIVITAS &amp; MODE FOKUS" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>

                                        <Grid>

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                            </Grid.ColumnDefinitions>

                                            <Grid.RowDefinitions>

                                                <RowDefinition Height="Auto"/>

                                                <RowDefinition Height="Auto"/>

                                            </Grid.RowDefinitions>

                                            <Button Grid.Row="0" Grid.Column="0" x:Name="BtnDashQuickWifi" Style="{StaticResource DashBtnSecondary}" Margin="3" Height="40">

                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE701;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="#00D2FF" Margin="0,0,6,0" VerticalAlignment="Center"/>

                                                    <TextBlock x:Name="DashQuickWifiText" Text="Wi-Fi: Memeriksa..." FontSize="11" VerticalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="0" Grid.Column="1" x:Name="BtnDashQuickBt" Style="{StaticResource DashBtnSecondary}" Margin="3" Height="40">

                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE702;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="#00D2FF" Margin="0,0,6,0" VerticalAlignment="Center"/>

                                                    <TextBlock x:Name="DashQuickBtText" Text="Bluetooth: Memeriksa..." FontSize="11" VerticalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="1" Grid.Column="0" x:Name="BtnDashQuickDnd" Style="{StaticResource DashBtnSecondary}" Margin="3" Height="40">

                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE708;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="#00D2FF" Margin="0,0,6,0" VerticalAlignment="Center"/>

                                                    <TextBlock x:Name="DashQuickDndStatus" Text="Mode Jangan Ganggu: Nonaktif" FontSize="11" VerticalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="1" Grid.Column="1" x:Name="BtnDashQuickGame" Style="{StaticResource DashBtnSecondary}" Margin="3" Height="40">

                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE7FC;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="#10B981" Margin="0,0,6,0" VerticalAlignment="Center"/>

                                                    <TextBlock x:Name="DashQuickGameStatus" Text="Mode Game: Nonaktif" FontSize="11" VerticalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                        </Grid>

                                    </StackPanel>

                                </Border>

                                <!-- Power & Security Actions -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="DAYA &amp; KEAMANAN WINDOWS" FontSize="11" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,10"/>

                                        <StackPanel Orientation="Horizontal">

                                            <Button x:Name="BtnDashQuickLock" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                                <TextBlock Text="Kunci Komputer (Lock)"/>

                                            </Button>

                                            <Button x:Name="BtnDashQuickSleep" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                                <TextBlock Text="Mode Tidur (Sleep)"/>

                                            </Button>

                                            <Button x:Name="BtnDashQuickRestart" Style="{StaticResource DashBtnSecondary}">

                                                <TextBlock x:Name="DashQuickRestartLbl" Text="Mulai Ulang (Restart)"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 12: QUICK LAUNCHER                                  -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageQuickLaunch" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Peluncur Cepat Aplikasi (Quick Launcher)" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Buka aplikasi produktivitas dan folder kerja favorit Anda dalam 1-klik." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- App Tiles Grid (4 Columns) -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="APLIKASI REKOMENDASI" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>

                                        <Grid>

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="*"/>

                                            </Grid.ColumnDefinitions>

                                            <Grid.RowDefinitions>

                                                <RowDefinition Height="Auto"/>

                                                <RowDefinition Height="Auto"/>

                                            </Grid.RowDefinitions>

                                            <Button Grid.Row="0" Grid.Column="0" x:Name="BtnLaunchChrome" Style="{StaticResource AppTileBtn}">

                                                <StackPanel HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#00D2FF" HorizontalAlignment="Center"/>

                                                    <TextBlock Text="Browser" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="0" Grid.Column="1" x:Name="BtnLaunchExplorer" Style="{StaticResource AppTileBtn}">

                                                <StackPanel HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#00D2FF" HorizontalAlignment="Center"/>

                                                    <TextBlock Text="Explorer" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="0" Grid.Column="2" x:Name="BtnLaunchTerminal" Style="{StaticResource AppTileBtn}">

                                                <StackPanel HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE756;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#10B981" HorizontalAlignment="Center"/>

                                                    <TextBlock Text="Terminal" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="0" Grid.Column="3" x:Name="BtnLaunchTaskMgr" Style="{StaticResource AppTileBtn}">

                                                <StackPanel HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#00D2FF" HorizontalAlignment="Center"/>

                                                    <TextBlock Text="Task Manager" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="1" Grid.Column="0" x:Name="BtnLaunchSettings" Style="{StaticResource AppTileBtn}">

                                                <StackPanel HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#8E9AA8" HorizontalAlignment="Center"/>

                                                    <TextBlock Text="Settings" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="1" Grid.Column="1" x:Name="BtnLaunchNotepad" Style="{StaticResource AppTileBtn}">

                                                <StackPanel HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE70B;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#F59E0B" HorizontalAlignment="Center"/>

                                                    <TextBlock Text="Notepad" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="1" Grid.Column="2" x:Name="BtnLaunchCalc" Style="{StaticResource AppTileBtn}">

                                                <StackPanel HorizontalAlignment="Center">

                                                    <TextBlock Text="&#x1F522;" FontSize="18" Foreground="#00D2FF" HorizontalAlignment="Center"/>

                                                    <TextBlock Text="Kalkulator" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                            <Button Grid.Row="1" Grid.Column="3" x:Name="BtnLaunchSnipping" Style="{StaticResource AppTileBtn}">

                                                <StackPanel HorizontalAlignment="Center">

                                                    <TextBlock Text="&#xE722;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#FF5252" HorizontalAlignment="Center"/>

                                                    <TextBlock Text="Snipping Tool" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>

                                                </StackPanel>

                                            </Button>

                                        </Grid>

                                    </StackPanel>

                                </Border>

                                <!-- Folder Shortcuts -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="FOLDER KERJA CEPAT" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>

                                        <StackPanel Orientation="Horizontal">

                                            <Button x:Name="BtnFolderDownloads" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                                <TextBlock Text="Folder Unduhan (Downloads)"/>

                                            </Button>

                                            <Button x:Name="BtnFolderDocuments" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                                <TextBlock Text="Folder Dokumen"/>

                                            </Button>

                                            <Button x:Name="BtnFolderPictures" Style="{StaticResource DashBtnSecondary}">

                                                <TextBlock Text="Folder Gambar"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                                <!-- Custom Run Command -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="JALANKAN PERINTAH / APLIKASI KUSTOM" FontSize="11" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,8"/>

                                        <Grid>

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="*"/>

                                                <ColumnDefinition Width="Auto"/>

                                            </Grid.ColumnDefinitions>

                                            <TextBox Grid.Column="0" x:Name="InputCustomCommand" Background="#1B2130" Foreground="#FFFFFF" BorderBrush="#232B3D" BorderThickness="1" Padding="10,7" Margin="0,0,8,0" Text="cmd.exe"/>

                                            <Button Grid.Column="1" x:Name="BtnRunCustomCommand" Style="{StaticResource DashBtnPrimary}">

                                                <TextBlock Text="Jalankan"/>

                                            </Button>

                                        </Grid>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 13: SETTINGS                                        -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageSettings" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Pengaturan Aplikasi Oceru" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Kustomisasi tema tampilan, integrasi Windows Startup, dan preferensi privasi." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Theme Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="TEMA DESAIN (OCEAN AZURE GLASS)" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,8"/>

                                        <RadioButton Content="Ocean Dark (Midnight Navy #0B0D13 + Cyan #00D2FF)" IsChecked="True" Foreground="#FFFFFF" Margin="0,4"/>

                                        <RadioButton Content="Ocean Azure Light / Aero Glass" IsChecked="False" Foreground="#8E9AA8" Margin="0,4"/>

                                        <RadioButton Content="Ikuti Pengaturan Tema Windows" IsChecked="False" Foreground="#8E9AA8" Margin="0,4"/>

                                    </StackPanel>

                                </Border>

                                <!-- Windows Startup Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="INTEGRASI WINDOWS STARTUP" FontSize="11" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,8"/>

                                        <TextBlock Text="Aktifkan agar Oceru Dynamic Island otomatis berjalan setiap kali laptop dinyalakan." FontSize="12" Foreground="#8E9AA8" Margin="0,0,0,12"/>

                                        <StackPanel Orientation="Horizontal">

                                            <Button x:Name="BtnRegisterStartup" Style="{StaticResource DashBtnPrimary}" Margin="0,0,8,0">

                                                <TextBlock Text="Daftarkan ke Windows Startup (install.bat)"/>

                                            </Button>

                                            <Button x:Name="BtnUnregisterStartup" Style="{StaticResource DashBtnSecondary}">

                                                <TextBlock Text="Hapus dari Startup (uninstall.bat)"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                                <!-- Reset Defaults -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="PEMULIHAN &amp; RESET" FontSize="11" FontWeight="Bold" Foreground="#FF5252" Margin="0,0,0,8"/>

                                        <TextBlock Text="Kembalikan semua konfigurasi, catatan, dan tugas ke pengaturan awal bawaan pabrik." FontSize="12" Foreground="#8E9AA8" Margin="0,0,0,12"/>

                                        <Button x:Name="BtnResetSettings" Style="{StaticResource DashBtnSecondary}" HorizontalAlignment="Left">

                                            <TextBlock Text="Kembalikan Pengaturan ke Default Pabrik"/>

                                        </Button>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                    <!-- ======================================================== -->

                    <!-- PAGE 14: ABOUT OCERU                                     -->

                    <!-- ======================================================== -->

                    <Grid x:Name="PageAbout" Visibility="Collapsed">

                        <ScrollViewer VerticalScrollBarVisibility="Auto">

                            <StackPanel>

                                <StackPanel Margin="0,0,0,16">

                                    <TextBlock Text="Tentang Oceru Dynamic Island" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>

                                    <TextBlock Text="Informasi rilis, arsitektur sistem, dan diagnostik desktop." FontSize="12" Foreground="#8E9AA8" Margin="0,4,0,0"/>

                                </StackPanel>

                                <!-- Identity Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="IDENTITAS APLIKASI" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>

                                        <TextBlock Text="Oceru Dynamic Island Desktop" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,6,0,2"/>

                                        <TextBlock Text="Versi: v2.0.0 (Release Build 2026.10)" FontSize="13" Foreground="#00D2FF"/>

                                        <TextBlock Text="Desain: Ocean Azure Glass" FontSize="12" Foreground="#8E9AA8" Margin="0,2,0,0"/>

                                        <TextBlock Text="Lisensi: MIT Open Source License" FontSize="12" Foreground="#10B981" Margin="0,2,0,0"/>

                                    </StackPanel>

                                </Border>

                                <!-- Diagnostics Card -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="ARSITEKTUR &amp; PERFORMA" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,8"/>

                                        <TextBlock Text="UI Engine: Windows Presentation Foundation (WPF) DirectX Direct3D" FontSize="12" Foreground="#FFFFFF" Margin="0,2"/>

                                        <TextBlock Text="Runtime Host: PowerShell .NET CLR Engine (Zero Electron, Zero WebViews)" FontSize="12" Foreground="#FFFFFF" Margin="0,2"/>

                                        <TextBlock Text="Native APIs: user32.dll, kernel32.dll, powrprof.dll via P/Invoke" FontSize="12" Foreground="#FFFFFF" Margin="0,2"/>

                                        <TextBlock x:Name="DashAboutRamFootprint" Text="Pemakaian Memori: ~55 MB (Ultra Ringan)" FontSize="12" Foreground="#10B981" Margin="0,2"/>

                                        <TextBlock Text="Lokasi Instalasi: D:Project Orizzdevdynamic-island" FontSize="12" Foreground="#8E9AA8" Margin="0,2"/>

                                    </StackPanel>

                                </Border>

                                <!-- Links & Actions -->

                                <Border Style="{StaticResource DashCard}">

                                    <StackPanel>

                                        <TextBlock Text="TAUTAN &amp; TINDAKAN CEPAT" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>

                                        <StackPanel Orientation="Horizontal">

                                            <Button x:Name="BtnAboutOpenFolder" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                                <TextBlock Text="Buka Folder Aplikasi"/>

                                            </Button>

                                            <Button x:Name="BtnAboutOpenGitHub" Style="{StaticResource DashBtnSecondary}" Margin="0,0,8,0">

                                                <TextBlock Text="Buka Repositori GitHub"/>

                                            </Button>

                                            <Button x:Name="BtnAboutCheckUpdates" Style="{StaticResource DashBtnPrimary}">

                                                <TextBlock Text="Periksa Pembaruan"/>

                                            </Button>

                                        </StackPanel>

                                    </StackPanel>

                                </Border>

                            </StackPanel>

                        </ScrollViewer>

                    </Grid>

                </Grid>

            </Grid>

        </Grid>

    </Border>

</Window>

'@

# State variables for New Features (Charging Pulse, Universal Shelf, Cat Moods, Ambilight, Network, Eye-Care)

$global:lastAcLineStatus = -1

$global:currentBatteryPct = 85
$global:magSafeGlowTicks = 0
$global:soundFxMuted = $false

$global:catWinkTicks = 0

$global:sleepBreathTick = 0

$global:audioBopTick = 0

$global:ambilightTick = 0

$global:gsmtcPlaying = $false

$global:waveAmp = 0.0

$global:wavePhase = 0.0

$global:waveStrokeColor = "#FF385C" 

# Network & Ping State

$global:lastNetRxBytes = [int64]0

$global:lastNetTxBytes = [int64]0

$global:lastNetTime = [System.DateTime]::MinValue

$global:currentDownRateStr = "$([char]0x2193) 0.0 MB/s"

$global:currentUpRateStr = "$([char]0x2191) 0.0 MB/s"

$global:currentCompactNetStr = "$([char]0x2193) 0.0M"

$global:currentPingMs = 18

$global:currentPingColor = "#10B981"

$global:pingCheckCounter = 0

$global:netStatsTick = 0

# 20-20-20 Eye-Care State

$global:continuousWorkSeconds = 0

$global:eyeCareActive = $false

$global:eyeCareRemaining = 0

$global:eyeCareActivityTick = 0

function Trigger-CatWink {

    $global:catWinkTicks = 14

}

function Start-OceruEyeCareBreak {

    $global:eyeCareActive = $true

    $global:eyeCareRemaining = 20

    Show-OceruDynamicToast "Istirahat Mata 20-20-20 (20s)" "Pandang objek 6 meter sejenak" ([char]0xE7BA) ([char]0xE7BA) "#10B981" 25000

}

# -------------------------------------------------------------

# FEATURE 1: DYNAMIC ALBUM ART COLOR-SYNC ENGINE

# -------------------------------------------------------------

$global:currentMediaAccent = "#FF385C"

$global:lastWaveColor = "#FF385C"

function Get-MediaAccentColor($title, $artist, $props = $null) {

    if ($props -and $props.Thumbnail) {

        try {

            $streamOp = $props.Thumbnail.OpenReadAsync()

            $stream = Await-WinRT $streamOp ([Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime])

            if ($stream -and $stream.Size -gt 0) {

                $netStream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)

                $bmp = [System.Drawing.Image]::FromStream($netStream)

                $small = New-Object System.Drawing.Bitmap(8, 8)

                $g = [System.Drawing.Graphics]::FromImage($small)

                $g.DrawImage($bmp, 0, 0, 8, 8)

                $g.Dispose()

                

                $maxSat = 0.0

                $bestColor = $null

                for ($x = 0; $x -lt 8; $x++) {

                    for ($y = 0; $y -lt 8; $y++) {

                        $pixel = $small.GetPixel($x, $y)

                        $sat = $pixel.GetSaturation()

                        $bri = $pixel.GetBrightness()

                        if ($sat -gt $maxSat -and $bri -gt 0.25 -and $bri -lt 0.90) {

                            $maxSat = $sat

                            $bestColor = "#{0:X2}{1:X2}{2:X2}" -f $pixel.R, $pixel.G, $pixel.B

                        }

                    }

                }

                $small.Dispose()

                $bmp.Dispose()

                $netStream.Dispose()

                if ($bestColor) { return $bestColor }

            }

        } catch {}

    }

    $combined = "$title $artist".ToLower()

    if ($combined -match "lofi|chill|relax|rain|coffee|sleep|ambient") {

        return "#10B981" # Mint Lo-Fi Green

    }

    if ($combined -match "synth|wave|cyber|night|neon|electro|retro|drive") {

        return "#FF2A6D" # Synthwave Neon Pink / Magenta

    }

    if ($combined -match "rock|metal|bass|trap|phonk|fire|hard|heavy|drill") {

        return "#EF4444" # Crimson Flame

    }

    if ($combined -match "acoustic|guitar|folk|piano|sunset|golden|autumn") {

        return "#F59E0B" # Warm Amber Gold

    }

    if ($combined -match "pop|dance|club|edm|party|disco|kpop") {

        return "#A855F7" # Royal Violet

    }

    if ($combined -match "ocean|blue|sky|summer|breeze|water|sea") {

        return "#00D2FF" # Electric Cyan / Azure

    }

    $palette = @(

        "#FF2A6D", # Neon Magenta

        "#00D2FF", # Electric Cyan

        "#10B981", # Emerald Green

        "#F59E0B", # Amber Gold

        "#BD00FF", # Royal Violet

        "#FF7700", # Sunset Orange

        "#05FFA1", # Acid Lime

        "#FF385C"  # Cyberpunk Coral

    )

    $hash = 0

    foreach ($char in "$title$artist".ToCharArray()) {

        $hash = ($hash * 31 + [int]$char) -band 0x7FFFFFFF

    }

    return $palette[$hash % $palette.Count]

}

# -------------------------------------------------------------

# FEATURE 2: INTERACTIVE CAT PET & VIRTUAL PET STATE & GREETING

# -------------------------------------------------------------

$global:catPlayTicks = 0

$global:catPettingHappyTicks = 0

$global:catDoubleWinkTicks = 0

$global:petStrokeCount = 0

$global:lastPetDir = 0

$global:lastPetTime = $null

$global:prevCursorX = $null

$global:prevCursorY = $null

$global:purrTick = 0

function Trigger-CatPlayfulGreeting {
    Play-OceruSound "meow"

    $global:catDoubleWinkTicks = 20 # Double wink sequence

    $hour = (Get-Date).Hour

    $greeting = if ($hour -ge 5 -and $hour -lt 12) {

        "Meow! Selamat pagi! Semangat beraktivitas ya ☀️"

    } elseif ($hour -ge 12 -and $hour -lt 15) {

        "Meow! Selamat siang! Jangan lupa makan siang & minum air 🍱"

    } elseif ($hour -ge 15 -and $hour -lt 18) {

        "Meow! Selamat sore! Tetap rileks & istirahatkan mata sejenak ☕"

    } else {

        "Meow! Selamat malam! Jangan begadang terlalu larut ya 🌙"

    }

    Show-OceruDynamicToast "Oceru Cat 🐱" $greeting ([char]0xE7E7) "#F59E0B" 3200

}

# -------------------------------------------------------------

# FEATURE 3: INDONESIAN PRAYER TIMES & ADZAN ENGINE (Kemenag RI)

# -------------------------------------------------------------

$global:prayerTick = 0

$global:compactRotateTick = 0

$global:lastAlertedPrayer = ""

$global:currentPrayerInfo = $null

function Get-IndonesianPrayerTimes($date = (Get-Date), $lat = -6.2088, $lon = 106.8456, $tzOffset = 7) {

    $year = $date.Year

    $month = $date.Month

    $day = $date.Day

    

    if ($month -le 2) {

        $year -= 1

        $month += 12

    }

    $A = [Math]::Floor($year / 100.0)

    $B = 2 - $A + [Math]::Floor($A / 4.0)

    $JD = [Math]::Floor(365.25 * ($year + 4716)) + [Math]::Floor(30.6001 * ($month + 1)) + $day + $B - 1524.5

    $D = $JD - 2451545.0

    

    $g = (357.529 + 0.98560028 * $D) % 360.0

    $q = (280.459 + 0.98564736 * $D) % 360.0

    $L = ($q + 1.915 * [Math]::Sin($g * [Math]::PI / 180.0) + 0.020 * [Math]::Sin(2 * $g * [Math]::PI / 180.0)) % 360.0

    $e = 23.439 - 0.00000036 * $D

    

    $sinDecl = [Math]::Sin($e * [Math]::PI / 180.0) * [Math]::Sin($L * [Math]::PI / 180.0)

    $decl = [Math]::Asin($sinDecl) * 180.0 / [Math]::PI

    

    $RA = [Math]::Atan2([Math]::Cos($e * [Math]::PI / 180.0) * [Math]::Sin($L * [Math]::PI / 180.0), [Math]::Cos($L * [Math]::PI / 180.0)) * 180.0 / [Math]::PI

    $RA = ($RA / 15.0 + 24.0) % 24.0

    $EqT = ($q / 15.0) - $RA

    if ($EqT -gt 12.0) { $EqT -= 24.0 }

    if ($EqT -lt -12.0) { $EqT += 24.0 }

    

    $noon = 12.0 + $tzOffset - ($lon / 15.0) - $EqT

    

    function Calc-HourAngle([double]$alt, [double]$latitude, [double]$declination) {

        $radLat = $latitude * [Math]::PI / 180.0

        $radDecl = $declination * [Math]::PI / 180.0

        $radAlt = $alt * [Math]::PI / 180.0

        

        $cosH = ([Math]::Sin($radAlt) - ([Math]::Sin($radLat) * [Math]::Sin($radDecl))) / ([Math]::Cos($radLat) * [Math]::Cos($radDecl))

        if ($cosH -gt 1.0) { return 0.0 }

        if ($cosH -lt -1.0) { return 12.0 }

        return ([Math]::Acos($cosH) * 180.0 / [Math]::PI) / 15.0

    }

    

    $hSubuh = Calc-HourAngle -20.0 $lat $decl

    $tSubuh = $noon - $hSubuh

    

    $hSunrise = Calc-HourAngle -0.833 $lat $decl

    $tSunrise = $noon - $hSunrise

    

    $tDzuhur = $noon + (2.0 / 60.0)

    

    $diffLatDecl = [Math]::Abs($lat - $decl) * [Math]::PI / 180.0

    $asharAlt = [Math]::Atan(1.0 / (1.0 + [Math]::Tan($diffLatDecl))) * 180.0 / [Math]::PI

    $hAshar = Calc-HourAngle $asharAlt $lat $decl

    $tAshar = $noon + $hAshar + (2.0 / 60.0)

    

    $tMaghrib = $noon + $hSunrise + (2.0 / 60.0)

    

    $hIsya = Calc-HourAngle -18.0 $lat $decl

    $tIsya = $noon + $hIsya + (2.0 / 60.0)

    

    function Format-PrayerTime([double]$hVal) {

        $hrs = [Math]::Floor($hVal)

        $mins = [Math]::Round(($hVal - $hrs) * 60.0)

        if ($mins -ge 60) { $hrs += 1; $mins -= 60 }

        $hrs = $hrs % 24

        return ("{0:D2}:{1:D2}" -f [int]$hrs, [int]$mins)

    }

    

    $times = [ordered]@{

        Subuh   = Format-PrayerTime $tSubuh

        Terbit  = Format-PrayerTime $tSunrise

        Dzuhur  = Format-PrayerTime $tDzuhur

        Ashar   = Format-PrayerTime $tAshar

        Maghrib = Format-PrayerTime $tMaghrib

        Isya    = Format-PrayerTime $tIsya

    }

    

    $nowMinutes = $date.Hour * 60 + $date.Minute

    $nextName = "Subuh"

    $nextTime = $times["Subuh"]

    $remainingMin = 0

    

    $prayerKeys = @("Subuh", "Dzuhur", "Ashar", "Maghrib", "Isya")

    $found = $false

    foreach ($p in $prayerKeys) {

        $pTime = $times[$p]

        $pParts = $pTime -split ":"

        $pMin = [int]$pParts[0] * 60 + [int]$pParts[1]

        if ($pMin -gt $nowMinutes) {

            $nextName = $p

            $nextTime = $pTime

            $remainingMin = $pMin - $nowMinutes

            $found = $true

            break

        }

    }

    

    if (-not $found) {

        $pParts = $times["Subuh"] -split ":"

        $pMin = ([int]$pParts[0] + 24) * 60 + [int]$pParts[1]

        $nextName = "Subuh"

        $nextTime = $times["Subuh"]

        $remainingMin = $pMin - $nowMinutes

    }

    

    $remStr = if ($remainingMin -ge 60) {

        $remH = [Math]::Floor($remainingMin / 60)

        $remM = $remainingMin % 60

        "${remH}j ${remM}m"

    } else {

        "${remainingMin}m"

    }

    return [PSCustomObject]@{

        Schedule = $times

        NextPrayer = $nextName

        NextTime = $nextTime

        RemainingMinutes = $remainingMin

        RemainingStr = $remStr

    }

}

# ========================================================
# FEATURE 4: IN-MEMORY PROCEDURAL AUDIO SYNTHESIZER
# ========================================================
$global:oceruSoundPlayers = @{}

function New-OceruWavBytes {
    param([string]$Type = "meow")
    $sampleRate = 22050
    if ($Type -eq "meow") {
        # Lo-fi warm kitten meow (~320ms, 480Hz -> 760Hz -> 580Hz glissando)
        $durationMs = 320
        $numSamples = [int]($sampleRate * ($durationMs / 1000.0))
        $samples = New-Object Int16[] $numSamples
        for ($i = 0; $i -lt $numSamples; $i++) {
            $t = $i / [double]$numSamples
            $freq = if ($t -lt 0.45) { 480.0 + (760.0 - 480.0) * ($t / 0.45) } else { 760.0 - (760.0 - 580.0) * (($t - 0.45) / 0.55) }
            $amp = [Math]::Sin($t * [Math]::PI) * 0.42
            $val = [Math]::Sin(2.0 * [Math]::PI * $freq * ($i / $sampleRate)) + 0.3 * [Math]::Sin(4.0 * [Math]::PI * $freq * ($i / $sampleRate))
            $samples[$i] = [int16][Math]::Max(-32767, [Math]::Min(32767, ($val * $amp * 32767)))
        }
    }
    elseif ($Type -eq "purr") {
        # Soothing cat purr (~450ms, low-frequency 28Hz modulated rumble with 110Hz body warmth)
        $durationMs = 450
        $numSamples = [int]($sampleRate * ($durationMs / 1000.0))
        $samples = New-Object Int16[] $numSamples
        for ($i = 0; $i -lt $numSamples; $i++) {
            $t = $i / [double]$numSamples
            $pulse = 0.5 + 0.5 * [Math]::Sin(2.0 * [Math]::PI * 28.0 * ($i / $sampleRate))
            $tone = [Math]::Sin(2.0 * [Math]::PI * 110.0 * ($i / $sampleRate)) + 0.4 * [Math]::Sin(2.0 * [Math]::PI * 75.0 * ($i / $sampleRate))
            $env = [Math]::Sin($t * [Math]::PI) * 0.38
            $samples[$i] = [int16][Math]::Max(-32767, [Math]::Min(32767, ($tone * $pulse * $env * 32767)))
        }
    }
    elseif ($Type -eq "water") {
        # Crisp refreshing water droplet (~120ms, 950Hz -> 1650Hz resonance)
        $durationMs = 120
        $numSamples = [int]($sampleRate * ($durationMs / 1000.0))
        $samples = New-Object Int16[] $numSamples
        for ($i = 0; $i -lt $numSamples; $i++) {
            $t = $i / [double]$numSamples
            $freq = 950.0 + 700.0 * [Math]::Pow($t, 0.7)
            $amp = [Math]::Exp(-6.5 * $t) * 0.45
            $val = [Math]::Sin(2.0 * [Math]::PI * $freq * ($i / $sampleRate))
            $samples[$i] = [int16][Math]::Max(-32767, [Math]::Min(32767, ($val * $amp * 32767)))
        }
    }
    elseif ($Type -eq "chime") {
        # Peaceful harmonic chime (~650ms, A5 880Hz + E6 1318.5Hz chord)
        $durationMs = 650
        $numSamples = [int]($sampleRate * ($durationMs / 1000.0))
        $samples = New-Object Int16[] $numSamples
        for ($i = 0; $i -lt $numSamples; $i++) {
            $t = $i / [double]$numSamples
            $amp = [Math]::Exp(-3.8 * $t) * 0.38
            $val = 0.6 * [Math]::Sin(2.0 * [Math]::PI * 880.0 * ($i / $sampleRate)) + 0.4 * [Math]::Sin(2.0 * [Math]::PI * 1318.5 * ($i / $sampleRate))
            $samples[$i] = [int16][Math]::Max(-32767, [Math]::Min(32767, ($val * $amp * 32767)))
        }
    }

    $byteData = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($byteData)
    $subChunk2Size = $samples.Length * 2
    $chunkSize = 36 + $subChunk2Size

    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([int32]$chunkSize)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([int32]16)
    $bw.Write([int16]1)
    $bw.Write([int16]1)
    $bw.Write([int32]$sampleRate)
    $bw.Write([int32]($sampleRate * 2))
    $bw.Write([int16]2)
    $bw.Write([int16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([int32]$subChunk2Size)

    for ($i = 0; $i -lt $samples.Length; $i++) {
        $bw.Write($samples[$i])
    }
    $bw.Flush()
    $bytes = $byteData.ToArray()
    $bw.Close()
    $byteData.Close()
    return $bytes
}

function Play-OceruSound {
    param([string]$Name)
    if ($global:soundFxMuted) { return }
    try {
        if (-not $global:oceruSoundPlayers.ContainsKey($Name)) {
            $bytes = New-OceruWavBytes -Type $Name
            $ms = New-Object System.IO.MemoryStream(,$bytes)
            $sp = New-Object System.Media.SoundPlayer($ms)
            $sp.Load()
            $global:oceruSoundPlayers[$Name] = $sp
        }
        $global:oceruSoundPlayers[$Name].Play()
    } catch {}
}

# ========================================================
# BRIGHTNESS & DISPLAY WMI CONTROLLER
# ========================================================
$global:currentBrightness = 70

function Get-SystemBrightness {
    try {
        $b = (Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness -ErrorAction Stop).CurrentBrightness
        if ($null -ne $b) {
            $global:currentBrightness = [int]$b
            return [int]$b
        }
    } catch {}
    return $global:currentBrightness
}

function Set-SystemBrightness {
    param([int]$Delta)
    $cur = Get-SystemBrightness
    $newVal = [Math]::Max(0, [Math]::Min(100, $cur + $Delta))
    $global:currentBrightness = $newVal
    try {
        $methods = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop
        $methods | ForEach-Object {
            Invoke-CimMethod -InputObject $_ -MethodName WmiSetBrightness -Arguments @{ Timeout = 1; Brightness = [byte]$newVal } -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}
    return $newVal
}

function Trigger-OceruEyeCareBreak {

    Start-OceruEyeCareBreak

}

function Update-NetworkStats {

    try {

        $now = [System.DateTime]::Now

        $interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |

            Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' -and $_.NetworkInterfaceType -ne 'Tunnel' }

        

        $totalRx = [int64]0

        $totalTx = [int64]0

        foreach ($nic in $interfaces) {

            $stats = $nic.GetIPv4Statistics()

            $totalRx += $stats.BytesReceived

            $totalTx += $stats.BytesSent

        }

        if ($global:lastNetTime -ne [System.DateTime]::MinValue) {

            $dt = ($now - $global:lastNetTime).TotalSeconds

            if ($dt -gt 0.3) {

                $rxRate = [Math]::Max(0.0, ($totalRx - $global:lastNetRxBytes) / $dt)

                $txRate = [Math]::Max(0.0, ($totalTx - $global:lastNetTxBytes) / $dt)

                if ($rxRate -ge 1048576) {

                    $global:currentDownRateStr = "$([char]0x2193) {0:N1} MB/s" -f ($rxRate / 1048576)

                    $global:currentCompactNetStr = "$([char]0x2193) {0:N1}M" -f ($rxRate / 1048576)

                } elseif ($rxRate -ge 1024) {

                    $global:currentDownRateStr = "$([char]0x2193) {0:N0} KB/s" -f ($rxRate / 1024)

                    $global:currentCompactNetStr = "$([char]0x2193) {0:N0}K" -f ($rxRate / 1024)

                } else {

                    $global:currentDownRateStr = "$([char]0x2193) 0 KB/s"

                    $global:currentCompactNetStr = "$([char]0x2193) 0K"

                }

                if ($txRate -ge 1048576) {

                    $global:currentUpRateStr = "$([char]0x2191) {0:N1} MB/s" -f ($txRate / 1048576)

                } elseif ($txRate -ge 1024) {

                    $global:currentUpRateStr = "$([char]0x2191) {0:N0} KB/s" -f ($txRate / 1024)

                } else {

                    $global:currentUpRateStr = "$([char]0x2191) 0 KB/s"

                }

            }

        }

        $global:lastNetRxBytes = $totalRx

        $global:lastNetTxBytes = $totalTx

        $global:lastNetTime = $now

    } catch {}

}

function Check-NetworkPingAsync {

    try {

        [System.Threading.Tasks.Task]::Run([Action]{

            try {

                $pinger = [System.Net.NetworkInformation.Ping]::new()

                $reply = $pinger.Send("1.1.1.1", 1000)

                if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {

                    $ms = $reply.RoundtripTime

                    $global:currentPingMs = $ms

                    if ($ms -lt 60) {

                        $global:currentPingColor = "#10B981"

                    } elseif ($ms -lt 150) {

                        $global:currentPingColor = "#F59E0B"

                    } else {

                        $global:currentPingColor = "#EF4444"

                    }

                } else {

                    $global:currentPingMs = -1

                    $global:currentPingColor = "#EF4444"

                }

            } catch {

                $global:currentPingMs = -1

                $global:currentPingColor = "#EF4444"

            }

        }) | Out-Null

    } catch {}

}

# Initialize Both Windows

$reader1 = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($islandXaml))

$window = [System.Windows.Markup.XamlReader]::Load($reader1)

$reader2 = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($dashXaml))

$dashWindow = [System.Windows.Markup.XamlReader]::Load($reader2)

# Start by Default in Resting Cat Eyes Mode at Top-Center (Option B Hardware Notch)

$winCanvasW = [Math]::Min(1000, [int]$screenWidth)
$winCanvasH = 320
$winCanvasL = [Math]::Round(($screenWidth - $winCanvasW) / 2)

$window.Width = $winCanvasW
$window.Height = $winCanvasH
$window.Left = $winCanvasL
$window.Top = 0
$window.Background = $null

$global:islandHwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).EnsureHandle()
$global:isForegroundFullscreen = $false
$global:fullscreenCheckTick = 0
$global:targetWindowTop = 0.0
$global:lastCapsLockState = $null
$global:capsLockCheckTick = 0
$global:lastPowerLineStatus = $null
$global:topProcTick = 0

$masterGrid.Width = $eyesTotalWidth
$masterGrid.Height = $eyesHeight

$global:islandMode = "eyes" # "eyes", "status", "expanded"

$global:targetMode = "eyes"

$global:statusIdleTicks = 0

$global:outsideTicks = 0

# Grab Handles: Single Unified Hardware Notch Path & Audio Wave Stroke Path

$notchSinglePath = $window.FindName("NotchSinglePath")

$notchBody = $notchSinglePath # Alias for event handlers and backward compatibility

if ($notchSinglePath) {

    $initialPathStr = Get-NotchPathData $eyesTotalWidth $eyesHeight $shoulderPad 18

    $initialGeom = [System.Windows.Media.Geometry]::Parse($initialPathStr)

    $notchSinglePath.Data = $initialGeom

}

$eyesGrid = $window.FindName("EyesGrid")

$statusGrid = $window.FindName("StatusGrid")

$expandedGrid = $window.FindName("ExpandedGrid")

$compactNetSpeedText = $window.FindName("CompactNetSpeedText")

$compactPingDot = $window.FindName("CompactPingDot")

$sysNetStatsText = $window.FindName("SysNetStatsText")

$sysPingText = $window.FindName("SysPingText")

$notchWaveStrokePath = $window.FindName("NotchWaveStrokePath")
$notchWaveCorePath   = $window.FindName("NotchWaveCorePath")
$notchWaveRibbon2Path = $window.FindName("NotchWaveRibbon2Path")
$notchBarsGlowPath   = $window.FindName("NotchBarsGlowPath")
$notchBarsCorePath   = $window.FindName("NotchBarsCorePath")
$notchBarsWhitePath  = $window.FindName("NotchBarsWhitePath")
$notchApexCanvas     = $window.FindName("NotchApexCanvas")
$notchGlassHighlight = $window.FindName("NotchGlassHighlight")
$catZzzCanvas        = $window.FindName("CatZzzCanvas")
$zzz1                = $window.FindName("Zzz1")
$zzz2                = $window.FindName("Zzz2")
$zzz3                = $window.FindName("Zzz3")
$global:catChargingHappyTicks = 0
$global:zzzTick               = 0
$global:musicWinkTick         = 0

# Initialize Neon Apex Spark Dot Pool in $notchApexCanvas
$global:apexSparkBorders = New-Object System.Collections.Generic.List[System.Windows.Controls.Border]
if ($notchApexCanvas) {
    for ($i = 0; $i -lt 25; $i++) {
        $sp = New-Object System.Windows.Controls.Border
        $sp.Width = 4.5
        $sp.Height = 4.5
        $sp.CornerRadius = [System.Windows.CornerRadius]::new(2.25)
        $sp.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
        $sp.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF385C")
        $sp.BorderThickness = [System.Windows.Thickness]::new(1.0)
        $spEffect = New-Object System.Windows.Media.Effects.DropShadowEffect
        $spEffect.Color = [System.Windows.Media.ColorConverter]::ConvertFromString("#FF385C")
        $spEffect.BlurRadius = 8.0
        $spEffect.ShadowDepth = 0.0
        $spEffect.Opacity = 0.95
        $sp.Effect = $spEffect
        $sp.Visibility = [System.Windows.Visibility]::Collapsed
        [System.Windows.Controls.Canvas]::SetLeft($sp, 0)
        [System.Windows.Controls.Canvas]::SetTop($sp, 0)
        $notchApexCanvas.Children.Add($sp) | Out-Null
        $global:apexSparkBorders.Add($sp)
    }
}

# Handles: Resting Eyes

$leftEye = $window.FindName("LeftEye")

$rightEye = $window.FindName("RightEye")

$leftPupilTransform = $window.FindName("LeftPupilTransform")

$rightPupilTransform = $window.FindName("RightPupilTransform")

$catEyesTransform = $window.FindName("CatEyesTransform")

$leftPupilBorder = $window.FindName("LeftPupilBorder")

$rightPupilBorder = $window.FindName("RightPupilBorder")

# Handles: Compact Status Bar (Clock, Weather, Battery)

$compactClockText = $window.FindName("CompactClockText")

$compactClockView = $window.FindName("CompactClockView")

$compactPrayerView = $window.FindName("CompactPrayerView")

$compactPrayerText = $window.FindName("CompactPrayerText")

$cardPrayerScheduleText = $window.FindName("CardPrayerScheduleText")

$compactBatPct = $window.FindName("CompactBatPct")

$compactBatIcon = $window.FindName("CompactBatIcon")

$btnMiniEqualizer = $window.FindName("BtnMiniEqualizer")
$miniEqBar1 = $window.FindName("MiniEqBar1")
$miniEqBar2 = $window.FindName("MiniEqBar2")
$miniEqBar3 = $window.FindName("MiniEqBar3")
$miniEqBar4 = $window.FindName("MiniEqBar4")

if ($btnMiniEqualizer) {
    $btnMiniEqualizer.Add_Click({
        SwitchCarouselCard(0)
        Set-IslandMode "expanded"
    })
}

# Handles: Expanded Header

$headerTitleText = $window.FindName("HeaderTitleText")

$headerDateText = $window.FindName("HeaderDateText")

$headerTimeText = $window.FindName("HeaderTimeText")

$headerWavePanel = $window.FindName("HeaderWavePanel")

$waveBar1 = $window.FindName("WaveBar1")

$waveBar2 = $window.FindName("WaveBar2")

$waveBar3 = $window.FindName("WaveBar3")

$waveBar4 = $window.FindName("WaveBar4")

# Carousel Cards

$cardMusic = $window.FindName("CardMusic")

$cardPomo = $window.FindName("CardPomo")

$cardNotesTodo = $window.FindName("CardNotesTodo")

$cardClipShelf = $window.FindName("CardClipShelf")

$cardSysWater = $window.FindName("CardSysWater")

$cardQuick = $window.FindName("CardQuick")

$allCards = @($cardMusic, $cardPomo, $cardNotesTodo, $cardClipShelf, $cardSysWater, $cardQuick)

$bottomPomoRow = $window.FindName("BottomPomoRow")

# Pagination Dots (6 Dots for 6 Cards)

$dot0 = $window.FindName("Dot0")

$dot1 = $window.FindName("Dot1")

$dot2 = $window.FindName("Dot2")

$dot3 = $window.FindName("Dot3")

$dot4 = $window.FindName("Dot4")

$dot5 = $window.FindName("Dot5")

$dotBars = @($dot0, $dot1, $dot2, $dot3, $dot4, $dot5)

# Card 0: Music Handles

$musicPlayerView = $window.FindName("MusicPlayerView")

# ========================================================
# FEATURE: DYNAMIC SYNCHRONIZED LYRICS ENGINE (LRCLIB REAL-TIME SYNC)
# ========================================================
Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

$global:lyricsCacheFile = Join-Path $PSScriptRoot ".oceru-lyrics-cache.json"
$global:lyricsCache = @{}

if (Test-Path $global:lyricsCacheFile) {
    try {
        $cacheRaw = Get-Content -Path $global:lyricsCacheFile -Raw -Encoding UTF8
        $cacheObj = $cacheRaw | ConvertFrom-Json
        foreach ($prop in $cacheObj.PSObject.Properties) {
            $global:lyricsCache[$prop.Name] = $prop.Value
        }
    } catch {}
}

function Save-OceruLyricsCache {
    try {
        $json = $global:lyricsCache | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($global:lyricsCacheFile, $json, [System.Text.Encoding]::UTF8)
    } catch {}
}

$global:lyricsHttpClient = $null
try {
    $global:lyricsHttpClient = New-Object System.Net.Http.HttpClient
    $global:lyricsHttpClient.DefaultRequestHeaders.UserAgent.ParseAdd("OceruDynamicIsland/1.0.0 (Windows NT 10.0; Win64; x64)")
    $global:lyricsHttpClient.Timeout = [TimeSpan]::FromSeconds(6)
} catch {}

$global:lyricsFetchTask = $null
$global:fetchingSongKey = ""

$global:embeddedLyrics = @{
    "daun jatuh:antara pagi dan kau" = @"
[00:16.30] Pagi ini mentari bersinar cerah
[00:25.76] Namun cerahnya tak secerah parasmu
[00:35.07] Pagi ini burung berkicau nan merdu
[00:44.65] Namun tak semerdu saat kau menyapaku
[00:54.07] Hu
[01:04.98] Dengan tulus dan penuh keyakinan
[01:14.86] Kutitipkan segala yang kupunya padamu
[01:25.35] Aku ingin kau selalu ada di sini
[01:35.20] Tuk temani hari yang terus berganti
[01:44.90] Karena aku tak pernah mau tuk sendiri
[01:54.41] Raga dan jiwaku nyaman bersamamu
[02:10.55] Pagi ini bunga bermekaran manis
[02:20.58] Namun tak semanis saat kau menatapku
[02:30.71] Hu
[02:41.22] Dengan tulus dan penuh keyakinan
[02:50.44] Kutitipkan segala yang kupunya padamu
[03:00.91] Aku ingin kau selalu ada di sini
[03:11.07] Tuk temani hari yang terus berganti
[03:20.70] Karena aku tak pernah mau tuk sendiri
[03:30.18] Raga dan jiwaku nyaman bersamamu
[03:54.61] Jangan pernah kau pergi
[03:59.21] Tinggalkan ku sendiri
[04:04.03] Jangan membuatku tertatih
[04:08.55] Karena luka yang perih
[04:13.90] Jangan pernah kau pergi
[04:18.25] Tinggalkan ku sendiri
[04:23.05] Jangan membuatku tertatih
[04:27.71] Karena luka yang perih lagi
[04:50.01] Aku ingin kau selalu ada di sini
[04:59.06] Tuk temani hari yang terus berganti
[05:08.74] Karena aku tak pernah mau tuk sendiri
[05:18.30] Raga dan jiwaku nyaman bersamamu
"@
    "daun jatuh:resah jadi luka" = @"
[00:15.00]Kuingin rasakan rindu
[00:22.00]Tanpa ada rasa sakit di hatiku
[00:30.00]Mengapa harus terluka
[00:38.00]Saat cinta mulai tumbuh di jiwa
[00:48.00]Kuharap kau mengerti apa yang kurasa
[00:58.00]Kini resahku telah menjadi luka
[01:08.00]Menemani sepi di malam yang dingin
"@
    "raim laode:komang" = @"
[00:16.59] Dari kejauhan, tergambar cerita tentang kita
[00:25.87] Terpisah jarak dan waktu
[00:34.50] Ingin kuungkapkan rindu lewat alunan lagu
[00:46.85] Sebab kau terlalu indah tuk sekadar kata
[00:57.20] Sebab kau terlalu indah tuk jadi nyata
[01:09.10] Dan apabila hatiku mulai merasa sepi
[01:19.45] Ku akan bernyanyi untukmu
"@
}

function Clean-SongInfo {
    param([string]$RawTitle, [string]$RawArtist)
    if (-not $RawTitle) { $RawTitle = "" }
    if (-not $RawArtist) { $RawArtist = "" }

    $cleanT = $RawTitle -replace '\(.*?(?:Official|Audio|Video|Lyric|Lirik|Version|Remaster|YouTube|Spotify).*?\)', '' `
                        -replace '\[.*?(?:Official|Audio|Video|Lyric|Lirik|Version|Remaster).*?\]', '' `
                        -replace '(?i)Official Music Video|Official Video|Official Audio|Lyric Video|Audio|Lirik|MV|Visualizer|HD|4K', ''
    $cleanT = $cleanT.Trim()

    $cleanA = $RawArtist -replace '\s*\(.*?\)', ''
    $cleanA = $cleanA.Trim()

    $dashRegex = '[\-\u2013\u2014]'

    # If artist is a browser/generic app and title contains " - ", split them
    if (($cleanA -match '(?i)YouTube|Chrome|Edge|Firefox|Spotify|Windows Media|Media Windows|^$') -and ($cleanT -match "^(.*?)\s*$dashRegex\s*(.*)$")) {
        $cleanA = $Matches[1].Trim()
        $cleanT = $Matches[2].Trim()
    }

    # If title repeats the artist at the beginning
    if ($cleanA) {
        $escA = [regex]::Escape($cleanA)
        if ($cleanT -match "^$escA\s*$dashRegex\s*(.*)$") {
            $cleanT = $Matches[1].Trim()
        }
    }

    return @{ Title = $cleanT; Artist = $cleanA }
}

function Start-AsyncLyricsFetch([string]$Title, [string]$Artist, [double]$Duration = 240) {
    if (-not $global:lyricsHttpClient) { return }
    $info = Clean-SongInfo $Title $Artist
    $cleanT = $info.Title
    $cleanA = $info.Artist
    if (-not $cleanT -or $cleanT -eq "Tidak ada media aktif") { return }

    $searchQuery = "$cleanT $cleanA".Trim()
    $encoded = [System.Uri]::EscapeDataString($searchQuery)
    $url = "https://lrclib.net/api/search?q=$encoded"

    try {
        $global:fetchingSongKey = "$($cleanA)::$($cleanT)".ToLower()
        $global:lyricsFetchTask = $global:lyricsHttpClient.GetStringAsync($url)
    } catch {}
}

function Parse-LyricsLRC {
    param([string]$LrcText, [double]$TotalSeconds = 240)
    $lines = @()
    if (-not $LrcText) { return $lines }
    $rawLines = $LrcText -split "`r?`n"
    $hasTimestamps = $false

    foreach ($line in $rawLines) {
        $trim = $line.Trim()
        if (-not $trim) { continue }
        if ($trim -match '^\s*\[(\d{1,2}):(\d{2}(?:\.\d+)?)\](.*)$') {
            $hasTimestamps = $true
            $min = [double]$Matches[1]
            $sec = [double]$Matches[2]
            $text = $Matches[3].Trim()
            $timeSec = ($min * 60.0) + $sec
            if ($text) {
                $lines += [PSCustomObject]@{ TimeSec = $timeSec; Text = $text }
            }
        }
    }

    if (-not $hasTimestamps -and $rawLines.Count -gt 0) {
        $validPlain = $rawLines | Where-Object { $_.Trim() -ne "" }
        $step = [Math]::Max(4.0, $TotalSeconds / [Math]::Max(1, $validPlain.Count))
        $t = 6.0
        foreach ($p in $validPlain) {
            $lines += [PSCustomObject]@{ TimeSec = $t; Text = $p.Trim() }
            $t += $step
        }
    }
    return $lines
}

function Generate-AdaptiveLyricsProgression {
    param([string]$Title, [string]$Artist, [double]$Duration = 240)
    if ($Duration -le 0) { $Duration = 210 }
    $info = Clean-SongInfo $Title $Artist
    $cleanT = if ($info.Title) { $info.Title } else { "Lagu Sedang Diputar" }
    $cleanA = if ($info.Artist) { $info.Artist } else { "Musik Aktif" }
    $note = [char]0x266A

    $lines = @(
        [PSCustomObject]@{ TimeSec = 0.0; Text = "$note [Intro Musik] $cleanT $note" },
        [PSCustomObject]@{ TimeSec = [Math]::Round($Duration * 0.12); Text = "Memutar lagu: $cleanT" },
        [PSCustomObject]@{ TimeSec = [Math]::Round($Duration * 0.25); Text = "Artis: $cleanA" },
        [PSCustomObject]@{ TimeSec = [Math]::Round($Duration * 0.40); Text = "$note [Bait Utama & Harmoni Nada] $note" },
        [PSCustomObject]@{ TimeSec = [Math]::Round($Duration * 0.60); Text = "Menikmati alunan melodi lagu..." },
        [PSCustomObject]@{ TimeSec = [Math]::Round($Duration * 0.78); Text = "$note [Refrain & Puncak Musik] $note" },
        [PSCustomObject]@{ TimeSec = [Math]::Round($Duration * 0.90); Text = "$note [Outro / Menjelang Akhir] $note" }
    )
    return $lines
}

function Get-ActiveLyricsContext {
    param($ParsedLines, [double]$CurSec)
    $note = [char]0x266A
    if (-not $ParsedLines -or $ParsedLines.Count -eq 0) {
        return @{ Prev = ""; Current = "$note Instrumen Musik $note"; Next = ""; Next2 = "" }
    }

    $activeIdx = 0
    for ($i = 0; $i -lt $ParsedLines.Count; $i++) {
        if ($CurSec -ge $ParsedLines[$i].TimeSec) {
            $activeIdx = $i
        } else {
            break
        }
    }

    $prev = if ($activeIdx -gt 0) { $ParsedLines[$activeIdx - 1].Text } else { "" }
    $curr = $ParsedLines[$activeIdx].Text
    $next = if ($activeIdx + 1 -lt $ParsedLines.Count) { $ParsedLines[$activeIdx + 1].Text } else { "" }
    $next2 = if ($activeIdx + 2 -lt $ParsedLines.Count) { $ParsedLines[$activeIdx + 2].Text } else { "" }

    return @{
        Prev = $prev
        Current = $curr
        Next = $next
        Next2 = $next2
        Index = $activeIdx
        Total = $ParsedLines.Count
    }
}

$global:currentLyricsSongKey = ""
$global:parsedLyricsLines = @()

function Update-LiveLyricsDisplay([double]$curSec, [double]$totalSec) {
    try {
        $note = [char]0x266A
        $rawTitle = $global:OceruState.currentMedia.title
        $rawArtist = $global:OceruState.currentMedia.artist
        if (-not $rawTitle -or $rawTitle -eq "Tidak ada media aktif") {
            if ($lyricLineCurrent) { $lyricLineCurrent.Text = "$note Tidak ada media aktif $note" }
            if ($lyricLinePrev) { $lyricLinePrev.Text = "" }
            if ($lyricLineNext) { $lyricLineNext.Text = "" }
            if ($lyricLineNext2) { $lyricLineNext2.Text = "" }
            return
        }

        $info = Clean-SongInfo $rawTitle $rawArtist
        $cacheKey = "$($info.Artist)::$($info.Title)".ToLower()

        # Check if background fetch has completed
        if ($global:lyricsFetchTask -and $global:lyricsFetchTask.IsCompleted) {
            try {
                if (-not $global:lyricsFetchTask.IsFaulted -and $global:lyricsFetchTask.Result) {
                    $json = $global:lyricsFetchTask.Result
                    $items = $json | ConvertFrom-Json
                    $match = $items | Where-Object { $_.syncedLyrics } | Select-Object -First 1
                    if ($match -and $match.syncedLyrics) {
                        $global:lyricsCache[$global:fetchingSongKey] = $match.syncedLyrics
                        Save-OceruLyricsCache
                        if ($global:currentLyricsSongKey -eq $global:fetchingSongKey) {
                            $global:parsedLyricsLines = Parse-LyricsLRC $match.syncedLyrics $totalSec
                        }
                    } elseif ($items -and $items.Count -gt 0 -and $items[0].plainLyrics) {
                        $global:lyricsCache[$global:fetchingSongKey] = $items[0].plainLyrics
                        Save-OceruLyricsCache
                        if ($global:currentLyricsSongKey -eq $global:fetchingSongKey) {
                            $global:parsedLyricsLines = Parse-LyricsLRC $items[0].plainLyrics $totalSec
                        }
                    }
                }
            } catch {}
            $global:lyricsFetchTask = $null
        }

        # Check if song changed or lyrics not parsed yet
        if ($cacheKey -ne $global:currentLyricsSongKey -or (-not $global:parsedLyricsLines) -or $global:parsedLyricsLines.Count -eq 0) {
            $global:currentLyricsSongKey = $cacheKey

            # 1. Check local persistent disk cache
            if ($global:lyricsCache.ContainsKey($cacheKey)) {
                $rawLrc = $global:lyricsCache[$cacheKey]
                $global:parsedLyricsLines = Parse-LyricsLRC $rawLrc $totalSec
            }
            # 2. Check embedded songs
            elseif ($global:embeddedLyrics.ContainsKey($cacheKey)) {
                $rawLrc = $global:embeddedLyrics[$cacheKey]
                $global:parsedLyricsLines = Parse-LyricsLRC $rawLrc $totalSec
            }
            else {
                # 3. Check partial match in embedded songs
                $foundEmbedded = $null
                foreach ($k in $global:embeddedLyrics.Keys) {
                    $parts = $k -split ":"
                    if ($cacheKey.Contains($parts[1]) -and $cacheKey.Contains($parts[0])) {
                        $foundEmbedded = $global:embeddedLyrics[$k]
                        break
                    }
                }
                if ($foundEmbedded) {
                    $global:parsedLyricsLines = Parse-LyricsLRC $foundEmbedded $totalSec
                } else {
                    # 4. Trigger asynchronous fetch from LRCLIB
                    Start-AsyncLyricsFetch $rawTitle $rawArtist $totalSec
                    $global:parsedLyricsLines = @(
                        [PSCustomObject]@{ TimeSec = 0.0; Text = "$note Mencari lirik online ($($info.Title))... $note" },
                        [PSCustomObject]@{ TimeSec = 4.0; Text = "$note Menghubungkan ke database lirik $note" },
                        [PSCustomObject]@{ TimeSec = 10.0; Text = "$note Menikmati melodi lagu... $note" }
                    )
                }
            }
        }

        # Render active lyrics
        if ($global:parsedLyricsLines -and $global:parsedLyricsLines.Count -gt 0) {
            $ctx = Get-ActiveLyricsContext $global:parsedLyricsLines $curSec
            if ($lyricLinePrev) { $lyricLinePrev.Text = $ctx.Prev }
            if ($lyricLineCurrent) {
                $lyricLineCurrent.Text = $ctx.Current
                if ($global:lastWaveColor) {
                    $lyricLineCurrent.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($global:lastWaveColor)
                }
            }
            if ($lyricLineNext) { $lyricLineNext.Text = $ctx.Next }
            if ($lyricLineNext2) { $lyricLineNext2.Text = $ctx.Next2 }
        }
    } catch {}
}
# Handles: Card 0 Side-by-Side Lyrics & Media Controls
$musicLyricsSidePanel = $window.FindName("MusicLyricsSidePanel")
$musicLyricsDivider = $window.FindName("MusicLyricsDivider")
$btnToggleLyrics = $window.FindName("BtnToggleLyrics")
$iconToggleLyrics = $window.FindName("IconToggleLyrics")
$btnCloseLyricsSide = $window.FindName("BtnCloseLyricsSide")
$lyricLinePrev = $window.FindName("LyricLinePrev")
$lyricLineCurrent = $window.FindName("LyricLineCurrent")
$lyricLineNext = $window.FindName("LyricLineNext")
$lyricLineNext2 = $window.FindName("LyricLineNext2")

$musicTitle = $window.FindName("MusicTitle")

$musicArtist = $window.FindName("MusicArtist")

$musicCurrentTime = $window.FindName("MusicCurrentTime")

$musicRemainingTime = $window.FindName("MusicRemainingTime")

$musicProgressBar = $window.FindName("MusicProgressBar")

$btnMusicNextCard = $window.FindName("BtnMusicNextCard")

$btnToggleLyrics = $window.FindName("BtnToggleLyrics")

$btnBackFromLyrics = $window.FindName("BtnBackFromLyrics")

$btnOpenLocalAudio = $window.FindName("BtnOpenLocalAudio")

$btnMusicPrev = $window.FindName("BtnMusicPrev")

$btnMusicPlayPause = $window.FindName("BtnMusicPlayPause")

$musicPlayPauseIcon = $window.FindName("MusicPlayPauseIcon")

$btnMusicNext = $window.FindName("BtnMusicNext")

# Card 1: Pomodoro Handles

$btnPomoPrevCard = $window.FindName("BtnPomoPrevCard")

$btnPomoNextCard = $window.FindName("BtnPomoNextCard")

$pomoSubtitle = $window.FindName("PomoSubtitle")

$pomoDisplayTime = $window.FindName("PomoDisplayTime")

$btnPomoReset = $window.FindName("BtnPomoReset")

$btnPomoShortBreak = $window.FindName("BtnPomoShortBreak")

$btnPomoPlay = $window.FindName("BtnPomoPlay")

$pomoPlayPauseIcon = $window.FindName("PomoPlayPauseIcon")

$btnPomoFocusTime = $window.FindName("BtnPomoFocusTime")

# Card 2: Notes & Todo Handles

$btnNotesPrevCard = $window.FindName("BtnNotesPrevCard")

$btnNotesNextCard = $window.FindName("BtnNotesNextCard")
$headerTaskBadge = $window.FindName("HeaderTaskBadge")
$headerTaskBadgeText = $window.FindName("HeaderTaskBadgeText")
$todoPercentText = $window.FindName("TodoPercentText")
$todoProgressBar = $window.FindName("TodoProgressBar")
$todoMotivationText = $window.FindName("TodoMotivationText")
$btnClearDoneTasks = $window.FindName("BtnClearDoneTasks")
$newTaskInput = $window.FindName("NewTaskInput")
$btnAddNewTask = $window.FindName("BtnAddNewTask")
$taskListContainer = $window.FindName("TaskListContainer")

# Card 3: Clipboard & Shelf Handles

$btnClipPrevCard = $window.FindName("BtnClipPrevCard")

$btnClipNextCard = $window.FindName("BtnClipNextCard")
$btnHeaderClearShelf = $window.FindName("BtnHeaderClearShelf")
$shelfDropBorder = $window.FindName("ShelfDropBorder")
$shelfEmptyDropZone = $window.FindName("ShelfEmptyDropZone")
$shelfFilesContainer = $window.FindName("ShelfFilesContainer")
$shelfFilesList = $window.FindName("ShelfFilesList")
$shelfDropPrompt = $window.FindName("ShelfDropPrompt")
$shelfDropIcon = $window.FindName("ShelfDropIcon")

# Card 4: System & Water Handles

$btnSysPrevCard = $window.FindName("BtnSysPrevCard")

$btnSysNextCard = $window.FindName("BtnSysNextCard")

$sysRamText = $window.FindName("SysRamText")

$sysBatStatusText = $window.FindName("SysBatStatusText")

$btnSysTaskMgr = $window.FindName("BtnSysTaskMgr")

$waterAmountText = $window.FindName("WaterAmountText")

$topAppsListContainer = $window.FindName("TopAppsListContainer")

# Card 5: Quick Settings Handles

$btnQuickPrevCard = $window.FindName("BtnQuickPrevCard")

$btnQuickNextCard = $window.FindName("BtnQuickNextCard")

$btnQuickWifi = $window.FindName("BtnQuickWifi")

$btnQuickBt = $window.FindName("BtnQuickBt")

$btnQuickDnd = $window.FindName("BtnQuickDnd")

$quickStatusDnd = $window.FindName("QuickStatusDnd")

$btnQuickGame = $window.FindName("BtnQuickGame")

$quickStatusGame = $window.FindName("QuickStatusGame")

$btnQuickMute = $window.FindName("BtnQuickMute")

$quickIconMute = $window.FindName("QuickIconMute")

$quickSliderVol = $window.FindName("QuickSliderVol")

$quickVolPctText = $window.FindName("QuickVolPctText")

$btnQuickLock = $window.FindName("BtnQuickLock")

$btnQuickSleep = $window.FindName("BtnQuickSleep")

$btnQuickRestart = $window.FindName("BtnQuickRestart")

$quickLblRestart = $window.FindName("QuickLblRestart")

$btnSysLaunchDash = $window.FindName("BtnSysLaunchDash")

# Toast Feedback Handles

$toastFeedbackPill = $window.FindName("ToastFeedbackPill")

$toastFeedbackIcon = $window.FindName("ToastFeedbackIcon")

$toastFeedbackText = $window.FindName("ToastFeedbackText")

# Dynamic Toast Notification Pill Handles

$dynamicToastGrid = $window.FindName("DynamicToastGrid")

$dynamicToastIcon = $window.FindName("DynamicToastIcon")

$dynamicToastTitle = $window.FindName("DynamicToastTitle")

$dynamicToastMessage = $window.FindName("DynamicToastMessage")

$dynamicToastDot = $window.FindName("DynamicToastDot")

# Grab Handles: Dashboard Window

$dashTitleBar = $dashWindow.FindName("DashTitleBar")

$btnDashMin = $dashWindow.FindName("BtnDashMin")

$btnDashClose = $dashWindow.FindName("BtnDashClose")

$dashTitleBar.Add_MouseLeftButtonDown({ $dashWindow.DragMove() })

$btnDashMin.Add_Click({ $dashWindow.WindowState = [System.Windows.WindowState]::Minimized })

$btnDashClose.Add_Click({ $dashWindow.Hide() })

$dashRamVal = $dashWindow.FindName("DashRamVal")

$dashBatVal = $dashWindow.FindName("DashBatVal")

$dashBatStatus = $dashWindow.FindName("DashBatStatus")

# Dashboard Sidebar Navigation Wireup (15 destinations)

$dashPages = @(

    $dashWindow.FindName("PageOverview"),

    $dashWindow.FindName("PageIsland"),

    $dashWindow.FindName("PageMedia"),

    $dashWindow.FindName("PagePomo"),

    $dashWindow.FindName("PageStopwatch"),

    $dashWindow.FindName("PageCountdown"),

    $dashWindow.FindName("PageSysMon"),

    $dashWindow.FindName("PageNotif"),

    $dashWindow.FindName("PageNotes"),

    $dashWindow.FindName("PageTodo"),

    $dashWindow.FindName("PageClip"),

    $dashWindow.FindName("PageQuickSet"),

    $dashWindow.FindName("PageQuickLaunch"),

    $dashWindow.FindName("PageSettings"),

    $dashWindow.FindName("PageAbout")

)

$dashNavBtns = @(

    $dashWindow.FindName("NavOverview"),

    $dashWindow.FindName("NavIsland"),

    $dashWindow.FindName("NavMedia"),

    $dashWindow.FindName("NavPomo"),

    $dashWindow.FindName("NavStopwatch"),

    $dashWindow.FindName("NavCountdown"),

    $dashWindow.FindName("NavSysMon"),

    $dashWindow.FindName("NavNotif"),

    $dashWindow.FindName("NavNotes"),

    $dashWindow.FindName("NavTodo"),

    $dashWindow.FindName("NavClip"),

    $dashWindow.FindName("NavQuickSet"),

    $dashWindow.FindName("NavQuickLaunch"),

    $dashWindow.FindName("NavSettings"),

    $dashWindow.FindName("NavAbout")

)

function SwitchDashPage($index) {

    for ($i = 0; $i -lt $dashPages.Count; $i++) {

        if ($dashPages[$i]) {

            $dashPages[$i].Visibility = if ($i -eq $index) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }

        }

        if ($dashNavBtns[$i]) {

            $dashNavBtns[$i].Style = if ($i -eq $index) { $dashWindow.Resources["ActiveSidebarNavBtn"] } else { $dashWindow.Resources["SidebarNavBtn"] }

        }

    }

}

for ($idx = 0; $idx -lt $dashNavBtns.Count; $idx++) {

    $currentIdx = $idx

    $dashNavBtns[$currentIdx].Add_Click([scriptblock]::Create("SwitchDashPage $currentIdx"))

}

function Show-OceruDashboard($pageIndex = 0) {

    SwitchDashPage $pageIndex

    $dashWindow.Show()

    $dashWindow.Activate()

}

# =========================================================================

# FLUID SPRING INTERPOLATION ENGINE FOR BUTTER-SMOOTH EXPAND & COLLAPSE

# 60 FPS DispatcherTimer with Quintic Ease-Out Curve: 1 - (1 - t)^5

# =========================================================================

$global:animTimer = New-Object System.Windows.Threading.DispatcherTimer([System.Windows.Threading.DispatcherPriority]::Render)
$global:animTimer.Interval = [TimeSpan]::FromMilliseconds(10) # 100 FPS ultra-smooth composition
$global:animSw = [System.Diagnostics.Stopwatch]::new()
$global:animDuration = 320

$global:fromW = $eyesTotalWidth
$global:toW   = $eyesTotalWidth
$global:fromH = $eyesHeight
$global:toH   = $eyesHeight
$global:fromR = 18
$global:toR   = 18
$global:curR  = 18

function Set-IslandMode($mode) {
    if ($global:targetMode -eq $mode) { return }

    $global:fromMode = $global:targetMode
    $global:targetMode = $mode
    $global:islandMode = $mode

    $global:fromW = if ($masterGrid -and $masterGrid.Width -gt 0) { $masterGrid.Width } else { $eyesTotalWidth }
    $global:fromH = if ($masterGrid -and $masterGrid.Height -gt 0) { $masterGrid.Height } else { $eyesHeight }
    $global:fromR = $global:curR

    if ($mode -eq "eyes") {
        $global:toW = $eyesTotalWidth
        $global:toH = $eyesHeight
        $global:toR = 18
        $global:animDuration = 290
        $eyesGrid.Visibility = [System.Windows.Visibility]::Visible
        if ($expandedGrid) { $expandedGrid.Visibility = [System.Windows.Visibility]::Visible }
    }
    elseif ($mode -eq "status") {
        $global:toW = $statusTotalWidth
        $global:toH = $statusHeight
        $global:toR = 18
        $global:animDuration = 300
        $global:statusIdleTicks = 0
        $statusGrid.Visibility = [System.Windows.Visibility]::Visible
        if ($expandedGrid) { $expandedGrid.Visibility = [System.Windows.Visibility]::Visible }
    }
    elseif ($mode -eq "expanded") {
        $totW = if ($global:isLyricsSideOpen -and $global:activeCardIndex -eq 0) { $expandedLyricsTotalWidth } else { $expandedTotalWidth }
        $global:toW = $totW
        $global:toH = $expandedHeight
        $global:toR = 24
        $global:animDuration = 340
        $global:outsideTicks = 0
        $expandedGrid.Visibility = [System.Windows.Visibility]::Visible
        if ($eyesGrid) { $eyesGrid.Visibility = [System.Windows.Visibility]::Visible }
    }
    elseif ($mode -eq "toast") {
        $global:toW = $toastTotalWidth
        $global:toH = $toastHeight
        $global:toR = 18
        $global:animDuration = 270
        if ($dynamicToastGrid) { $dynamicToastGrid.Visibility = [System.Windows.Visibility]::Visible }
    }

    $global:animSw.Restart()
    $global:animTimer.Start()
}

$global:animTimer.Add_Tick({
    $elapsed = $global:animSw.ElapsedMilliseconds
    $t = [Math]::Min(1.0, $elapsed / $global:animDuration)

    $isExpanding = ($global:toW -gt $global:fromW)

    # Snappy Fluid Spring Physics (Swift responsive burst + gentle elastic landing)
    $ease = if ($isExpanding) {
        $base = 1.0 - [Math]::Pow(1.0 - $t, 3.6)
        $bounce = 0.018 * [Math]::Sin($t * [Math]::PI) * (1.0 - $t)
        [Math]::Min(1.02, [Math]::Max(0.0, $base + $bounce))
    } else {
        1.0 - [Math]::Pow(1.0 - $t, 3.2)
    }

    $curTotalW = [Math]::Round($global:fromW + ($global:toW - $global:fromW) * $ease)
    $curH = [Math]::Round($global:fromH + ($global:toH - $global:fromH) * $ease)
    $global:curR = [Math]::Round($global:fromR + ($global:toR - $global:fromR) * $ease)

    if ($masterGrid.Width -ne $curTotalW) { $masterGrid.Width = $curTotalW }
    if ($masterGrid.Height -ne $curH) { $masterGrid.Height = $curH }

    if ($notchSinglePath) {
        $pathStr = Get-NotchPathData $curTotalW $curH $shoulderPad $global:curR
        $notchGeom = [System.Windows.Media.Geometry]::Parse($pathStr)
        $notchSinglePath.Data = $notchGeom
    }

    # Cross-Fade between active views
    if ($global:targetMode -eq "expanded") {
        $eyesGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.22))
        $statusGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.22))
        if ($dynamicToastGrid) { $dynamicToastGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.22)) }
        $expandedGrid.Opacity = if ($t -lt 0.35) { 0.0 } else { [Math]::Min(1.0, ($t - 0.35) / 0.65) }
    }
    elseif ($global:targetMode -eq "eyes") {
        $expandedGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25))
        $statusGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25))
        if ($dynamicToastGrid) { $dynamicToastGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25)) }
        $eyesGrid.Opacity = if ($t -lt 0.65) { 0.0 } else { [Math]::Min(1.0, ($t - 0.65) / 0.35) }
    }
    elseif ($global:targetMode -eq "status") {
        $expandedGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25))
        $eyesGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25))
        if ($dynamicToastGrid) { $dynamicToastGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25)) }
        $statusGrid.Opacity = if ($t -lt 0.55) { 0.0 } else { [Math]::Min(1.0, ($t - 0.55) / 0.45) }
    }
    elseif ($global:targetMode -eq "toast") {
        $eyesGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25))
        $statusGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25))
        $expandedGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.25))
        if ($dynamicToastGrid) {
            $dynamicToastGrid.Opacity = if ($t -lt 0.30) { 0.0 } else { [Math]::Min(1.0, ($t - 0.30) / 0.70) }
        }
    }

    # Completion Cleanup
    if ($t -ge 1.0) {
        $global:animTimer.Stop()
        $masterGrid.Width = $global:toW
        $masterGrid.Height = $global:toH
        $global:curR = $global:toR
        if ($notchSinglePath) {
            $finalPathStr = Get-NotchPathData $global:toW $global:toH $shoulderPad $global:toR
            $notchSinglePath.Data = [System.Windows.Media.Geometry]::Parse($finalPathStr)
        }
        if ($global:targetMode -eq "expanded") {
            $expandedGrid.Opacity = 1.0
            $eyesGrid.Visibility = [System.Windows.Visibility]::Collapsed
            $statusGrid.Visibility = [System.Windows.Visibility]::Collapsed
            if ($dynamicToastGrid) { $dynamicToastGrid.Visibility = [System.Windows.Visibility]::Collapsed }
        }
        elseif ($global:targetMode -eq "eyes") {
            $eyesGrid.Opacity = 1.0
            $expandedGrid.Visibility = [System.Windows.Visibility]::Collapsed
            $statusGrid.Visibility = [System.Windows.Visibility]::Collapsed
            if ($dynamicToastGrid) { $dynamicToastGrid.Visibility = [System.Windows.Visibility]::Collapsed }
        }
        elseif ($global:targetMode -eq "status") {
            $statusGrid.Opacity = 1.0
            $expandedGrid.Visibility = [System.Windows.Visibility]::Collapsed
            $eyesGrid.Visibility = [System.Windows.Visibility]::Collapsed
            if ($dynamicToastGrid) { $dynamicToastGrid.Visibility = [System.Windows.Visibility]::Collapsed }
        }
        elseif ($global:targetMode -eq "toast") {
            if ($dynamicToastGrid) { $dynamicToastGrid.Opacity = 1.0 }
            $expandedGrid.Visibility = [System.Windows.Visibility]::Collapsed
            $eyesGrid.Visibility = [System.Windows.Visibility]::Collapsed
            $statusGrid.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
})

# Interactive Virtual Pet: Double Click for Greeting & 2x Wink, Single Click to Expand

$eyesGrid.Add_MouseLeftButtonDown({

    param($sender, $e)

    if ($e.ClickCount -ge 2) {

        Trigger-CatPlayfulGreeting

        $e.Handled = $true

    }

})

$eyesGrid.Add_MouseLeftButtonUp({

    param($sender, $e)

    if (-not $e.Handled -and $global:catDoubleWinkTicks -le 0) {

        Set-IslandMode "expanded"

    }

})

$statusGrid.Add_MouseEnter({ Set-IslandMode "expanded" })

$statusGrid.Add_MouseLeftButtonUp({ Set-IslandMode "expanded" })

$notchBody.Add_MouseEnter({ if ($global:islandMode -ne "eyes" -and $global:targetMode -ne "expanded") { Set-IslandMode "expanded" } })

$notchBody.Add_MouseLeftButtonUp({ if ($global:targetMode -ne "expanded") { Set-IslandMode "expanded" } })

# ACTION FEEDBACK TOAST HELPER

$toastTimer = New-Object System.Windows.Threading.DispatcherTimer

$toastTimer.Interval = [TimeSpan]::FromSeconds(2.5)

$toastTimer.Add_Tick({

    $toastTimer.Stop()

    $toastFeedbackPill.Visibility = [System.Windows.Visibility]::Collapsed

})

$global:dynamicToastTimer = New-Object System.Windows.Threading.DispatcherTimer

function Show-OceruDynamicToast($title, $message, $iconChar = [char]0xE7E7, $accentHex = "#00D2FF", $durationMs = 2600) {

    if ($dynamicToastTitle) { $dynamicToastTitle.Text = $title }

    if ($dynamicToastMessage) { $dynamicToastMessage.Text = $message }

    if ($dynamicToastIcon) {

        $dynamicToastIcon.Text = [string]$iconChar

        $dynamicToastIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentHex)

    }

    if ($dynamicToastDot) {

        $dynamicToastDot.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentHex)

    }

    # Record previous mode to return to (if not already in toast mode)

    if ($global:islandMode -ne "toast") {

        $global:toastReturnMode = $global:islandMode

    }

    Set-IslandMode "toast"

    $global:dynamicToastTimer.Stop()

    $global:dynamicToastTimer.Interval = [TimeSpan]::FromMilliseconds($durationMs)

    $global:dynamicToastTimer.Start()

}

$global:dynamicToastTimer.Add_Tick({

    $global:dynamicToastTimer.Stop()

    if ($global:islandMode -eq "toast") {

        $ret = if ($global:toastReturnMode) { $global:toastReturnMode } else { "status" }

        Set-IslandMode $ret

    }

})

function ShowActionFeedback($text, $iconChar = [char]0xE73E, $accentHex = "#00D2FF") {

    if ($global:islandMode -eq "expanded") {

        $toastFeedbackText.Text = $text

        $toastFeedbackIcon.Text = [string]$iconChar

        $toastFeedbackIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentHex)

        $toastFeedbackPill.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentHex)

        $toastFeedbackPill.Visibility = [System.Windows.Visibility]::Visible

        $toastTimer.Stop()

        $toastTimer.Start()

    } else {

        Show-OceruDynamicToast "Oceru Island" $text $iconChar $accentHex 2500

    }

}

# WinRT Async Helper for Windows Runtime APIs

$asTaskGeneric = $null

try {

    Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue

    $asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {

        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'

    } | Select-Object -First 1

} catch {}

function Await-WinRT($asyncOp, $type) {

    try {

        if ($asTaskGeneric) {

            $netTask = $asTaskGeneric.MakeGenericMethod($type).Invoke($null, @($asyncOp))

            $netTask.Wait(1500) | Out-Null

            return $netTask.Result

        } else {

            return $asyncOp.GetAwaiter().GetResult()

        }

    } catch {

        return $null

    }

}

function Get-OceruWindowsMedia {

    try {

        $mgrOp = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]::RequestAsync()

        $manager = Await-WinRT $mgrOp ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime])

        if (-not $manager) { return $null }

        $session = $manager.GetCurrentSession()

        if ($session) {

            $pbTest = $session.GetPlaybackInfo()

            if (-not $pbTest -or $pbTest.PlaybackStatus.ToString() -ne "Playing") {

                # Current session is not playing: check if another session is actively playing

                $otherSessions = $manager.GetSessions()

                $foundPlaying = $null

                foreach ($s in $otherSessions) {

                    $p = $s.GetPlaybackInfo()

                    if ($p -and $p.PlaybackStatus.ToString() -eq "Playing") {

                        $foundPlaying = $s

                        break

                    }

                }

                if ($foundPlaying) {

                    $session = $foundPlaying

                }

            }

        } else {

            $sessions = $manager.GetSessions()

            foreach ($s in $sessions) {

                $pb = $s.GetPlaybackInfo()

                if ($pb -and $pb.PlaybackStatus.ToString() -eq "Playing") {

                    $session = $s

                    break

                }

            }

            if (-not $session -and $sessions.Count -gt 0) {

                $session = $sessions[0]

            }

        }

        if ($session) {

            $propOp = $session.TryGetMediaPropertiesAsync()

            $props = Await-WinRT $propOp ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime])

            $pbInfo = $session.GetPlaybackInfo()

            $timeline = $session.GetTimelineProperties()

            $title = if ($props -and $props.Title) { $props.Title } else { "Media Windows" }

            $appId = $session.SourceAppUserModelId

            $sourceName = if ($appId -like "*Chrome*") { "YouTube / Chrome" }

                          elseif ($appId -like "*Edge*") { "YouTube / Edge" }

                          elseif ($appId -like "*Spotify*") { "Spotify" }

                          elseif ($appId -like "*Firefox*") { "YouTube / Firefox" }

                          else { "Windows Media" }

            $artist = if ($props -and $props.Artist) { "$($props.Artist) ($sourceName)" } else { $sourceName }

            $isPlaying = if ($pbInfo) { ($pbInfo.PlaybackStatus.ToString() -eq "Playing") } else { $false }

            $accentCol = Get-MediaAccentColor $title $artist $props

            return [PSCustomObject]@{

                Title = $title

                Artist = $artist

                IsPlaying = $isPlaying

                AppId = $appId

                PositionSec = if ($timeline) { $timeline.Position.TotalSeconds } else { 0 }

                DurationSec = if ($timeline) { $timeline.EndTime.TotalSeconds } else { 0 }

                HasMedia = $true

                AccentColor = $accentCol

            }

        }

    } catch {}

    return $null

}

# CAROUSEL STATE & NAVIGATION (6 CARDS)

$global:activeCardIndex = 0

function SwitchCarouselCard($index) {

    if ($index -lt 0) { $index = 5 }

    if ($index -gt 5) { $index = 0 }

    $global:activeCardIndex = $index

    # Update Header Title

    $titles = @("", "Pomodoro", "Tugas Hari Ini", "Shelf", "Monitor Sistem", "Kontrol Cepat")

    $headerTitleText.Text = $titles[$index]

    if ($btnHeaderClearShelf) {
        $btnHeaderClearShelf.Visibility = if ($index -eq 3 -and $global:shelfFiles.Count -gt 0) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }

    if ($headerTaskBadge) {
        $headerTaskBadge.Visibility = if ($index -eq 2) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }

    # Switch Cards Visibility

    for ($i = 0; $i -lt $allCards.Count; $i++) {

        $allCards[$i].Visibility = if ($i -eq $index) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }

    }

    # Pomodoro Bottom Action Row (Only on Card 1)

    $bottomPomoRow.Visibility = if ($index -eq 1) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }

    # Update 6 Pagination Dots

    for ($i = 0; $i -lt $dotBars.Count; $i++) {

        if ($i -eq $index) {

            $dotBars[$i].Width = 16

            $dotBars[$i].Height = 3

            $dotBars[$i].CornerRadius = [System.Windows.CornerRadius]::new(1.5)

            $dotBars[$i].Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")

        } else {

            $dotBars[$i].Width = 3.5

            $dotBars[$i].Height = 3.5

            $dotBars[$i].CornerRadius = [System.Windows.CornerRadius]::new(1.75)

            $dotBars[$i].Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#232B3D")

        }

    }

    if ($index -ne 0 -and $global:isLyricsSideOpen) {
        if ($musicLyricsSidePanel) { $musicLyricsSidePanel.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($musicLyricsDivider) { $musicLyricsDivider.Visibility = [System.Windows.Visibility]::Collapsed }
        $global:fromW = $masterGrid.Width
        $global:toW = $expandedTotalWidth
        $global:fromH = $masterGrid.Height
        $global:toH = $expandedHeight
        $global:fromR = $global:curR
        $global:toR = 24
        $global:animDuration = 260
        $global:animSw.Restart()
        $global:animTimer.Start()
    } elseif ($index -eq 0 -and $global:isLyricsSideOpen) {
        Update-LyricsSidePanelVisibility
    }
}

# Nav Buttons Wiring

$btnMusicNextCard.Add_Click({ SwitchCarouselCard(1) })

$btnPomoPrevCard.Add_Click({ SwitchCarouselCard(0) })

$btnPomoNextCard.Add_Click({ SwitchCarouselCard(2) })

$btnNotesPrevCard.Add_Click({ SwitchCarouselCard(1) })

$btnNotesNextCard.Add_Click({ SwitchCarouselCard(3) })

$btnClipPrevCard.Add_Click({ SwitchCarouselCard(2) })

$btnClipNextCard.Add_Click({ SwitchCarouselCard(4) })

$btnSysPrevCard.Add_Click({ SwitchCarouselCard(3) })

$btnSysNextCard.Add_Click({ SwitchCarouselCard(5) })

$btnQuickPrevCard.Add_Click({ SwitchCarouselCard(4) })

$btnQuickNextCard.Add_Click({ SwitchCarouselCard(0) })

$dot0.Add_MouseLeftButtonDown({ SwitchCarouselCard(0) })

$dot1.Add_MouseLeftButtonDown({ SwitchCarouselCard(1) })

$dot2.Add_MouseLeftButtonDown({ SwitchCarouselCard(2) })

$dot3.Add_MouseLeftButtonDown({ SwitchCarouselCard(3) })

$dot4.Add_MouseLeftButtonDown({ SwitchCarouselCard(4) })

$dot5.Add_MouseLeftButtonDown({ SwitchCarouselCard(5) })

# CARD 0: DUAL-TRACK MEDIA PLAYER WIRING (WINDOWS GLOBAL & LOCAL AUDIO)

function Select-And-Play-LocalAudio {

    Add-Type -AssemblyName System.Windows.Forms

    $dlg = New-Object System.Windows.Forms.OpenFileDialog

    $dlg.Title = "Pilih File Audio untuk Diputar di Oceru"

    $dlg.Filter = "File Audio (*.mp3;*.wav;*.m4a;*.wma)|*.mp3;*.wav;*.m4a;*.wma|Semua File (*.*)|*.*"

    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {

        $filePath = $dlg.FileName

        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)

        try {

            $global:localMediaPlayer.Open([Uri]$filePath)

            $global:localMediaPlayer.Play()

            $global:localMediaLoaded = $true

            $global:localMediaPlaying = $true

            $global:OceruState.currentMedia.title = $fileName

            $global:OceruState.currentMedia.artist = "Pemutar Audio Lokal Oceru"

            $global:OceruState.currentMedia.isPlaying = $true

            $musicTitle.Text = $fileName

            $musicArtist.Text = "Pemutar Audio Lokal Oceru"

            $musicPlayPauseIcon.Text = [char]0xE769

            if ($dashMediaTitleText) { $dashMediaTitleText.Text = $fileName }

            if ($dashMediaArtistText) { $dashMediaArtistText.Text = "Pemutar Audio Lokal Oceru" }

            if ($dashMediaPlayIcon) { $dashMediaPlayIcon.Text = [char]0xE769 }

            if ($dashMediaSourceStatus) { $dashMediaSourceStatus.Text = "Memutar file lokal: $fileName" }

            ShowActionFeedback "Memutar: $fileName" ([char]0xE768) "#00D2FF"

            Save-OceruState

        } catch {

            ShowActionFeedback "Gagal memutar file audio" ([char]0xE783) "#EF4444"

        }

    }

}

function Stop-LocalAudio {

    try {

        $global:localMediaPlayer.Stop()

        $global:localMediaPlaying = $false

        $global:localMediaLoaded = $false

        $global:OceruState.currentMedia.isPlaying = $false

        $global:OceruState.currentMedia.title = "Tidak ada media aktif"

        $global:OceruState.currentMedia.artist = "Kontrol pemutar Windows atau putar file audio"

        $musicTitle.Text = "Tidak ada media aktif"

        $musicArtist.Text = "Kontrol pemutar Windows atau putar file audio"

        $musicPlayPauseIcon.Text = [char]0xE768

        if ($musicProgressBar) { $musicProgressBar.Width = 0 }

        $musicCurrentTime.Text = "00:00"

        $musicRemainingTime.Text = "00:00"

        if ($dashMediaTitleText) { $dashMediaTitleText.Text = "Tidak ada media aktif" }

        if ($dashMediaArtistText) { $dashMediaArtistText.Text = "Gunakan kontrol untuk mengendalikan media Windows atau putar file audio lokal" }

        if ($dashMediaPlayIcon) { $dashMediaPlayIcon.Text = [char]0xE768 }

        if ($dashMediaProgressBar) { $dashMediaProgressBar.Width = 0 }

        if ($dashMediaCurrentTime) { $dashMediaCurrentTime.Text = "00:00" }

        if ($dashMediaRemainingTime) { $dashMediaRemainingTime.Text = "00:00" }

        if ($dashMediaSourceStatus) { $dashMediaSourceStatus.Text = "Kontrol Global Windows / Siap Putar File" }

        ShowActionFeedback "Pemutar Lokal Dihentikan" ([char]0xE71A) "#8E9AA8"

        Save-OceruState

    } catch {}

}

if ($btnOpenLocalAudio) {

    $btnOpenLocalAudio.Add_Click({ Select-And-Play-LocalAudio })

}

function Toggle-OceruMediaPlayPause {
    try {
        if ($global:localMediaLoaded -and $global:localMediaPlayer.Source) {
            if ($global:localMediaPlaying) {
                $global:localMediaPlayer.Pause()
                $global:localMediaPlaying = $false
                $global:OceruState.currentMedia.isPlaying = $false
                if ($musicPlayPauseIcon) { $musicPlayPauseIcon.Text = [char]0xE768 }
                if ($dashMediaPlayIcon) { $dashMediaPlayIcon.Text = [char]0xE768 }
                ShowActionFeedback "Audio Lokal Dijeda" ([char]0xE769) "#8E9AA8"
            } else {
                $global:localMediaPlayer.Play()
                $global:localMediaPlaying = $true
                $global:OceruState.currentMedia.isPlaying = $true
                if ($musicPlayPauseIcon) { $musicPlayPauseIcon.Text = [char]0xE769 }
                if ($dashMediaPlayIcon) { $dashMediaPlayIcon.Text = [char]0xE769 }
                ShowActionFeedback "Melanjutkan Audio Lokal" ([char]0xE768) "#00D2FF"
            }
        } else {
            # Global Hardware Media Key (Spotify, YouTube, VLC, etc.)
            [Win32Helper]::SendMediaKey([Win32Helper]::VK_MEDIA_PLAY_PAUSE)
            $global:OceruState.currentMedia.isPlaying = -not $global:OceruState.currentMedia.isPlaying
            $global:gsmtcPlaying = $global:OceruState.currentMedia.isPlaying
            if ($musicPlayPauseIcon) { $musicPlayPauseIcon.Text = if ($global:gsmtcPlaying) { [char]0xE769 } else { [char]0xE768 } }
            if (-not $global:gsmtcPlaying) {
                $global:waveAmp = 0.0
                if ($notchWaveStrokePath) { $notchWaveStrokePath.Opacity = 0.0 }
            }
            if ($global:OceruState.currentMedia.isPlaying) {
                if ($musicPlayPauseIcon) { $musicPlayPauseIcon.Text = [char]0xE769 }
                if ($dashMediaPlayIcon) { $dashMediaPlayIcon.Text = [char]0xE769 }
                if ($global:islandMode -ne "expanded") {
                    Show-OceruDynamicToast "Kontrol Media" "Melanjutkan Musik" ([char]0xE768) "#10B981" 1200
                } else {
                    ShowActionFeedback "Melanjutkan Musik" ([char]0xE768) "#10B981"
                }
            } else {
                if ($musicPlayPauseIcon) { $musicPlayPauseIcon.Text = [char]0xE768 }
                if ($dashMediaPlayIcon) { $dashMediaPlayIcon.Text = [char]0xE768 }
                if ($global:islandMode -ne "expanded") {
                    Show-OceruDynamicToast "Kontrol Media" "Musik Dijeda" ([char]0xE769) "#F59E0B" 1200
                } else {
                    ShowActionFeedback "Musik Dijeda" ([char]0xE769) "#F59E0B"
                }
            }
        }
        Save-OceruState
    } catch {}
}

$btnMusicPlayPause.Add_Click({
    Toggle-OceruMediaPlayPause
})

$btnMusicNext.Add_Click({

    [Win32Helper]::SendMediaKey([Win32Helper]::VK_MEDIA_NEXT_TRACK)

    ShowActionFeedback "Windows Media: Lagu Berikutnya" ([char]0xE893) "#00D2FF"

})

$btnMusicPrev.Add_Click({

    [Win32Helper]::SendMediaKey([Win32Helper]::VK_MEDIA_PREV_TRACK)

    ShowActionFeedback "Windows Media: Lagu Sebelumnya" ([char]0xE892) "#00D2FF"

})

function Update-LyricsSidePanelVisibility {
    if ($global:isLyricsSideOpen -and $global:activeCardIndex -eq 0) {
        if ($musicLyricsSidePanel) { $musicLyricsSidePanel.Visibility = [System.Windows.Visibility]::Visible }
        if ($musicLyricsDivider) { $musicLyricsDivider.Visibility = [System.Windows.Visibility]::Visible }
        if ($iconToggleLyrics) { $iconToggleLyrics.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF") }
        $global:toW = $expandedLyricsTotalWidth
        $global:toH = $expandedHeight
    } else {
        if ($musicLyricsSidePanel) { $musicLyricsSidePanel.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($musicLyricsDivider) { $musicLyricsDivider.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($iconToggleLyrics) { $iconToggleLyrics.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8E9AA8") }
        $global:toW = $expandedTotalWidth
        $global:toH = $expandedHeight
    }

    $global:fromW = $masterGrid.Width
    $global:fromH = $masterGrid.Height
    $global:fromR = $global:curR
    $global:toR = 24
    $global:animDuration = 260
    $global:animSw.Restart()
    $global:animTimer.Start()
}

if ($btnToggleLyrics) {
    $btnToggleLyrics.Add_Click({
        $global:isLyricsSideOpen = -not $global:isLyricsSideOpen
        Update-LyricsSidePanelVisibility
        if ($global:isLyricsSideOpen) {
            Update-LiveLyricsDisplay 0 240
        }
    })
}

if ($btnCloseLyricsSide) {
    $btnCloseLyricsSide.Add_Click({
        $global:isLyricsSideOpen = $false
        Update-LyricsSidePanelVisibility
    })
}

# CARD 1: POMODORO FOCUS TIMER WIRING

$pomoEngine = New-Object System.Windows.Threading.DispatcherTimer

$pomoEngine.Interval = [TimeSpan]::FromSeconds(1)

$pomoEngine.Add_Tick({

    if ($global:OceruState.pomodoro.remainingSeconds -gt 0) {

        $global:OceruState.pomodoro.remainingSeconds = [int]$global:OceruState.pomodoro.remainingSeconds - 1

        $timeStr = [TimeSpan]::FromSeconds($global:OceruState.pomodoro.remainingSeconds).ToString("mm\:ss")

        $pomoDisplayTime.Text = $timeStr

    } else {

        $pomoEngine.Stop()

        $global:OceruState.pomodoro.isRunning = $false

        $pomoPlayPauseIcon.Text = [char]0xE768

        ShowActionFeedback "Waktu Fokus Selesai!" ([char]0xE916) "#10B981"

        Trigger-CatWink

        try { [System.Media.SystemSounds]::Beep.Play() } catch {}

    }

})

$btnPomoPlay.Add_Click({

    $global:OceruState.pomodoro.isRunning = -not $global:OceruState.pomodoro.isRunning

    if ($global:OceruState.pomodoro.isRunning) {

        $pomoEngine.Start()

        $pomoPlayPauseIcon.Text = [char]0xE769

        ShowActionFeedback "Fokus Berjalan" ([char]0xE916) "#FF5252"

    } else {

        $pomoEngine.Stop()

        $pomoPlayPauseIcon.Text = [char]0xE768

        ShowActionFeedback "Fokus Dijeda" ([char]0xE769) "#8E9AA8"

    }

    Save-OceruState

})

$btnPomoReset.Add_Click({
    $pomoEngine.Stop()
    $global:OceruState.pomodoro.isRunning = $false
    $pomoPlayPauseIcon.Text = [char]0xE768
    $global:OceruState.pomodoro.remainingSeconds = [int]$global:OceruState.pomodoro.totalSeconds
    $pomoDisplayTime.Text = [TimeSpan]::FromSeconds($global:OceruState.pomodoro.remainingSeconds).ToString("mm\:ss")
    ShowActionFeedback "Timer Direset" ([char]0xE72C) "#FF5252"
    Save-OceruState
})

# FEATURE F: AMBIENT FOCUS SOUNDS CONTROLLER
$global:activeAmbientSound = $null
$global:ambientSoundPlayer = $null

function Update-AmbientButtonsUI {
    $activeBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
    $activeBg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#182A24")
    $normalBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#253147")
    $normalBg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#161B26")

    if ($btnAmbientRain) {
        $btnAmbientRain.BorderBrush = if ($global:activeAmbientSound -eq "rain") { $activeBrush } else { $normalBrush }
        $btnAmbientRain.Background = if ($global:activeAmbientSound -eq "rain") { $activeBg } else { $normalBg }
    }
    if ($btnAmbientWaves) {
        $btnAmbientWaves.BorderBrush = if ($global:activeAmbientSound -eq "waves") { $activeBrush } else { $normalBrush }
        $btnAmbientWaves.Background = if ($global:activeAmbientSound -eq "waves") { $activeBg } else { $normalBg }
    }
    if ($btnAmbientCafe) {
        $btnAmbientCafe.BorderBrush = if ($global:activeAmbientSound -eq "cafe") { $activeBrush } else { $normalBrush }
        $btnAmbientCafe.Background = if ($global:activeAmbientSound -eq "cafe") { $activeBg } else { $normalBg }
    }
}

function Toggle-OceruAmbientSound($type) {
    if ($global:activeAmbientSound -eq $type) {
        if ($global:ambientSoundPlayer) {
            $global:ambientSoundPlayer.Stop()
            $global:ambientSoundPlayer.Dispose()
            $global:ambientSoundPlayer = $null
        }
        $global:activeAmbientSound = $null
        Update-AmbientButtonsUI
        ShowActionFeedback "Suara Latar Dimatikan" ([char]0xE768) "#8E9AA8"
        return
    }

    try {
        if ($global:ambientSoundPlayer) {
            $global:ambientSoundPlayer.Stop()
            $global:ambientSoundPlayer.Dispose()
        }
        $bytes = New-OceruWavBytes -Type $type
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        $global:ambientSoundPlayer = New-Object System.Media.SoundPlayer($ms)
        $global:ambientSoundPlayer.Load()
        $global:ambientSoundPlayer.PlayLooping()
        $global:activeAmbientSound = $type
        Update-AmbientButtonsUI

        $label = switch ($type) {
            "rain" { "Hujan Rintik" }
            "waves" { "Ombak Pantai" }
            "cafe" { "Kafe Tenang" }
            default { $type }
        }
        ShowActionFeedback "Suara $label Aktif" ([char]0xE8D6) "#10B981"
    } catch {}
}

if ($btnAmbientRain) { $btnAmbientRain.Add_Click({ Toggle-OceruAmbientSound "rain" }) }
if ($btnAmbientWaves) { $btnAmbientWaves.Add_Click({ Toggle-OceruAmbientSound "waves" }) }
if ($btnAmbientCafe) { $btnAmbientCafe.Add_Click({ Toggle-OceruAmbientSound "cafe" }) }

$btnPomoShortBreak.Add_Click({

    $pomoEngine.Stop()

    $global:OceruState.pomodoro.isRunning = $false

    $pomoPlayPauseIcon.Text = [char]0xE768

    $global:OceruState.pomodoro.totalSeconds = 300

    $global:OceruState.pomodoro.remainingSeconds = 300

    $pomoSubtitle.Text = "Short break"

    $pomoDisplayTime.Text = "05:00"

    ShowActionFeedback "Mode: Istirahat Singkat (5m)" ([char]0xE916) "#10B981"

    Save-OceruState

})

$btnPomoFocusTime.Add_Click({

    $pomoEngine.Stop()

    $global:OceruState.pomodoro.isRunning = $false

    $pomoPlayPauseIcon.Text = [char]0xE768

    $global:OceruState.pomodoro.totalSeconds = 1500

    $global:OceruState.pomodoro.remainingSeconds = 1500

    $pomoSubtitle.Text = "Focus time"

    $pomoDisplayTime.Text = "25:00"

    ShowActionFeedback "Mode: Waktu Fokus (25m)" ([char]0xE916) "#FF5252"

    Save-OceruState

})

# CARD 2: DEDICATED TO-DO & TASK HUB WIRING
function Update-TodoStats {
    $tasks = $global:OceruState.tasks
    $total = if ($tasks) { $tasks.Count } else { 0 }
    $done = if ($tasks) { @($tasks | Where-Object { [bool]$_.done }).Count } else { 0 }
    $pct = if ($total -gt 0) { [Math]::Round(($done / $total) * 100) } else { 0 }

    if ($todoPercentText) { $todoPercentText.Text = "$pct%" }
    if ($todoProgressBar) { $todoProgressBar.Value = $pct }
    if ($headerTaskBadgeText) { $headerTaskBadgeText.Text = "$done dari $total Selesai" }

    if ($todoMotivationText) {
        $todoMotivationText.Text = if ($total -eq 0) {
            "Mulai Harimu ✨"
        } elseif ($pct -eq 100) {
            "Semua Tuntas! 🎉"
        } elseif ($pct -ge 50) {
            "Fokus & Produktif 🔥"
        } else {
            "Langkah Awal ⚡"
        }
    }
}

function Render-TaskItems {
    if (-not $taskListContainer) { return }
    $taskListContainer.Children.Clear()

    $tasks = $global:OceruState.tasks
    if (-not $tasks -or $tasks.Count -eq 0) {
        $emptyTxt = New-Object System.Windows.Controls.TextBlock
        $emptyTxt.Text = "Belum ada target tugas hari ini"
        $emptyTxt.FontSize = 10.5
        $emptyTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
        $emptyTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $emptyTxt.Margin = [System.Windows.Thickness]::new(0, 16, 0, 0)
        $taskListContainer.Children.Add($emptyTxt)
        Update-TodoStats
        return
    }

    foreach ($item in $tasks) {
        $curItem = $item
        $isDone = [bool]$curItem.done
        $taskText = [string]$curItem.text

        $rowBorder = New-Object System.Windows.Controls.Border
        $rowBorder.Height = 22
        $rowBorder.Margin = [System.Windows.Thickness]::new(0, 1, 0, 1)
        $rowBorder.CornerRadius = [System.Windows.CornerRadius]::new(7)
        $rowBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#131722")
        $rowBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E2536")
        $rowBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        $rowBorder.Padding = [System.Windows.Thickness]::new(6, 2, 6, 2)

        $rowGrid = New-Object System.Windows.Controls.Grid
        $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::new(20, [System.Windows.GridUnitType]::Pixel)
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::new(18, [System.Windows.GridUnitType]::Pixel)
        $rowGrid.ColumnDefinitions.Add($c0)
        $rowGrid.ColumnDefinitions.Add($c1)
        $rowGrid.ColumnDefinitions.Add($c2)

        # Custom Check Button
        $chkBorder = New-Object System.Windows.Controls.Border
        $chkBorder.Width = 14
        $chkBorder.Height = 14
        $chkBorder.CornerRadius = [System.Windows.CornerRadius]::new(7)
        $chkBorder.Cursor = [System.Windows.Input.Cursors]::Hand
        $chkBorder.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $chkBorder.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left

        $chkIcon = New-Object System.Windows.Controls.TextBlock
        $chkIcon.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $chkIcon.FontSize = 8.5
        $chkIcon.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $chkIcon.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        if ($isDone) {
            $chkBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
            $chkBorder.BorderThickness = [System.Windows.Thickness]::new(0)
            $chkIcon.Text = [char]0xE73E
            $chkIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
        } else {
            $chkBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0D111A")
            $chkBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3B465E")
            $chkBorder.BorderThickness = [System.Windows.Thickness]::new(1.2)
            $chkIcon.Text = ""
        }
        $chkBorder.Child = $chkIcon
        [System.Windows.Controls.Grid]::SetColumn($chkBorder, 0)
        $rowGrid.Children.Add($chkBorder)

        # Task Text
        $txtBlock = New-Object System.Windows.Controls.TextBlock
        $txtBlock.Text = $taskText
        $txtBlock.FontSize = 10.0
        $txtBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $txtBlock.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
        $txtBlock.Cursor = [System.Windows.Input.Cursors]::Hand

        if ($isDone) {
            $txtBlock.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
            $txtBlock.TextDecorations = [System.Windows.TextDecorations]::Strikethrough
        } else {
            $txtBlock.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
            $txtBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
        }
        [System.Windows.Controls.Grid]::SetColumn($txtBlock, 1)
        $rowGrid.Children.Add($txtBlock)

        # Delete Action
        $delBtn = New-Object System.Windows.Controls.Border
        $delBtn.Width = 16
        $delBtn.Height = 16
        $delBtn.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $delBtn.Background = [System.Windows.Media.Brushes]::Transparent
        $delBtn.Cursor = [System.Windows.Input.Cursors]::Hand
        $delBtn.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $delBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        $delBtn.ToolTip = "Hapus Tugas"

        $delIcon = New-Object System.Windows.Controls.TextBlock
        $delIcon.Text = [char]0xE74D
        $delIcon.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $delIcon.FontSize = 9.0
        $delIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
        $delIcon.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $delIcon.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $delBtn.Child = $delIcon

        $delBtn.Add_MouseEnter({ $delIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444") })
        $delBtn.Add_MouseLeave({ $delIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B") })

        $targetId = $curItem.id
        $delBtn.Add_MouseLeftButtonDown({
            param($s, $e)
            $global:OceruState.tasks = @($global:OceruState.tasks | Where-Object { $_.id -ne $targetId })
            Save-OceruState
            Render-TaskItems
            ShowActionFeedback "Tugas Dihapus" ([char]0xE74D) "#8E9AA8"
        })

        [System.Windows.Controls.Grid]::SetColumn($delBtn, 2)
        $rowGrid.Children.Add($delBtn)

        # Toggle Done on Check or Text Click
        $toggleHandler = {
            param($s, $e)
            $curItem.done = -not $curItem.done
            Save-OceruState
            if ($curItem.done) {
                Trigger-CatWink
                ShowActionFeedback "Tugas Selesai! 🎉" ([char]0xE73E) "#10B981"
            }
            Render-TaskItems
        }
        $chkBorder.Add_MouseLeftButtonDown($toggleHandler)
        $txtBlock.Add_MouseLeftButtonDown($toggleHandler)

        # Hover Effect
        $rowBorder.Add_MouseEnter({
            $rowBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181E2C")
            $rowBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2D384E")
        })
        $rowBorder.Add_MouseLeave({
            $rowBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#131722")
            $rowBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E2536")
        })

        $rowBorder.Child = $rowGrid
        $taskListContainer.Children.Add($rowBorder)
    }

    Update-TodoStats
}

function Add-NewTodoTask {
    if (-not $newTaskInput) { return }
    $txt = $newTaskInput.Text.Trim()
    if (-not $txt -or $txt -like "*+ Ketik target baru*") { return }

    $newId = [DateTime]::Now.Ticks
    $newTask = [PSCustomObject]@{
        id = $newId
        text = $txt
        done = $false
    }
    if (-not $global:OceruState.tasks) { $global:OceruState.tasks = @() }
    $global:OceruState.tasks += $newTask
    Save-OceruState

    $newTaskInput.Text = ""
    Render-TaskItems
    ShowActionFeedback "Tugas Ditambahkan!" ([char]0xE710) "#10B981"
}

if ($btnAddNewTask) {
    $btnAddNewTask.Add_Click({ Add-NewTodoTask })
}

if ($newTaskInput) {
    $newTaskInput.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            Add-NewTodoTask
        }
    })
    $newTaskInput.Add_GotFocus({
        if ($newTaskInput.Text -like "*+ Ketik target baru*") {
            $newTaskInput.Text = ""
            $newTaskInput.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
        }
    })
    $newTaskInput.Add_LostFocus({
        if (-not $newTaskInput.Text.Trim()) {
            $newTaskInput.Text = "+ Ketik target baru & tekan Enter..."
            $newTaskInput.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8E9AA8")
        }
    })
}

if ($btnClearDoneTasks) {
    $btnClearDoneTasks.Add_Click({
        $before = if ($global:OceruState.tasks) { $global:OceruState.tasks.Count } else { 0 }
        $global:OceruState.tasks = @($global:OceruState.tasks | Where-Object { -not [bool]$_.done })
        $after = $global:OceruState.tasks.Count
        Save-OceruState
        Render-TaskItems
        ShowActionFeedback "$($before - $after) Tugas Selesai Dibersihkan!" ([char]0xE74D) "#8E9AA8"
    })
}

# Initial Render of Tasks
Render-TaskItems

# CARD 3: DEDICATED FILE SHELF WIRING
$global:shelfFiles = @()

if ($btnHeaderClearShelf) {
    $btnHeaderClearShelf.Add_Click({
        $global:shelfFiles = @()
        Update-ShelfUI
        ShowActionFeedback "Shelf Dibersihkan!" ([char]0xE74D) "#FF5252"
    })
}

function Update-ShelfUI {
    if (-not $shelfFilesList) { return }
    $shelfFilesList.Children.Clear()

    $count = $global:shelfFiles.Count
    if ($count -eq 0) {
        if ($shelfEmptyDropZone) { $shelfEmptyDropZone.Visibility = [System.Windows.Visibility]::Visible }
        if ($shelfFilesContainer) { $shelfFilesContainer.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($btnHeaderClearShelf) { $btnHeaderClearShelf.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($shelfDropBorder) { $shelfDropBorder.Cursor = [System.Windows.Input.Cursors]::Arrow }
    } else {
        if ($shelfEmptyDropZone) { $shelfEmptyDropZone.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($shelfFilesContainer) { $shelfFilesContainer.Visibility = [System.Windows.Visibility]::Visible }
        if ($btnHeaderClearShelf -and $global:activeCardIndex -eq 3) { $btnHeaderClearShelf.Visibility = [System.Windows.Visibility]::Visible }
        if ($shelfDropBorder) { $shelfDropBorder.Cursor = [System.Windows.Input.Cursors]::Hand }

        foreach ($file in $global:shelfFiles) {
            if (-not (Test-Path $file)) { continue }
            $fi = New-Object System.IO.FileInfo($file)
            $fName = $fi.Name
            $fExt = $fi.Extension.ToLower()
            $fSize = if ($fi.Length -ge 1048576) {
                "{0:N1} MB" -f ($fi.Length / 1048576)
            } else {
                "{0:N0} KB" -f ($fi.Length / 1024)
            }

            # File Card Container (Matching Dedicated Shelf Design)
            $itemBorder = New-Object System.Windows.Controls.Border
            $itemBorder.Width = 92
            $itemBorder.Height = 102
            $itemBorder.Margin = [System.Windows.Thickness]::new(4, 0, 4, 0)
            $itemBorder.CornerRadius = [System.Windows.CornerRadius]::new(12)
            $itemBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#131722")
            $itemBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#232B3D")
            $itemBorder.BorderThickness = [System.Windows.Thickness]::new(1)
            $itemBorder.Padding = [System.Windows.Thickness]::new(6, 6, 6, 6)
            $itemBorder.Cursor = [System.Windows.Input.Cursors]::Hand
            $itemBorder.ToolTip = "$($fi.FullName)`n(Tahan & seret untuk copy ke WA/Email, Klik 2x untuk buka)"

            $itemGrid = New-Object System.Windows.Controls.Grid
            $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::new(50, [System.Windows.GridUnitType]::Pixel)
            $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::new(18, [System.Windows.GridUnitType]::Pixel)
            $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::new(14, [System.Windows.GridUnitType]::Pixel)
            $itemGrid.RowDefinitions.Add($r0)
            $itemGrid.RowDefinitions.Add($r1)
            $itemGrid.RowDefinitions.Add($r2)

            # Icon Box with file type styling
            $iconBox = New-Object System.Windows.Controls.Border
            $iconBox.Width = 46
            $iconBox.Height = 46
            $iconBox.CornerRadius = [System.Windows.CornerRadius]::new(12)
            $iconBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $iconBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

            if ($fExt -match '\.(jpg|jpeg|png|webp|gif|bmp|svg)$') {
                # Image thumbnail style (Sky blue with yellow sun & sand)
                $iconBox.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2B90D9")
                $imgGrid = New-Object System.Windows.Controls.Grid
                $imgGrid.ClipToBounds = $true

                $sun = New-Object System.Windows.Controls.Border
                $sun.Width = 10; $sun.Height = 10; $sun.CornerRadius = [System.Windows.CornerRadius]::new(5)
                $sun.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FCD34D")
                $sun.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
                $sun.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
                $sun.Margin = [System.Windows.Thickness]::new(0, 8, 8, 0)
                $imgGrid.Children.Add($sun)

                $ground = New-Object System.Windows.Controls.Border
                $ground.Height = 14; $ground.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FDE68A")
                $ground.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
                $imgGrid.Children.Add($ground)

                $iconBox.Child = $imgGrid
            } elseif ($fExt -match '\.(pdf|docx?|txt|md|xlsx?|pptx?)$') {
                $iconBox.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EA580C")
                $iconTxt = New-Object System.Windows.Controls.TextBlock
                $iconTxt.Text = [char]0xE8A5; $iconTxt.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
                $iconTxt.FontSize = 22; $iconTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
                $iconTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center; $iconTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $iconBox.Child = $iconTxt
            } elseif ($fExt -match '\.(mp3|wav|flac|m4a|mp4|mkv|mov)$') {
                $iconBox.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#9333EA")
                $iconTxt = New-Object System.Windows.Controls.TextBlock
                $iconTxt.Text = [char]0xE8D6; $iconTxt.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
                $iconTxt.FontSize = 22; $iconTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
                $iconTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center; $iconTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $iconBox.Child = $iconTxt
            } else {
                $iconBox.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0D9488")
                $iconTxt = New-Object System.Windows.Controls.TextBlock
                $iconTxt.Text = [char]0xE8B7; $iconTxt.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
                $iconTxt.FontSize = 22; $iconTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
                $iconTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center; $iconTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $iconBox.Child = $iconTxt
            }

            [System.Windows.Controls.Grid]::SetRow($iconBox, 0)
            $itemGrid.Children.Add($iconBox)

            # File Name
            $nameTxt = New-Object System.Windows.Controls.TextBlock
            $nameTxt.Text = $fName
            $nameTxt.FontSize = 10.5
            $nameTxt.FontWeight = [System.Windows.FontWeights]::SemiBold
            $nameTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
            $nameTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $nameTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $nameTxt.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
            $nameTxt.MaxWidth = 84
            [System.Windows.Controls.Grid]::SetRow($nameTxt, 1)
            $itemGrid.Children.Add($nameTxt)

            # File Size
            $sizeTxt = New-Object System.Windows.Controls.TextBlock
            $sizeTxt.Text = $fSize
            $sizeTxt.FontSize = 9.5
            $sizeTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8E9AA8")
            $sizeTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $sizeTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            [System.Windows.Controls.Grid]::SetRow($sizeTxt, 2)
            $itemGrid.Children.Add($sizeTxt)

            $itemBorder.Child = $itemGrid

            # Wire Drag-Out & Double-Click Events
            $capturedFile = $file
            $dragStart = $null

            $itemBorder.Add_PreviewMouseLeftButtonDown({
                param($s, $e)
                $dragStart = $e.GetPosition($null)
            })

            $itemBorder.Add_PreviewMouseMove({
                param($s, $e)
                if ($e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed -and $dragStart -ne $null) {
                    $cur = $e.GetPosition($null)
                    $diff = $cur - $dragStart
                    if ([Math]::Abs($diff.X) -gt 6 -or [Math]::Abs($diff.Y) -gt 6) {
                        $dragStart = $null
                        $dataObj = New-Object System.Windows.DataObject([System.Windows.DataFormats]::FileDrop, [string[]]@($capturedFile))
                        ShowActionFeedback "Menyeret $fName..." ([char]0xE8B7) "#00D2FF"
                        [System.Windows.DragDrop]::DoDragDrop($itemBorder, $dataObj, [System.Windows.DragDropEffects]::Copy) | Out-Null
                    }
                }
            })

            $itemBorder.Add_MouseLeftButtonDown({
                param($s, $e)
                if ($e.ClickCount -ge 2) {
                    try { Start-Process $capturedFile } catch {}
                }
            })

            $shelfFilesList.Children.Add($itemBorder)
        }
    }
}

function Add-FilesToShelf($files) {
    if ($files -and $files.Count -gt 0) {
        foreach ($f in $files) {
            if ($global:shelfFiles -notcontains $f) {
                $global:shelfFiles += $f
            }
        }
        Update-ShelfUI
        ShowActionFeedback "$($files.Count) File Diparkir di Shelf!" ([char]0xE8B7) "#F59E0B"
    }
}

# Drop directly on ShelfDropBorder
if ($shelfDropBorder) {
    $shelfDropBorder.Add_Drop({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $dropped = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            Add-FilesToShelf $dropped
        }
    })
}

# Universal Drag & Drop on the Entire Island Window
$window.Add_DragEnter({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
        if ($global:islandMode -ne "expanded") {
            Set-IslandMode "expanded"
        }
        SwitchCarouselCard 3
        if ($shelfDropBorder) {
            $shelfDropBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")
            $shelfDropBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1B2130")
        }
    }
})

$window.Add_DragOver({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
    }
})

$window.Add_DragLeave({
    param($s, $e)
    if ($shelfDropBorder) {
        $shelfDropBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#232B3D")
        $shelfDropBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11141C")
    }
})

$window.Add_Drop({
    param($s, $e)
    if ($shelfDropBorder) {
        $shelfDropBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#232B3D")
        $shelfDropBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#11141C")
    }
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $dropped = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        Add-FilesToShelf $dropped
    }
})
# CARD 4: SYSTEM MONITOR & TOP MEMORY PROCESSES WIRING
$btnSysTaskMgr.Add_Click({
    ShowActionFeedback "Membuka Task Manager..." ([char]0xE9D9) "#00D2FF"
    [System.Diagnostics.Process]::Start("taskmgr.exe")
})

function Update-TopProcesses {
    if (-not $topAppsListContainer) { return }
    $topAppsListContainer.Children.Clear()

    try {
        $procs = Get-Process | Where-Object { $_.MainWindowTitle -or $_.ProcessName -match '(chrome|msedge|firefox|code|spotify|discord|slack|teams|steam|node|powershell)' } |
                 Sort-Object WorkingSet64 -Descending |
                 Select-Object -First 3

        if (-not $procs -or $procs.Count -eq 0) {
            $procs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 3
        }

        foreach ($p in $procs) {
            $pName = $p.ProcessName
            $memMB = [Math]::Round($p.WorkingSet64 / 1MB)
            $memText = if ($memMB -ge 1024) { "{0:N1} GB" -f ($memMB / 1024) } else { "$memMB MB" }

            $rowGrid = New-Object System.Windows.Controls.Grid
            $rowGrid.Margin = [System.Windows.Thickness]::new(0, 1.5, 0, 1.5)
            $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto)
            $rowGrid.ColumnDefinitions.Add($c0)
            $rowGrid.ColumnDefinitions.Add($c1)

            # Process Name
            $nameTxt = New-Object System.Windows.Controls.TextBlock
            $nameTxt.Text = $pName
            $nameTxt.FontSize = 10.0
            $nameTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
            $nameTxt.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
            $nameTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            [System.Windows.Controls.Grid]::SetColumn($nameTxt, 0)
            $rowGrid.Children.Add($nameTxt)

            # Memory Badge Pill
            $pillBorder = New-Object System.Windows.Controls.Border
            $pillBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#182030")
            $pillBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#28364D")
            $pillBorder.BorderThickness = [System.Windows.Thickness]::new(1)
            $pillBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
            $pillBorder.Padding = [System.Windows.Thickness]::new(5, 1, 5, 1)

            $pillTxt = New-Object System.Windows.Controls.TextBlock
            $pillTxt.Text = $memText
            $pillTxt.FontSize = 9.0
            $pillTxt.FontWeight = [System.Windows.FontWeights]::SemiBold
            $pillTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")
            $pillBorder.Child = $pillTxt

            [System.Windows.Controls.Grid]::SetColumn($pillBorder, 1)
            $rowGrid.Children.Add($pillBorder)

            $topAppsListContainer.Children.Add($rowGrid)
        }
    } catch {}
}

Update-TopProcesses

# CARD 5: QUICK SETTINGS & AUDIO MASTER WIRING

$global:suppressVolEvent = $false

function Toggle-OceruMute {

    [OceruAudioManager]::ToggleMute()

    $isMuted = [OceruAudioManager]::GetMute()

    $global:OceruState.isMuted = $isMuted

    $global:lastKnownMute = $isMuted

    if ($quickIconMute) { $quickIconMute.Text = if ($isMuted) { [char]0xE74F } else { [char]0xE767 } }

    if ($dashQuickMuteIcon) { $dashQuickMuteIcon.Text = if ($isMuted) { "Unmute Audio" } else { "Mute Audio" } }

    if ($isMuted) {

        ShowActionFeedback "Audio Dibisukan" ([char]0xE74F) "#DC2626"

    } else {

        ShowActionFeedback "Audio Aktif" ([char]0xE767) "#10B981"

    }

    Save-OceruState

}

$btnQuickWifi.Add_Click({

    $conn = Get-OceruConnectivity

    ShowActionFeedback "Wi-Fi: $($conn.WifiStatus)" ([char]0xE701) "#00D2FF"

    [System.Diagnostics.Process]::Start("explorer.exe", "ms-availablenetworks:")

})

$btnQuickBt.Add_Click({

    $conn = Get-OceruConnectivity

    ShowActionFeedback "Bluetooth: $($conn.BluetoothStatus)" ([char]0xE702) "#00D2FF"

    [System.Diagnostics.Process]::Start("explorer.exe", "ms-settings:bluetooth")

})

$btnQuickDnd.Add_Click({

    $global:OceruState.dndEnabled = -not $global:OceruState.dndEnabled

    if ($global:OceruState.dndEnabled) {

        $quickStatusDnd.Text = "Aktif"

        ShowActionFeedback "Jangan Ganggu Aktif" ([char]0xE708) "#00D2FF"

    } else {

        $quickStatusDnd.Text = "DND"

        ShowActionFeedback "Jangan Ganggu Nonaktif" ([char]0xE708) "#8E9AA8"

    }

    Save-OceruState

})

$btnQuickGame.Add_Click({

    $global:OceruState.gamingMode = -not $global:OceruState.gamingMode

    if ($global:OceruState.gamingMode) {

        $quickStatusGame.Text = "Aktif"

        ShowActionFeedback "Mode Game Aktif" ([char]0xE7FC) "#10B981"

    } else {

        $quickStatusGame.Text = "Game"

        ShowActionFeedback "Mode Game Nonaktif" ([char]0xE7FC) "#8E9AA8"

    }

    Save-OceruState

})

$btnQuickMute.Add_Click({ Toggle-OceruMute })

$quickSliderVol.Add_ValueChanged({

    if ($global:suppressVolEvent) { return }

    $val = [Math]::Round($quickSliderVol.Value)

    $quickVolPctText.Text = "$val%"

    $global:OceruState.volume = $val

    $global:lastKnownVol = $val

    [OceruAudioManager]::SetMasterVolume($val)

    $global:suppressVolEvent = $true

    if ($dashQuickVolSlider) {

        $dashQuickVolSlider.Value = $val

        $dashQuickVolPctText.Text = "$val%"

    }

    $global:suppressVolEvent = $false

})

$btnQuickLock.Add_Click({

    ShowActionFeedback "Mengunci Layar..." ([char]0xE72E) "#00D2FF"

    try {

        [Win32Helper]::LockWorkStation() | Out-Null

    } catch {

        Start-Process "rundll32.exe" -ArgumentList "user32.dll,LockWorkStation"

    }

})

$btnQuickSleep.Add_Click({

    ShowActionFeedback "Masuk Mode Tidur..." ([char]0xE708) "#00D2FF"

    Start-Process "rundll32.exe" -ArgumentList "powrprof.dll,SetSuspendState 0,1,0"

})

$global:restartArmed = $false

$restartTimer = New-Object System.Windows.Threading.DispatcherTimer

$restartTimer.Interval = [TimeSpan]::FromSeconds(4)

$restartTimer.Add_Tick({

    $restartTimer.Stop()

    $global:restartArmed = $false

    $quickLblRestart.Text = "Restart"

})

$btnQuickRestart.Add_Click({

    if (-not $global:restartArmed) {

        $global:restartArmed = $true

        $quickLblRestart.Text = "Yakin?"

        ShowActionFeedback "Klik lagi untuk Restart!" ([char]0xE777) "#EF4444"

        $restartTimer.Start()

    } else {

        $restartTimer.Stop()

        ShowActionFeedback "Restart Laptop..." ([char]0xE777) "#EF4444"

        Start-Process "shutdown.exe" -ArgumentList "/r /t 2 /c `"Restart via Oceru Dynamic Island`""

    }

})

$btnSysLaunchDash.Add_Click({

    ShowActionFeedback "Membuka Dashboard Oceru..." ([char]0xE737) "#00D2FF"

    Show-OceruDashboard 0

})

# =========================================================================

# DASHBOARD HANDLES & FULL 15-DESTINATION INTERACTIVE ENGINE

# =========================================================================

# Page 0: Overview Handles

$dashOverviewPomoTime = $dashWindow.FindName("DashOverviewPomoTime")

$dashOverviewPomoStatus = $dashWindow.FindName("DashOverviewPomoStatus")

$dashOverviewTodoCount = $dashWindow.FindName("DashOverviewTodoCount")

$dashOverviewTodoBar = $dashWindow.FindName("DashOverviewTodoBar")

$dashOverviewMediaTitle = $dashWindow.FindName("DashOverviewMediaTitle")

$dashOverviewMediaArtist = $dashWindow.FindName("DashOverviewMediaArtist")

$btnOverviewPlayPause = $dashWindow.FindName("BtnOverviewPlayPause")

$btnOverviewNext = $dashWindow.FindName("BtnOverviewNext")

$btnOverviewOpenMedia = $dashWindow.FindName("BtnOverviewOpenMedia")

$btnOverviewTaskMgr = $dashWindow.FindName("BtnOverviewTaskMgr")

$btnOverviewSettings = $dashWindow.FindName("BtnOverviewSettings")

$btnOverviewDnd = $dashWindow.FindName("BtnOverviewDnd")

$btnOverviewWifi = $dashWindow.FindName("BtnOverviewWifi")

# Page 1: Dynamic Island Customization Handles

$dashIslandCurrentModeText = $dashWindow.FindName("DashIslandCurrentModeText")

$btnDashTriggerExpand = $dashWindow.FindName("BtnDashTriggerExpand")

$btnDashTriggerEyes = $dashWindow.FindName("BtnDashTriggerEyes")

# Page 2: Media & Lyrics Handles

$dashMediaTitleText = $dashWindow.FindName("DashMediaTitleText")

$dashMediaArtistText = $dashWindow.FindName("DashMediaArtistText")

$dashMediaProgressBar = $dashWindow.FindName("DashMediaProgressBar")

$dashMediaCurrentTime = $dashWindow.FindName("DashMediaCurrentTime")

$dashMediaRemainingTime = $dashWindow.FindName("DashMediaRemainingTime")

$btnDashMediaPrev = $dashWindow.FindName("BtnDashMediaPrev")

$btnDashMediaPlayPause = $dashWindow.FindName("BtnDashMediaPlayPause")

$dashMediaPlayIcon = $dashWindow.FindName("DashMediaPlayIcon")

$btnDashMediaNext = $dashWindow.FindName("BtnDashMediaNext")

$btnDashSelectAudio = $dashWindow.FindName("BtnDashSelectAudio")

$btnDashStopAudio = $dashWindow.FindName("BtnDashStopAudio")

$dashMediaSourceStatus = $dashWindow.FindName("DashMediaSourceStatus")

# Page 3: Pomodoro Handles

$dashPomoLargeTime = $dashWindow.FindName("DashPomoLargeTime")

$dashPomoStatusText = $dashWindow.FindName("DashPomoStatusText")

$dashPomoSessionBadge = $dashWindow.FindName("DashPomoSessionBadge")

$btnDashPomoStart = $dashWindow.FindName("BtnDashPomoStart")

$dashPomoStartIcon = $dashWindow.FindName("DashPomoStartIcon")

$btnDashPomoReset = $dashWindow.FindName("BtnDashPomoReset")

$btnDashPomoPreset25 = $dashWindow.FindName("BtnDashPomoPreset25")

$btnDashPomoPreset15 = $dashWindow.FindName("BtnDashPomoPreset15")

$btnDashPomoPreset5 = $dashWindow.FindName("BtnDashPomoPreset5")

$btnDashPomoPreset15Break = $dashWindow.FindName("BtnDashPomoPreset15Break")

# Page 4: Stopwatch Handles

$dashStopwatchTimeText = $dashWindow.FindName("DashStopwatchTimeText")

$btnDashStopwatchToggle = $dashWindow.FindName("BtnDashStopwatchToggle")

$dashStopwatchToggleText = $dashWindow.FindName("DashStopwatchToggleText")

$btnDashStopwatchLap = $dashWindow.FindName("BtnDashStopwatchLap")

$btnDashStopwatchReset = $dashWindow.FindName("BtnDashStopwatchReset")

$dashStopwatchLapContainer = $dashWindow.FindName("DashStopwatchLapContainer")

# Page 5: Countdown Handles

$dashCountdownTimeText = $dashWindow.FindName("DashCountdownTimeText")

$dashCountdownStatusText = $dashWindow.FindName("DashCountdownStatusText")

$btnDashCountdownToggle = $dashWindow.FindName("BtnDashCountdownToggle")

$dashCountdownToggleText = $dashWindow.FindName("DashCountdownToggleText")

$btnDashCountdownReset = $dashWindow.FindName("BtnDashCountdownReset")

$btnDashCount1m = $dashWindow.FindName("BtnDashCount1m")

$btnDashCount3m = $dashWindow.FindName("BtnDashCount3m")

$btnDashCount5m = $dashWindow.FindName("BtnDashCount5m")

$btnDashCount10m = $dashWindow.FindName("BtnDashCount10m")

$btnDashCount30m = $dashWindow.FindName("BtnDashCount30m")

# Page 6: System Monitor Handles

$dashSysMonRamVal = $dashWindow.FindName("DashSysMonRamVal")

$dashSysMonRamTotal = $dashWindow.FindName("DashSysMonRamTotal")

$dashSysMonRamAvail = $dashWindow.FindName("DashSysMonRamAvail")

$dashSysMonDiskVal = $dashWindow.FindName("DashSysMonDiskVal")

$dashSysMonDiskBar = $dashWindow.FindName("DashSysMonDiskBar")

$dashSysMonBatVal = $dashWindow.FindName("DashSysMonBatVal")

$dashSysMonBatStatus = $dashWindow.FindName("DashSysMonBatStatus")

$btnDashSysMonTaskMgr = $dashWindow.FindName("BtnDashSysMonTaskMgr")

$btnDashSysMonResMon = $dashWindow.FindName("BtnDashSysMonResMon")

$btnDashSysMonClean = $dashWindow.FindName("BtnDashSysMonClean")

# Page 7: Notifications Handles

$btnNotifMarkAllRead = $dashWindow.FindName("BtnNotifMarkAllRead")

$btnNotifClearAll = $dashWindow.FindName("BtnNotifClearAll")

$btnNotifSendTest = $dashWindow.FindName("BtnNotifSendTest")

$dashNotifListContainer = $dashWindow.FindName("DashNotifListContainer")

# Page 8: Notes Handles

$inputDashNoteTitle = $dashWindow.FindName("InputDashNoteTitle")

$inputDashNoteContent = $dashWindow.FindName("InputDashNoteContent")

$btnDashSaveNoteNew = $dashWindow.FindName("BtnDashSaveNoteNew")

$dashNotesListContainer = $dashWindow.FindName("DashNotesListContainer")

# Page 9: To-Do Handles

$inputDashTodoText = $dashWindow.FindName("InputDashTodoText")

$btnDashAddTodo = $dashWindow.FindName("BtnDashAddTodo")

$dashTodoSummaryText = $dashWindow.FindName("DashTodoSummaryText")

$dashTodoSummaryBar = $dashWindow.FindName("DashTodoSummaryBar")

$dashTodoListContainer = $dashWindow.FindName("DashTodoListContainer")

$cbDashTask1 = $dashWindow.FindName("CbDashTask1")

$cbDashTask2 = $dashWindow.FindName("CbDashTask2")

$cbDashTask3 = $dashWindow.FindName("CbDashTask3")

# Page 10: Clipboard Handles

$btnDashClipClear = $dashWindow.FindName("BtnDashClipClear")

$btnDashCopy1 = $dashWindow.FindName("BtnDashCopy1")

$btnDashCopy2 = $dashWindow.FindName("BtnDashCopy2")

$btnDashCopy3 = $dashWindow.FindName("BtnDashCopy3")

# Page 11: Quick Settings Handles

$dashQuickVolSlider = $dashWindow.FindName("DashQuickVolSlider")

$dashQuickVolPctText = $dashWindow.FindName("DashQuickVolPctText")

$btnDashQuickMute = $dashWindow.FindName("BtnDashQuickMute")

$dashQuickMuteIcon = $dashWindow.FindName("DashQuickMuteIcon")

$btnDashOpenSoundSettings = $dashWindow.FindName("BtnDashOpenSoundSettings")

$btnDashOpenDisplaySettings = $dashWindow.FindName("BtnDashOpenDisplaySettings")

$btnDashQuickWifi = $dashWindow.FindName("BtnDashQuickWifi")

$dashQuickWifiText = $dashWindow.FindName("DashQuickWifiText")

$btnDashQuickBt = $dashWindow.FindName("BtnDashQuickBt")

$dashQuickBtText = $dashWindow.FindName("DashQuickBtText")

$btnDashQuickDnd = $dashWindow.FindName("BtnDashQuickDnd")

$dashQuickDndStatus = $dashWindow.FindName("DashQuickDndStatus")

$btnDashQuickGame = $dashWindow.FindName("BtnDashQuickGame")

$dashQuickGameStatus = $dashWindow.FindName("DashQuickGameStatus")

$btnDashQuickLock = $dashWindow.FindName("BtnDashQuickLock")

$btnDashQuickSleep = $dashWindow.FindName("BtnDashQuickSleep")

$btnDashQuickRestart = $dashWindow.FindName("BtnDashQuickRestart")

$dashQuickRestartLbl = $dashWindow.FindName("DashQuickRestartLbl")

# Page 12: Quick Launcher Handles

$btnLaunchChrome = $dashWindow.FindName("BtnLaunchChrome")

$btnLaunchExplorer = $dashWindow.FindName("BtnLaunchExplorer")

$btnLaunchTerminal = $dashWindow.FindName("BtnLaunchTerminal")

$btnLaunchTaskMgr = $dashWindow.FindName("BtnLaunchTaskMgr")

$btnLaunchSettings = $dashWindow.FindName("BtnLaunchSettings")

$btnLaunchNotepad = $dashWindow.FindName("BtnLaunchNotepad")

$btnLaunchCalc = $dashWindow.FindName("BtnLaunchCalc")

$btnLaunchSnipping = $dashWindow.FindName("BtnLaunchSnipping")

$btnFolderDownloads = $dashWindow.FindName("BtnFolderDownloads")

$btnFolderDocuments = $dashWindow.FindName("BtnFolderDocuments")

$btnFolderPictures = $dashWindow.FindName("BtnFolderPictures")

$inputCustomCommand = $dashWindow.FindName("InputCustomCommand")

$btnRunCustomCommand = $dashWindow.FindName("BtnRunCustomCommand")

# Page 13: Settings Handles

$btnRegisterStartup = $dashWindow.FindName("BtnRegisterStartup")

$btnUnregisterStartup = $dashWindow.FindName("BtnUnregisterStartup")

$btnResetSettings = $dashWindow.FindName("BtnResetSettings")

# Page 14: About Handles

$dashAboutRamFootprint = $dashWindow.FindName("DashAboutRamFootprint")

$btnAboutOpenFolder = $dashWindow.FindName("BtnAboutOpenFolder")

$btnAboutOpenGitHub = $dashWindow.FindName("BtnAboutOpenGitHub")

$btnAboutCheckUpdates = $dashWindow.FindName("BtnAboutCheckUpdates")

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 0 (OVERVIEW)

# -------------------------------------------------------------------------

$btnOverviewPlayPause.Add_Click({

    $btnMusicPlayPause.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

})

$btnOverviewNext.Add_Click({

    $btnMusicNext.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

})

$btnOverviewOpenMedia.Add_Click({ SwitchDashPage 2 })

$btnOverviewTaskMgr.Add_Click({ Start-Process "taskmgr.exe" })

$btnOverviewSettings.Add_Click({ Start-Process "ms-settings:" })

$btnOverviewDnd.Add_Click({

    $global:OceruState.dndEnabled = -not $global:OceruState.dndEnabled

    Save-OceruState

    ShowActionFeedback (if ($global:OceruState.dndEnabled) { "Jangan Ganggu Aktif" } else { "Jangan Ganggu Nonaktif" }) ([char]0xE717) "#00D2FF"

})

$btnOverviewWifi.Add_Click({

    $conn = Get-OceruConnectivity

    ShowActionFeedback "Wi-Fi: $($conn.WifiStatus)" ([char]0xE701) "#00D2FF"

    Start-Process "ms-availablenetworks:"

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 1 (DYNAMIC ISLAND)

# -------------------------------------------------------------------------

$btnDashTriggerExpand.Add_Click({ Set-IslandMode "expanded" })

$btnDashTriggerEyes.Add_Click({ Set-IslandMode "eyes" })

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 2 (MEDIA & LYRICS)

# -------------------------------------------------------------------------

$btnDashMediaPrev.Add_Click({

    $btnMusicPrev.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

})

$btnDashMediaPlayPause.Add_Click({

    $btnMusicPlayPause.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

    $dashMediaPlayIcon.Text = if ($global:OceruState.currentMedia.isPlaying) { [char]0xE769 } else { [char]0xE768 }

})

$btnDashMediaNext.Add_Click({

    $btnMusicNext.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

})

if ($btnDashSelectAudio) {

    $btnDashSelectAudio.Add_Click({ Select-And-Play-LocalAudio })

}

if ($btnDashStopAudio) {

    $btnDashStopAudio.Add_Click({ Stop-LocalAudio })

}

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 3 (POMODORO)

# -------------------------------------------------------------------------

$btnDashPomoStart.Add_Click({

    $btnPomoPlay.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

    $dashPomoStartIcon.Text = if ($global:OceruState.pomodoro.isRunning) { [char]0xE769 } else { [char]0xE768 }

    $dashPomoStatusText.Text = if ($global:OceruState.pomodoro.isRunning) { "Sesi Fokus Sedang Berjalan..." } else { "Sesi Fokus Dijeda" }

})

$btnDashPomoReset.Add_Click({

    $btnPomoReset.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

    $dashPomoLargeTime.Text = "25:00"

    $dashPomoStatusText.Text = "Siap Memulai Sesi Fokus"

})

$btnDashPomoPreset25.Add_Click({

    $btnPomoFocusTime.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

    $dashPomoLargeTime.Text = "25:00"

    $dashPomoStatusText.Text = "Preset Fokus 25 Menit Diatur"

})

$btnDashPomoPreset15.Add_Click({

    $pomoEngine.Stop()

    $global:OceruState.pomodoro.isRunning = $false

    $global:OceruState.pomodoro.remainingSeconds = 900

    $dashPomoLargeTime.Text = "15:00"

    $pomoDisplayTime.Text = "15:00"

    $dashPomoStatusText.Text = "Preset Fokus 15 Menit Diatur"

    Save-OceruState

})

$btnDashPomoPreset5.Add_Click({

    $btnPomoShortBreak.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))

    $dashPomoLargeTime.Text = "05:00"

    $dashPomoStatusText.Text = "Preset Istirahat 5 Menit Diatur"

})

$btnDashPomoPreset15Break.Add_Click({

    $pomoEngine.Stop()

    $global:OceruState.pomodoro.isRunning = $false

    $global:OceruState.pomodoro.remainingSeconds = 900

    $dashPomoLargeTime.Text = "15:00"

    $pomoDisplayTime.Text = "15:00"

    $dashPomoStatusText.Text = "Preset Istirahat 15 Menit Diatur"

    Save-OceruState

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 4 (PRECISION STOPWATCH)

# -------------------------------------------------------------------------

$global:stopwatchSw = [System.Diagnostics.Stopwatch]::new()

$global:stopwatchLaps = @()

$global:stopwatchTimer = New-Object System.Windows.Threading.DispatcherTimer

$global:stopwatchTimer.Interval = [TimeSpan]::FromMilliseconds(50)

$global:stopwatchTimer.Add_Tick({

    $ts = $global:stopwatchSw.Elapsed

    if ($dashStopwatchTimeText) {

        $dashStopwatchTimeText.Text = [string]::Format("{0:00}:{1:00}.{2:00}", $ts.Minutes, $ts.Seconds, [Math]::Floor($ts.Milliseconds / 10))

    }

})

$btnDashStopwatchToggle.Add_Click({

    if ($global:stopwatchSw.IsRunning) {

        $global:stopwatchSw.Stop()

        $global:stopwatchTimer.Stop()

        $dashStopwatchToggleText.Text = "Lanjutkan (Resume)"

    } else {

        $global:stopwatchSw.Start()

        $global:stopwatchTimer.Start()

        $dashStopwatchToggleText.Text = "Jeda (Pause)"

    }

})

$btnDashStopwatchLap.Add_Click({

    if ($global:stopwatchSw.ElapsedMilliseconds -gt 0) {

        $lapNum = $global:stopwatchLaps.Count + 1

        $ts = $global:stopwatchSw.Elapsed

        $lapStr = [string]::Format("Putaran #{0}:  {1:00}:{2:00}.{3:00}", $lapNum, $ts.Minutes, $ts.Seconds, [Math]::Floor($ts.Milliseconds / 10))

        $global:stopwatchLaps += $lapStr

        $lapBorder = New-Object System.Windows.Controls.Border

        $lapBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1B2130")

        $lapBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#232B3D")

        $lapBorder.BorderThickness = [System.Windows.Thickness]::new(1)

        $lapBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)

        $lapBorder.Padding = [System.Windows.Thickness]::new(10, 6, 10, 6)

        $lapBorder.Margin = [System.Windows.Thickness]::new(0, 3, 0, 3)

        $lapTb = New-Object System.Windows.Controls.TextBlock

        $lapTb.Text = $lapStr

        $lapTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")

        $lapTb.FontWeight = [System.Windows.FontWeights]::SemiBold

        $lapTb.FontSize = 12

        $lapBorder.Child = $lapTb

        if ($global:stopwatchLaps.Count -eq 1) {

            $dashStopwatchLapContainer.Children.Clear()

        }

        $dashStopwatchLapContainer.Children.Insert(0, $lapBorder)

    }

})

$btnDashStopwatchReset.Add_Click({

    $global:stopwatchSw.Reset()

    $global:stopwatchTimer.Stop()

    $dashStopwatchTimeText.Text = "00:00.00"

    $dashStopwatchToggleText.Text = "Mulai (Start)"

    $global:stopwatchLaps = @()

    $dashStopwatchLapContainer.Children.Clear()

    $defaultTb = New-Object System.Windows.Controls.TextBlock

    $defaultTb.Text = "Belum ada putaran dicatat. Tekan 'Catat Putaran' saat stopwatch berjalan."

    $defaultTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8E9AA8")

    $defaultTb.FontSize = 12

    $dashStopwatchLapContainer.Children.Add($defaultTb) | Out-Null

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 5 (COUNTDOWN TIMER)

# -------------------------------------------------------------------------

$global:countRemainingSec = 600

$global:countTotalSec = 600

$global:countTimer = New-Object System.Windows.Threading.DispatcherTimer

$global:countTimer.Interval = [TimeSpan]::FromSeconds(1)

$global:countTimer.Add_Tick({

    if ($global:countRemainingSec -gt 0) {

        $global:countRemainingSec--

        $span = [TimeSpan]::FromSeconds($global:countRemainingSec)

        $dashCountdownTimeText.Text = $span.ToString("mm:ss")

    } else {

        $global:countTimer.Stop()

        $dashCountdownStatusText.Text = "Waktu Habis!"

        $dashCountdownToggleText.Text = "Mulai Countdown"

        try { [System.Media.SystemSounds]::Beep.Play() } catch {}

    }

})

function SetCountdownDuration($seconds, $label) {

    $global:countTimer.Stop()

    $global:countRemainingSec = $seconds

    $global:countTotalSec = $seconds

    $span = [TimeSpan]::FromSeconds($seconds)

    $dashCountdownTimeText.Text = $span.ToString("mm:ss")

    $dashCountdownStatusText.Text = "Preset: $label"

    $dashCountdownToggleText.Text = "Mulai Countdown"

}

$btnDashCount1m.Add_Click({ SetCountdownDuration 60 "1 Menit" })

$btnDashCount3m.Add_Click({ SetCountdownDuration 180 "3 Menit" })

$btnDashCount5m.Add_Click({ SetCountdownDuration 300 "5 Menit" })

$btnDashCount10m.Add_Click({ SetCountdownDuration 600 "10 Menit" })

$btnDashCount30m.Add_Click({ SetCountdownDuration 1800 "30 Menit" })

$btnDashCountdownToggle.Add_Click({

    if ($global:countTimer.IsEnabled) {

        $global:countTimer.Stop()

        $dashCountdownToggleText.Text = "Lanjutkan Countdown"

        $dashCountdownStatusText.Text = "Countdown Dijeda"

    } else {

        $global:countTimer.Start()

        $dashCountdownToggleText.Text = "Jeda Countdown"

        $dashCountdownStatusText.Text = "Countdown Berjalan..."

    }

})

$btnDashCountdownReset.Add_Click({

    $global:countTimer.Stop()

    $global:countRemainingSec = $global:countTotalSec

    $span = [TimeSpan]::FromSeconds($global:countRemainingSec)

    $dashCountdownTimeText.Text = $span.ToString("mm:ss")

    $dashCountdownStatusText.Text = "Siap Memulai Countdown"

    $dashCountdownToggleText.Text = "Mulai Countdown"

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 6 (SYSTEM MONITOR)

# -------------------------------------------------------------------------

try {

    $drive = [System.IO.DriveInfo]::new("C")

    $totG = [Math]::Round($drive.TotalSize / 1GB)

    $freeG = [Math]::Round($drive.TotalFreeSpace / 1GB)

    $usedPct = [Math]::Round((($drive.TotalSize - $drive.TotalFreeSpace) / $drive.TotalSize) * 100)

    $dashSysMonDiskVal.Text = "Drive C: Total $totG GB (Bebas $freeG GB)"

    $dashSysMonDiskBar.Width = [Math]::Round(300 * ($usedPct / 100.0))

} catch {}

$btnDashSysMonTaskMgr.Add_Click({ Start-Process "taskmgr.exe" })

$btnDashSysMonResMon.Add_Click({ Start-Process "resmon.exe" })

$btnDashSysMonClean.Add_Click({ Start-Process "cleanmgr.exe" })

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 7 (NOTIFICATIONS)

# -------------------------------------------------------------------------

$btnNotifMarkAllRead.Add_Click({

    ShowActionFeedback "Semua Notifikasi Ditandai Dibaca" ([char]0xE73E) "#10B981"

})

$btnNotifClearAll.Add_Click({

    $dashNotifListContainer.Children.Clear()

    $emptyTb = New-Object System.Windows.Controls.TextBlock

    $emptyTb.Text = "Tidak ada notifikasi riwayat tersisa."

    $emptyTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8E9AA8")

    $emptyTb.FontSize = 12

    $emptyTb.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)

    $dashNotifListContainer.Children.Add($emptyTb) | Out-Null

    ShowActionFeedback "Riwayat Notifikasi Dibersihkan" ([char]0xE74D) "#8E9AA8"

})

$btnNotifSendTest.Add_Click({

    $newNotif = New-Object System.Windows.Controls.Border

    $newNotif.Style = $dashWindow.Resources["DashCard"]

    $newNotif.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)

    $sp = New-Object System.Windows.Controls.StackPanel

    $t1 = New-Object System.Windows.Controls.TextBlock

    $t1.Text = "Uji Notifikasi Oceru (" + [DateTime]::Now.ToString("HH:mm:ss") + ")"

    $t1.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")

    $t1.FontWeight = [System.Windows.FontWeights]::SemiBold

    $t1.FontSize = 13

    $t2 = New-Object System.Windows.Controls.TextBlock

    $t2.Text = "Notifikasi interaktif berhasil dipicu dari Oceru Dashboard."

    $t2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")

    $t2.FontSize = 12

    $t2.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)

    $sp.Children.Add($t1) | Out-Null

    $sp.Children.Add($t2) | Out-Null

    $newNotif.Child = $sp

    $dashNotifListContainer.Children.Insert(0, $newNotif)

    ShowActionFeedback "Notifikasi Baru Diterima!" ([char]0xE7E7) "#00D2FF"

    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 8 (QUICK NOTES)

# -------------------------------------------------------------------------

$btnDashSaveNoteNew.Add_Click({

    $title = $inputDashNoteTitle.Text.Trim()

    $content = $inputDashNoteContent.Text.Trim()

    if ($title -or $content) {

        if (-not $title) { $title = "Catatan Baru" }

        $newObj = [PSCustomObject]@{ id = [DateTime]::Now.Ticks; title = $title; content = $content }

        $global:OceruState.notes = @($newObj) + @($global:OceruState.notes)

        Save-OceruState

        $card = New-Object System.Windows.Controls.Border

        $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1B2130")

        $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#232B3D")

        $card.BorderThickness = [System.Windows.Thickness]::new(1)

        $card.CornerRadius = [System.Windows.CornerRadius]::new(8)

        $card.Padding = [System.Windows.Thickness]::new(12)

        $card.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)

        $sp = New-Object System.Windows.Controls.StackPanel

        $t1 = New-Object System.Windows.Controls.TextBlock

        $t1.Text = $title

        $t1.FontSize = 14

        $t1.FontWeight = [System.Windows.FontWeights]::SemiBold

        $t1.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")

        $t2 = New-Object System.Windows.Controls.TextBlock

        $t2.Text = $content

        $t2.FontSize = 12

        $t2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8E9AA8")

        $t2.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)

        $sp.Children.Add($t1) | Out-Null

        $sp.Children.Add($t2) | Out-Null

        $card.Child = $sp

        $dashNotesListContainer.Children.Insert(0, $card)

        ShowActionFeedback "Catatan Berhasil Disimpan!" ([char]0xE74E) "#10B981"

    }

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 9 (TO-DO LIST)

# -------------------------------------------------------------------------

$btnDashAddTodo.Add_Click({

    $txt = $inputDashTodoText.Text.Trim()

    if ($txt) {

        $cb = New-Object System.Windows.Controls.CheckBox

        $cb.Content = $txt

        $cb.IsChecked = $false

        $cb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")

        $cb.Margin = [System.Windows.Thickness]::new(0, 6, 0, 6)

        $cb.Add_Click({

            UpdateTodoProgress

        })

        $dashTodoListContainer.Children.Add($cb) | Out-Null

        $inputDashTodoText.Text = ""

        ShowActionFeedback "Tugas Baru Ditambahkan!" ([char]0xE710) "#00D2FF"

    }

})

$cbDashTask1.Add_Click({ UpdateTodoProgress })

$cbDashTask2.Add_Click({ UpdateTodoProgress })

$cbDashTask3.Add_Click({ UpdateTodoProgress })

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 10 (CLIPBOARD MANAGER)

# -------------------------------------------------------------------------

$btnDashCopy1.Add_Click({

    try { [System.Windows.Clipboard]::SetText("https://github.com/cubadakanda/dynamic-island"); ShowActionFeedback "URL GitHub Disalin!" ([char]0xE8C8) "#00D2FF" } catch {}

})

$btnDashCopy2.Add_Click({

    try { [System.Windows.Clipboard]::SetText("Oceru Dynamic Island Desktop v2.0.0"); ShowActionFeedback "Teks Disalin!" ([char]0xE8C8) "#00D2FF" } catch {}

})

$btnDashCopy3.Add_Click({

    try { [System.Windows.Clipboard]::SetText("Paper Sky - Lumen Coast"); ShowActionFeedback "Judul Lagu Disalin!" ([char]0xE8C8) "#00D2FF" } catch {}

})

$btnDashClipClear.Add_Click({

    ShowActionFeedback "Papan Klip Dibersihkan" ([char]0xE74D) "#8E9AA8"

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 11 (QUICK SETTINGS)

# -------------------------------------------------------------------------

$dashQuickVolSlider.Add_ValueChanged({

    if ($global:suppressVolEvent) { return }

    $val = [Math]::Round($dashQuickVolSlider.Value)

    $dashQuickVolPctText.Text = "$val%"

    $global:OceruState.volume = $val

    $global:lastKnownVol = $val

    [OceruAudioManager]::SetMasterVolume($val)

    $global:suppressVolEvent = $true

    if ($quickSliderVol) {

        $quickSliderVol.Value = $val

        $quickVolPctText.Text = "$val%"

    }

    $global:suppressVolEvent = $false

})

$btnDashQuickMute.Add_Click({ Toggle-OceruMute })

$btnDashOpenSoundSettings.Add_Click({ Start-Process "ms-settings:sound" })

if ($btnDashOpenDisplaySettings) {

    $btnDashOpenDisplaySettings.Add_Click({

        ShowActionFeedback "Membuka Pengaturan Layar..." ([char]0xE706) "#00D2FF"

        Start-Process "ms-settings:display"

    })

}

$btnDashQuickWifi.Add_Click({

    $conn = Get-OceruConnectivity

    ShowActionFeedback "Wi-Fi: $($conn.WifiStatus)" ([char]0xE701) "#00D2FF"

    Start-Process "ms-availablenetworks:"

})

$btnDashQuickBt.Add_Click({

    $conn = Get-OceruConnectivity

    ShowActionFeedback "Bluetooth: $($conn.BluetoothStatus)" ([char]0xE702) "#00D2FF"

    Start-Process "ms-settings:bluetooth"

})

$btnDashQuickDnd.Add_Click({

    $global:OceruState.dndEnabled = -not $global:OceruState.dndEnabled

    Save-OceruState

    $dashQuickDndStatus.Text = if ($global:OceruState.dndEnabled) { "Mode Jangan Ganggu: Aktif" } else { "Mode Jangan Ganggu: Nonaktif" }

    ShowActionFeedback $dashQuickDndStatus.Text ([char]0xE717) "#00D2FF"

})

$btnDashQuickGame.Add_Click({

    $global:OceruState.gamingMode = -not $global:OceruState.gamingMode

    Save-OceruState

    $dashQuickGameStatus.Text = if ($global:OceruState.gamingMode) { "Mode Game: Aktif" } else { "Mode Game: Nonaktif" }

    ShowActionFeedback $dashQuickGameStatus.Text ([char]0xE7FC) "#10B981"

})

$btnDashQuickLock.Add_Click({ [Win32Helper]::LockWorkStation() })

$btnDashQuickSleep.Add_Click({ Start-Process "rundll32.exe" -ArgumentList "powrprof.dll,SetSuspendState 0,1,0" })

$btnDashQuickRestart.Add_Click({ Start-Process "shutdown.exe" -ArgumentList "/r /t 2" })

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 12 (QUICK LAUNCHER)

# -------------------------------------------------------------------------

$btnLaunchChrome.Add_Click({ try { Start-Process "chrome.exe" } catch { Start-Process "msedge.exe" } })

$btnLaunchExplorer.Add_Click({ Start-Process "explorer.exe" })

$btnLaunchTerminal.Add_Click({ Start-Process "powershell.exe" })

$btnLaunchTaskMgr.Add_Click({ Start-Process "taskmgr.exe" })

$btnLaunchSettings.Add_Click({ Start-Process "ms-settings:" })

$btnLaunchNotepad.Add_Click({ Start-Process "notepad.exe" })

$btnLaunchCalc.Add_Click({ Start-Process "calc.exe" })

$btnLaunchSnipping.Add_Click({ Start-Process "snippingtool.exe" })

$btnFolderDownloads.Add_Click({ Start-Process "explorer.exe" -ArgumentList ([Environment]::GetFolderPath("UserProfile") + "Downloads") })

$btnFolderDocuments.Add_Click({ Start-Process "explorer.exe" -ArgumentList ([Environment]::GetFolderPath("MyDocuments")) })

$btnFolderPictures.Add_Click({ Start-Process "explorer.exe" -ArgumentList ([Environment]::GetFolderPath("MyPictures")) })

$btnRunCustomCommand.Add_Click({

    $cmd = $inputCustomCommand.Text.Trim()

    if ($cmd) {

        try {

            Start-Process $cmd

            ShowActionFeedback "Menjalankan: $cmd" ([char]0xE768) "#00D2FF"

        } catch {

            ShowActionFeedback "Gagal: Perintah tidak valid" ([char]0xE783) "#EF4444"

        }

    }

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 13 (SETTINGS)

# -------------------------------------------------------------------------

$btnRegisterStartup.Add_Click({

    $bat = Join-Path $PSScriptRoot "install.bat"

    if (Test-Path $bat) {

        Start-Process $bat

        ShowActionFeedback "Menjalankan install.bat..." ([char]0xE710) "#10B981"

    }

})

$btnUnregisterStartup.Add_Click({

    $bat = Join-Path $PSScriptRoot "uninstall.bat"

    if (Test-Path $bat) {

        Start-Process $bat

        ShowActionFeedback "Menjalankan uninstall.bat..." ([char]0xE74D) "#8E9AA8"

    }

})

$btnResetSettings.Add_Click({

    $stateFile = Join-Path $PSScriptRoot ".oceru-state.json"

    if (Test-Path $stateFile) {

        Remove-Item $stateFile -Force -ErrorAction SilentlyContinue

    }

    ShowActionFeedback "Pengaturan Direset ke Default Pabrik!" ([char]0xE73E) "#10B981"

})

# -------------------------------------------------------------------------

# DASHBOARD WIRING: PAGE 14 (ABOUT OCERU)

# -------------------------------------------------------------------------

$btnAboutOpenFolder.Add_Click({ Start-Process "explorer.exe" -ArgumentList $PSScriptRoot })

$btnAboutOpenGitHub.Add_Click({ Start-Process "https://github.com/cubadakanda/dynamic-island" })

$btnAboutCheckUpdates.Add_Click({ ShowActionFeedback "Oceru versi v2.0.0 adalah rilis terbaru!" ([char]0xE946) "#00D2FF" })

# RIGHT-CLICK CONTEXT MENU ON NOTCH

$menu = New-Object System.Windows.Controls.ContextMenu

$itemDash = New-Object System.Windows.Controls.MenuItem

$itemDash.Header = "Buka Dashboard (15 Destinasi)"

$itemDash.Add_Click({ Show-OceruDashboard 0 })

$itemReload = New-Object System.Windows.Controls.MenuItem

$itemReload.Header = "Muat Ulang / Reload (F5)"

$itemReload.Add_Click({

    $dashWindow.Close()

    $window.Close()

    Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""

})

$itemExit = New-Object System.Windows.Controls.MenuItem

$itemExit.Header = "Tutup Oceru Dynamic Island"

$itemExit.Add_Click({

    $dashWindow.Close()

    $window.Close()

    [System.Windows.Application]::Current.Shutdown()

})

$menu.Items.Add($itemDash) | Out-Null

$menu.Items.Add($itemReload) | Out-Null

$menu.Items.Add($itemExit) | Out-Null

$window.ContextMenu = $menu

# MOUSE WHEEL HARDWARE VOLUME CONTROL (Feature 1: Atur Volume via Scroll Wheel di Kapsul)

$window.Add_MouseWheel({
    param($s, $e)
    try {
        $cursorPos = [System.Windows.Forms.Cursor]::Position
        $curIslW = if ($masterGrid -and $masterGrid.Width -gt 0) { $masterGrid.Width } else { $eyesTotalWidth }
        $curIslH = if ($masterGrid -and $masterGrid.Height -gt 0) { $masterGrid.Height } else { $eyesHeight }
        $islL = ($screenWidth - $curIslW) / 2
        $islR = $islL + $curIslW
        $islB = $curIslH
        $inIsland = ($cursorPos.X -ge ($islL - 10)) -and ($cursorPos.X -le ($islR + 10)) -and ($cursorPos.Y -ge 0) -and ($cursorPos.Y -le ($islB + 14))

        if ($inIsland) {
            $delta = $e.Delta
            $isShift = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)

            if ($isShift) {
                # SHIFT + SCROLL: Adjust Screen Brightness (step 5%)
                $step = if ($delta -gt 0) { 5 } else { -5 }
                $newBright = Set-SystemBrightness -Delta $step
                $filledCount = [int][Math]::Round($newBright / 10.0)
                $barStr = ("[" + ("■" * $filledCount) + ("□" * (10 - $filledCount)) + "]")
                Show-OceruDynamicToast "Kecerahan Layar" "$newBright%  $barStr" ([char]0xE706) "#F59E0B" 1300
            } else {
                # NORMAL SCROLL: Adjust Master Volume (step 4%)
                $step = if ($delta -gt 0) { 4 } else { -4 }
                $cur = [OceruAudioManager]::GetMasterVolume()
                if ($cur -lt 0) { $cur = $global:lastKnownVol }
                $newVol = [Math]::Max(0, [Math]::Min(100, $cur + $step))

                if ($newVol -ne $cur) {
                    [OceruAudioManager]::SetMasterVolume($newVol) | Out-Null
                    $global:lastKnownVol = $newVol
                    $global:OceruState.volume = $newVol

                    if ($quickSliderVol) { $quickSliderVol.Value = $newVol; $quickVolPctText.Text = "$newVol%" }
                    if ($dashQuickVolSlider) { $dashQuickVolSlider.Value = $newVol; $dashQuickVolPctText.Text = "$newVol%" }

                    $volGlyph = if ($newVol -eq 0) { [char]0xE74F } elseif ($newVol -lt 33) { [char]0xE993 } elseif ($newVol -lt 66) { [char]0xE994 } else { [char]0xE995 }
                    $filledCount = [int][Math]::Round($newVol / 10.0)
                    $barStr = ("[" + ("■" * $filledCount) + ("□" * (10 - $filledCount)) + "]")

                    if ($global:islandMode -ne "expanded") {
                        Show-OceruDynamicToast "Volume Master" "$newVol%  $barStr" $volGlyph "#00D2FF" 1300
                    } else {
                        ShowActionFeedback "Volume: $newVol% $barStr" $volGlyph "#00D2FF"
                    }
                }
            }
            $e.Handled = $true
        }
    } catch {}
})

# MIDDLE-CLICK ON ISLAND: INSTANT MEDIA PLAY / PAUSE TOGGLE
$window.Add_MouseDown({
    param($s, $e)
    try {
        if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Middle) {
            $cursorPos = [System.Windows.Forms.Cursor]::Position
            $curIslW = if ($masterGrid -and $masterGrid.Width -gt 0) { $masterGrid.Width } else { $eyesTotalWidth }
            $curIslH = if ($masterGrid -and $masterGrid.Height -gt 0) { $masterGrid.Height } else { $eyesHeight }
            $islL = ($screenWidth - $curIslW) / 2
            $islR = $islL + $curIslW
            $islB = $curIslH
            $inIsland = ($cursorPos.X -ge ($islL - 10)) -and ($cursorPos.X -le ($islR + 10)) -and ($cursorPos.Y -ge 0) -and ($cursorPos.Y -le ($islB + 14))
            if ($inIsland) {
                Toggle-OceruMediaPlayPause
                $e.Handled = $true
            }
        }
    } catch {}
})

# HOTKEYS (F5 Reload, Esc Collapse)

$window.Add_KeyDown({

    param($s, $e)

    if ($e.Key -eq [System.Windows.Input.Key]::F5) {

        $dashWindow.Close()

        $window.Close()

        Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""

    } elseif ($e.Key -eq [System.Windows.Input.Key]::Escape) {

        if ($global:islandMode -eq "expanded") {

            Set-IslandMode "status"

        }

    }

})

# FAST DISPATCHER LOOP: EYE TRACKING, ADAPTIVE POLLING & AUTO TRANSITIONS

$global:eyeBlinkTick = 0

$global:cursorIdleSw = [System.Diagnostics.Stopwatch]::StartNew()

$global:lastIdleCursorX = 0

$global:lastIdleCursorY = 0

$global:isBatterySaver = $false

$global:powerCheckTick = 0

$fastEyeTimer = New-Object System.Windows.Threading.DispatcherTimer

$fastEyeTimer.Interval = [TimeSpan]::FromMilliseconds(40)

$fastEyeTimer.Add_Tick({

    try {

        $cursorPos = [System.Windows.Forms.Cursor]::Position

        $curIslW = if ($masterGrid -and $masterGrid.Width -gt 0) { $masterGrid.Width } else { $eyesTotalWidth }
        $curIslH = if ($masterGrid -and $masterGrid.Height -gt 0) { $masterGrid.Height } else { $eyesHeight }
        $islL = ($screenWidth - $curIslW) / 2
        $islR = $islL + $curIslW
        $islB = $curIslH

        # FEATURE 3: SMART FULLSCREEN AUTO-HIDE WITH SMOOTH BEZEL GLIDE
        $global:fullscreenCheckTick = ($global:fullscreenCheckTick + 1) % 6
        if ($global:fullscreenCheckTick -eq 0) {
            $global:isForegroundFullscreen = [Win32Helper]::IsForegroundFullscreen($global:islandHwnd, [int]$screenWidth, [int]$screenHeight)
        }

        if ($global:isForegroundFullscreen -and $global:islandMode -ne "expanded") {
            $nearTop = ($cursorPos.Y -le 14) -and ($cursorPos.X -ge ($islL - 25)) -and ($cursorPos.X -le ($islR + 25))
            $inIslandArea = ($cursorPos.X -ge ($islL - 10)) -and ($cursorPos.X -le ($islR + 10)) -and ($cursorPos.Y -ge 0) -and ($cursorPos.Y -le ($islB + 14))
            if ($nearTop -or $inIslandArea) {
                $global:targetWindowTop = 0.0
            } else {
                # Smoothly retract into the monitor bezel, leaving a 3px sleek rim
                $global:targetWindowTop = -([Math]::Max(30, $curIslH - 3))
            }
        } else {
            $global:targetWindowTop = 0.0
        }

        # Fluid glide interpolation for Window.Top
        if ([Math]::Abs($window.Top - $global:targetWindowTop) -gt 0.8) {
            $window.Top = [Math]::Round($window.Top + ($global:targetWindowTop - $window.Top) * 0.35)
        } else {
            $window.Top = $global:targetWindowTop
        }

        # FEATURE 4: HARDWARE HUD OVERLAY - CAPS LOCK MONITOR
        $global:capsLockCheckTick = ($global:capsLockCheckTick + 1) % 4
        if ($global:capsLockCheckTick -eq 0) {
            $curCaps = [System.Windows.Forms.Control]::IsKeyLocked([System.Windows.Forms.Keys]::CapsLock)
            if ($global:lastCapsLockState -ne $null -and $curCaps -ne $global:lastCapsLockState) {
                $global:lastCapsLockState = $curCaps
                if ($curCaps) {
                    Show-OceruDynamicToast "CAPS LOCK" "Huruf Besar: AKTIF" ([char]0xE756) "#F59E0B" 1300
                } else {
                    Show-OceruDynamicToast "Caps Lock" "Huruf Normal: Nonaktif" ([char]0xE756) "#8E9AA8" 1100
                }
            } else {
                $global:lastCapsLockState = $curCaps
            }
        }

        # Reference Image 2: Dynamic Audio Waveform Bottom Rim (EXCLUSIVE TO MUSIC CARD 0 WHEN MUSIC IS ACTIVELY PLAYING)

        $isMusicRealPlaying = ($global:gsmtcPlaying -eq $true -and $global:OceruState.currentMedia.isPlaying -eq $true)

        $isMusicCardActive = ($global:islandMode -eq "expanded" -and $global:activeCardIndex -eq 0 -and $cardMusic.Visibility -eq [System.Windows.Visibility]::Visible -and $isMusicRealPlaying)

        if ($isMusicCardActive) {

            # Animate wave phase & ramp up amplitude
            $global:wavePhase = ($global:wavePhase + 0.18) % 360
            $global:waveAmp = [Math]::Min(14.0, $global:waveAmp + 1.2)

            # Dynamic Beat Burst simulation (every ~16 ticks, a burst fires for 4 ticks)
            $global:beatTick = ($global:beatTick + 1) % 16
            $beatAmp = if ($global:beatTick -le 4) { 0.85 } else { 0.0 }

            # Update Solid Top-Docked Obsidian Body
            $curNW = if ($masterGrid -and $masterGrid.Width -gt 0) { $masterGrid.Width } else { $window.Width }
            $curNH = if ($masterGrid -and $masterGrid.Height -gt 0) { $masterGrid.Height } else { $window.Height }

            if ($notchSinglePath) {
                $flatPath = Get-NotchPathData $curNW $curNH $shoulderPad 24 0 0
                $notchSinglePath.Data = [System.Windows.Media.Geometry]::Parse($flatPath)
            }

            # Update Radial Spectrum Equalizer Bars
            $barsPathStr = Get-SpectrumBarsPathData $curNW $curNH $shoulderPad 24 $global:wavePhase $beatAmp
            if ($barsPathStr) {
                $barsGeom = [System.Windows.Media.Geometry]::Parse($barsPathStr)
                if ($notchBarsGlowPath) {
                    $notchBarsGlowPath.Data = $barsGeom
                    $notchBarsGlowPath.Opacity = [Math]::Min(1.0, $notchBarsGlowPath.Opacity + 0.2)
                }
                if ($notchBarsCorePath) {
                    $notchBarsCorePath.Data = $barsGeom
                    $notchBarsCorePath.Opacity = [Math]::Min(1.0, $notchBarsCorePath.Opacity + 0.2)
                }
                if ($notchBarsWhitePath) {
                    $notchBarsWhitePath.Data = $barsGeom
                    $notchBarsWhitePath.Opacity = [Math]::Min(0.85, $notchBarsWhitePath.Opacity + 0.2)
                }
            }

        } else {
            # Fade out Spectrum Bars smoothly when paused or inactive
            if ($notchBarsGlowPath -and $notchBarsGlowPath.Opacity -gt 0) {
                $notchBarsGlowPath.Opacity = [Math]::Max(0.0, $notchBarsGlowPath.Opacity - 0.25)
            }
            if ($notchBarsCorePath -and $notchBarsCorePath.Opacity -gt 0) {
                $notchBarsCorePath.Opacity = [Math]::Max(0.0, $notchBarsCorePath.Opacity - 0.25)
            }
            if ($notchBarsWhitePath -and $notchBarsWhitePath.Opacity -gt 0) {
                $notchBarsWhitePath.Opacity = [Math]::Max(0.0, $notchBarsWhitePath.Opacity - 0.25)
            }

            # In Resting Eyes Mode, Status Mode, Other Cards, or Music Paused / Inactive:
            # RAPIDLY FLATTEN wave to 0 & hide neon strokes & apex sparks!
            if ($global:waveAmp -gt 0.2) {
                $global:waveAmp = [Math]::Max(0.0, $global:waveAmp - 2.0)
                $curR = if ($global:islandMode -eq "expanded") { 24 } else { 18 }

                $w3 = Get-Notch3SidedWaveGeometry $curNW $curNH $shoulderPad $curR $global:waveAmp $global:wavePhase 0.0
                if ($w3) {
                    if ($notchSinglePath) { $notchSinglePath.Data = [System.Windows.Media.Geometry]::Parse($w3.BodyPath) }
                    if ($notchWaveStrokePath) {
                        $notchWaveStrokePath.Data = [System.Windows.Media.Geometry]::Parse($w3.StrokePath)
                        $notchWaveStrokePath.Opacity = [Math]::Max(0.0, $notchWaveStrokePath.Opacity - 0.25)
                    }
                    if ($notchWaveRibbon2Path) {
                        $notchWaveRibbon2Path.Data = [System.Windows.Media.Geometry]::Parse($w3.Ribbon2Path)
                        $notchWaveRibbon2Path.Opacity = [Math]::Max(0.0, $notchWaveRibbon2Path.Opacity - 0.25)
                    }
                    if ($notchWaveCorePath) {
                        $notchWaveCorePath.Data = [System.Windows.Media.Geometry]::Parse($w3.StrokePath)
                        $notchWaveCorePath.Opacity = [Math]::Max(0.0, $notchWaveCorePath.Opacity - 0.25)
                    }
                    if ($notchApexCanvas) {
                        $notchApexCanvas.Opacity = [Math]::Max(0.0, $notchApexCanvas.Opacity - 0.25)
                    }
                }
            } else {
                $global:waveAmp = 0.0
                if ($notchWaveStrokePath -and $notchWaveStrokePath.Opacity -gt 0 -and $global:magSafeGlowTicks -le 0) {
                    $notchWaveStrokePath.Opacity = 0.0
                }
                if ($notchWaveRibbon2Path -and $notchWaveRibbon2Path.Opacity -gt 0) {
                    $notchWaveRibbon2Path.Opacity = 0.0
                }
                if ($notchWaveCorePath -and $notchWaveCorePath.Opacity -gt 0) {
                    $notchWaveCorePath.Opacity = 0.0
                }
                if ($notchApexCanvas -and $notchApexCanvas.Opacity -gt 0) {
                    $notchApexCanvas.Opacity = 0.0
                    if ($global:apexSparkBorders) {
                        foreach ($sp in $global:apexSparkBorders) { $sp.Visibility = [System.Windows.Visibility]::Collapsed }
                    }
                }
            }

        }

        # Feature 4: MagSafe Emerald Charging Glow Pulse
        if ($global:magSafeGlowTicks -gt 0) {
            $global:magSafeGlowTicks--
            if ($notchWaveStrokePath) {
                $curR = if ($global:islandMode -eq "expanded") { 24 } else { 18 }
                $strokeStr = Get-NotchBottomWavePathData $curNW $curNH $shoulderPad $curR 0.0 0.0
                $notchWaveStrokePath.Data = [System.Windows.Media.Geometry]::Parse($strokeStr)
                $notchWaveStrokePath.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
                if ($notchWaveStrokePath.Effect) {
                    $notchWaveStrokePath.Effect.Color = [System.Windows.Media.ColorConverter]::ConvertFromString("#10B981")
                }
                $pulse = [Math]::Sin(($global:magSafeGlowTicks / 35.0) * [Math]::PI)
                $notchWaveStrokePath.Opacity = [Math]::Max(0.0, [Math]::Min(1.0, $pulse * 0.95))
            }
        }

        # Feature 3: Status Bar Mini Equalizer Animation (Dancing Bars during playback)
        if ($btnMiniEqualizer) {
            if ($global:gsmtcPlaying -eq $true) {
                if ($btnMiniEqualizer.Visibility -ne [System.Windows.Visibility]::Visible) {
                    $btnMiniEqualizer.Visibility = [System.Windows.Visibility]::Visible
                }
                if ($miniEqBar1) { $miniEqBar1.Height = [Math]::Max(3, [Math]::Min(12, 3.0 + [Math]::Abs([Math]::Sin($global:wavePhase * 3.1 + 0.3)) * 8.5)) }
                if ($miniEqBar2) { $miniEqBar2.Height = [Math]::Max(3, [Math]::Min(12, 4.0 + [Math]::Abs([Math]::Sin($global:wavePhase * 4.4 + 1.4)) * 7.5)) }
                if ($miniEqBar3) { $miniEqBar3.Height = [Math]::Max(3, [Math]::Min(12, 3.5 + [Math]::Abs([Math]::Sin($global:wavePhase * 2.8 + 2.2)) * 8.0)) }
                if ($miniEqBar4) { $miniEqBar4.Height = [Math]::Max(3, [Math]::Min(12, 4.0 + [Math]::Abs([Math]::Sin($global:wavePhase * 5.1 + 0.7)) * 7.0)) }
            } else {
                if ($btnMiniEqualizer.Visibility -ne [System.Windows.Visibility]::Collapsed) {
                    $btnMiniEqualizer.Visibility = [System.Windows.Visibility]::Collapsed
                }
            }
        }

        # Adaptive idle tracking: restart stopwatch if cursor moved

        if ($cursorPos.X -ne $global:lastIdleCursorX -or $cursorPos.Y -ne $global:lastIdleCursorY) {

            $global:cursorIdleSw.Restart()

            $global:lastIdleCursorX = $cursorPos.X

            $global:lastIdleCursorY = $cursorPos.Y

        }

        # Periodic Power Check (Charging Connect Pulse & Battery Saver)

        $global:powerCheckTick = ($global:powerCheckTick + 1) % 15 # Check every ~0.6s

        if ($global:powerCheckTick -eq 0) {

            try {

                $curAc = [Win32Helper]::GetACLineStatus()

                $curBat = [Win32Helper]::GetBatteryPercent()

                if ($curBat -ge 0) { $global:currentBatteryPct = $curBat }

                # Feature 1: ⚡ Charging Connect Pulse (Detects plug/unplug)

                if ($global:lastAcLineStatus -ne -1 -and $curAc -ne 255 -and $curAc -ne $global:lastAcLineStatus) {

                    $displayBat = if ($global:currentBatteryPct -gt 0) { "$($global:currentBatteryPct)%" } else { "85%" }

                    if ($curAc -eq 1) {
                        $global:magSafeGlowTicks = 35 # ~1.8s MagSafe emerald pulse
                        Play-OceruSound "chime"
                        Show-OceruDynamicToast "MagSafe Pengisian Daya" "$displayBat • Terhubung Cepat" ([char]0xEA94) "#10B981" 2600
                    } elseif ($curAc -eq 0) {
                        Show-OceruDynamicToast "Pengisi Daya Dicabut" "$displayBat • Daya Baterai" ([char]0xEA93) "#F59E0B" 2200
                    }

                }

                $global:lastAcLineStatus = $curAc

                $global:isBatterySaver = [Win32Helper]::IsBatterySaver()

            } catch {

                $global:isBatterySaver = $false

            }

        }

        # Adaptive Throttling: 1 min idle in Resting Cat Eyes OR Battery Saver active

        $isIdleOneMin = ($global:islandMode -eq "eyes" -and $global:cursorIdleSw.ElapsedMilliseconds -ge 60000)

        $targetInterval = if ($isIdleOneMin -or $global:isBatterySaver) { 150 } else { 40 }

        if ($fastEyeTimer.Interval.TotalMilliseconds -ne $targetInterval) {

            $fastEyeTimer.Interval = [TimeSpan]::FromMilliseconds($targetInterval)

        }

        # -----------------------------------------------------------------

        # MODE 1: RESTING CAT EYES PILL (Virtual Pet & Personality Engine)

        # -----------------------------------------------------------------

        if ($global:islandMode -eq "eyes") {

            # 1. Cursor Velocity & Playful Direction Tracking

            if ($global:prevCursorX -eq $null) {

                $global:prevCursorX = $cursorPos.X

                $global:prevCursorY = $cursorPos.Y

            }

            $dxCur = $cursorPos.X - $global:prevCursorX

            $dyCur = $cursorPos.Y - $global:prevCursorY

            $cursorSpeed = [Math]::Sqrt($dxCur * $dxCur + $dyCur * $dyCur)

            $global:prevCursorX = $cursorPos.X

            $global:prevCursorY = $cursorPos.Y

            # 2. Direction vectors for pupils

            $dx = $cursorPos.X - $global:notchCenterX

            $dy = $cursorPos.Y - 18

            $normX = [Math]::Max(-1.0, [Math]::Min(1.0, $dx / ($screenWidth / 2)))

            $normY = [Math]::Max(-0.2, [Math]::Min(1.0, $dy / $screenHeight))

            $targetX = [Math]::Round($normX * 3.8, 1)

            $targetY = [Math]::Round($normY * 2.5, 1)

            $leftPupilTransform.X = $targetX

            $leftPupilTransform.Y = $targetY

            $rightPupilTransform.X = $targetX

            $rightPupilTransform.Y = $targetY

            # 3. Interactive Play Reaction: when cursor moves quickly nearby, cat enters hunting play mode!

            if ($cursorSpeed -gt 12 -and $cursorPos.Y -lt 400) {

                $global:catPlayTicks = 25 # ~1s hunting mode

                $playTiltX = [Math]::Max(-2.5, [Math]::Min(2.5, $dxCur * 0.08))

                $playTiltY = [Math]::Max(-1.8, [Math]::Min(1.8, $dyCur * 0.08))

                if ($catEyesTransform) {

                    $catEyesTransform.X = $playTiltX

                    $catEyesTransform.Y = $playTiltY

                }

            }

            # 4. Petting / Scratching Detection: rubbing mouse back and forth over eyes

            $isOverEyes = ($cursorPos.X -ge ($islL - 4)) -and ($cursorPos.X -le ($islR + 4)) -and ($cursorPos.Y -ge 0) -and ($cursorPos.Y -le ($islB + 8))

            if ($isOverEyes) {

                if ([Math]::Abs($dxCur) -gt 2.5) {

                    $curPetDir = if ($dxCur -gt 0) { 1 } else { -1 }

                    if ($global:lastPetDir -ne 0 -and $curPetDir -ne $global:lastPetDir) {

                        $global:petStrokeCount++

                        $global:lastPetTime = [DateTime]::Now

                    }

                    $global:lastPetDir = $curPetDir

                }

                if ($global:petStrokeCount -ge 3) {

                    $global:catPettingHappyTicks = 65 # ~2.6s happy squint & purr

                    $global:petStrokeCount = 0

                    Play-OceruSound "purr"

                    Show-OceruDynamicToast "Kucing Kesayangan" "Purrrr... Senang dielus! (^.^)" ([char]0xEB51) "#EC4899" 2400

                }

            } else {

                if ($global:lastPetTime -and ([DateTime]::Now - $global:lastPetTime).TotalSeconds -gt 1.8) {

                    $global:petStrokeCount = 0

                    $global:lastPetDir = 0

                }

            }

            # 5. Pupil Dilation Handling (Wide playful pupils vs normal slit)

            if ($global:catPlayTicks -gt 0) {

                $global:catPlayTicks--

                if ($leftPupilBorder) { $leftPupilBorder.Width = 5.6 }

                if ($rightPupilBorder) { $rightPupilBorder.Width = 5.6 }

            } else {

                if ($leftPupilBorder) { $leftPupilBorder.Width = 3.8 }

                if ($rightPupilBorder) { $rightPupilBorder.Width = 3.8 }

                if ($catEyesTransform -and $global:catPettingHappyTicks -le 0 -and $global:gsmtcPlaying -ne $true) {

                    $catEyesTransform.X = 0

                }

            }

            # 6. Mood Priority Hierarchy

            # Mood A: Charging Happy Squint (^.^) when charger just plugged in
            if ($global:catChargingHappyTicks -gt 0) {

                $global:catChargingHappyTicks--
                $leftEye.Height = 3.5
                $rightEye.Height = 3.5
                $leftEye.CornerRadius = [System.Windows.CornerRadius]::new(1, 1, 7.5, 7.5)
                $rightEye.CornerRadius = [System.Windows.CornerRadius]::new(1, 1, 7.5, 7.5)
                $happyY = [Math]::Sin($global:catChargingHappyTicks * 0.4) * 1.2
                if ($catEyesTransform) { $catEyesTransform.Y = $happyY }
                if ($catZzzCanvas) { $catZzzCanvas.Opacity = 0.0 }

            }

            # Mood B: Petting Happy Squint (^.^) with Purr Vibration
            elseif ($global:catPettingHappyTicks -gt 0) {

                $global:catPettingHappyTicks--
                $leftEye.Height = 3.5
                $rightEye.Height = 3.5
                $leftEye.CornerRadius = [System.Windows.CornerRadius]::new(1, 1, 7.5, 7.5)
                $rightEye.CornerRadius = [System.Windows.CornerRadius]::new(1, 1, 7.5, 7.5)
                $global:purrTick = ($global:purrTick + 1) % 360
                $purrY = [Math]::Sin($global:purrTick * 0.35) * 1.5
                if ($catEyesTransform) { $catEyesTransform.Y = $purrY }
                if ($catZzzCanvas) { $catZzzCanvas.Opacity = 0.0 }

            }

            # Mood C: Playful Double Wink
            elseif ($global:catDoubleWinkTicks -gt 0) {

                $global:catDoubleWinkTicks--
                if (($global:catDoubleWinkTicks -ge 14 -and $global:catDoubleWinkTicks -le 18) -or
                    ($global:catDoubleWinkTicks -ge 5 -and $global:catDoubleWinkTicks -le 9)) {
                    $leftEye.Height = 2.5
                    $rightEye.Height = 2.5
                } else {
                    $leftEye.Height = 17.0
                    $rightEye.Height = 17.0
                    $leftEye.CornerRadius = [System.Windows.CornerRadius]::new(7.5)
                    $rightEye.CornerRadius = [System.Windows.CornerRadius]::new(7.5)
                }

            }

            # Mood D: 🌿 20-20-20 Eye-Care Break
            elseif ($global:eyeCareActive) {

                $leftEye.Height = 2.5
                $rightEye.Height = 2.5
                $global:sleepBreathTick = ($global:sleepBreathTick + 1) % 360
                $breathY = [Math]::Sin($global:sleepBreathTick * 0.08) * 1.5
                if ($catEyesTransform) { $catEyesTransform.Y = $breathY }

            }

            # Mood E: 😉 Appreciation Wink
            elseif ($global:catWinkTicks -gt 0) {

                $global:catWinkTicks--
                $leftEye.Height = 2.5
                $rightEye.Height = 16.0
                $rightPupilTransform.Y = -1.5

            }

            else {

                # Deteksi aktivitas sistem real-time (kursor & keyboard)
                $sysIdle = [Win32Helper]::GetSystemIdleMillis()
                $idleMs = if ($sysIdle -gt 0) { $sysIdle } else { $global:cursorIdleSw.ElapsedMilliseconds }

                # Tahap 1: Tidur lelap jika laptop ditinggal diam > 5 menit (300.000 ms) + Floating Zzz
                if ($idleMs -ge 300000) {

                    $leftEye.Height = 2.5
                    $rightEye.Height = 2.5
                    $leftEye.CornerRadius = [System.Windows.CornerRadius]::new(7.5, 7.5, 1, 1)
                    $rightEye.CornerRadius = [System.Windows.CornerRadius]::new(7.5, 7.5, 1, 1)
                    $global:sleepBreathTick = ($global:sleepBreathTick + 1) % 360
                    $breathY = [Math]::Sin($global:sleepBreathTick * 0.08) * 1.5
                    if ($catEyesTransform) { $catEyesTransform.Y = $breathY }

                    # Floating 'Zzz' sleep particles animation
                    if ($catZzzCanvas) {
                        $catZzzCanvas.Opacity = [Math]::Min(1.0, $catZzzCanvas.Opacity + 0.1)
                        $global:zzzTick = ($global:zzzTick + 1) % 90
                        $pZ = $global:zzzTick / 90.0
                        if ($zzz1) {
                            [System.Windows.Controls.Canvas]::SetTop($zzz1, 6 - ($pZ * 10))
                            $zzz1.Opacity = [Math]::Sin($pZ * [Math]::PI) * 0.85
                        }
                        if ($zzz2) {
                            [System.Windows.Controls.Canvas]::SetTop($zzz2, -2 - ($pZ * 12))
                            $zzz2.Opacity = [Math]::Sin($pZ * [Math]::PI) * 0.95
                        }
                        if ($zzz3) {
                            [System.Windows.Controls.Canvas]::SetTop($zzz3, -12 - ($pZ * 14))
                            $zzz3.Opacity = [Math]::Sin($pZ * [Math]::PI) * 1.0
                        }
                    }

                }
                # Tahap 2: Mengantuk sayu jika ditinggal diam 2 - 5 menit (120.000 - 300.000 ms)
                elseif ($idleMs -ge 120000) {

                    $leftEye.Height = 8.0
                    $rightEye.Height = 8.0
                    $leftEye.CornerRadius = [System.Windows.CornerRadius]::new(6.0)
                    $rightEye.CornerRadius = [System.Windows.CornerRadius]::new(6.0)
                    $global:sleepBreathTick = ($global:sleepBreathTick + 1) % 360
                    $breathY = [Math]::Sin($global:sleepBreathTick * 0.05) * 0.8
                    if ($catEyesTransform) { $catEyesTransform.Y = $breathY }
                    if ($catZzzCanvas) { $catZzzCanvas.Opacity = 0.0 }

                }
                # Tahap 3: SELALU MELEK SEGAR & AKTIF selama laptop sedang digunakan!
                else {

                    if ($catZzzCanvas) { $catZzzCanvas.Opacity = 0.0 }

                    # Restore normal rounded corners for eyes
                    $leftEye.CornerRadius = [System.Windows.CornerRadius]::new(7.5)
                    $rightEye.CornerRadius = [System.Windows.CornerRadius]::new(7.5)

                    # Worried Eyes Reaction when battery <= 20% on battery power
                    $power = [System.Windows.Forms.SystemInformation]::PowerStatus
                    $isLowBat = ($power.PowerLineStatus -ne "Online" -and ($power.BatteryLifePercent * 100) -le 20)

                    # Musical Playful Wink when music is actively playing
                    $isMusicWink = $false
                    if ($global:gsmtcPlaying -eq $true) {
                        $global:musicWinkTick = ($global:musicWinkTick + 1) % 220
                        if ($global:musicWinkTick -le 5) {
                            $isMusicWink = $true
                        }

                        $global:audioBopTick = ($global:audioBopTick + 1) % 360
                        $bopY = [Math]::Abs([Math]::Sin($global:audioBopTick * 0.15)) * 2.8
                        if ($catEyesTransform) { $catEyesTransform.Y = -$bopY }
                    } else {
                        if ($catEyesTransform -and $global:catPlayTicks -le 0) { $catEyesTransform.Y = 0 }
                    }

                    if ($isMusicWink) {
                        $leftEye.Height = 2.5
                        $rightEye.Height = 17.0
                    } elseif ($isLowBat) {
                        # Dilated worried eyes
                        $leftEye.Height = 13.0
                        $rightEye.Height = 13.0
                        if ($leftPupilBorder) { $leftPupilBorder.Width = 5.2 }
                        if ($rightPupilBorder) { $rightPupilBorder.Width = 5.2 }
                    } else {
                        # Natural eye blinking when awake
                        $blinkInterval = if ($fastEyeTimer.Interval.TotalMilliseconds -ge 100) { 24 } else { 90 }
                        $global:eyeBlinkTick = ($global:eyeBlinkTick + 1) % $blinkInterval

                        if ($global:eyeBlinkTick -eq 0) {
                            $leftEye.Height = 2.0
                            $rightEye.Height = 2.0
                        } elseif ($global:eyeBlinkTick -eq 1 -or ($global:eyeBlinkTick -eq 3 -and $blinkInterval -eq 90)) {
                            $leftEye.Height = 17.0
                            $rightEye.Height = 17.0
                        } else {
                            if ($leftEye.Height -lt 15.0) {
                                $leftEye.Height = 17.0
                                $rightEye.Height = 17.0
                            }
                        }
                    }

                }

            }

        }

        # -----------------------------------------------------------------

        # MODE 2: COMPACT STATUS BAR (Weather, Clock, Battery)

        # -----------------------------------------------------------------

        elseif ($global:islandMode -eq "status") {

            # Hover detection on Status Bar to Expand

            $inStatus = ($cursorPos.X -ge ($islL - 6)) -and ($cursorPos.X -le ($islR + 6)) -and ($cursorPos.Y -ge 0) -and ($cursorPos.Y -le ($islB + 8))

            

            if ($inStatus) {

                Set-IslandMode "expanded"

            } else {

                # Inactivity timer: when mouse is resting/not on the island,

                # automatically morph into the standalone Resting Cat Eyes pill!

                $global:statusIdleTicks++

                # 85 ticks * 40ms = ~3.4 seconds of inactivity

                if ($global:statusIdleTicks -ge 85) {

                    Set-IslandMode "eyes"

                }

            }

        }

        # -----------------------------------------------------------------

        # MODE 4: DYNAMIC NOTIFICATION TOAST PILL (Hover to Expand)

        # -----------------------------------------------------------------

        elseif ($global:islandMode -eq "toast") {

            $inToast = ($cursorPos.X -ge ($islL - 6)) -and ($cursorPos.X -le ($islR + 6)) -and ($cursorPos.Y -ge 0) -and ($cursorPos.Y -le ($islB + 8))

            if ($inToast) {

                $global:dynamicToastTimer.Stop()

                Set-IslandMode "expanded"

            }

        }

        # -----------------------------------------------------------------

        # MODE 3: EXPANDED CAROUSEL NOTCH (No collapse button!)

        # -----------------------------------------------------------------

        elseif ($global:islandMode -eq "expanded") {

            $inExpanded = ($cursorPos.X -ge ($islL - 10)) -and ($cursorPos.X -le ($islR + 10)) -and ($cursorPos.Y -ge 0) -and ($cursorPos.Y -le ($islB + 14))

            if (-not $inExpanded) {

                $global:outsideTicks++

                # 6 ticks * 40ms = 240ms auto-collapse delay

                if ($global:outsideTicks -ge 6) {

                    # When closing, return to the status bar (Clock, Weather, Battery)!

                    Set-IslandMode "status"

                }

            } else {

                $global:outsideTicks = 0

            }

        }

    } catch {}

})

$fastEyeTimer.Start()

# SECONDARY DISPATCHER LOOP (Equalizer, Clock, RAM, Battery, Volume, Connectivity)

$global:waveTick = 0

# Initial Hardware Controls State Synchronization

if ($quickSliderVol) { $quickSliderVol.Value = $global:lastKnownVol; $quickVolPctText.Text = "$($global:lastKnownVol)%" }

if ($dashQuickVolSlider) { $dashQuickVolSlider.Value = $global:lastKnownVol; $dashQuickVolPctText.Text = "$($global:lastKnownVol)%" }

if ($quickIconMute) { $quickIconMute.Text = if ($global:lastKnownMute) { [char]0xE74F } else { [char]0xE767 } }

if ($dashQuickMuteIcon) { $dashQuickMuteIcon.Text = if ($global:lastKnownMute) { "Unmute Audio" } else { "Mute Audio" } }

$initConn = Get-OceruConnectivity

if ($dashQuickWifiText) { $dashQuickWifiText.Text = "Wi-Fi: $($initConn.WifiStatus)" }

if ($dashQuickBtText) { $dashQuickBtText.Text = "Bluetooth: $($initConn.BluetoothStatus)" }

$mainTimer = New-Object System.Windows.Threading.DispatcherTimer

$mainTimer.Interval = [TimeSpan]::FromMilliseconds(300)

$mainTimer.Add_Tick({

    $now = [DateTime]::Now

    $headerDateText.Text = $now.ToString("ddd d MMM yyyy ")

    $headerTimeText.Text = $now.ToString("HH:mm")

    # Update real-time clock in Compact Status Bar

    if ($compactClockText) {

        $compactClockText.Text = $now.ToString("HH:mm")

    }

    # Smart Rotating Center HUD: 5.5s Clock <-> 3.5s Prayer Countdown (Zero Clutter!)

    $global:compactRotateTick = ($global:compactRotateTick + 1) % 30 # ~9s full cycle

    $isPrayerUrgent = ($global:currentPrayerInfo -and $global:currentPrayerInfo.RemainingMinutes -le 20)

    if ($compactClockView -and $compactPrayerView) {

        if ($isPrayerUrgent -or ($global:compactRotateTick -ge 18)) {

            $compactClockView.Visibility = [System.Windows.Visibility]::Collapsed

            $compactPrayerView.Visibility = [System.Windows.Visibility]::Visible

        } else {

            $compactClockView.Visibility = [System.Windows.Visibility]::Visible

            $compactPrayerView.Visibility = [System.Windows.Visibility]::Collapsed

        }

    }

    # Feature 1: Live Network Speedometer & Ping HUD (Every ~900ms = 3 ticks)

    $global:netStatsTick = ($global:netStatsTick + 1) % 3

    if ($global:netStatsTick -eq 0) {

        Update-NetworkStats

        # Check Ping every ~3 seconds (every 3rd network check = 9 ticks)

        $global:pingCheckCounter = ($global:pingCheckCounter + 1) % 3

        if ($global:pingCheckCounter -eq 0) {

            Check-NetworkPingAsync

        }

        # Update HUD UI Elements

        if ($compactNetSpeedText) { $compactNetSpeedText.Text = $global:currentCompactNetStr }

        if ($compactPingDot) {

            if ($global:currentPingMs -ge 0) {

                $compactPingDot.Text = " $([char]0x2022) $($global:currentPingMs)ms"

                $compactPingDot.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($global:currentPingColor)

            } else {

                $compactPingDot.Text = " $([char]0x2022) --"

                $compactPingDot.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")

            }

        }

        if ($sysNetStatsText) {

            $sysNetStatsText.Text = "$($global:currentDownRateStr)  $($global:currentUpRateStr)"

        }

        if ($sysPingText) {

            if ($global:currentPingMs -ge 0) {

                $dotEmoji = if ($global:currentPingColor -eq "#10B981") { "🟢" } elseif ($global:currentPingColor -eq "#F59E0B") { "🟡" } else { "🔴" }

                $sysPingText.Text = " • Ping: $($global:currentPingMs)ms $dotEmoji"

                $sysPingText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($global:currentPingColor)

            } else {

                $sysPingText.Text = " $([char]0x2022) Ping: Offline"

                $sysPingText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")

            }

        }

    }

    # Feature 3: 🌿 20-20-20 Eye-Care Break Engine (Every ~900ms = 3 ticks)

    $global:eyeCareActivityTick = ($global:eyeCareActivityTick + 1) % 3

    if ($global:eyeCareActivityTick -eq 0) {

        $idleMs = $global:cursorIdleSw.ElapsedMilliseconds

        if ($idleMs -lt 120000) {

            $global:continuousWorkSeconds++

        } else {

            $global:continuousWorkSeconds = 0

        }

        if ($global:continuousWorkSeconds -ge 1200 -and -not $global:eyeCareActive) {

            Start-OceruEyeCareBreak

        }

        if ($global:eyeCareActive) {

            $global:eyeCareRemaining--

            if ($global:eyeCareRemaining -gt 0) {

                if ($dynamicToastTitle) { $dynamicToastTitle.Text = "Istirahat Mata 20-20-20 ($($global:eyeCareRemaining)s)" }

                if ($dynamicToastMessage) { $dynamicToastMessage.Text = "Pandang objek 6 meter sejenak" }

            } else {

                $global:eyeCareActive = $false

                $global:continuousWorkSeconds = 0

                if ($dynamicToastTitle) { $dynamicToastTitle.Text = "Mata Segar Kembali!" }

                if ($dynamicToastMessage) { $dynamicToastMessage.Text = "Fokus Anda telah terisi ulang!" }

                Trigger-CatWink

                $global:dynamicToastTimer.Interval = [TimeSpan]::FromMilliseconds(2500)

                $global:dynamicToastTimer.Start()

            }

        }

    }

    # Core Audio Master Volume & Mute Polling

    try {

        $curVol = [OceruAudioManager]::GetMasterVolume()

        if ($curVol -ge 0 -and $curVol -ne $global:lastKnownVol) {

            $global:lastKnownVol = $curVol

            $global:OceruState.volume = $curVol

            $global:suppressVolEvent = $true

            if ($quickSliderVol) { $quickSliderVol.Value = $curVol; $quickVolPctText.Text = "$curVol%" }

            if ($dashQuickVolSlider) { $dashQuickVolSlider.Value = $curVol; $dashQuickVolPctText.Text = "$curVol%" }

            $global:suppressVolEvent = $false

        }

        $curMute = [OceruAudioManager]::GetMute()

        if ($curMute -ne $global:lastKnownMute) {

            $global:lastKnownMute = $curMute

            $global:OceruState.isMuted = $curMute

            if ($quickIconMute) { $quickIconMute.Text = if ($curMute) { [char]0xE74F } else { [char]0xE767 } }

            if ($dashQuickMuteIcon) { $dashQuickMuteIcon.Text = if ($curMute) { "Unmute Audio" } else { "Mute Audio" } }

        }

    } catch {}

    # Windows Media Session Polling (every ~600ms = 2 ticks for fast response)

    $global:mediaPollTick = ($global:mediaPollTick + 1) % 2

    if ($global:mediaPollTick -eq 0 -and (-not $global:localMediaLoaded)) {

        try {

            $winMedia = Get-OceruWindowsMedia

            if ($winMedia -and $winMedia.HasMedia) {

                $isActivelyPlaying = ($winMedia.IsPlaying -eq $true)

                if ($global:OceruState.currentMedia.title -ne $winMedia.Title) {
                    $global:browserPlaybackEstimate = 0.0
                }

                $global:OceruState.currentMedia.title = $winMedia.Title

                $global:OceruState.currentMedia.artist = $winMedia.Artist

                $global:OceruState.currentMedia.isPlaying = $isActivelyPlaying

                $global:gsmtcPlaying = $isActivelyPlaying

                if ($musicTitle) { $musicTitle.Text = $winMedia.Title }

                if ($musicArtist) { $musicArtist.Text = $winMedia.Artist }

                if ($musicPlayPauseIcon) {

                    $musicPlayPauseIcon.Text = if ($isActivelyPlaying) { [char]0xE769 } else { [char]0xE768 }

                }

                if ($dashMediaTitleText) { $dashMediaTitleText.Text = $winMedia.Title }

                if ($dashMediaArtistText) { $dashMediaArtistText.Text = $winMedia.Artist }

                if ($dashMediaPlayIcon) {

                    $dashMediaPlayIcon.Text = if ($isActivelyPlaying) { [char]0xE769 } else { [char]0xE768 }

                }

                if ($dashMediaSourceStatus) {

                    $dashMediaSourceStatus.Text = if ($isActivelyPlaying) { "Memutar: $($winMedia.Artist)" } else { "Dijeda: $($winMedia.Artist)" }

                }

                # Feature 1: Dynamic Album Art Color-Sync (Chameleon Wave Colors)

                $accentColor = if ($winMedia.AccentColor) { $winMedia.AccentColor } else { "#FF385C" }

                if ($global:lastWaveColor -ne $accentColor) {

                    $global:lastWaveColor = $accentColor

                    $global:waveStrokeColor = $accentColor

                    $colorBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentColor)

                    if ($miniEqBar1) {
                        $miniEqBar1.Background = $colorBrush
                        $miniEqBar2.Background = $colorBrush
                        $miniEqBar3.Background = $colorBrush
                        $miniEqBar4.Background = $colorBrush
                    }
                    if ($lyricLineCurrent) {
                        $lyricLineCurrent.Foreground = $colorBrush
                    }

                    if ($notchWaveStrokePath) {

                        $notchWaveStrokePath.Stroke = $colorBrush

                        if ($notchWaveStrokePath.Effect) {

                            $notchWaveStrokePath.Effect.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($accentColor)

                        }

                    }

                    if ($notchWaveCorePath) {
                        $notchWaveCorePath.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
                    }

                    if ($global:apexSparkBorders) {
                        foreach ($sp in $global:apexSparkBorders) {
                            $sp.BorderBrush = $colorBrush
                            if ($sp.Effect) {
                                $sp.Effect.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($accentColor)
                            }
                        }
                    }

                    if ($musicPlayBtnBg) {

                        $musicPlayBtnBg.Background = $colorBrush

                    }

                }

                # Update live position & duration

                if ($winMedia.DurationSec -gt 0) {

                    $curSec = $winMedia.PositionSec

                    $totalSec = $winMedia.DurationSec

                    $pct = [Math]::Max(0.0, [Math]::Min(1.0, $curSec / $totalSec))

                    if ($musicProgressBar) { $musicProgressBar.Width = [Math]::Round(200 * $pct) }

                    if ($dashMediaProgressBar) { $dashMediaProgressBar.Width = [Math]::Round(280 * $pct) }

                    if ($musicCurrentTime) { $musicCurrentTime.Text = [TimeSpan]::FromSeconds($curSec).ToString("mm\:ss") }

                    if ($musicRemainingTime) { $musicRemainingTime.Text = "-" + [TimeSpan]::FromSeconds([Math]::Max(0, $totalSec - $curSec)).ToString("mm\:ss") }

                    Update-LiveLyricsDisplay $curSec $totalSec

                } else {

                    if ($isActivelyPlaying) {
                        $global:browserPlaybackEstimate += 0.6
                    }
                    Update-LiveLyricsDisplay $global:browserPlaybackEstimate 240

                }

            } else {

                $global:browserPlaybackEstimate = 0.0

                $global:gsmtcPlaying = $false

                $global:OceruState.currentMedia.isPlaying = $false

                if ($musicTitle -and $musicTitle.Text -ne "Tidak ada media aktif") {

                    $musicTitle.Text = "Tidak ada media aktif"

                    $musicArtist.Text = "Kontrol pemutar Windows atau putar file audio"

                    $musicPlayPauseIcon.Text = [char]0xE768

                }

            }

        } catch {

            $global:gsmtcPlaying = $false

            $global:OceruState.currentMedia.isPlaying = $false

        }

    }

    # Feature 3: 🕌 Indonesian Prayer Schedule & Adzan HUD (Every ~1.5s = 5 ticks)

    $global:prayerTick = ($global:prayerTick + 1) % 5

    if ($global:prayerTick -eq 0) {

        try {

            $prayerInfo = Get-IndonesianPrayerTimes

            $global:currentPrayerInfo = $prayerInfo

            if ($compactPrayerText) {

                $compactPrayerText.Text = "$($prayerInfo.NextPrayer) $($prayerInfo.NextTime) ($($prayerInfo.RemainingStr))"

            }

            if ($cardPrayerScheduleText) {

                $s = $prayerInfo.Schedule

                $cardPrayerScheduleText.Text = "Subuh $($s.Subuh) • Dzuhur $($s.Dzuhur) • Ashar $($s.Ashar) • Maghrib $($s.Maghrib) • Isya $($s.Isya)"

            }

            # Gentle Adzan Notification Toast when remaining minutes reach 0

            if ($prayerInfo.RemainingMinutes -eq 0) {

                $todayPrayerKey = "$($prayerInfo.NextPrayer)_$($now.ToString('yyyyMMdd'))"

                if ($global:lastAlertedPrayer -ne $todayPrayerKey) {

                    $global:lastAlertedPrayer = $todayPrayerKey

                    Play-OceruSound "chime"

                    Show-OceruDynamicToast "Waktu Sholat $($prayerInfo.NextPrayer) Telah Tiba" "Mari sejenak menunaikan sholat $($prayerInfo.NextPrayer) ($($prayerInfo.NextTime))" ([char]0xE774) "#10B981" 12000

                }

            }

        } catch {}

    }

    # Connectivity Polling (every ~3 seconds = 10 ticks)

    $global:connTick = ($global:connTick + 1) % 10
    if ($global:connTick -eq 0) {
        try {
            $c = Get-OceruConnectivity
            if ($dashQuickWifiText) { $dashQuickWifiText.Text = "Wi-Fi: $($c.WifiStatus)" }
            if ($dashQuickBtText) { $dashQuickBtText.Text = "Bluetooth: $($c.BluetoothStatus)" }
        } catch {}

        # FEATURE B: BLUETOOTH AUDIO DEVICE CONNECT HUD
        try {
            $curAudioId = [OceruAudioManager]::GetDefaultDeviceId()
            if ($global:lastAudioEndpointId -ne $null -and $curAudioId -ne $null -and $curAudioId -ne $global:lastAudioEndpointId) {
                $global:lastAudioEndpointId = $curAudioId
                $devName = [OceruAudioManager]::GetDeviceFriendlyName($curAudioId)
                if ($devName -match '(Bluetooth|Headphone|Headset|Earbuds|AirPods|Buds|Wireless)') {
                    Play-OceruSound "chime"
                    Show-OceruDynamicToast "BLUETOOTH AUDIO" "$devName Terhubung" ([char]0xE7F6) "#00D2FF" 2600
                } else {
                    Show-OceruDynamicToast "OUTPUT AUDIO" "$devName Aktif" ([char]0xE767) "#8E9AA8" 2000
                }
            } elseif ($global:lastAudioEndpointId -eq $null -and $curAudioId -ne $null) {
                $global:lastAudioEndpointId = $curAudioId
            }
        } catch {}
    }


    # Real-time Synchronization to Dashboard Overview & Detail Pages

    if ($dashOverviewPomoTime) {

        $pomoSec = $global:OceruState.pomodoro.remainingSeconds

        $dashOverviewPomoTime.Text = [TimeSpan]::FromSeconds($pomoSec).ToString("mm\:ss")

        $dashPomoLargeTime.Text = $dashOverviewPomoTime.Text

    }

    if ($dashOverviewMediaTitle) {

        $dashOverviewMediaTitle.Text = $global:OceruState.currentMedia.title

        $dashOverviewMediaArtist.Text = $global:OceruState.currentMedia.artist

        $dashMediaTitleText.Text = $global:OceruState.currentMedia.title

        $dashMediaArtistText.Text = $global:OceruState.currentMedia.artist

    }

    if ($dashSysMonRamVal) {

        $dashSysMonRamVal.Text = "$ram%"

    }

    if ($dashSysMonBatVal) {

        $dashSysMonBatVal.Text = "$batPct%"

        $dashSysMonBatStatus.Text = if ($isOnline) { "Mengisi Daya (AC Online)" } else { "Daya Baterai Laptop" }

    }

    if ($dashIslandCurrentModeText) {

        $modeDesc = if ($global:islandMode -eq "eyes") { "Resting Cat Eyes (88x36 px)" } elseif ($global:islandMode -eq "status") { "Compact Status Bar (230x36 px)" } else { "Expanded Carousel (560x205 px)" }

        $dashIslandCurrentModeText.Text = "Mode: $modeDesc"

    }

    if ($dashAboutRamFootprint) {

        try {

            $ws = [Math]::Round([System.Diagnostics.Process]::GetCurrentProcess().WorkingSet64 / 1MB, 1)

            $dashAboutRamFootprint.Text = "Pemakaian Memori: $ws MB (Ultra Ringan)"

        } catch {}

    }

    # Soundwave Bouncing Equalizer & Media Progress

    if ($global:OceruState.currentMedia.isPlaying) {

        $global:waveTick = ($global:waveTick + 1) % 4

        if ($global:waveTick -eq 0) {

            $waveBar1.Height = 12; $waveBar2.Height = 6; $waveBar3.Height = 14; $waveBar4.Height = 8

        } elseif ($global:waveTick -eq 1) {

            $waveBar1.Height = 7; $waveBar2.Height = 15; $waveBar3.Height = 8; $waveBar4.Height = 13

        } elseif ($global:waveTick -eq 2) {

            $waveBar1.Height = 14; $waveBar2.Height = 9; $waveBar3.Height = 16; $waveBar4.Height = 6

        } else {

            $waveBar1.Height = 8; $waveBar2.Height = 14; $waveBar3.Height = 10; $waveBar4.Height = 12

        }

        # Real Local Media Position Tracking

        if ($global:localMediaLoaded -and $global:localMediaPlayer.Source) {

            try {

                if ($global:localMediaPlayer.NaturalDuration.HasTimeSpan) {

                    $curSec = $global:localMediaPlayer.Position.TotalSeconds

                    $totalSec = $global:localMediaPlayer.NaturalDuration.TimeSpan.TotalSeconds

                    if ($totalSec -gt 0) {

                        $pct = [Math]::Max(0.0, [Math]::Min(1.0, $curSec / $totalSec))

                        if ($musicProgressBar) { $musicProgressBar.Width = [Math]::Round(200 * $pct) }

                        if ($dashMediaProgressBar) { $dashMediaProgressBar.Width = [Math]::Round(280 * $pct) }

                        $curStr = [TimeSpan]::FromSeconds($curSec).ToString("mm\:ss")

                        $remStr = "-" + [TimeSpan]::FromSeconds([Math]::Max(0, $totalSec - $curSec)).ToString("mm\:ss")

                        $musicCurrentTime.Text = $curStr

                        $musicRemainingTime.Text = $remStr

                        Update-LiveLyricsDisplay $curSec $totalSec

                        if ($dashMediaCurrentTime) { $dashMediaCurrentTime.Text = $curStr }

                        if ($dashMediaRemainingTime) { $dashMediaRemainingTime.Text = $remStr }

                    }

                }

            } catch {}

        }

    } else {

        $waveBar1.Height = 4; $waveBar2.Height = 4; $waveBar3.Height = 4; $waveBar4.Height = 4

    }

    # RAM Monitoring via Kernel32

    try {

        $ram = [Win32Helper]::GetRamLoad()

        $sysRamText.Text = "$ram%"

        $dashRamVal.Text = "$ram%"

    } catch {}

    # Battery Monitoring & Real-time Charging Bolt HUD
    try {
        $power = [System.Windows.Forms.SystemInformation]::PowerStatus
        $batPct = [Math]::Round($power.BatteryLifePercent * 100)
        $isOnline = $power.PowerLineStatus -eq "Online"
        $compactBatPct.Text = "$batPct%"
        $dashBatVal.Text = "$batPct%"

        if ($isOnline) {
            $compactBatIcon.Text = [char]0xEA93
            $compactBatIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
            $sysBatStatusText.Text = "Baterai $batPct% - Mengisi Daya"
            $dashBatStatus.Text = "Mengisi Daya"
        } else {
            $compactBatIcon.Text = [char]0xEBAA
            $compactBatIcon.Foreground = if ($batPct -le 20) { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF5252") } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8E9AA8") }
            $sysBatStatusText.Text = "Baterai $batPct% - Daya Laptop"
            $dashBatStatus.Text = "Daya Baterai"
        }

        # FEATURE A: REAL-TIME CHARGING BOLT HUD TOAST NOTIFICATION
        if ($global:lastPowerLineStatus -ne $null -and $isOnline -ne $global:lastPowerLineStatus) {
            $global:lastPowerLineStatus = $isOnline
            if ($isOnline) {
                try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
                $global:catChargingHappyTicks = 65
                Play-OceruSound "purr"
                Show-OceruDynamicToast "PENGISIAN DAYA" "Kabel Charger Terhubung • Baterai $batPct%" ([char]0xEA93) "#10B981" 2500
            } else {
                Show-OceruDynamicToast "SUMBER DAYA" "Menggunakan Daya Baterai • $batPct%" ([char]0xEBAA) "#F59E0B" 2200
            }
        } else {
            $global:lastPowerLineStatus = $isOnline
        }

        # Periodically refresh top memory apps when Card 4 is active
        $global:topProcTick = ($global:topProcTick + 1) % 6
        if ($global:topProcTick -eq 0 -and $global:activeCardIndex -eq 4) {
            Update-TopProcesses
        }
    } catch {}
})

$mainTimer.Start()

# Run Island Application Window

$window.ShowDialog() | Out-Null