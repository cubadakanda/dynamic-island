Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

# Embedded Native Win32 Helper for Hardware, Memory & Power Control
$win32Code = @"
using System;
using System.Runtime.InteropServices;

public class Win32Helper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool LockWorkStation();

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessageW(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);

    public const int WM_APPCOMMAND = 0x0319;
    public const int APPCOMMAND_VOLUME_MUTE = 0x80000;
    public const int APPCOMMAND_VOLUME_UP = 0xa0000;
    public const int APPCOMMAND_VOLUME_DOWN = 0x90000;

    public static void ToggleMute() {
        SendMessageW(new IntPtr(0xffff), WM_APPCOMMAND, IntPtr.Zero, new IntPtr(APPCOMMAND_VOLUME_MUTE));
    }

    public static void VolumeUp() {
        SendMessageW(new IntPtr(0xffff), WM_APPCOMMAND, IntPtr.Zero, new IntPtr(APPCOMMAND_VOLUME_UP));
    }

    public static void VolumeDown() {
        SendMessageW(new IntPtr(0xffff), WM_APPCOMMAND, IntPtr.Zero, new IntPtr(APPCOMMAND_VOLUME_DOWN));
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
try { $PID | Out-File -FilePath $pidPath -Force -Encoding ASCII } catch {}

# Global Shared Application State
function Load-OceruState {
    if (Test-Path $statePath) {
        try {
            $raw = Get-Content $statePath -Raw -Encoding UTF8
            return ($raw | ConvertFrom-Json)
        } catch {}
    }
    # Default State
    return [PSCustomObject]@{
        theme = "ocean-dark"
        accentColor = "#00D2FF"
        dndEnabled = $false
        gamingMode = $false
        islandPosition = "top-center"
        islandWidth = 185
        islandOpacity = 0.95
        autoCollapseSeconds = 5
        language = "id"
        volume = 75
        isMuted = $false
        currentMedia = [PSCustomObject]@{
            title = "Never Gonna Give You Up"
            artist = "Rick Astley • YouTube Music"
            isPlaying = $false
            progress = 42
        }
        pomodoro = [PSCustomObject]@{
            mode = "focus"
            remainingSeconds = 1500
            isRunning = $false
        }
        stopwatch = [PSCustomObject]@{
            elapsedSeconds = 0
            isRunning = $false
            laps = @()
        }
        countdown = [PSCustomObject]@{
            totalSeconds = 300
            remainingSeconds = 300
            isRunning = $false
        }
        notes = @(
            [PSCustomObject]@{ id = 1; title = "Catatan Proyek Oceru"; content = "Desain antarmuka Ocean Azure Glass dengan integrasi kontrol hardware Windows."; updatedAt = "2026-10-24 23:30" }
        )
        tasks = @(
            [PSCustomObject]@{ id = 1; text = "Desain UI bertema Ocean Azure Glass"; done = $true },
            [PSCustomObject]@{ id = 2; text = "Hubungkan slider volume dan flyout Wi-Fi"; done = $true },
            [PSCustomObject]@{ id = 3; text = "Kembangkan Dashboard 15 destinasi"; done = $false }
        )
        clipboard = @(
            [PSCustomObject]@{ text = "https://github.com/cubadakanda/dynamic-island"; pinned = $true },
            [PSCustomObject]@{ text = "Oceru Dynamic Island Desktop"; pinned = $false },
            [PSCustomObject]@{ text = "Never Gonna Give You Up - Rick Astley"; pinned = $false }
        )
        quickLauncher = @(
            [PSCustomObject]@{ name = "Google Chrome"; path = "chrome.exe"; icon = "Web" },
            [PSCustomObject]@{ name = "File Explorer"; path = "explorer.exe"; icon = "Files" },
            [PSCustomObject]@{ name = "Terminal PowerShell"; path = "powershell.exe"; icon = "CLI" },
            [PSCustomObject]@{ name = "Task Manager"; path = "taskmgr.exe"; icon = "Task" },
            [PSCustomObject]@{ name = "Windows Settings"; path = "ms-settings:"; icon = "Config" }
        )
        notifications = @(
            [PSCustomObject]@{ id = 1; title = "Selamat Datang di Oceru"; message = "Oceru Dynamic Island telah aktif di desktop Windows."; time = "23:45"; read = $false }
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

$screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
$winWidth = 660
$leftPos = [Math]::Round(($screenWidth - $winWidth) / 2)

# XAML 1: DYNAMIC ISLAND & EXPANDED QUICK PANEL (Top Center Screen)
$islandXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Oceru Dynamic Island"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="True"
        ShowInTaskbar="False"
        WindowStartupLocation="Manual"
        Top="0" Width="660" Height="270">
    <Window.Resources>
        <!-- Inactive Tab Button -->
        <Style x:Key="NavIconBtn" TargetType="Button">
            <Setter Property="Background" Value="#0B1220"/>
            <Setter Property="Foreground" Value="#7888A6"/>
            <Setter Property="Width" Value="32"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="Margin" Value="0,0,4,0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#17243B"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Active Tab Pill Button (Ocean Azure Gradient) -->
        <Style x:Key="ActiveNavBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Margin" Value="0,0,4,0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#00D2FF"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border CornerRadius="8">
                            <Border.Background>
                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                    <GradientStop Color="#0284C7" Offset="0"/>
                                    <GradientStop Color="#1E40AF" Offset="1"/>
                                </LinearGradientBrush>
                            </Border.Background>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Ocean Glass Card Style -->
        <Style x:Key="GlassCardBtn" TargetType="Button">
            <Setter Property="Background" Value="#0C1527"/>
            <Setter Property="BorderBrush" Value="#1E3150"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="VerticalContentAlignment" Value="Stretch"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="CardBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="12"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#00D2FF"/>
                                <Setter TargetName="CardBorder" Property="Background" Value="#111F38"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="CardBorder" Property="Background" Value="#16294A"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Quick Action Pill -->
        <Style x:Key="SysActionBtn" TargetType="Button">
            <Setter Property="Background" Value="#0C1527"/>
            <Setter Property="Foreground" Value="#CBD5E1"/>
            <Setter Property="BorderBrush" Value="#1E3150"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Height" Value="34"/>
            <Setter Property="Padding" Value="8,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="BtnBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="BtnBorder" Property="BorderBrush" Value="#38BDF8"/>
                                <Setter TargetName="BtnBorder" Property="Background" Value="#13223D"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Duration Preset Pill -->
        <Style x:Key="TimerPill" TargetType="Button">
            <Setter Property="Background" Value="#101D33"/>
            <Setter Property="Foreground" Value="#93C5FD"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Margin" Value="2,0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#223961"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="PillBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="PillBorder" Property="Background" Value="#0284C7"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid HorizontalAlignment="Center" VerticalAlignment="Top">
        
        <!-- Main Notch Container (Ocean Azure Glass Bezel) -->
        <Border x:Name="NotchBorder"
                Background="#070B14"
                BorderBrush="#172640"
                BorderThickness="1,0,1,1"
                CornerRadius="0,0,18,18"
                Width="185" Height="32"
                Cursor="Hand"
                AllowDrop="True">
            <Border.ContextMenu>
                <ContextMenu Background="#09101E" Foreground="#E2E8F0" BorderBrush="#1E3150" BorderThickness="1">
                    <MenuItem x:Name="MenuOpenDashboard" Header="Buka Dashboard Oceru (Penuh)" Foreground="#38BDF8" FontWeight="Bold"/>
                    <Separator Background="#1E3150"/>
                    <MenuItem x:Name="MenuReload" Header="Muat Ulang / Reload (F5)" Foreground="#93C5FD"/>
                    <MenuItem Header="Pilihan Tema Visual">
                        <MenuItem x:Name="CtxThemeDark" Header="Ocean Dark (Midnight Navy)" Foreground="#CBD5E1"/>
                        <MenuItem x:Name="CtxThemeGlass" Header="Aero Glassmorphism (Cyan)" Foreground="#38BDF8"/>
                        <MenuItem x:Name="CtxThemeCyber" Header="Neon Cyberpunk (Magenta)" Foreground="#F43F5E"/>
                    </MenuItem>
                    <Separator Background="#1E3150"/>
                    <MenuItem x:Name="MenuOpenWifi" Header="Panel Wi-Fi Windows" Foreground="#93C5FD"/>
                    <MenuItem x:Name="MenuOpenBt" Header="Pengaturan Bluetooth" Foreground="#93C5FD"/>
                    <MenuItem x:Name="MenuOpenFolder" Header="Buka Folder Proyek" Foreground="#CBD5E1"/>
                    <Separator Background="#1E3150"/>
                    <MenuItem x:Name="MenuExit" Header="Tutup Oceru Dynamic Island" Foreground="#F87171" FontWeight="SemiBold"/>
                </ContextMenu>
            </Border.ContextMenu>
            <Border.Effect>
                <DropShadowEffect BlurRadius="28" ShadowDepth="5" Opacity="0.9" Color="#000000"/>
            </Border.Effect>

            <Grid>
                <!-- 1. COMPACT ISLAND: Multi-Contextual Modes -->
                
                <!-- 1A: Idle Mode (Weather, Clock & Battery) -->
                <Grid x:Name="CompactIdleView" VerticalAlignment="Center" Margin="12,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    
                    <!-- Weather -->
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE706;" FontSize="10" Foreground="#FBBF24" Margin="0,0,3,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="WeatherSmallText" Text="28°" Foreground="#FDE68A" FontSize="10" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    </StackPanel>
                    
                    <!-- Digital Clock -->
                    <TextBlock Grid.Column="1" x:Name="ClockText" Text="23:50"
                               Foreground="#FFFFFF" FontWeight="Bold" FontSize="11"
                               HorizontalAlignment="Center" FontFamily="Segoe UI, Consolas"/>
                    
                    <!-- Battery & Mode Icons -->
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock x:Name="DndIconCompact" FontFamily="Segoe MDL2 Assets" Text="&#xE708;" FontSize="10" Foreground="#A78BFA" Margin="0,0,3,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                        <TextBlock x:Name="CollapsedBatIcon" FontFamily="Segoe MDL2 Assets" Text="&#xEBAA;" FontSize="11" Foreground="#38BDF8" Margin="0,0,2,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="CollapsedBatPct" Text="88%" Foreground="#94A3B8" FontSize="9" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    </StackPanel>
                </Grid>

                <!-- 1B: Resting Mode (Animated Glowing Eyes) -->
                <Grid x:Name="CompactRestingView" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Center">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Border x:Name="LeftEye" Width="6" Height="10" Background="#FFFFFF" CornerRadius="3" Margin="0,0,8,0">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="7" Color="#00D2FF" ShadowDepth="0" Opacity="0.85"/>
                            </Border.Effect>
                        </Border>
                        <Border x:Name="RightEye" Width="6" Height="10" Background="#FFFFFF" CornerRadius="3">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="7" Color="#00D2FF" ShadowDepth="0" Opacity="0.85"/>
                            </Border.Effect>
                        </Border>
                    </StackPanel>
                </Grid>

                <!-- 1C: Media Playback Mode (Compact Music Pill) -->
                <Grid x:Name="CompactMediaView" Visibility="Collapsed" VerticalAlignment="Center" Margin="10,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" FontFamily="Segoe MDL2 Assets" Text="&#xE189;" FontSize="10" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                    <TextBlock Grid.Column="1" x:Name="CompactTrackText" Text="Never Gonna Give You Up" Foreground="#FFFFFF" FontSize="10" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                    <TextBlock Grid.Column="2" x:Name="CompactWaveText" Text="|||" Foreground="#38BDF8" FontSize="9" Margin="4,0,0,0" VerticalAlignment="Center"/>
                </Grid>

                <!-- 1D: Timer Running Mode (Pomodoro / Stopwatch / Countdown) -->
                <Grid x:Name="CompactTimerView" Visibility="Collapsed" VerticalAlignment="Center" Margin="10,0">
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <TextBlock x:Name="CompactTimerIcon" FontFamily="Segoe MDL2 Assets" Text="&#xE916;" FontSize="11" Foreground="#10B981" Margin="0,0,6,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="CompactTimerText" Text="24:59" Foreground="#FFFFFF" FontSize="11" FontWeight="Bold" FontFamily="Segoe UI, Consolas" VerticalAlignment="Center"/>
                    </StackPanel>
                </Grid>

                <!-- 1E: Collapsed Dynamic Toast Popup -->
                <Grid x:Name="ToastView" Visibility="Collapsed" VerticalAlignment="Center" Margin="10,0">
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <TextBlock x:Name="ToastIcon" FontFamily="Segoe MDL2 Assets" Text="&#xE7F6;" FontSize="12" Foreground="#60A5FA" Margin="0,0,6,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="ToastText" Text="Perangkat Terhubung" Foreground="#FFFFFF" FontSize="10" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    </StackPanel>
                </Grid>

                <!-- 2. EXPANDED QUICK PANEL (Full Dashboard Navigation & Controls) -->
                <Grid x:Name="ExpandedView" Visibility="Collapsed" Margin="14,10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Top Bar: Segmented Tabs & Action Feedback -->
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <!-- Sleek Segmented Navigation (7 Core Quick Panes) -->
                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                            <!-- Tab 1: Control -->
                            <Button x:Name="BtnControl" Style="{StaticResource ActiveNavBtn}">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE770;" FontSize="11" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblControl" Text="Kontrol" FontSize="10" FontWeight="Bold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 2: Music -->
                            <Button x:Name="BtnMusic" Style="{StaticResource NavIconBtn}" ToolTip="Pemutar Musik">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE189;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblMusic" Text="Media" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 3: Lyrics -->
                            <Button x:Name="BtnLyrics" Style="{StaticResource NavIconBtn}" ToolTip="Lirik Sinkron">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE8BD;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblLyrics" Text="Lirik" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 4: Timer -->
                            <Button x:Name="BtnPomo" Style="{StaticResource NavIconBtn}" ToolTip="Fokus Timer &amp; Stopwatch">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE916;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblPomo" Text="Fokus" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 5: Clipboard -->
                            <Button x:Name="BtnClip" Style="{StaticResource NavIconBtn}" ToolTip="Riwayat Papan Klip">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE8C8;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblClip" Text="Klip" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 6: Notes -->
                            <Button x:Name="BtnTodo" Style="{StaticResource NavIconBtn}" ToolTip="Catatan &amp; To-Do">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE73E;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblTodo" Text="Catatan" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 7: Shelf -->
                            <Button x:Name="BtnShelf" Style="{StaticResource NavIconBtn}" ToolTip="File Shelf">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xED25;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblShelf" Text="Shelf" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                    <TextBlock x:Name="ShelfBadgeCount" Text="" Foreground="#00D2FF" FontWeight="Bold" FontSize="9"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                        <!-- Header Right Controls -->
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <!-- In-Notch Action Feedback Pill -->
                            <Border x:Name="ExpandedToastPill" Background="#0284C7" CornerRadius="7" Padding="7,3" Margin="0,0,6,0" Visibility="Collapsed">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock x:Name="ExpandedToastIcon" FontFamily="Segoe MDL2 Assets" Text="&#xE73E;" FontSize="9" Foreground="#FFFFFF" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="ExpandedToastText" Text="Aksi Berhasil" Foreground="#FFFFFF" FontSize="9" FontWeight="Bold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Border>

                            <!-- Dashboard Fullscreen Launcher Button -->
                            <Button x:Name="BtnLaunchDashboard" Background="#101D33" BorderBrush="#00D2FF" BorderThickness="1" Padding="7,3" Margin="0,0,6,0" Cursor="Hand" ToolTip="Buka Dashboard Lengkap 15 Halaman">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="7"/></Style></Button.Resources>
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7F4;" FontSize="9" Foreground="#00D2FF" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Dashboard" Foreground="#E0F2FE" FontSize="9" FontWeight="Bold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Bluetooth Pill -->
                            <Button x:Name="BtnHeaderBt" Background="#0C1527" BorderBrush="#1E3150" BorderThickness="1" Padding="6,3" Margin="0,0,5,0" Cursor="Hand" ToolTip="Kelola Bluetooth">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="7"/></Style></Button.Resources>
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7F6;" FontSize="9" Foreground="#60A5FA" Margin="0,0,3,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="BtBadge" Text="Bluetooth" Foreground="#93C5FD" FontSize="9" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Battery Pill -->
                            <Border Background="#091814" BorderBrush="#065F46" BorderThickness="1" CornerRadius="7" Padding="6,3" Margin="0,0,5,0">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock x:Name="HeaderBatIcon" FontFamily="Segoe MDL2 Assets" Text="&#xEBAA;" FontSize="9" Foreground="#10B981" Margin="0,0,3,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="HeaderBatText" Text="88%" Foreground="#6EE7B7" FontSize="9" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Border>

                            <TextBlock x:Name="DateText" Text="23:50" Foreground="#94A3B8" FontSize="10" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Grid>

                    <!-- Content Panes -->
                    <Grid Grid.Row="1">
                        
                        <!-- TAB 1: KONTROL (Grouped Connectivity, Audio Slider, Display, & System Actions) -->
                        <Grid x:Name="PaneControl" Visibility="Visible">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Row 1: Connectivity & Audio Master Slider -->
                            <Grid Grid.Row="0" Margin="0,0,0,6">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="1*"/>
                                    <ColumnDefinition Width="1*"/>
                                    <ColumnDefinition Width="1.35*"/>
                                </Grid.ColumnDefinitions>

                                <!-- 1. Wi-Fi Card -->
                                <Button x:Name="CardWifi" Grid.Column="0" Style="{StaticResource GlassCardBtn}" Margin="0,0,5,0" ToolTip="Buka Flyout Jaringan Wi-Fi Windows">
                                    <Grid VerticalAlignment="Center">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Border x:Name="IconBgWifi" Background="#0284C7" CornerRadius="9" Width="30" Height="30" Margin="0,0,8,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE701;" FontSize="12" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Wi-Fi" Foreground="#FFFFFF" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="StatusWifi" Text="Buka Jaringan &#x2197;" Foreground="#38BDF8" FontSize="8.5" Margin="0,1,0,0"/>
                                        </StackPanel>
                                    </Grid>
                                </Button>

                                <!-- 2. Bluetooth Card -->
                                <Button x:Name="CardBt" Grid.Column="1" Style="{StaticResource GlassCardBtn}" Margin="0,0,5,0" ToolTip="Buka Pengaturan Bluetooth Windows">
                                    <Grid VerticalAlignment="Center">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Border x:Name="IconBgBt" Background="#0284C7" CornerRadius="9" Width="30" Height="30" Margin="0,0,8,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7F6;" FontSize="12" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Bluetooth" Foreground="#FFFFFF" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="StatusBt" Text="Kelola TWS/Audio &#x2197;" Foreground="#38BDF8" FontSize="8.5" Margin="0,1,0,0"/>
                                        </StackPanel>
                                    </Grid>
                                </Button>

                                <!-- 3. Audio Master Volume with Live Slider -->
                                <Border x:Name="CardMuteBorder" Grid.Column="2" Background="#0C1527" BorderBrush="#1E3150" BorderThickness="1" CornerRadius="12" Padding="8,5">
                                    <Grid VerticalAlignment="Center">
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                        </Grid.RowDefinitions>
                                        
                                        <!-- Top: Mute Button + Volume Percentage -->
                                        <Grid Grid.Row="0" Margin="0,0,0,3">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <Button x:Name="CardMute" Background="Transparent" BorderThickness="0" Cursor="Hand" HorizontalAlignment="Left">
                                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                                    <TextBlock x:Name="IconMute" FontFamily="Segoe MDL2 Assets" Text="&#xE767;" FontSize="11" Foreground="#38BDF8" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                                    <TextBlock x:Name="StatusMute" Text="Volume Suara" Foreground="#FFFFFF" FontSize="10.5" FontWeight="Bold" VerticalAlignment="Center"/>
                                                </StackPanel>
                                            </Button>
                                            <TextBlock Grid.Column="1" x:Name="LblVolPct" Text="75%" Foreground="#94A3B8" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                        </Grid>

                                        <!-- Bottom: Interactive Slider & Step Buttons -->
                                        <Grid Grid.Row="1">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <Button x:Name="BtnVolDown" Grid.Column="0" Background="#13223D" BorderBrush="#223961" BorderThickness="1" Width="18" Height="18" Margin="0,0,4,0" Cursor="Hand" ToolTip="Turunkan Volume">
                                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="4"/></Style></Button.Resources>
                                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE74F;" FontSize="8" Foreground="#93C5FD" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Button>
                                            <Slider x:Name="SliderVol" Grid.Column="1" Minimum="0" Maximum="100" Value="75" Height="16" VerticalAlignment="Center"/>
                                            <Button x:Name="BtnVolUp" Grid.Column="2" Background="#13223D" BorderBrush="#223961" BorderThickness="1" Width="18" Height="18" Margin="4,0,0,0" Cursor="Hand" ToolTip="Naikkan Volume">
                                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="4"/></Style></Button.Resources>
                                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE767;" FontSize="8" Foreground="#93C5FD" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Button>
                                        </Grid>
                                    </Grid>
                                </Border>
                            </Grid>

                            <!-- Row 2: Modes & Display (DND, Gaming, Brightness, Task Manager) -->
                            <Grid Grid.Row="1" Margin="0,0,0,6">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <!-- DND Toggle -->
                                <Button x:Name="BtnToggleDnd" Grid.Column="0" Style="{StaticResource SysActionBtn}" Margin="0,0,4,0" ToolTip="Aktifkan Mode Jangan Ganggu">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border x:Name="BgDnd" Background="#1E1736" CornerRadius="5" Width="18" Height="18" Margin="0,0,6,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE708;" FontSize="9" Foreground="#C084FC" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock x:Name="LblDnd" Text="Jangan Ganggu" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- Gaming Mode Toggle -->
                                <Button x:Name="BtnToggleGame" Grid.Column="1" Style="{StaticResource SysActionBtn}" Margin="0,0,4,0" ToolTip="Optimalkan Performa untuk Game">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border x:Name="BgGame" Background="#112920" CornerRadius="5" Width="18" Height="18" Margin="0,0,6,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7FC;" FontSize="9" Foreground="#34D399" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock x:Name="LblGame" Text="Mode Game" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- Brightness Display Shortcut -->
                                <Button x:Name="BtnSysBright" Grid.Column="2" Style="{StaticResource SysActionBtn}" Margin="0,0,4,0" ToolTip="Buka Pengaturan Kecerahan Layar">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#2B2109" CornerRadius="5" Width="18" Height="18" Margin="0,0,6,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE706;" FontSize="9" Foreground="#FBBF24" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock Text="Kecerahan &#x2197;" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- Task Manager Shortcut -->
                                <Button x:Name="BtnSysTaskMgr" Grid.Column="3" Style="{StaticResource SysActionBtn}" ToolTip="Buka Task Manager Windows">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#0C2338" CornerRadius="5" Width="18" Height="18" Margin="0,0,6,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE9D9;" FontSize="9" Foreground="#38BDF8" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock Text="Task Manager" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </Grid>

                            <!-- Row 3: System & Power Actions (Lock, Sleep, Restart, Theme) -->
                            <Grid Grid.Row="2">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <!-- 1: Lock Workstation -->
                                <Button x:Name="BtnSysLock" Grid.Column="0" Style="{StaticResource SysActionBtn}" Margin="0,0,4,0" ToolTip="Kunci Layar Windows Seketika">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#102447" CornerRadius="5" Width="18" Height="18" Margin="0,0,6,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE72E;" FontSize="9" Foreground="#60A5FA" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock Text="Kunci Layar" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- 2: Sleep Mode -->
                                <Button x:Name="BtnSysSleep" Grid.Column="1" Style="{StaticResource SysActionBtn}" Margin="0,0,4,0" ToolTip="Masuk Mode Tidur (Sleep)">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#241347" CornerRadius="5" Width="18" Height="18" Margin="0,0,6,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE708;" FontSize="9" Foreground="#C084FC" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock Text="Mode Tidur" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- 3: Restart with Safe Confirmation -->
                                <Button x:Name="BtnSysRestart" Grid.Column="2" Style="{StaticResource SysActionBtn}" Margin="0,0,4,0" ToolTip="Restart Laptop (Dengan Konfirmasi)">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#3D1807" CornerRadius="5" Width="18" Height="18" Margin="0,0,6,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE777;" FontSize="9" Foreground="#FBBF24" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock x:Name="LblRestart" Text="Restart" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- 4: Theme Toggle -->
                                <Button x:Name="BtnThemeSwitch" Grid.Column="3" Style="{StaticResource SysActionBtn}" ToolTip="Ganti Tema Visual">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#06382C" CornerRadius="5" Width="18" Height="18" Margin="0,0,6,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE790;" FontSize="9" Foreground="#34D399" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock x:Name="LblTheme" Text="Ganti Tema" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </Grid>
                        </Grid>

                        <!-- TAB 2: MEDIA PLAYER (Playback, Progress, YouTube Search, Equalizer) -->
                        <Grid x:Name="PaneMusic" Visibility="Collapsed">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="58"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="185"/>
                            </Grid.ColumnDefinitions>

                            <Border Grid.Column="0" CornerRadius="12" Width="52" Height="52" HorizontalAlignment="Left">
                                <Border.Background>
                                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                        <GradientStop Color="#0284C7" Offset="0"/>
                                        <GradientStop Color="#4F46E5" Offset="0.5"/>
                                        <GradientStop Color="#E11D48" Offset="1"/>
                                    </LinearGradientBrush>
                                </Border.Background>
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="12" Color="#0284C7" ShadowDepth="2" Opacity="0.4"/>
                                </Border.Effect>
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE189;" FontSize="18" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>

                            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="10,0">
                                <TextBlock x:Name="TrackTitle" Text="Never Gonna Give You Up" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11.5" TextTrimming="CharacterEllipsis"/>
                                <TextBlock x:Name="TrackArtist" Text="Rick Astley • YouTube Music" Foreground="#94A3B8" FontSize="9" Margin="0,1,0,4"/>
                                
                                <Grid Margin="0,0,0,5">
                                    <ProgressBar x:Name="TrackProgress" Value="42" Maximum="100" Height="3" Background="#162238" Foreground="#00D2FF" BorderThickness="0"/>
                                </Grid>

                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <Button x:Name="BtnPrev" Background="Transparent" Foreground="#CBD5E1" BorderThickness="0" Margin="0,0,8,0" Cursor="Hand" ToolTip="Lagu Sebelumnya">
                                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE892;" FontSize="12"/>
                                    </Button>
                                    
                                    <Button x:Name="BtnPlay" Width="26" Height="26" Background="#0284C7" BorderThickness="0" Cursor="Hand" ToolTip="Putar / Jeda">
                                        <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="13"/></Style></Button.Resources>
                                        <TextBlock x:Name="PlayIcon" FontFamily="Segoe MDL2 Assets" Text="&#xE768;" FontSize="10" Foreground="#FFFFFF"/>
                                    </Button>
                                    
                                    <Button x:Name="BtnNext" Background="Transparent" Foreground="#CBD5E1" BorderThickness="0" Margin="8,0,10,0" Cursor="Hand" ToolTip="Lagu Selanjutnya">
                                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE893;" FontSize="12"/>
                                    </Button>
                                    
                                    <TextBox x:Name="YtInput" Text="Cari / paste link YouTube..."
                                             Foreground="#64748B" Background="#0C1527" BorderBrush="#1E3150"
                                             Padding="8,3" FontSize="9" Width="140" VerticalAlignment="Center">
                                        <TextBox.Resources><Style TargetType="{x:Type Border}"><Setter Property="CornerRadius" Value="6"/></Style></TextBox.Resources>
                                    </TextBox>
                                </StackPanel>
                            </StackPanel>

                            <!-- Synced Lyrics Preview Box -->
                            <Border Grid.Column="2" Background="#09101E" BorderBrush="#192A45" BorderThickness="1" CornerRadius="10" Padding="10,7">
                                <StackPanel VerticalAlignment="Center">
                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,3">
                                        <TextBlock Text="LIRIK SINKRON" Foreground="#64748B" FontSize="8" FontWeight="Bold"/>
                                        <TextBlock x:Name="WaveAnimText" Text=" &#x266B;" Foreground="#00D2FF" FontSize="9"/>
                                    </StackPanel>
                                    <TextBlock x:Name="MusicLyricMini" Text="Never gonna give you up... never gonna let you down"
                                               Foreground="#38BDF8" FontSize="9.5" FontWeight="SemiBold" TextWrapping="Wrap" LineHeight="13"/>
                                </StackPanel>
                            </Border>

                            <!-- Hidden Web Engine for YouTube Audio -->
                            <WebBrowser x:Name="AudioWebEngine" Width="0" Height="0" Visibility="Collapsed"/>
                        </Grid>

                        <!-- TAB 3: LIRIK SINKRON (Karaoke View) -->
                        <Grid x:Name="PaneLyrics" Visibility="Collapsed">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            
                            <Border Grid.Column="0" Background="#09101E" BorderBrush="#192A45" BorderThickness="1" CornerRadius="10" Padding="12,8" Margin="0,0,6,0">
                                <StackPanel VerticalAlignment="Center">
                                    <TextBlock Text="KARAOKE REAL-TIME" Foreground="#64748B" FontSize="8" FontWeight="Bold" Margin="0,0,0,3"/>
                                    <TextBlock x:Name="LyricLinePast" Text="I just wanna tell you how I'm feeling" Foreground="#64748B" FontSize="9.5" Margin="0,0,0,2"/>
                                    <TextBlock x:Name="LyricLineActive" Text="Gotta make you understand..." Foreground="#00D2FF" FontSize="12" FontWeight="Bold" Margin="0,0,0,2"/>
                                    <TextBlock x:Name="LyricLineNext" Text="Never gonna give you up" Foreground="#94A3B8" FontSize="9.5"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="1" Background="#09101E" BorderBrush="#192A45" BorderThickness="1" CornerRadius="10" Padding="12,8">
                                <StackPanel VerticalAlignment="Center">
                                    <TextBlock Text="METADATA AUDIO" Foreground="#64748B" FontSize="8" FontWeight="Bold" Margin="0,0,0,3"/>
                                    <TextBlock Text="Never Gonna Give You Up" Foreground="#FFFFFF" FontSize="11" FontWeight="Bold"/>
                                    <TextBlock Text="Rick Astley • LRCLIB Engine" Foreground="#94A3B8" FontSize="9.5" Margin="0,1,0,4"/>
                                    <TextBlock Text="Ketuk baris lirik untuk melompat ke bagian musik" Foreground="#64748B" FontSize="8.5"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- TAB 4: FOKUS & PENGATUR WAKTU (Pomodoro, Stopwatch, Countdown) -->
                        <Grid x:Name="PanePomo" Visibility="Collapsed">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="6,0">
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,2">
                                    <TextBlock x:Name="PomoStatus" Text="FOKUS AKTIF" Foreground="#10B981" FontSize="9" FontWeight="Bold" VerticalAlignment="Center"/>
                                    <TextBlock Text=" • Pilih durasi:" Foreground="#64748B" FontSize="9" VerticalAlignment="Center" Margin="4,0,5,0"/>
                                    <Button x:Name="BtnPill5" Content="5m" Style="{StaticResource TimerPill}"/>
                                    <Button x:Name="BtnPill10" Content="10m" Style="{StaticResource TimerPill}"/>
                                    <Button x:Name="BtnPill15" Content="15m" Style="{StaticResource TimerPill}"/>
                                    <Button x:Name="BtnPill25" Content="25m" Style="{StaticResource TimerPill}"/>
                                    <Button x:Name="BtnPill45" Content="45m" Style="{StaticResource TimerPill}"/>
                                </StackPanel>
                                <TextBlock x:Name="PomoTimer" Text="25:00" Foreground="#FFFFFF" FontSize="32" FontWeight="Bold" FontFamily="Segoe UI, Consolas"/>
                            </StackPanel>

                            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                <Button x:Name="BtnPomoStart" Content="Mulai" Background="#10B981" Foreground="#FFFFFF" FontWeight="Bold" Padding="12,5" BorderThickness="0" Margin="0,0,4,0" Cursor="Hand">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="7"/></Style></Button.Resources>
                                </Button>
                                <Button x:Name="BtnPomoReset" Content="Reset" Background="#13223D" Foreground="#CBD5E1" FontWeight="Bold" Padding="10,5" BorderThickness="0" Margin="0,0,4,0" Cursor="Hand">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="7"/></Style></Button.Resources>
                                </Button>
                                <Button x:Name="BtnPomoMode" Content="Istirahat" Background="#13223D" Foreground="#38BDF8" FontWeight="Bold" Padding="10,5" BorderThickness="0" Cursor="Hand">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="7"/></Style></Button.Resources>
                                </Button>
                            </StackPanel>
                        </Grid>

                        <!-- TAB 5: RIWAYAT PAPAN KLIP (Clipboard) -->
                        <Grid x:Name="PaneClip" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Grid.Row="0" Text="RIWAYAT PAPAN KLIP (KLIK UNTUK MENYALIN ULANG)" Foreground="#64748B" FontSize="8" FontWeight="Bold" Margin="0,0,0,4"/>
                            <StackPanel Grid.Row="1" x:Name="ClipListPanel">
                                <Button x:Name="BtnClipItem1" Style="{StaticResource GlassCardBtn}" Padding="8,4" Margin="0,0,0,3" ToolTip="Klik untuk salin">
                                    <TextBlock Text="https://github.com/cubadakanda/dynamic-island" Foreground="#93C5FD" FontSize="9.5"/>
                                </Button>
                                <Button x:Name="BtnClipItem2" Style="{StaticResource GlassCardBtn}" Padding="8,4" Margin="0,0,0,3" ToolTip="Klik untuk salin">
                                    <TextBlock Text="Oceru Dynamic Island Desktop" Foreground="#CBD5E1" FontSize="9.5"/>
                                </Button>
                                <Button x:Name="BtnClipItem3" Style="{StaticResource GlassCardBtn}" Padding="8,4" ToolTip="Klik untuk salin">
                                    <TextBlock Text="Never Gonna Give You Up - Rick Astley" Foreground="#94A3B8" FontSize="9.5"/>
                                </Button>
                            </StackPanel>
                        </Grid>

                        <!-- TAB 6: CATATAN & TO-DO -->
                        <Grid x:Name="PaneTodo" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <Grid Grid.Row="0" Margin="0,0,0,5">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="TodoInput" Text="Tulis catatan / tugas baru lalu tekan Enter..."
                                         Foreground="#64748B" Background="#09101E" BorderBrush="#192A45"
                                         Padding="8,4" FontSize="9.5">
                                    <TextBox.Resources><Style TargetType="{x:Type Border}"><Setter Property="CornerRadius" Value="6"/></Style></TextBox.Resources>
                                </TextBox>
                                <TextBlock Grid.Column="1" x:Name="TodoCounterText" Text="2 dari 3 selesai" Foreground="#10B981" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center" Margin="10,0,0,0"/>
                            </Grid>

                            <StackPanel Grid.Row="1" x:Name="TodoListPanel">
                                <Border Background="#09101E" BorderBrush="#192A45" BorderThickness="1" CornerRadius="6" Padding="7,3" Margin="0,0,0,3">
                                    <StackPanel Orientation="Horizontal">
                                        <CheckBox x:Name="Chk1" IsChecked="True" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                        <TextBlock x:Name="Txt1" Text="Desain UI bertema Ocean Azure Glass" Foreground="#64748B" TextDecorations="Strikethrough" FontSize="9.5" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Border>
                                <Border Background="#09101E" BorderBrush="#192A45" BorderThickness="1" CornerRadius="6" Padding="7,3" Margin="0,0,0,3">
                                    <StackPanel Orientation="Horizontal">
                                        <CheckBox x:Name="Chk2" IsChecked="True" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                        <TextBlock x:Name="Txt2" Text="Integrasi hardware: Wi-Fi flyout, Audio slider, Lock" Foreground="#64748B" TextDecorations="Strikethrough" FontSize="9.5" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Border>
                                <Border Background="#09101E" BorderBrush="#192A45" BorderThickness="1" CornerRadius="6" Padding="7,3">
                                    <StackPanel Orientation="Horizontal">
                                        <CheckBox x:Name="Chk3" IsChecked="False" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                        <TextBlock x:Name="Txt3" Text="Kembangkan Dashboard 15 destinasi lengkap" Foreground="#FFFFFF" FontSize="9.5" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </Grid>

                        <!-- TAB 7: FILE SHELF -->
                        <Grid x:Name="PaneShelf" Visibility="Collapsed">
                            <Border BorderBrush="#0284C7" BorderThickness="1.5" CornerRadius="10" Background="#09101E" Padding="10">
                                <Grid>
                                    <StackPanel x:Name="ShelfPlaceholder" VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xED25;" FontSize="18" Foreground="#00D2FF" HorizontalAlignment="Center"/>
                                        <TextBlock Text="Tarik &amp; lepas file ke sini untuk menyimpan sementara"
                                                   Foreground="#94A3B8" FontSize="10" Margin="0,3,0,0" HorizontalAlignment="Center"/>
                                        <TextBlock Text="File tetap aman di laptopmu dan bisa ditarik kembali ke chat atau email"
                                                   Foreground="#64748B" FontSize="8.5" Margin="0,1,0,0" HorizontalAlignment="Center"/>
                                    </StackPanel>
                                    
                                    <StackPanel x:Name="ShelfItemsList" Orientation="Horizontal" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </Grid>

                    </Grid>
                </Grid>

            </Grid>
        </Border>
    </Grid>
</Window>
'@

# XAML 2: FULL OCERU DASHBOARD WINDOW (15 Dedicated Destinations)
$dashXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Oceru Dashboard — Ocean Azure Glass"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Width="980" Height="650">
    <Window.Resources>
        <!-- Sidebar Navigation Button Style -->
        <Style x:Key="SidebarNavBtn" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#8EA2C6"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="Margin" Value="0,1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="SideBorder" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="SideBorder" Property="Background" Value="#14223A"/>
                                <Setter Property="Foreground" Value="#00D2FF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Active Sidebar Item Style -->
        <Style x:Key="ActiveSidebarNavBtn" TargetType="Button" BasedOn="{StaticResource SidebarNavBtn}">
            <Setter Property="Background" Value="#172A47"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>

        <!-- Dashboard Card Style -->
        <Style x:Key="DashCard" TargetType="Border">
            <Setter Property="Background" Value="#0C1527"/>
            <Setter Property="BorderBrush" Value="#1E3150"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Padding" Value="16"/>
        </Style>

        <!-- Primary Pill Button -->
        <Style x:Key="DashPrimaryBtn" TargetType="Button">
            <Setter Property="Background" Value="#0284C7"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <!-- Outer Frame with Ocean Azure Glass Drop Shadow -->
    <Border Background="#070B14" BorderBrush="#1C2F4D" BorderThickness="1" CornerRadius="18">
        <Border.Effect>
            <DropShadowEffect BlurRadius="36" ShadowDepth="8" Opacity="0.9" Color="#000000"/>
        </Border.Effect>

        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="42"/> <!-- Modern Drag Title Bar -->
                <RowDefinition Height="*"/>  <!-- Main Content -->
            </Grid.RowDefinitions>

            <!-- 1. Custom Title Bar -->
            <Border Grid.Row="0" x:Name="DashTitleBar" Background="#0A1220" BorderBrush="#172640" BorderThickness="0,0,0,1" CornerRadius="18,18,0,0">
                <Grid Margin="16,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <!-- Brand / App Info -->
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <Border Background="#0284C7" Width="18" Height="18" CornerRadius="5" Margin="0,0,8,0">
                            <TextBlock Text="O" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="Oceru Dashboard" Foreground="#FFFFFF" FontWeight="Bold" FontSize="12" VerticalAlignment="Center"/>
                        <Border Background="#0B2638" BorderBrush="#00D2FF" BorderThickness="1" CornerRadius="5" Padding="5,1" Margin="8,0,0,0" VerticalAlignment="Center">
                            <TextBlock Text="Ocean Azure Glass" Foreground="#38BDF8" FontSize="9" FontWeight="SemiBold"/>
                        </Border>
                    </StackPanel>

                    <!-- Window Control Buttons (Minimize, Close) -->
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="BtnDashMin" Background="Transparent" Foreground="#8EA2C6" BorderThickness="0" Width="28" Height="28" Cursor="Hand" ToolTip="Minimize">
                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE921;" FontSize="10"/>
                        </Button>
                        <Button x:Name="BtnDashClose" Background="Transparent" Foreground="#F87171" BorderThickness="0" Width="28" Height="28" Cursor="Hand" Margin="4,0,0,0" ToolTip="Tutup Dashboard">
                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE8BB;" FontSize="10"/>
                        </Button>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- 2. Main Body Grid: Sidebar + Viewport -->
            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="220"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Left Sidebar (15 Destinations) -->
                <Border Grid.Column="0" Background="#09101E" BorderBrush="#172640" BorderThickness="0,0,1,0" Padding="10,12">
                    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <StackPanel>
                            <TextBlock Text="MENU UTAMA" Foreground="#64748B" FontSize="8.5" FontWeight="Bold" Margin="10,0,0,6"/>
                            
                            <!-- Destination 1: Overview -->
                            <Button x:Name="NavOverview" Style="{StaticResource ActiveSidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE80F;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Ringkasan (Overview)" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 2: Dynamic Island -->
                            <Button x:Name="NavIsland" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7F4;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Dynamic Island" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 3: Media -->
                            <Button x:Name="NavMedia" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE189;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Media &amp; Lirik" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 4: Pomodoro -->
                            <Button x:Name="NavPomo" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE916;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Fokus Pomodoro" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 5: Stopwatch -->
                            <Button x:Name="NavStopwatch" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE823;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Stopwatch" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 6: Countdown -->
                            <Button x:Name="NavCountdown" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE787;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Hitung Mundur" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <TextBlock Text="PRODUKTIVITAS &amp; ALAT" Foreground="#64748B" FontSize="8.5" FontWeight="Bold" Margin="10,12,0,6"/>

                            <!-- Destination 7: System Monitor -->
                            <Button x:Name="NavSysMon" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE9D9;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Monitor Sistem" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 8: Notifications -->
                            <Button x:Name="NavNotif" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xEA8F;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Pusat Notifikasi" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 9: Notes -->
                            <Button x:Name="NavNotes" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE70B;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Catatan (Notes)" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 10: To-Do -->
                            <Button x:Name="NavTodo" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE73E;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Daftar Tugas (To-Do)" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 11: Clipboard -->
                            <Button x:Name="NavClip" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE8C8;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Papan Klip" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <TextBlock Text="PENGATURAN &amp; SISTEM" Foreground="#64748B" FontSize="8.5" FontWeight="Bold" Margin="10,12,0,6"/>

                            <!-- Destination 12: Quick Settings -->
                            <Button x:Name="NavQuickSet" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE770;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Pengaturan Cepat" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 13: Quick Launcher -->
                            <Button x:Name="NavQuickLaunch" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xEC5A;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Peluncur Cepat" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 14: Settings -->
                            <Button x:Name="NavSettings" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE713;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Pengaturan" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Destination 15: About -->
                            <Button x:Name="NavAbout" Style="{StaticResource SidebarNavBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE946;" FontSize="12" Margin="0,0,9,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Tentang Oceru" FontSize="11" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </ScrollViewer>
                </Border>

                <!-- Right Viewport: Destination Content Panes -->
                <Grid Grid.Column="1" Margin="24,18">
                    
                    <!-- PAGE 1: OVERVIEW (Ringkasan Sistem & Status) -->
                    <Grid x:Name="PageOverview" Visibility="Visible">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- Header -->
                        <StackPanel Grid.Row="0" Margin="0,0,0,16">
                            <TextBlock Text="Selamat Datang di Oceru Desktop" Foreground="#FFFFFF" FontSize="20" FontWeight="Bold"/>
                            <TextBlock Text="Pusat kontrol smart notch, pemantauan sistem, dan produktivitas Anda." Foreground="#8EA2C6" FontSize="11" Margin="0,3,0,0"/>
                        </StackPanel>

                        <!-- Metric Highlights Cards (CPU, RAM, Baterai, Audio) -->
                        <Grid Grid.Row="1" Margin="0,0,0,16">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Border Grid.Column="0" Style="{StaticResource DashCard}" Margin="0,0,8,0">
                                <StackPanel>
                                    <TextBlock Text="PENGGUNAAN RAM" Foreground="#64748B" FontSize="9" FontWeight="Bold"/>
                                    <TextBlock x:Name="DashRamVal" Text="86%" Foreground="#00D2FF" FontSize="24" FontWeight="Bold" Margin="0,4,0,0"/>
                                    <TextBlock Text="Memori Fisik Aktif" Foreground="#8EA2C6" FontSize="9.5" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="1" Style="{StaticResource DashCard}" Margin="0,0,8,0">
                                <StackPanel>
                                    <TextBlock Text="STATUS BATERAI" Foreground="#64748B" FontSize="9" FontWeight="Bold"/>
                                    <TextBlock x:Name="DashBatVal" Text="88%" Foreground="#10B981" FontSize="24" FontWeight="Bold" Margin="0,4,0,0"/>
                                    <TextBlock x:Name="DashBatStatus" Text="Mengisi Daya ⚡" Foreground="#8EA2C6" FontSize="9.5" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="2" Style="{StaticResource DashCard}" Margin="0,0,8,0">
                                <StackPanel>
                                    <TextBlock Text="VOLUME MASTER" Foreground="#64748B" FontSize="9" FontWeight="Bold"/>
                                    <TextBlock x:Name="DashVolVal" Text="75%" Foreground="#38BDF8" FontSize="24" FontWeight="Bold" Margin="0,4,0,0"/>
                                    <TextBlock x:Name="DashMuteStatus" Text="Audio Bersuara" Foreground="#8EA2C6" FontSize="9.5" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="3" Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="MODE FOKUS" Foreground="#64748B" FontSize="9" FontWeight="Bold"/>
                                    <TextBlock x:Name="DashPomoVal" Text="25:00" Foreground="#FBBF24" FontSize="24" FontWeight="Bold" Margin="0,4,0,0"/>
                                    <TextBlock Text="Pomodoro Siap" Foreground="#8EA2C6" FontSize="9.5" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- Quick Shortcuts Grid -->
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="1.4*"/>
                                <ColumnDefinition Width="1*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Left: Recent Tasks & Notes Preview -->
                            <Border Grid.Column="0" Style="{StaticResource DashCard}" Margin="0,0,10,0">
                                <StackPanel>
                                    <TextBlock Text="DAFTAR TUGAS AKTIF" Foreground="#00D2FF" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                                    <TextBlock Text="✓ Desain UI bertema Ocean Azure Glass (Selesai)" Foreground="#64748B" FontSize="10.5" Margin="0,0,0,6"/>
                                    <TextBlock Text="✓ Integrasi hardware: Wi-Fi flyout &amp; audio slider (Selesai)" Foreground="#64748B" FontSize="10.5" Margin="0,0,0,6"/>
                                    <TextBlock Text="• Selesaikan integrasi 15 destinasi Dashboard Oceru" Foreground="#FFFFFF" FontSize="10.5" FontWeight="SemiBold"/>
                                </StackPanel>
                            </Border>

                            <!-- Right: Dynamic Island Quick Settings -->
                            <Border Grid.Column="1" Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="AKSI CEPAT NOTCH" Foreground="#00D2FF" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                                    <Button x:Name="BtnQuickLock" Content="🔒 Kunci Layar Windows" Style="{StaticResource DashPrimaryBtn}" Margin="0,0,0,6"/>
                                    <Button x:Name="BtnQuickSleep" Content="🌙 Mode Tidur (Sleep)" Style="{StaticResource DashPrimaryBtn}" Background="#1E3150" Margin="0,0,0,6"/>
                                    <Button x:Name="BtnQuickRestart" Content="⟳ Restart Laptop (Konfirmasi)" Style="{StaticResource DashPrimaryBtn}" Background="#1E3150"/>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </Grid>

                    <!-- PAGE 2: DYNAMIC ISLAND CUSTOMIZATION -->
                    <Grid x:Name="PageIsland" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Kustomisasi Dynamic Island" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Atur posisi, ukuran, transparansi, dan perilaku animasi notch di atas layar." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}" Margin="0,0,0,12">
                                <StackPanel>
                                    <TextBlock Text="PRATINJAU NOTCH (PREVIEW)" Foreground="#00D2FF" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                                    <Border Background="#070B14" BorderBrush="#00D2FF" BorderThickness="1" CornerRadius="0,0,18,18" Width="200" Height="36" HorizontalAlignment="Center" Margin="0,10">
                                        <Grid VerticalAlignment="Center" Margin="12,0">
                                            <TextBlock Text="☀️ 28°" Foreground="#FDE68A" FontSize="10" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                            <TextBlock Text="23:50" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            <TextBlock Text="⚡ 88%" Foreground="#10B981" FontSize="10" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>
                                </StackPanel>
                            </Border>

                            <Border Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="PENGATURAN PERILAKU" Foreground="#00D2FF" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                                    <CheckBox Content="Aktifkan Animasi Mata Berkedip (Resting Eyes) saat Idle" IsChecked="True" Foreground="#FFFFFF" Margin="0,0,0,8"/>
                                    <CheckBox Content="Otomatis Mengecilkan Notch (Auto-Collapse) setelah 5 detik" IsChecked="True" Foreground="#FFFFFF" Margin="0,0,0,8"/>
                                    <CheckBox Content="Tampilkan Animasi Toast saat Perangkat Terhubung / Terputus" IsChecked="True" Foreground="#FFFFFF"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 3: MEDIA & LIRIK -->
                    <Grid x:Name="PageMedia" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Media &amp; Lirik Sinkron" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Pemutar musik terintegrasi dengan mesin audio YouTube dan tampilan lirik karaoke." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="80"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" CornerRadius="12" Width="70" Height="70" Background="#0284C7">
                                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE189;" FontSize="28" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <StackPanel Grid.Column="1" Margin="14,0,0,0" VerticalAlignment="Center">
                                        <TextBlock Text="Never Gonna Give You Up" Foreground="#FFFFFF" FontSize="14" FontWeight="Bold"/>
                                        <TextBlock Text="Rick Astley • YouTube Music Audio" Foreground="#94A3B8" FontSize="11" Margin="0,2,0,8"/>
                                        <ProgressBar Value="42" Maximum="100" Height="4" Background="#162238" Foreground="#00D2FF" BorderThickness="0" Margin="0,0,0,10"/>
                                        <StackPanel Orientation="Horizontal">
                                            <Button Content="⏮ Sebelumnya" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,6,0"/>
                                            <Button Content="▶ Putar Musik" Style="{StaticResource DashPrimaryBtn}" Margin="0,0,6,0"/>
                                            <Button Content="⏭ Selanjutnya" Style="{StaticResource DashPrimaryBtn}" Background="#13223D"/>
                                        </StackPanel>
                                    </StackPanel>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 4: FOKUS POMODORO -->
                    <Grid x:Name="PagePomo" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Fokus Pomodoro" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Tingkatkan produktivitas dengan teknik interval fokus dan istirahat." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}" Padding="30">
                                <StackPanel HorizontalAlignment="Center">
                                    <TextBlock Text="25:00" Foreground="#00D2FF" FontSize="56" FontWeight="Bold" FontFamily="Segoe UI, Consolas" HorizontalAlignment="Center"/>
                                    <TextBlock Text="INTERVAL FOKUS AKTIF" Foreground="#10B981" FontSize="11" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,4,0,16"/>
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <Button Content="▶ Mulai Sesi" Style="{StaticResource DashPrimaryBtn}" Margin="0,0,8,0"/>
                                        <Button Content="⟳ Reset" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,8,0"/>
                                        <Button Content="☕ Istirahat 5m" Style="{StaticResource DashPrimaryBtn}" Background="#13223D"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 5: STOPWATCH -->
                    <Grid x:Name="PageStopwatch" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Stopwatch" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Penghitung waktu presisi milidetik dengan pencatat putaran (Lap)." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}" Padding="30">
                                <StackPanel HorizontalAlignment="Center">
                                    <TextBlock x:Name="DashStopwatchText" Text="00:00.0" Foreground="#FFFFFF" FontSize="52" FontWeight="Bold" FontFamily="Segoe UI, Consolas" HorizontalAlignment="Center"/>
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,16,0,0">
                                        <Button x:Name="BtnDashSwStart" Content="▶ Mulai" Style="{StaticResource DashPrimaryBtn}" Margin="0,0,8,0"/>
                                        <Button x:Name="BtnDashSwLap" Content="🏁 Catat Putaran (Lap)" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,8,0"/>
                                        <Button x:Name="BtnDashSwReset" Content="⟳ Reset" Style="{StaticResource DashPrimaryBtn}" Background="#13223D"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 6: COUNTDOWN TIMER -->
                    <Grid x:Name="PageCountdown" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Hitung Mundur (Countdown)" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Atur waktu hitung mundur khusus untuk deadline atau pengingat." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}" Padding="30">
                                <StackPanel HorizontalAlignment="Center">
                                    <TextBlock Text="05:00" Foreground="#38BDF8" FontSize="52" FontWeight="Bold" FontFamily="Segoe UI, Consolas" HorizontalAlignment="Center"/>
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,16,0,0">
                                        <Button Content="▶ Mulai Hitung Mundur" Style="{StaticResource DashPrimaryBtn}" Margin="0,0,8,0"/>
                                        <Button Content="⟳ Reset 5 Menit" Style="{StaticResource DashPrimaryBtn}" Background="#13223D"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 7: MONITOR SISTEM -->
                    <Grid x:Name="PageSysMon" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Monitor Sistem &amp; Perangkat Keras" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Status kesehatan RAM, CPU, Baterai laptop, dan Konektivitas real-time." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Grid Margin="0,0,0,12">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource DashCard}" Margin="0,0,8,0">
                                    <StackPanel>
                                        <TextBlock Text="MEMORI RAM FISIK" Foreground="#64748B" FontSize="10" FontWeight="Bold"/>
                                        <TextBlock x:Name="DashSysMonRam" Text="86% Digunakan" Foreground="#00D2FF" FontSize="20" FontWeight="Bold" Margin="0,4,0,0"/>
                                        <ProgressBar Value="86" Maximum="100" Height="8" Background="#162238" Foreground="#00D2FF" BorderThickness="0" Margin="0,8,0,0"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="BATERAI LAPTOP" Foreground="#64748B" FontSize="10" FontWeight="Bold"/>
                                        <TextBlock x:Name="DashSysMonBat" Text="88% (Online ⚡)" Foreground="#10B981" FontSize="20" FontWeight="Bold" Margin="0,4,0,0"/>
                                        <ProgressBar Value="88" Maximum="100" Height="8" Background="#162238" Foreground="#10B981" BorderThickness="0" Margin="0,8,0,0"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 8: NOTIFIKASI -->
                    <Grid x:Name="PageNotif" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Pusat Notifikasi" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Riwayat peringatan baterai, konektivitas perangkat, dan catatan sistem." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}" Margin="0,0,0,8">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE73E;" FontSize="16" Foreground="#10B981" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                    <StackPanel Grid.Column="1">
                                        <TextBlock Text="Oceru Dynamic Island Aktif" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11"/>
                                        <TextBlock Text="Sistem berjalan mulus di tepi atas layar dengan tema Ocean Azure Glass." Foreground="#8EA2C6" FontSize="10" Margin="0,2,0,0"/>
                                    </StackPanel>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 9: CATATAN (NOTES) -->
                    <Grid x:Name="PageNotes" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Catatan Cepat (Notes)" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Tulis ide, memo, atau referensi dan simpan otomatis di laptopmu." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBox x:Name="DashNoteBox" Text="Desain antarmuka Ocean Azure Glass dengan integrasi kontrol hardware Windows."
                                             Background="#09101E" BorderBrush="#1E3150" Foreground="#FFFFFF"
                                             TextWrapping="Wrap" AcceptsReturn="True" Height="140" Padding="10" FontSize="11"/>
                                    <Button x:Name="BtnSaveNote" Content="💾 Simpan Catatan" Style="{StaticResource DashPrimaryBtn}" Margin="0,10,0,0" HorizontalAlignment="Right"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 10: DAFTAR TUGAS (TO-DO) -->
                    <Grid x:Name="PageTodo" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Daftar Tugas (To-Do)" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Kelola pekerjaan dan checklist harian langsung dari desktop." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="✓ Desain antarmuka Ocean Azure Glass" Foreground="#64748B" TextDecorations="Strikethrough" FontSize="11" Margin="0,0,0,6"/>
                                    <TextBlock Text="✓ Integrasi kontrol Wi-Fi, Bluetooth, dan Audio Mute" Foreground="#64748B" TextDecorations="Strikethrough" FontSize="11" Margin="0,0,0,6"/>
                                    <TextBlock Text="• Selesaikan kustomisasi dan penyesuaian tema" Foreground="#FFFFFF" FontSize="11"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 11: PAPAN KLIP (CLIPBOARD) -->
                    <Grid x:Name="PageClip" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Papan Klip (Clipboard Manager)" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Riwayat teks yang Anda salin, siap dipakai kembali dengan satu klik." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <Border Background="#09101E" BorderBrush="#1E3150" BorderThickness="1" CornerRadius="8" Padding="10,8" Margin="0,0,0,6">
                                        <TextBlock Text="https://github.com/cubadakanda/dynamic-island" Foreground="#00D2FF" FontSize="11"/>
                                    </Border>
                                    <Border Background="#09101E" BorderBrush="#1E3150" BorderThickness="1" CornerRadius="8" Padding="10,8">
                                        <TextBlock Text="Oceru Dynamic Island Desktop" Foreground="#E2E8F0" FontSize="11"/>
                                    </Border>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 12: PENGATURAN CEPAT -->
                    <Grid x:Name="PageQuickSet" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Pengaturan Cepat (Quick Settings Matrix)" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Semua pintasan hardware dan preferensi sistem terpusat." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Button x:Name="BtnQsWifi" Content="📶 Buka Panel Wi-Fi" Style="{StaticResource DashPrimaryBtn}" Margin="0,0,6,0"/>
                                <Button x:Name="BtnQsBt" Content="🎧 Buka Pengaturan Bluetooth" Style="{StaticResource DashPrimaryBtn}" Grid.Column="1" Background="#13223D"/>
                            </Grid>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 13: PELUNCUR CEPAT (QUICK LAUNCHER) -->
                    <Grid x:Name="PageQuickLaunch" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Peluncur Cepat (Quick Launcher)" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Buka aplikasi favorit secara instan tanpa perlu mencari di menu Start." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}">
                                <WrapPanel>
                                    <Button x:Name="BtnQkChrome" Content="🌐 Google Chrome" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,8,8"/>
                                    <Button x:Name="BtnQkExplorer" Content="📁 File Explorer" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,8,8"/>
                                    <Button x:Name="BtnQkTerminal" Content="💻 PowerShell" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,8,8"/>
                                    <Button x:Name="BtnQkTaskMgr" Content="⚡ Task Manager" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,8,8"/>
                                    <Button x:Name="BtnQkSettings" Content="⚙️ Windows Settings" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,8,8"/>
                                </WrapPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 14: PENGATURAN (SETTINGS) -->
                    <Grid x:Name="PageSettings" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Pengaturan Oceru" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Konfigurasi tema, transparansi, integrasi startup, dan pintasan keyboard." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}" Margin="0,0,0,10">
                                <StackPanel>
                                    <TextBlock Text="TEMA VISUAL APLIKASI" Foreground="#00D2FF" FontSize="11" FontWeight="Bold" Margin="0,0,0,8"/>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="BtnThemeSetDark" Content="Ocean Dark (Midnight Navy)" Style="{StaticResource DashPrimaryBtn}" Margin="0,0,8,0"/>
                                        <Button x:Name="BtnThemeSetGlass" Content="Aero Glassmorphism" Style="{StaticResource DashPrimaryBtn}" Background="#13223D" Margin="0,0,8,0"/>
                                        <Button x:Name="BtnThemeSetCyber" Content="Neon Cyberpunk" Style="{StaticResource DashPrimaryBtn}" Background="#13223D"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>

                            <Border Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="INTEGRASI SISTEM" Foreground="#00D2FF" FontSize="11" FontWeight="Bold" Margin="0,0,0,8"/>
                                    <CheckBox Content="Jalankan otomatis saat Windows login (Auto-Start)" IsChecked="True" Foreground="#FFFFFF" Margin="0,0,0,6"/>
                                    <CheckBox Content="Selalu di depan aplikasi lain (Always On Top)" IsChecked="True" Foreground="#FFFFFF" Margin="0,0,0,6"/>
                                    <CheckBox Content="Heningkan notifikasi saat Mode Game aktif" IsChecked="True" Foreground="#FFFFFF"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 15: TENTANG OCERU (ABOUT) -->
                    <Grid x:Name="PageAbout" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Tentang Oceru Dynamic Island" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Informasi lisensi, rilis, dan diagnostik lingkungan desktop Anda." Foreground="#8EA2C6" FontSize="11" Margin="0,0,0,16"/>
                            
                            <Border Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="OCERU DESKTOP v1.0.0" Foreground="#00D2FF" FontSize="14" FontWeight="Bold"/>
                                    <TextBlock Text="Bahasa Desain: Ocean Azure Glass" Foreground="#CBD5E1" FontSize="11" Margin="0,4,0,2"/>
                                    <TextBlock Text="Pengembang: Orizzdev" Foreground="#8EA2C6" FontSize="10.5" Margin="0,0,0,10"/>
                                    <Separator Background="#1E3150" Margin="0,0,0,10"/>
                                    <TextBlock Text="Diagnostik Sistem:" Foreground="#64748B" FontSize="9.5" FontWeight="Bold" Margin="0,0,0,4"/>
                                    <TextBlock Text="• Windows Platform: Windows 10/11 64-bit" Foreground="#8EA2C6" FontSize="10"/>
                                    <TextBlock Text="• Engine: Windows Presentation Foundation (WPF Direct3D Acceleration)" Foreground="#8EA2C6" FontSize="10"/>
                                    <TextBlock Text="• Status Runtime: Aktif &amp; Terhubung ke Hardware API" Foreground="#10B981" FontSize="10" FontWeight="SemiBold"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

# Initialize Both Windows
$reader1 = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($islandXaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader1)

$reader2 = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($dashXaml))
$dashWindow = [System.Windows.Markup.XamlReader]::Load($reader2)

$window.Left = $leftPos
$window.Top = 0

# Grab Handles: Island Window
$notch = $window.FindName("NotchBorder")
$compactIdleView = $window.FindName("CompactIdleView")
$compactRestingView = $window.FindName("CompactRestingView")
$compactMediaView = $window.FindName("CompactMediaView")
$compactTimerView = $window.FindName("CompactTimerView")
$toastView = $window.FindName("ToastView")
$toastIcon = $window.FindName("ToastIcon")
$toastText = $window.FindName("ToastText")
$expandedView = $window.FindName("ExpandedView")

$leftEye = $window.FindName("LeftEye")
$rightEye = $window.FindName("RightEye")
$clockText = $window.FindName("ClockText")
$weatherSmallText = $window.FindName("WeatherSmallText")
$dndIconCompact = $window.FindName("DndIconCompact")
$collapsedBatIcon = $window.FindName("CollapsedBatIcon")
$collapsedBatPct = $window.FindName("CollapsedBatPct")
$compactTrackText = $window.FindName("CompactTrackText")
$compactWaveText = $window.FindName("CompactWaveText")
$compactTimerIcon = $window.FindName("CompactTimerIcon")
$compactTimerText = $window.FindName("CompactTimerText")

$expandedToastPill = $window.FindName("ExpandedToastPill")
$expandedToastIcon = $window.FindName("ExpandedToastIcon")
$expandedToastText = $window.FindName("ExpandedToastText")
$btnLaunchDashboard = $window.FindName("BtnLaunchDashboard")
$btnHeaderBt = $window.FindName("BtnHeaderBt")
$btBadge = $window.FindName("BtBadge")
$headerBatIcon = $window.FindName("HeaderBatIcon")
$headerBatText = $window.FindName("HeaderBatText")
$dateText = $window.FindName("DateText")

# Tabs Handles
$btnControl = $window.FindName("BtnControl")
$btnMusic = $window.FindName("BtnMusic")
$btnLyrics = $window.FindName("BtnLyrics")
$btnPomo = $window.FindName("BtnPomo")
$btnClip = $window.FindName("BtnClip")
$btnTodo = $window.FindName("BtnTodo")
$btnShelf = $window.FindName("BtnShelf")
$shelfBadgeCount = $window.FindName("ShelfBadgeCount")

$lblControl = $window.FindName("LblControl")
$lblMusic = $window.FindName("LblMusic")
$lblLyrics = $window.FindName("LblLyrics")
$lblPomo = $window.FindName("LblPomo")
$lblClip = $window.FindName("LblClip")
$lblTodo = $window.FindName("LblTodo")
$lblShelf = $window.FindName("LblShelf")

$paneControl = $window.FindName("PaneControl")
$paneMusic = $window.FindName("PaneMusic")
$paneLyrics = $window.FindName("PaneLyrics")
$panePomo = $window.FindName("PanePomo")
$paneClip = $window.FindName("PaneClip")
$paneTodo = $window.FindName("PaneTodo")
$paneShelf = $window.FindName("PaneShelf")

# Control Center Controls
$cardWifi = $window.FindName("CardWifi")
$cardBt = $window.FindName("CardBt")
$cardMute = $window.FindName("CardMute")
$iconMute = $window.FindName("IconMute")
$statusMute = $window.FindName("StatusMute")
$lblVolPct = $window.FindName("LblVolPct")
$sliderVol = $window.FindName("SliderVol")
$btnVolDown = $window.FindName("BtnVolDown")
$btnVolUp = $window.FindName("BtnVolUp")

$btnToggleDnd = $window.FindName("BtnToggleDnd")
$bgDnd = $window.FindName("BgDnd")
$lblDnd = $window.FindName("LblDnd")

$btnToggleGame = $window.FindName("BtnToggleGame")
$bgGame = $window.FindName("BgGame")
$lblGame = $window.FindName("LblGame")

$btnSysBright = $window.FindName("BtnSysBright")
$btnSysTaskMgr = $window.FindName("BtnSysTaskMgr")
$btnSysLock = $window.FindName("BtnSysLock")
$btnSysSleep = $window.FindName("BtnSysSleep")
$btnSysRestart = $window.FindName("BtnSysRestart")
$lblRestart = $window.FindName("LblRestart")
$btnThemeSwitch = $window.FindName("BtnThemeSwitch")
$lblTheme = $window.FindName("LblTheme")

# Grab Handles: Dashboard Window
$dashTitleBar = $dashWindow.FindName("DashTitleBar")
$btnDashMin = $dashWindow.FindName("BtnDashMin")
$btnDashClose = $dashWindow.FindName("BtnDashClose")

$navOverview = $dashWindow.FindName("NavOverview")
$navIsland = $dashWindow.FindName("NavIsland")
$navMedia = $dashWindow.FindName("NavMedia")
$navPomo = $dashWindow.FindName("NavPomo")
$navStopwatch = $dashWindow.FindName("NavStopwatch")
$navCountdown = $dashWindow.FindName("NavCountdown")
$navSysMon = $dashWindow.FindName("NavSysMon")
$navNotif = $dashWindow.FindName("NavNotif")
$navNotes = $dashWindow.FindName("NavNotes")
$navTodo = $dashWindow.FindName("NavTodo")
$navClip = $dashWindow.FindName("NavClip")
$navQuickSet = $dashWindow.FindName("NavQuickSet")
$navQuickLaunch = $dashWindow.FindName("NavQuickLaunch")
$navSettings = $dashWindow.FindName("NavSettings")
$navAbout = $dashWindow.FindName("NavAbout")

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
    $navOverview, $navIsland, $navMedia, $navPomo, $navStopwatch, $navCountdown,
    $navSysMon, $navNotif, $navNotes, $navTodo, $navClip, $navQuickSet,
    $navQuickLaunch, $navSettings, $navAbout
)

# Dragging & Title Bar Events for Dashboard Window
$dashTitleBar.Add_MouseLeftButtonDown({
    param($s, $e)
    $dashWindow.DragMove()
})

$btnDashMin.Add_Click({ $dashWindow.WindowState = [System.Windows.WindowState]::Minimized })
$btnDashClose.Add_Click({ $dashWindow.Hide() })

# Dashboard Switch View Function
function SwitchDashPage($pageIndex) {
    for ($i = 0; $i -lt $dashPages.Count; $i++) {
        if ($i -eq $pageIndex) {
            $dashPages[$i].Visibility = [System.Windows.Visibility]::Visible
            $dashNavBtns[$i].Style = $dashWindow.FindResource("ActiveSidebarNavBtn")
        } else {
            $dashPages[$i].Visibility = [System.Windows.Visibility]::Collapsed
            $dashNavBtns[$i].Style = $dashWindow.FindResource("SidebarNavBtn")
        }
    }
}

for ($idx = 0; $idx -lt $dashNavBtns.Count; $idx++) {
    $currentIdx = $idx
    $dashNavBtns[$currentIdx].Add_Click([scriptblock]::Create("SwitchDashPage $currentIdx"))
}

# Open Dashboard Helper
function Show-OceruDashboard($pageIndex = 0) {
    SwitchDashPage $pageIndex
    $dashWindow.Show()
    $dashWindow.Activate()
}

$btnLaunchDashboard.Add_Click({ Show-OceruDashboard 0 })
$menuOpenDashboard = $window.FindName("MenuOpenDashboard")
if ($menuOpenDashboard) { $menuOpenDashboard.Add_Click({ Show-OceruDashboard 0 }) }

# Music & Lyrics Elements
$btnPlay = $window.FindName("BtnPlay")
$btnPrev = $window.FindName("BtnPrev")
$btnNext = $window.FindName("BtnNext")
$playIcon = $window.FindName("PlayIcon")
$trackTitle = $window.FindName("TrackTitle")
$trackArtist = $window.FindName("TrackArtist")
$trackProgress = $window.FindName("TrackProgress")
$ytInput = $window.FindName("YtInput")
$musicLyricMini = $window.FindName("MusicLyricMini")
$lyricLineActive = $window.FindName("LyricLineActive")
$lyricLinePast = $window.FindName("LyricLinePast")
$lyricLineNext = $window.FindName("LyricLineNext")
$waveAnimText = $window.FindName("WaveAnimText")
$audioWebEngine = $window.FindName("AudioWebEngine")

# Timer Elements
$pomoTimer = $window.FindName("PomoTimer")
$pomoStatus = $window.FindName("PomoStatus")
$btnPill5 = $window.FindName("BtnPill5")
$btnPill10 = $window.FindName("BtnPill10")
$btnPill15 = $window.FindName("BtnPill15")
$btnPill25 = $window.FindName("BtnPill25")
$btnPill45 = $window.FindName("BtnPill45")
$btnPomoStart = $window.FindName("BtnPomoStart")
$btnPomoReset = $window.FindName("BtnPomoReset")
$btnPomoMode = $window.FindName("BtnPomoMode")

# Clipboard Elements
$btnClipItem1 = $window.FindName("BtnClipItem1")
$btnClipItem2 = $window.FindName("BtnClipItem2")
$btnClipItem3 = $window.FindName("BtnClipItem3")

# Todo Elements
$todoInput = $window.FindName("TodoInput")
$todoListPanel = $window.FindName("TodoListPanel")
$todoCounterText = $window.FindName("TodoCounterText")
$chk1 = $window.FindName("Chk1")
$chk2 = $window.FindName("Chk2")
$chk3 = $window.FindName("Chk3")
$txt1 = $window.FindName("Txt1")
$txt2 = $window.FindName("Txt2")
$txt3 = $window.FindName("Txt3")

# Shelf Elements
$shelfPlaceholder = $window.FindName("ShelfPlaceholder")
$shelfItemsList = $window.FindName("ShelfItemsList")

# Context Menu
function ReloadIsland {
    $script = Join-Path $PSScriptRoot "run-island.ps1"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    $window.Close()
}

$menuReload = $window.FindName("MenuReload")
if ($menuReload) { $menuReload.Add_Click({ ReloadIsland }) }

$menuOpenFolder = $window.FindName("MenuOpenFolder")
if ($menuOpenFolder) { $menuOpenFolder.Add_Click({ [System.Diagnostics.Process]::Start("explorer.exe", $PSScriptRoot) }) }

$menuOpenWifi = $window.FindName("MenuOpenWifi")
if ($menuOpenWifi) { $menuOpenWifi.Add_Click({ [System.Diagnostics.Process]::Start("explorer.exe", "ms-availablenetworks:") }) }

$menuOpenBt = $window.FindName("MenuOpenBt")
if ($menuOpenBt) { $menuOpenBt.Add_Click({ [System.Diagnostics.Process]::Start("explorer.exe", "ms-settings:bluetooth") }) }

$menuExit = $window.FindName("MenuExit")
if ($menuExit) { $menuExit.Add_Click({ $window.Close(); $dashWindow.Close() }) }

$window.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::F5 -or ($e.Key -eq [System.Windows.Input.Key]::R -and [System.Windows.Input.Keyboard]::Modifiers -eq [System.Windows.Input.ModifierKeys]::Control)) {
        ReloadIsland
    }
})

$window.Add_Closed({
    if (Test-Path $pidPath) { Remove-Item $pidPath -Force -ErrorAction SilentlyContinue }
    $dashWindow.Close()
})

# State Variables
$global:isExpanded = $false
$global:isToastActive = $false
$global:currentTab = "control"
$global:restartArmed = $false
$global:idleSeconds = 0

# Timers
$idleCheckTimer = New-Object System.Windows.Threading.DispatcherTimer
$idleCheckTimer.Interval = [TimeSpan]::FromSeconds(1)

$blinkTimer = New-Object System.Windows.Threading.DispatcherTimer
$blinkTimer.Interval = [TimeSpan]::FromMilliseconds(3800)

$leaveTimer = New-Object System.Windows.Threading.DispatcherTimer
$leaveTimer.Interval = [TimeSpan]::FromMilliseconds(320)

$toastTimer = New-Object System.Windows.Threading.DispatcherTimer
$toastTimer.Interval = [TimeSpan]::FromMilliseconds(2800)

$expandedToastTimer = New-Object System.Windows.Threading.DispatcherTimer
$expandedToastTimer.Interval = [TimeSpan]::FromMilliseconds(2200)

# Instant Visual Feedback Helper
function ShowActionFeedback($message, $glyphChar, $colorHex) {
    # 1. Update in-notch expanded feedback pill
    $expandedToastText.Text = $message
    $expandedToastIcon.Text = $glyphChar
    $expandedToastPill.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($colorHex)
    $expandedToastPill.Visibility = [System.Windows.Visibility]::Visible

    $expandedToastTimer.Stop()
    $expandedToastTimer.Start()

    # 2. Update collapsed toast view
    $toastText.Text = $message
    $toastIcon.Text = $glyphChar
    $toastIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($colorHex)

    if (-not $global:isExpanded) {
        $global:isToastActive = $true
        $compactIdleView.Visibility = [System.Windows.Visibility]::Collapsed
        $compactRestingView.Visibility = [System.Windows.Visibility]::Collapsed
        $compactMediaView.Visibility = [System.Windows.Visibility]::Collapsed
        $compactTimerView.Visibility = [System.Windows.Visibility]::Collapsed
        $toastView.Visibility = [System.Windows.Visibility]::Visible

        $wAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(185, 280, [TimeSpan]::FromMilliseconds(220))
        $wAnim.DecelerationRatio = 0.8
        $notch.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $wAnim)

        $toastTimer.Stop()
        $toastTimer.Start()
    }
}

$expandedToastTimer.Add_Tick({
    $expandedToastTimer.Stop()
    $expandedToastPill.Visibility = [System.Windows.Visibility]::Collapsed
})

$toastTimer.Add_Tick({
    $toastTimer.Stop()
    $global:isToastActive = $false
    if (-not $global:isExpanded) {
        $wAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(280, 185, [TimeSpan]::FromMilliseconds(220))
        $wAnim.DecelerationRatio = 0.8
        $notch.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $wAnim)
        $toastView.Visibility = [System.Windows.Visibility]::Collapsed
        UpdateCompactView
    }
})

# Animation Helpers
function AnimateExpand {
    if ($global:isExpanded) { return }
    $global:isExpanded = $true

    $wAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(185, 660, [TimeSpan]::FromMilliseconds(260))
    $wAnim.DecelerationRatio = 0.85
    $hAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(32, 230, [TimeSpan]::FromMilliseconds(260))
    $hAnim.DecelerationRatio = 0.85

    $notch.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $wAnim)
    $notch.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $hAnim)
    $notch.CornerRadius = New-Object System.Windows.CornerRadius(0, 0, 24, 24)

    $compactIdleView.Visibility = [System.Windows.Visibility]::Collapsed
    $compactRestingView.Visibility = [System.Windows.Visibility]::Collapsed
    $compactMediaView.Visibility = [System.Windows.Visibility]::Collapsed
    $compactTimerView.Visibility = [System.Windows.Visibility]::Collapsed
    $toastView.Visibility = [System.Windows.Visibility]::Collapsed
    $expandedView.Visibility = [System.Windows.Visibility]::Visible
}

function AnimateCollapse {
    if (-not $global:isExpanded) { return }
    $global:isExpanded = $false

    $wAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(660, 185, [TimeSpan]::FromMilliseconds(240))
    $wAnim.DecelerationRatio = 0.85
    $hAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(230, 32, [TimeSpan]::FromMilliseconds(240))
    $hAnim.DecelerationRatio = 0.85

    $notch.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $wAnim)
    $notch.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $hAnim)
    $notch.CornerRadius = New-Object System.Windows.CornerRadius(0, 0, 18, 18)

    $expandedView.Visibility = [System.Windows.Visibility]::Collapsed
    if ($global:isToastActive) {
        $toastView.Visibility = [System.Windows.Visibility]::Visible
    } else {
        UpdateCompactView
    }
}

# Dynamic Compact View Logic
function UpdateCompactView {
    if ($global:isExpanded -or $global:isToastActive) { return }

    $compactIdleView.Visibility = [System.Windows.Visibility]::Collapsed
    $compactRestingView.Visibility = [System.Windows.Visibility]::Collapsed
    $compactMediaView.Visibility = [System.Windows.Visibility]::Collapsed
    $compactTimerView.Visibility = [System.Windows.Visibility]::Collapsed

    # 1. Timer Active Mode
    if ($global:OceruState.pomodoro.isRunning) {
        $compactTimerIcon.Text = [char]0xE916
        $compactTimerIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
        $compactTimerText.Text = [TimeSpan]::FromSeconds($global:OceruState.pomodoro.remainingSeconds).ToString("mm\:ss")
        $compactTimerView.Visibility = [System.Windows.Visibility]::Visible
        return
    }

    # 2. Media Playing Mode
    if ($global:OceruState.currentMedia.isPlaying) {
        $compactTrackText.Text = $global:OceruState.currentMedia.title
        $compactMediaView.Visibility = [System.Windows.Visibility]::Visible
        return
    }

    # 3. Resting Eyes Mode (Idle > 5 seconds)
    if ($global:idleSeconds -ge 5) {
        $compactRestingView.Visibility = [System.Windows.Visibility]::Visible
        return
    }

    # 4. Default Idle View
    $compactIdleView.Visibility = [System.Windows.Visibility]::Visible
}

# Mouse Hover Handlers
$notch.Add_MouseEnter({
    $leaveTimer.Stop()
    $global:idleSeconds = 0
    AnimateExpand
})

$notch.Add_MouseLeave({
    $leaveTimer.Start()
})

$leaveTimer.Add_Tick({
    $leaveTimer.Stop()
    AnimateCollapse
})

# Idle Check Timer
$idleCheckTimer.Add_Tick({
    if (-not $global:isExpanded -and -not $global:isToastActive) {
        $global:idleSeconds++
        UpdateCompactView
    } else {
        $global:idleSeconds = 0
    }
})
$idleCheckTimer.Start()

# Blink Timer
$blinkTimer.Add_Tick({
    if ($compactRestingView.Visibility -eq [System.Windows.Visibility]::Visible) {
        $blinkAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(10, 2, [TimeSpan]::FromMilliseconds(120))
        $blinkAnim.AutoReverse = $true
        $leftEye.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $blinkAnim)
        $rightEye.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $blinkAnim)
    }
})
$blinkTimer.Start()

# Tab Switching (Zero Scrollbars, Perfect Proportions!)
function ResetTabButtons {
    $btnControl.Style = $window.FindResource("NavIconBtn")
    $btnMusic.Style = $window.FindResource("NavIconBtn")
    $btnLyrics.Style = $window.FindResource("NavIconBtn")
    $btnPomo.Style = $window.FindResource("NavIconBtn")
    $btnClip.Style = $window.FindResource("NavIconBtn")
    $btnTodo.Style = $window.FindResource("NavIconBtn")
    $btnShelf.Style = $window.FindResource("NavIconBtn")

    $btnControl.Width = 32
    $btnMusic.Width = 32
    $btnLyrics.Width = 32
    $btnPomo.Width = 32
    $btnClip.Width = 32
    $btnTodo.Width = 32
    $btnShelf.Width = 32

    $lblControl.Visibility = [System.Windows.Visibility]::Collapsed
    $lblMusic.Visibility = [System.Windows.Visibility]::Collapsed
    $lblLyrics.Visibility = [System.Windows.Visibility]::Collapsed
    $lblPomo.Visibility = [System.Windows.Visibility]::Collapsed
    $lblClip.Visibility = [System.Windows.Visibility]::Collapsed
    $lblTodo.Visibility = [System.Windows.Visibility]::Collapsed
    $lblShelf.Visibility = [System.Windows.Visibility]::Collapsed

    $paneControl.Visibility = [System.Windows.Visibility]::Collapsed
    $paneMusic.Visibility = [System.Windows.Visibility]::Collapsed
    $paneLyrics.Visibility = [System.Windows.Visibility]::Collapsed
    $panePomo.Visibility = [System.Windows.Visibility]::Collapsed
    $paneClip.Visibility = [System.Windows.Visibility]::Collapsed
    $paneTodo.Visibility = [System.Windows.Visibility]::Collapsed
    $paneShelf.Visibility = [System.Windows.Visibility]::Collapsed
}

function SwitchTab($tab) {
    $global:currentTab = $tab
    ResetTabButtons

    if ($tab -eq "control") {
        $btnControl.Style = $window.FindResource("ActiveNavBtn")
        $btnControl.Width = [double]::NaN
        $lblControl.Visibility = [System.Windows.Visibility]::Visible
        $paneControl.Visibility = [System.Windows.Visibility]::Visible
    } elseif ($tab -eq "music") {
        $btnMusic.Style = $window.FindResource("ActiveNavBtn")
        $btnMusic.Width = [double]::NaN
        $lblMusic.Visibility = [System.Windows.Visibility]::Visible
        $paneMusic.Visibility = [System.Windows.Visibility]::Visible
    } elseif ($tab -eq "lyrics") {
        $btnLyrics.Style = $window.FindResource("ActiveNavBtn")
        $btnLyrics.Width = [double]::NaN
        $lblLyrics.Visibility = [System.Windows.Visibility]::Visible
        $paneLyrics.Visibility = [System.Windows.Visibility]::Visible
    } elseif ($tab -eq "pomo") {
        $btnPomo.Style = $window.FindResource("ActiveNavBtn")
        $btnPomo.Width = [double]::NaN
        $lblPomo.Visibility = [System.Windows.Visibility]::Visible
        $panePomo.Visibility = [System.Windows.Visibility]::Visible
    } elseif ($tab -eq "clip") {
        $btnClip.Style = $window.FindResource("ActiveNavBtn")
        $btnClip.Width = [double]::NaN
        $lblClip.Visibility = [System.Windows.Visibility]::Visible
        $paneClip.Visibility = [System.Windows.Visibility]::Visible
    } elseif ($tab -eq "todo") {
        $btnTodo.Style = $window.FindResource("ActiveNavBtn")
        $btnTodo.Width = [double]::NaN
        $lblTodo.Visibility = [System.Windows.Visibility]::Visible
        $paneTodo.Visibility = [System.Windows.Visibility]::Visible
    } elseif ($tab -eq "shelf") {
        $btnShelf.Style = $window.FindResource("ActiveNavBtn")
        $btnShelf.Width = [double]::NaN
        $lblShelf.Visibility = [System.Windows.Visibility]::Visible
        $paneShelf.Visibility = [System.Windows.Visibility]::Visible
    }
}

$btnControl.Add_Click({ SwitchTab("control") })
$btnMusic.Add_Click({ SwitchTab("music") })
$btnLyrics.Add_Click({ SwitchTab("lyrics") })
$btnPomo.Add_Click({ SwitchTab("pomo") })
$btnClip.Add_Click({ SwitchTab("clip") })
$btnTodo.Add_Click({ SwitchTab("todo") })
$btnShelf.Add_Click({ SwitchTab("shelf") })

# 1. REAL HARDWARE WI-FI ACTION
$cardWifi.Add_Click({
    ShowActionFeedback "Membuka Panel Wi-Fi..." ([char]0xE701) "#0284C7"
    [System.Diagnostics.Process]::Start("explorer.exe", "ms-availablenetworks:")
})

# 2. REAL HARDWARE BLUETOOTH ACTION
function OpenBluetoothSettings {
    ShowActionFeedback "Membuka Bluetooth..." ([char]0xE7F6) "#0284C7"
    [System.Diagnostics.Process]::Start("explorer.exe", "ms-settings:bluetooth")
}
$cardBt.Add_Click({ OpenBluetoothSettings })
$btnHeaderBt.Add_Click({ OpenBluetoothSettings })

# 3. REAL HARDWARE AUDIO & VOLUME SLIDER
$cardMute.Add_Click({
    $global:OceruState.isMuted = -not $global:OceruState.isMuted
    try { [Win32Helper]::ToggleMute() } catch {}

    if ($global:OceruState.isMuted) {
        $iconMute.Text = [char]0xE74F
        $statusMute.Text = "Bisu (Muted)"
        ShowActionFeedback "Audio Dibisukan" ([char]0xE74F) "#DC2626"
    } else {
        $iconMute.Text = [char]0xE767
        $statusMute.Text = "Volume Suara"
        ShowActionFeedback "Audio Bersuara" ([char]0xE767) "#10B981"
    }
    Save-OceruState
})

$btnVolDown.Add_Click({
    try { [Win32Helper]::VolumeDown() } catch {}
    $global:OceruState.volume = [Math]::Max(0, $global:OceruState.volume - 2)
    $sliderVol.Value = $global:OceruState.volume
    $lblVolPct.Text = "$($global:OceruState.volume)%"
    ShowActionFeedback "Volume $($global:OceruState.volume)%" ([char]0xE74F) "#38BDF8"
    Save-OceruState
})

$btnVolUp.Add_Click({
    try { [Win32Helper]::VolumeUp() } catch {}
    $global:OceruState.volume = [Math]::Min(100, $global:OceruState.volume + 2)
    $sliderVol.Value = $global:OceruState.volume
    $lblVolPct.Text = "$($global:OceruState.volume)%"
    ShowActionFeedback "Volume $($global:OceruState.volume)%" ([char]0xE767) "#38BDF8"
    Save-OceruState
})

$sliderVol.Add_ValueChanged({
    $val = [Math]::Round($sliderVol.Value)
    $lblVolPct.Text = "$val%"
    $global:OceruState.volume = $val
})

# 4. MODES & SHORTCUTS (DND, Gaming, Brightness, Task Manager)
$btnToggleDnd.Add_Click({
    $global:OceruState.dndEnabled = -not $global:OceruState.dndEnabled
    if ($global:OceruState.dndEnabled) {
        $bgDnd.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#7C3AED")
        $lblDnd.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C084FC")
        $dndIconCompact.Visibility = [System.Windows.Visibility]::Visible
        ShowActionFeedback "Jangan Ganggu Aktif" ([char]0xE708) "#7C3AED"
    } else {
        $bgDnd.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1736")
        $lblDnd.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CBD5E1")
        $dndIconCompact.Visibility = [System.Windows.Visibility]::Collapsed
        ShowActionFeedback "Jangan Ganggu Nonaktif" ([char]0xE708) "#64748B"
    }
    Save-OceruState
})

$btnToggleGame.Add_Click({
    $global:OceruState.gamingMode = -not $global:OceruState.gamingMode
    if ($global:OceruState.gamingMode) {
        $bgGame.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
        $lblGame.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        ShowActionFeedback "Mode Game Aktif" ([char]0xE7FC) "#059669"
    } else {
        $bgGame.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#112920")
        $lblGame.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CBD5E1")
        ShowActionFeedback "Mode Game Nonaktif" ([char]0xE7FC) "#64748B"
    }
    Save-OceruState
})

$btnSysBright.Add_Click({
    ShowActionFeedback "Membuka Kecerahan..." ([char]0xE706) "#FBBF24"
    [System.Diagnostics.Process]::Start("explorer.exe", "ms-settings:display")
})

$btnSysTaskMgr.Add_Click({
    ShowActionFeedback "Membuka Task Manager..." ([char]0xE9D9) "#38BDF8"
    [System.Diagnostics.Process]::Start("taskmgr.exe")
})

# 5. REAL HARDWARE LOCK & SLEEP
$btnSysLock.Add_Click({
    ShowActionFeedback "Mengunci Layar..." ([char]0xE72E) "#38BDF8"
    try {
        [Win32Helper]::LockWorkStation() | Out-Null
    } catch {
        Start-Process "rundll32.exe" -ArgumentList "user32.dll,LockWorkStation"
    }
})

$btnSysSleep.Add_Click({
    ShowActionFeedback "Masuk Mode Tidur..." ([char]0xE708) "#C084FC"
    Start-Process "rundll32.exe" -ArgumentList "powrprof.dll,SetSuspendState 0,1,0"
})

# 6. RESTART WITH SAFE CONFIRMATION
$restartTimer = New-Object System.Windows.Threading.DispatcherTimer
$restartTimer.Interval = [TimeSpan]::FromSeconds(4)
$restartTimer.Add_Tick({
    $restartTimer.Stop()
    $global:restartArmed = $false
    $lblRestart.Text = "Restart"
    $btnSysRestart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0C1527")
})

$btnSysRestart.Add_Click({
    if (-not $global:restartArmed) {
        $global:restartArmed = $true
        $lblRestart.Text = "Yakin? (Klik)"
        $btnSysRestart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#991B1B")
        ShowActionFeedback "Klik lagi untuk Restart!" ([char]0xE777) "#EF4444"
        $restartTimer.Start()
    } else {
        $restartTimer.Stop()
        ShowActionFeedback "Restart Laptop..." ([char]0xE777) "#EF4444"
        Start-Process "shutdown.exe" -ArgumentList "/r /t 2 /c `"Restart via Oceru Dynamic Island`""
    }
})

# 7. VISUAL THEME SWITCHER
function ApplyTheme($theme) {
    $global:OceruState.theme = $theme
    if ($theme -eq "ocean-dark") {
        $notch.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#070B14")
        $notch.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#172640")
        $lblTheme.Text = "Ocean Dark"
        ShowActionFeedback "Tema: Ocean Dark" ([char]0xE790) "#0284C7"
    } elseif ($theme -eq "glass") {
        $notch.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E60C1B2E")
        $notch.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")
        $lblTheme.Text = "Aero Glass"
        ShowActionFeedback "Tema: Aero Glass" ([char]0xE790) "#00D2FF"
    } elseif ($theme -eq "cyber") {
        $notch.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0D0518")
        $notch.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF007F")
        $lblTheme.Text = "Cyberpunk"
        ShowActionFeedback "Tema: Cyberpunk" ([char]0xE790) "#FF007F"
    }
    Save-OceruState
}

$btnThemeSwitch.Add_Click({
    if ($global:OceruState.theme -eq "ocean-dark") { ApplyTheme("glass") }
    elseif ($global:OceruState.theme -eq "glass") { ApplyTheme("cyber") }
    else { ApplyTheme("ocean-dark") }
})

# Context Menu Themes
$ctxDark = $window.FindName("CtxThemeDark")
if ($ctxDark) { $ctxDark.Add_Click({ ApplyTheme("ocean-dark") }) }
$ctxGlass = $window.FindName("CtxThemeGlass")
if ($ctxGlass) { $ctxGlass.Add_Click({ ApplyTheme("glass") }) }
$ctxCyber = $window.FindName("CtxThemeCyber")
if ($ctxCyber) { $ctxCyber.Add_Click({ ApplyTheme("cyber") }) }

# 8. MUSIC & LYRICS CONTROLLER
$lyricsList = @(
    "Never gonna give you up... never gonna let you down",
    "Never gonna run around and desert you",
    "Never gonna make you cry, never gonna say goodbye",
    "Never gonna tell a lie and hurt you",
    "We've known each other for so long, your heart's been aching"
)
$lyricIndex = 0

$btnPlay.Add_Click({
    $global:OceruState.currentMedia.isPlaying = -not $global:OceruState.currentMedia.isPlaying
    if ($global:OceruState.currentMedia.isPlaying) {
        $playIcon.Text = [char]0xE769 # Pause icon
        $btnPlay.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EAB308")
        ShowActionFeedback "Memutar Musik" ([char]0xE189) "#00D2FF"
    } else {
        $playIcon.Text = [char]0xE768 # Play icon
        $btnPlay.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0284C7")
        ShowActionFeedback "Musik Dijeda" ([char]0xE768) "#94A3B8"
    }
    UpdateCompactView
    Save-OceruState
})

$btnNext.Add_Click({
    $global:lyricIndex = ($global:lyricIndex + 1) % $lyricsList.Count
    $musicLyricMini.Text = $lyricsList[$global:lyricIndex]
    $lyricLineActive.Text = $lyricsList[$global:lyricIndex]
    ShowActionFeedback "Lagu Berikutnya" ([char]0xE893) "#60A5FA"
})

$btnPrev.Add_Click({
    $global:lyricIndex = ($global:lyricIndex - 1 + $lyricsList.Count) % $lyricsList.Count
    $musicLyricMini.Text = $lyricsList[$global:lyricIndex]
    $lyricLineActive.Text = $lyricsList[$global:lyricIndex]
    ShowActionFeedback "Lagu Sebelumnya" ([char]0xE892) "#60A5FA"
})

$ytInput.Add_GotFocus({
    if ($ytInput.Text -eq "Cari / paste link YouTube...") {
        $ytInput.Text = ""
        $ytInput.Foreground = [System.Windows.Media.Brushes]::White
    }
})

$ytInput.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($ytInput.Text)) {
        $ytInput.Text = "Cari / paste link YouTube..."
        $ytInput.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
    }
})

$ytInput.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        if (-not [string]::IsNullOrWhiteSpace($ytInput.Text) -and $ytInput.Text -ne "Cari / paste link YouTube...") {
            $inputQuery = $ytInput.Text
            $trackTitle.Text = $inputQuery
            $global:OceruState.currentMedia.title = $inputQuery
            $global:OceruState.currentMedia.isPlaying = $true
            $playIcon.Text = [char]0xE769
            $btnPlay.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EAB308")
            ShowActionFeedback "Memutar Audio YouTube!" ([char]0xE189) "#00D2FF"
            UpdateCompactView

            if ($inputQuery -match "^https?://") {
                try {
                    $audioWebEngine.Navigate($inputQuery)
                } catch {
                    [System.Diagnostics.Process]::Start("explorer.exe", $inputQuery)
                }
            } else {
                $searchUrl = "https://www.youtube.com/results?search_query=" + [System.Uri]::EscapeDataString($inputQuery)
                [System.Diagnostics.Process]::Start("explorer.exe", $searchUrl)
            }
            Save-OceruState
        }
    }
})

# 9. POMODORO FOCUS TIMER
$pomoTimerEngine = New-Object System.Windows.Threading.DispatcherTimer
$pomoTimerEngine.Interval = [TimeSpan]::FromSeconds(1)

$pomoTimerEngine.Add_Tick({
    if ($global:OceruState.pomodoro.remainingSeconds -gt 0) {
        $global:OceruState.pomodoro.remainingSeconds = [int]$global:OceruState.pomodoro.remainingSeconds - 1
        $timeStr = [TimeSpan]::FromSeconds($global:OceruState.pomodoro.remainingSeconds).ToString("mm\:ss")
        $pomoTimer.Text = $timeStr
        $compactTimerText.Text = $timeStr
    } else {
        $pomoTimerEngine.Stop()
        $global:OceruState.pomodoro.isRunning = $false
        ShowActionFeedback "Waktu Fokus Selesai!" ([char]0xE916) "#10B981"
        UpdateCompactView
    }
})

function SetTimerMinutes($mins) {
    $global:OceruState.pomodoro.remainingSeconds = $mins * 60
    $pomoTimer.Text = [TimeSpan]::FromSeconds($global:OceruState.pomodoro.remainingSeconds).ToString("mm\:ss")
    ShowActionFeedback "Timer: $mins Menit" ([char]0xE916) "#38BDF8"
    Save-OceruState
}

$btnPill5.Add_Click({ SetTimerMinutes(5) })
$btnPill10.Add_Click({ SetTimerMinutes(10) })
$btnPill15.Add_Click({ SetTimerMinutes(15) })
$btnPill25.Add_Click({ SetTimerMinutes(25) })
$btnPill45.Add_Click({ SetTimerMinutes(45) })

$btnPomoStart.Add_Click({
    $global:OceruState.pomodoro.isRunning = -not $global:OceruState.pomodoro.isRunning
    if ($global:OceruState.pomodoro.isRunning) {
        $btnPomoStart.Content = "Jeda"
        $btnPomoStart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EAB308")
        $pomoTimerEngine.Start()
        ShowActionFeedback "Timer Dimulai!" ([char]0xE916) "#10B981"
    } else {
        $btnPomoStart.Content = "Mulai"
        $btnPomoStart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
        $pomoTimerEngine.Stop()
        ShowActionFeedback "Timer Dijeda" ([char]0xE916) "#94A3B8"
    }
    UpdateCompactView
    Save-OceruState
})

$btnPomoReset.Add_Click({
    $pomoTimerEngine.Stop()
    $global:OceruState.pomodoro.isRunning = $false
    $btnPomoStart.Content = "Mulai"
    $btnPomoStart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
    $global:OceruState.pomodoro.remainingSeconds = if ($global:OceruState.pomodoro.mode -eq "focus") { 25 * 60 } else { 5 * 60 }
    $pomoTimer.Text = [TimeSpan]::FromSeconds($global:OceruState.pomodoro.remainingSeconds).ToString("mm\:ss")
    ShowActionFeedback "Timer Direset" ([char]0xE916) "#60A5FA"
    UpdateCompactView
    Save-OceruState
})

$btnPomoMode.Add_Click({
    $pomoTimerEngine.Stop()
    $global:OceruState.pomodoro.isRunning = $false
    $btnPomoStart.Content = "Mulai"
    $btnPomoStart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
    if ($global:OceruState.pomodoro.mode -eq "focus") {
        $global:OceruState.pomodoro.mode = "break"
        $pomoStatus.Text = "WAKTU ISTIRAHAT"
        $pomoStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
        $btnPomoMode.Content = "Mode Fokus"
        $global:OceruState.pomodoro.remainingSeconds = 5 * 60
        ShowActionFeedback "Mode Istirahat (5m)" ([char]0xE916) "#38BDF8"
    } else {
        $global:OceruState.pomodoro.mode = "focus"
        $pomoStatus.Text = "FOKUS AKTIF"
        $pomoStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
        $btnPomoMode.Content = "Istirahat"
        $global:OceruState.pomodoro.remainingSeconds = 25 * 60
        ShowActionFeedback "Mode Fokus (25m)" ([char]0xE916) "#10B981"
    }
    $pomoTimer.Text = [TimeSpan]::FromSeconds($global:OceruState.pomodoro.remainingSeconds).ToString("mm\:ss")
    UpdateCompactView
    Save-OceruState
})

# 10. CLIPBOARD MANAGER (1-Click Re-Copy)
function CopyClipText($text) {
    try {
        [System.Windows.Clipboard]::SetText($text)
        ShowActionFeedback "Tersalin ke Clipboard!" ([char]0xE8C8) "#00D2FF"
    } catch {}
}

$btnClipItem1.Add_Click({ CopyClipText("https://github.com/cubadakanda/dynamic-island") })
$btnClipItem2.Add_Click({ CopyClipText("Oceru Dynamic Island Desktop") })
$btnClipItem3.Add_Click({ CopyClipText("Never Gonna Give You Up - Rick Astley") })

# 11. TO-DO MANAGER
function UpdateTodoCount {
    $total = 0
    $done = 0
    foreach ($child in $todoListPanel.Children) {
        if ($child -is [System.Windows.Controls.Border]) {
            $sp = $child.Child
            if ($sp -and $sp.Children.Count -ge 2) {
                $cb = $sp.Children[0]
                $total++
                if ($cb.IsChecked) { $done++ }
            }
        }
    }
    $todoCounterText.Text = "$done dari $total selesai"
}

$chk1.Add_Click({
    if ($chk1.IsChecked) {
        $txt1.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
        $txt1.TextDecorations = [System.Windows.TextDecorations]::Strikethrough
    } else {
        $txt1.Foreground = [System.Windows.Media.Brushes]::White
        $txt1.TextDecorations = $null
    }
    UpdateTodoCount
})

$chk2.Add_Click({
    if ($chk2.IsChecked) {
        $txt2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
        $txt2.TextDecorations = [System.Windows.TextDecorations]::Strikethrough
    } else {
        $txt2.Foreground = [System.Windows.Media.Brushes]::White
        $txt2.TextDecorations = $null
    }
    UpdateTodoCount
})

$chk3.Add_Click({
    if ($chk3.IsChecked) {
        $txt3.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
        $txt3.TextDecorations = [System.Windows.TextDecorations]::Strikethrough
    } else {
        $txt3.Foreground = [System.Windows.Media.Brushes]::White
        $txt3.TextDecorations = $null
    }
    UpdateTodoCount
})

$todoInput.Add_GotFocus({
    if ($todoInput.Text -eq "Tulis catatan / tugas baru lalu tekan Enter...") {
        $todoInput.Text = ""
        $todoInput.Foreground = [System.Windows.Media.Brushes]::White
    }
})

$todoInput.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($todoInput.Text)) {
        $todoInput.Text = "Tulis catatan / tugas baru lalu tekan Enter..."
        $todoInput.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
    }
})

$todoInput.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        if (-not [string]::IsNullOrWhiteSpace($todoInput.Text) -and $todoInput.Text -ne "Tulis catatan / tugas baru lalu tekan Enter...") {
            $taskText = $todoInput.Text

            $b = New-Object System.Windows.Controls.Border
            $b.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#09101E")
            $b.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#192A45")
            $b.BorderThickness = New-Object System.Windows.Thickness(1)
            $b.CornerRadius = New-Object System.Windows.CornerRadius(6)
            $b.Padding = New-Object System.Windows.Thickness(7, 3, 7, 3)
            $b.Margin = New-Object System.Windows.Thickness(0, 0, 0, 3)

            $sp = New-Object System.Windows.Controls.StackPanel
            $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal

            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = $taskText
            $tb.Foreground = [System.Windows.Media.Brushes]::White
            $tb.FontSize = 9.5
            $tb.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.IsChecked = $false
            $cb.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $cb.Margin = New-Object System.Windows.Thickness(0, 0, 7, 0)
            $cb.Tag = $tb

            $cb.Add_Click({
                param($sender, $eventArgs)
                $targetTb = $sender.Tag
                if ($sender.IsChecked) {
                    $targetTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
                    $targetTb.TextDecorations = [System.Windows.TextDecorations]::Strikethrough
                } else {
                    $targetTb.Foreground = [System.Windows.Media.Brushes]::White
                    $targetTb.TextDecorations = $null
                }
                UpdateTodoCount
            })

            $sp.Children.Add($cb) | Out-Null
            $sp.Children.Add($tb) | Out-Null
            $b.Child = $sp
            $todoListPanel.Children.Add($b) | Out-Null

            $todoInput.Text = ""
            UpdateTodoCount
            ShowActionFeedback "Tugas Ditambahkan!" ([char]0xE73E) "#10B981"
        }
    }
})

# 12. DRAG AND DROP FILE SHELF
$stagedCount = 0
$notch.Add_DragEnter({
    param($s, $e)
    AnimateExpand
    SwitchTab("shelf")
    $e.Effects = [System.Windows.DragDropEffects]::Copy
    $e.Handled = $true
})

$notch.Add_Drop({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        $shelfPlaceholder.Visibility = [System.Windows.Visibility]::Collapsed
        
        foreach ($file in $files) {
            $global:stagedCount++
            $shelfBadgeCount.Text = "($global:stagedCount)"
            $name = [System.IO.Path]::GetFileName($file)
            
            $card = New-Object System.Windows.Controls.Border
            $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0C1527")
            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E3150")
            $card.BorderThickness = New-Object System.Windows.Thickness(1)
            $card.CornerRadius = New-Object System.Windows.CornerRadius(6)
            $card.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
            $card.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
            $card.Cursor = [System.Windows.Input.Cursors]::Hand

            $sp = New-Object System.Windows.Controls.StackPanel
            $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal

            $icon = New-Object System.Windows.Controls.TextBlock
            $icon.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
            $icon.Text = [char]0xE8A5
            $icon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")
            $icon.FontSize = 11
            $icon.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)

            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = $name
            $tb.Foreground = [System.Windows.Media.Brushes]::White
            $tb.FontSize = 10

            $sp.Children.Add($icon) | Out-Null
            $sp.Children.Add($tb) | Out-Null
            $card.Child = $sp

            $shelfItemsList.Children.Add($card) | Out-Null
        }
        ShowActionFeedback "$($files.Count) File Ditambahkan!" ([char]0xED25) "#00D2FF"
    }
})

# 13. DASHBOARD SHORTCUT ACTIONS
$btnQuickLock = $dashWindow.FindName("BtnQuickLock")
if ($btnQuickLock) { $btnQuickLock.Add_Click({ [Win32Helper]::LockWorkStation() }) }

$btnQuickSleep = $dashWindow.FindName("BtnQuickSleep")
if ($btnQuickSleep) { $btnQuickSleep.Add_Click({ Start-Process "rundll32.exe" -ArgumentList "powrprof.dll,SetSuspendState 0,1,0" }) }

$btnQuickRestart = $dashWindow.FindName("BtnQuickRestart")
if ($btnQuickRestart) { $btnQuickRestart.Add_Click({ Start-Process "shutdown.exe" -ArgumentList "/r /t 2 /c `"Restart via Oceru Dashboard`"" }) }

$dashNoteBox = $dashWindow.FindName("DashNoteBox")
$btnSaveNote = $dashWindow.FindName("BtnSaveNote")
if ($btnSaveNote -and $dashNoteBox) {
    $btnSaveNote.Add_Click({
        $global:OceruState.notes[0].content = $dashNoteBox.Text
        $global:OceruState.notes[0].updatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        Save-OceruState
        ShowActionFeedback "Catatan Tersimpan!" ([char]0xE73E) "#10B981"
    })
}

# Quick Launcher Handlers
$btnQkChrome = $dashWindow.FindName("BtnQkChrome")
if ($btnQkChrome) { $btnQkChrome.Add_Click({ Start-Process "chrome.exe" -ErrorAction SilentlyContinue }) }
$btnQkExplorer = $dashWindow.FindName("BtnQkExplorer")
if ($btnQkExplorer) { $btnQkExplorer.Add_Click({ Start-Process "explorer.exe" }) }
$btnQkTerminal = $dashWindow.FindName("BtnQkTerminal")
if ($btnQkTerminal) { $btnQkTerminal.Add_Click({ Start-Process "powershell.exe" }) }
$btnQkTaskMgr = $dashWindow.FindName("BtnQkTaskMgr")
if ($btnQkTaskMgr) { $btnQkTaskMgr.Add_Click({ Start-Process "taskmgr.exe" }) }
$btnQkSettings = $dashWindow.FindName("BtnQkSettings")
if ($btnQkSettings) { $btnQkSettings.Add_Click({ Start-Process "ms-settings:" }) }

$btnQsWifi = $dashWindow.FindName("BtnQsWifi")
if ($btnQsWifi) { $btnQsWifi.Add_Click({ [System.Diagnostics.Process]::Start("explorer.exe", "ms-availablenetworks:") }) }
$btnQsBt = $dashWindow.FindName("BtnQsBt")
if ($btnQsBt) { $btnQsBt.Add_Click({ [System.Diagnostics.Process]::Start("explorer.exe", "ms-settings:bluetooth") }) }

$btnThemeSetDark = $dashWindow.FindName("BtnThemeSetDark")
if ($btnThemeSetDark) { $btnThemeSetDark.Add_Click({ ApplyTheme("ocean-dark") }) }
$btnThemeSetGlass = $dashWindow.FindName("BtnThemeSetGlass")
if ($btnThemeSetGlass) { $btnThemeSetGlass.Add_Click({ ApplyTheme("glass") }) }
$btnThemeSetCyber = $dashWindow.FindName("BtnThemeSetCyber")
if ($btnThemeSetCyber) { $btnThemeSetCyber.Add_Click({ ApplyTheme("cyber") }) }

# 14. REAL-TIME HARDWARE & SYSTEM MONITOR (1 Second Interval)
$dashRamVal = $dashWindow.FindName("DashRamVal")
$dashBatVal = $dashWindow.FindName("DashBatVal")
$dashBatStatus = $dashWindow.FindName("DashBatStatus")
$dashVolVal = $dashWindow.FindName("DashVolVal")
$dashMuteStatus = $dashWindow.FindName("DashMuteStatus")
$dashSysMonRam = $dashWindow.FindName("DashSysMonRam")
$dashSysMonBat = $dashWindow.FindName("DashSysMonBat")

$musicProgressVal = 42
$waveState = 0
$monitorTimer = New-Object System.Windows.Threading.DispatcherTimer
$monitorTimer.Interval = [TimeSpan]::FromSeconds(1)

$monitorTimer.Add_Tick({
    $now = Get-Date
    $clockText.Text = $now.ToString("HH:mm")
    $dateText.Text = $now.ToString("HH:mm")

    # 1. Real-time RAM Load (Fast Kernel32 GlobalMemoryStatusEx)
    try {
        $ram = [Win32Helper]::GetRamLoad()
        $dashRamVal.Text = "$ram%"
        $dashSysMonRam.Text = "$ram% Digunakan"
    } catch {}

    # 2. Real-time Battery Check
    try {
        $power = [System.Windows.Forms.SystemInformation]::PowerStatus
        $batPct = [Math]::Round($power.BatteryLifePercent * 100)
        $isOnline = $power.PowerLineStatus -eq "Online"

        $collapsedBatPct.Text = "$batPct%"
        $headerBatText.Text = "$batPct%"
        $dashBatVal.Text = "$batPct%"

        if ($isOnline) {
            $collapsedBatIcon.Text = [char]0xEA93 # Lightning
            $collapsedBatIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
            $headerBatIcon.Text = [char]0xEA93
            $dashBatStatus.Text = "Mengisi Daya ⚡"
            $dashSysMonBat.Text = "$batPct% (Mengisi Daya ⚡)"
        } else {
            $collapsedBatIcon.Text = [char]0xEBAA # Battery
            $collapsedBatIcon.Foreground = if ($batPct -lt 20) { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444") } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8") }
            $headerBatIcon.Text = [char]0xEBAA
            $dashBatStatus.Text = "Baterai Laptop"
            $dashSysMonBat.Text = "$batPct% (Baterai)"
        }
    } catch {}

    # 3. Audio & Volume Display
    $dashVolVal.Text = "$($global:OceruState.volume)%"
    $dashMuteStatus.Text = if ($global:OceruState.isMuted) { "Audio Bisu (Muted)" } else { "Audio Normal" }

    # 4. Music Equalizer & Lyric Simulation
    if ($global:OceruState.currentMedia.isPlaying) {
        $global:musicProgressVal = ($global:musicProgressVal + 1) % 100
        $trackProgress.Value = $global:musicProgressVal

        if ($global:musicProgressVal % 4 -eq 0) {
            $global:lyricIndex = ($global:lyricIndex + 1) % $lyricsList.Count
            $activeLyric = $lyricsList[$global:lyricIndex]
            $pastLyric = $lyricsList[($global:lyricIndex - 1 + $lyricsList.Count) % $lyricsList.Count]
            $nextLyric = $lyricsList[($global:lyricIndex + 1) % $lyricsList.Count]

            $musicLyricMini.Text = $activeLyric
            $lyricLineActive.Text = $activeLyric
            $lyricLinePast.Text = $pastLyric
            $lyricLineNext.Text = $nextLyric

            $global:waveState = ($global:waveState + 1) % 3
            if ($global:waveState -eq 0) {
                $waveAnimText.Text = " |||"
                $compactWaveText.Text = "|||"
            } elseif ($global:waveState -eq 1) {
                $waveAnimText.Text = " | |"
                $compactWaveText.Text = "| |"
            } else {
                $waveAnimText.Text = " || "
                $compactWaveText.Text = "|| "
            }
        }
    }
})

$monitorTimer.Start()

# Apply saved theme on start
ApplyTheme($global:OceruState.theme)

# Run Island Application Window
$window.ShowDialog() | Out-Null
