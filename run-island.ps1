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

$screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
$screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight

# Geometry for 3 Distinct Island Modes:
# 1. Eyes Mode (Resting standalone cat eyes pill)
$eyesWidth = 88
$eyesHeight = 36
$eyesLeftPos = [Math]::Round(($screenWidth - $eyesWidth) / 2)

# 2. Status Mode (Clock, Weather, Battery status bar on collapse)
$statusWidth = 230
$statusHeight = 36
$statusLeftPos = [Math]::Round(($screenWidth - $statusWidth) / 2)

# 3. Expanded Mode (Full 6-card carousel notch)
$expandedWidth = 560
$expandedHeight = 205
$expandedLeftPos = [Math]::Round(($screenWidth - $expandedWidth) / 2)

$global:notchCenterX = $screenWidth / 2

# XAML 1: DYNAMIC ISLAND (RESTING CAT EYES + STATUS BAR + 6-CARD CAROUSEL)
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
        Top="0" Width="88" Height="36">
    <Window.Resources>
        <!-- Circle Navigation Button -->
        <Style x:Key="CircleNavBtn" TargetType="Button">
            <Setter Property="Width" Value="28"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="Background" Value="#242426"/>
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
                                <Setter TargetName="BtnBorder" Property="Background" Value="#38383A"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Pill Button -->
        <Style x:Key="PillBtn" TargetType="Button">
            <Setter Property="Background" Value="#1C1C1E"/>
            <Setter Property="BorderBrush" Value="#2C2C2E"/>
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
                                <Setter TargetName="PillBorder" Property="Background" Value="#2C2C2E"/>
                                <Setter TargetName="PillBorder" Property="BorderBrush" Value="#38BDF8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Quick Mini Button -->
        <Style x:Key="QuickMiniBtn" TargetType="Button">
            <Setter Property="Background" Value="#141416"/>
            <Setter Property="BorderBrush" Value="#242426"/>
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
                                <Setter TargetName="MiniBorder" Property="Background" Value="#202024"/>
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

    <Grid>
        <!-- ======================================================== -->
        <!-- VIEW 1: RESTING CAT EYES PILL (Standalone, Eyes Only!)    -->
        <!-- ======================================================== -->
        <Grid x:Name="EyesGrid" Visibility="Visible" HorizontalAlignment="Center" VerticalAlignment="Top" Width="88" Height="36" Cursor="Hand">
            <!-- Sleek Concave Silhouette for 88px Pill -->
            <Path x:Name="EyesNotchBg" Fill="#000000"
                  Data="M 0,0 C 6,0 12,6 12,12 L 12,20 A 16,16 0 0 0 28,36 L 60,36 A 16,16 0 0 0 76,20 L 76,12 C 76,6 82,0 88,0 L 0,0 Z">
                <Path.Effect>
                    <DropShadowEffect BlurRadius="12" ShadowDepth="3" Direction="270" Opacity="0.6" Color="#000000"/>
                </Path.Effect>
            </Path>

            <!-- Centered Interactive Cat Eyes (Tracks Cursor Everywhere!) -->
            <StackPanel x:Name="CatEyesContainer" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                <!-- Left Eye -->
                <Border x:Name="LeftEye" Width="14" Height="16" CornerRadius="7" Background="#FFFFFF" Margin="0,0,8,0" ClipToBounds="True">
                    <Grid>
                        <Grid x:Name="LeftPupil" HorizontalAlignment="Center" VerticalAlignment="Center">
                            <Grid.RenderTransform>
                                <TranslateTransform x:Name="LeftPupilTransform" X="0" Y="0"/>
                            </Grid.RenderTransform>
                            <Border Width="4.5" Height="10" CornerRadius="2.25" Background="#060A14"/>
                            <Border Width="1.8" Height="1.8" CornerRadius="0.9" Background="#FFFFFF" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,1,0.5,0"/>
                        </Grid>
                    </Grid>
                </Border>

                <!-- Right Eye -->
                <Border x:Name="RightEye" Width="14" Height="16" CornerRadius="7" Background="#FFFFFF" ClipToBounds="True">
                    <Grid>
                        <Grid x:Name="RightPupil" HorizontalAlignment="Center" VerticalAlignment="Center">
                            <Grid.RenderTransform>
                                <TranslateTransform x:Name="RightPupilTransform" X="0" Y="0"/>
                            </Grid.RenderTransform>
                            <Border Width="4.5" Height="10" CornerRadius="2.25" Background="#060A14"/>
                            <Border Width="1.8" Height="1.8" CornerRadius="0.9" Background="#FFFFFF" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,1,0.5,0"/>
                        </Grid>
                    </Grid>
                </Border>
            </StackPanel>
        </Grid>


        <!-- ======================================================== -->
        <!-- VIEW 2: COMPACT STATUS BAR (Weather, Clock, Battery)     -->
        <!-- ======================================================== -->
        <Grid x:Name="StatusGrid" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Top" Width="230" Height="36" Cursor="Hand">
            <!-- Silhouette with Concave Ears for 230px Status Bar -->
            <Path x:Name="StatusNotchBg" Fill="#000000"
                  Data="M 0,0 C 6,0 12,6 12,12 L 12,20 A 16,16 0 0 0 28,36 L 202,36 A 16,16 0 0 0 218,20 L 218,12 C 218,6 224,0 230,0 L 0,0 Z">
                <Path.Effect>
                    <DropShadowEffect BlurRadius="14" ShadowDepth="3" Direction="270" Opacity="0.6" Color="#000000"/>
                </Path.Effect>
            </Path>

            <!-- Status Content Row: Weather on Left, Clock in Center, Battery on Right -->
            <Grid Margin="16,0,16,0">
                <!-- Left: Weather -->
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
                    <TextBlock Text="&#xE706;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" Margin="0,0,4,0" VerticalAlignment="Center"/>
                    <TextBlock Text="28&#176;" FontSize="11" FontWeight="SemiBold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                </StackPanel>

                <!-- Center: REAL-TIME CLOCK (Replaces Eyes in Status Bar!) -->
                <TextBlock x:Name="CompactClockText" Text="09:35" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>

                <!-- Right: Battery & Mode -->
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <TextBlock x:Name="CompactBatPct" Text="85%" FontSize="11" Foreground="#CBD5E1" Margin="0,0,4,0" VerticalAlignment="Center"/>
                    <TextBlock x:Name="CompactBatIcon" Text="&#xEA93;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" VerticalAlignment="Center"/>
                </StackPanel>
            </Grid>
        </Grid>


        <!-- ======================================================== -->
        <!-- VIEW 3: EXPANDED CAROUSEL VIEW (Full Notch)              -->
        <!-- ======================================================== -->
        <Grid x:Name="ExpandedGrid" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Top" Width="560" Height="205">
            <!-- Background Notch Silhouette with Concave Ears -->
            <Path x:Name="NotchBgPath" Fill="#000000"
                  Data="M 0,0 C 10,0 20,10 20,20 L 20,162 A 28,28 0 0 0 48,190 L 512,190 A 28,28 0 0 0 540,162 L 540,20 C 540,10 550,0 560,0 L 0,0 Z">
                <Path.Effect>
                    <DropShadowEffect BlurRadius="25" ShadowDepth="6" Direction="270" Opacity="0.6" Color="#000000"/>
                </Path.Effect>
            </Path>

            <!-- Main Interior Container -->
            <Grid Margin="26,0,26,0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="34"/>  <!-- Top Status / Header Row -->
                    <RowDefinition Height="114"/> <!-- Main Carousel Card Body -->
                    <RowDefinition Height="38"/>  <!-- Bottom Action Buttons & Pagination -->
                </Grid.RowDefinitions>

                <!-- Center Top Sensor / Camera Dot -->
                <Border Width="6" Height="6" CornerRadius="3" Background="#18181A"
                        HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,3,0,0"/>

                <!-- TOP HEADER ROW (NO COLLAPSE BUTTON!) -->
                <Grid Grid.Row="0" Margin="10,6,10,0">
                    <!-- Left: Card Title -->
                    <TextBlock x:Name="HeaderTitleText" Text="" FontWeight="SemiBold" FontSize="15" Foreground="#FFFFFF"
                               VerticalAlignment="Center" HorizontalAlignment="Left" Cursor="Hand"/>

                    <!-- Center: Green Ring + Date & Time -->
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Border Width="13" Height="13" CornerRadius="6.5" BorderThickness="2" BorderBrush="#10B981"
                                Margin="0,0,7,0" Background="Transparent"/>
                        <TextBlock x:Name="HeaderDateText" Text="Sun 25 Oct 2026 " FontSize="12" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                        <TextBlock x:Name="HeaderTimeText" Text="09:35" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                    </StackPanel>

                    <!-- Right: Soundwave Equalizer Bars (Collapse Button Removed as Requested!) -->
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <StackPanel x:Name="HeaderWavePanel" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,4,0">
                            <Border x:Name="WaveBar1" Width="2.5" Height="8" CornerRadius="1.25" Background="#FFFFFF" Margin="1.5,0"/>
                            <Border x:Name="WaveBar2" Width="2.5" Height="14" CornerRadius="1.25" Background="#FFFFFF" Margin="1.5,0"/>
                            <Border x:Name="WaveBar3" Width="2.5" Height="10" CornerRadius="1.25" Background="#FFFFFF" Margin="1.5,0"/>
                            <Border x:Name="WaveBar4" Width="2.5" Height="12" CornerRadius="1.25" Background="#FFFFFF" Margin="1.5,0"/>
                        </StackPanel>
                    </StackPanel>
                </Grid>

                <!-- MAIN CAROUSEL CONTENT (6 CARDS) -->
                <Grid Grid.Row="1" Margin="10,0,10,0">
                    
                    <!-- ============================================== -->
                    <!-- CARD 0: MUSIC PLAYER                           -->
                    <!-- ============================================== -->
                    <Grid x:Name="CardMusic" Visibility="Visible">
                        <!-- Default Player Layout -->
                        <Grid x:Name="MusicPlayerView" Visibility="Visible">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="68"/>
                                <RowDefinition Height="20"/>
                                <RowDefinition Height="26"/>
                            </Grid.RowDefinitions>

                            <Grid Grid.Row="0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="78"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="32"/>
                                </Grid.ColumnDefinitions>

                                <!-- Stylized Vinyl Album Art -->
                                <Border Grid.Column="0" Width="68" Height="68" CornerRadius="14" Background="#DCEAF8"
                                        HorizontalAlignment="Left" VerticalAlignment="Center" ClipToBounds="True">
                                    <Grid>
                                        <Border Height="1" Background="#CBDCF0" VerticalAlignment="Top" Margin="0,14,0,0"/>
                                        <Border Height="1" Background="#CBDCF0" VerticalAlignment="Top" Margin="0,28,0,0"/>
                                        <Border Height="1" Background="#CBDCF0" VerticalAlignment="Top" Margin="0,42,0,0"/>
                                        <Border Height="1" Background="#CBDCF0" VerticalAlignment="Top" Margin="0,56,0,0"/>
                                        <Border Width="46" Height="46" CornerRadius="23" BorderThickness="1.5" BorderBrush="#94C5EE"
                                                HorizontalAlignment="Center" VerticalAlignment="Center">
                                            <Border Width="38" Height="38" CornerRadius="19" Background="#0284C7"
                                                    HorizontalAlignment="Center" VerticalAlignment="Center">
                                                <Border Width="24" Height="24" CornerRadius="12" BorderThickness="1.5" BorderBrush="#BAE6FD"
                                                        HorizontalAlignment="Center" VerticalAlignment="Center">
                                                    <Border Width="10" Height="10" CornerRadius="5" Background="#0369A1"/>
                                                </Border>
                                            </Border>
                                        </Border>
                                        <Path Data="M 14,8 L 54,60" Stroke="#FFFFFF" StrokeThickness="1.5" Opacity="0.9"/>
                                    </Grid>
                                </Border>

                                <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="4,0,0,0">
                                    <TextBlock x:Name="MusicTitle" Text="Paper Sky" FontSize="16" FontWeight="SemiBold"
                                               Foreground="#FFFFFF" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock x:Name="MusicArtist" Text="Lumen Coast - Summer Flows" FontSize="12"
                                               Foreground="#8E8E93" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>

                                <Button x:Name="BtnMusicNextCard" Grid.Column="2" Style="{StaticResource CircleNavBtn}"
                                        HorizontalAlignment="Right" VerticalAlignment="Center">
                                    <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                                </Button>
                            </Grid>

                            <!-- Seekbar -->
                            <Grid Grid.Row="1" VerticalAlignment="Center">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="42"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="46"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock x:Name="MusicCurrentTime" Grid.Column="0" Text="03:13" FontSize="11" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                                <Grid Grid.Column="1" Margin="6,0" VerticalAlignment="Center">
                                    <Border Height="4" CornerRadius="2" Background="#2C2C2E"/>
                                    <Border x:Name="MusicProgressBar" Height="4" CornerRadius="2" Background="#FFFFFF" HorizontalAlignment="Left" Width="150"/>
                                </Grid>
                                <TextBlock x:Name="MusicRemainingTime" Grid.Column="2" Text="-01:03" FontSize="11" Foreground="#8E8E93"
                                           HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>

                            <!-- Controls Row -->
                            <Grid Grid.Row="2">
                                <Button x:Name="BtnToggleLyrics" Style="{StaticResource CircleNavBtn}" Width="26" Height="26"
                                        HorizontalAlignment="Left" VerticalAlignment="Center" ToolTip="Lihat Lirik Lagu">
                                    <TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#8E8E93"/>
                                </Button>

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                                    <Button x:Name="BtnMusicPrev" Style="{StaticResource MediaControlBtn}" Margin="0,0,24,0">
                                        <TextBlock Text="&#xE892;" FontFamily="Segoe MDL2 Assets" FontSize="15" Foreground="#FFFFFF"/>
                                    </Button>
                                    <Button x:Name="BtnMusicPlayPause" Style="{StaticResource MediaControlBtn}" Margin="0,0,24,0">
                                        <TextBlock x:Name="MusicPlayPauseIcon" Text="&#xE769;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="#FFFFFF"/>
                                    </Button>
                                    <Button x:Name="BtnMusicNext" Style="{StaticResource MediaControlBtn}">
                                        <TextBlock Text="&#xE893;" FontFamily="Segoe MDL2 Assets" FontSize="15" Foreground="#FFFFFF"/>
                                    </Button>
                                </StackPanel>
                            </Grid>
                        </Grid>

                        <!-- Synced Lyrics View (Toggled via Lyrics button) -->
                        <Grid x:Name="MusicLyricsView" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="24"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <Button x:Name="BtnBackFromLyrics" Grid.Row="0" Style="{StaticResource CircleNavBtn}" Width="22" Height="22" HorizontalAlignment="Left">
                                <TextBlock Text="&#xE72B;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#CBD5E1"/>
                            </Button>
                            <StackPanel Grid.Row="1" VerticalAlignment="Center" HorizontalAlignment="Center">
                                <TextBlock Text="Gliding high above the quiet morning sky..." FontSize="12" Foreground="#64748B" HorizontalAlignment="Center" Margin="0,2"/>
                                <TextBlock Text="Ocean breeze whispers what you left behind" FontSize="14" FontWeight="Bold" Foreground="#00D2FF" HorizontalAlignment="Center" Margin="0,2"/>
                                <TextBlock Text="Folded wings of paper chasing summer light" FontSize="12" Foreground="#64748B" HorizontalAlignment="Center" Margin="0,2"/>
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
                                <ColumnDefinition Width="90"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <!-- Circular Timer Dial -->
                            <Grid Grid.Column="0" Width="82" Height="82" HorizontalAlignment="Center" VerticalAlignment="Center">
                                <Border Width="82" Height="82" CornerRadius="41" BorderThickness="2.5" BorderBrush="#222224" Background="#121214"/>
                                <Border Width="82" Height="82" CornerRadius="41" BorderThickness="2.5" BorderBrush="#FF5252"
                                        Opacity="0.85" Background="Transparent"/>
                                <Border Width="6" Height="6" CornerRadius="3" Background="#FF5252" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,2,0,0"/>
                                <TextBlock Text="&#xE916;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#FF5252"
                                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Grid>

                            <!-- Timer Typography and Reset -->
                            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="14,0,0,0">
                                <TextBlock Text="Waktu Fokus" FontSize="12" Foreground="#A1A1AA" Margin="0,0,0,2"/>
                                <TextBlock x:Name="PomoSubtitle" Text="Focus time" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                                <StackPanel Orientation="Horizontal" Margin="0,2,0,0">
                                    <TextBlock x:Name="PomoDisplayTime" Text="25:00" FontFamily="Segoe UI, Consolas" FontSize="30" FontWeight="Bold" Foreground="#FFFFFF"/>
                                    <Button x:Name="BtnPomoReset" Style="{StaticResource CircleNavBtn}" Width="24" Height="24" Margin="10,0,0,0" ToolTip="Reset Timer">
                                        <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A1A1AA"/>
                                    </Button>
                                </StackPanel>
                            </StackPanel>
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
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="32"/>
                        </Grid.ColumnDefinitions>

                        <Button x:Name="BtnNotesPrevCard" Grid.Column="0" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Left" VerticalAlignment="Center">
                            <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                        </Button>

                        <!-- Left Half: Quick Note Editor -->
                        <Border Grid.Column="1" Background="#0C1424" BorderBrush="#162744" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="22"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="24"/>
                                </Grid.RowDefinitions>
                                <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Left">
                                    <TextBlock Text="&#xE70B;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Catatan Cepat" FontSize="12" FontWeight="Bold" Foreground="#00D2FF" VerticalAlignment="Center"/>
                                </StackPanel>
                                <TextBox x:Name="InputNoteText" Grid.Row="1" Background="#070C18" Foreground="#FFFFFF" BorderBrush="#1B2F50"
                                         FontSize="11" Margin="0,3" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Hidden"
                                         Text="Meeting project Oceru jam 10 pagi..."/>
                                <Button x:Name="BtnSaveNote" Grid.Row="2" Style="{StaticResource PillBtn}" Padding="8,2" HorizontalAlignment="Right">
                                    <TextBlock Text="Simpan" FontSize="10" Foreground="#38BDF8"/>
                                </Button>
                            </Grid>
                        </Border>

                        <!-- Right Half: To-Do Checklist -->
                        <Border Grid.Column="2" Background="#0C1424" BorderBrush="#162744" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="22"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Left">
                                    <TextBlock Text="&#xE73E;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Tugas Hari Ini" FontSize="12" FontWeight="Bold" Foreground="#10B981" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="TodoStatusCount" Text=" (2/3)" FontSize="11" Foreground="#94A3B8" Margin="4,0,0,0" VerticalAlignment="Center"/>
                                </StackPanel>
                                <StackPanel Grid.Row="1" Margin="0,4,0,0">
                                    <CheckBox x:Name="CbTask1" Content="Uji responsivitas Notch" IsChecked="True" Foreground="#CBD5E1" FontSize="11" Margin="0,2"/>
                                    <CheckBox x:Name="CbTask2" Content="Sinkronisasi audio &amp; volume" IsChecked="True" Foreground="#CBD5E1" FontSize="11" Margin="0,2"/>
                                    <CheckBox x:Name="CbTask3" Content="Cek catatan &amp; to-do list" IsChecked="False" Foreground="#CBD5E1" FontSize="11" Margin="0,2"/>
                                </StackPanel>
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
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="32"/>
                        </Grid.ColumnDefinitions>

                        <Button x:Name="BtnClipPrevCard" Grid.Column="0" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Left" VerticalAlignment="Center">
                            <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                        </Button>

                        <!-- Left: Clipboard History -->
                        <Border Grid.Column="1" Background="#0C1424" BorderBrush="#162744" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="22"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Left">
                                    <TextBlock Text="&#xE77F;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#C084FC" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Riwayat Salinan" FontSize="12" FontWeight="Bold" Foreground="#C084FC" VerticalAlignment="Center"/>
                                </StackPanel>
                                <StackPanel Grid.Row="1" Margin="0,4,0,0">
                                    <Button x:Name="BtnCopyClip1" Style="{StaticResource QuickMiniBtn}" Margin="0,2" HorizontalContentAlignment="Left">
                                        <StackPanel Orientation="Horizontal">
                                            <TextBlock Text="&#xE71B;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#38BDF8" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="github.com/cubadakanda..." FontSize="11" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                        </StackPanel>
                                    </Button>
                                    <Button x:Name="BtnCopyClip2" Style="{StaticResource QuickMiniBtn}" Margin="0,2" HorizontalContentAlignment="Left">
                                        <StackPanel Orientation="Horizontal">
                                            <TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="Oceru Dynamic Island" FontSize="11" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                        </StackPanel>
                                    </Button>
                                </StackPanel>
                            </Grid>
                        </Border>

                        <!-- Right: File Shelf Drop Zone -->
                        <Border x:Name="ShelfDropBorder" Grid.Column="2" Background="#0C1424" BorderBrush="#162744" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0" AllowDrop="True">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="22"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Left">
                                    <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="File Shelf (Tarik File)" FontSize="12" FontWeight="Bold" Foreground="#F59E0B" VerticalAlignment="Center"/>
                                </StackPanel>
                                <Border Grid.Row="1" BorderBrush="#2A3B58" BorderThickness="1" CornerRadius="8" Background="#070D18" Margin="0,3">
                                    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                            <TextBlock Text="&#xED25;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                            <TextBlock Text="Lepas file di sini" FontSize="11" Foreground="#94A3B8" VerticalAlignment="Center"/>
                                        </StackPanel>
                                        <TextBlock x:Name="ShelfFileCount" Text="0 file tersimpan" FontSize="10" Foreground="#64748B" HorizontalAlignment="Center" Margin="0,2,0,0"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                        </Border>

                        <Button x:Name="BtnClipNextCard" Grid.Column="3" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">
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
                        <Border Grid.Column="1" Background="#0C1424" BorderBrush="#162744" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                            <StackPanel VerticalAlignment="Center">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock x:Name="SysRamText" Text="48%" FontFamily="Segoe UI, Consolas" FontSize="28" FontWeight="Bold" Foreground="#FFFFFF"/>
                                    <TextBlock Text=" RAM" FontSize="14" FontWeight="SemiBold" Foreground="#00D2FF" VerticalAlignment="Bottom" Margin="4,0,0,4"/>
                                </StackPanel>
                                <TextBlock x:Name="SysBatStatusText" Text="Baterai 85% - Mengisi Daya" FontSize="11" Foreground="#8E8E93" Margin="0,2,0,0"/>
                                <Button x:Name="BtnSysTaskMgr" Style="{StaticResource QuickMiniBtn}" Margin="0,6,0,0" HorizontalAlignment="Left">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#38BDF8" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Buka Task Manager" FontSize="10" Foreground="#38BDF8" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </StackPanel>
                        </Border>

                        <!-- Right: Water Reminder -->
                        <Border Grid.Column="2" Background="#0C1424" BorderBrush="#162744" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                            <StackPanel VerticalAlignment="Center">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE798;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Air Minum" FontSize="12" FontWeight="Bold" Foreground="#38BDF8" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="WaterAmountText" Text=" (1.250 ml)" FontSize="11" Foreground="#94A3B8" Margin="4,0,0,0" VerticalAlignment="Center"/>
                                </StackPanel>
                                <Grid Margin="0,6">
                                    <Border Height="5" CornerRadius="2.5" Background="#162846"/>
                                    <Border x:Name="WaterProgressBar" Height="5" CornerRadius="2.5" Background="#00D2FF" HorizontalAlignment="Left" Width="110"/>
                                </Grid>
                                <Button x:Name="BtnAddWater" Style="{StaticResource PillBtn}" Padding="8,3" HorizontalAlignment="Left">
                                    <TextBlock Text="+ 250 ml (1 Gelas)" FontSize="10" Foreground="#E2E8F0"/>
                                </Button>
                            </StackPanel>
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
                                        <TextBlock Text="&#xE701;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Wi-Fi" FontSize="11" Foreground="#E2E8F0" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button x:Name="BtnQuickBt" Grid.Column="1" Margin="2" Style="{StaticResource QuickMiniBtn}">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE702;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Bluetooth" FontSize="11" Foreground="#E2E8F0" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button x:Name="BtnQuickDnd" Grid.Column="2" Margin="2" Style="{StaticResource QuickMiniBtn}">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE708;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A855F7" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="QuickStatusDnd" Text="DND" FontSize="11" Foreground="#E2E8F0" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button x:Name="BtnQuickGame" Grid.Column="3" Margin="2" Style="{StaticResource QuickMiniBtn}">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE7FC;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="QuickStatusGame" Text="Game" FontSize="11" Foreground="#E2E8F0" VerticalAlignment="Center"/>
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
                                    <TextBlock x:Name="QuickIconMute" Text="&#xE767;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#38BDF8"/>
                                </Button>
                                <Slider x:Name="QuickSliderVol" Grid.Column="1" Minimum="0" Maximum="100" Value="72" VerticalAlignment="Center" Margin="8,0"/>
                                <TextBlock x:Name="QuickVolPctText" Grid.Column="2" Text="72%" FontSize="11" Foreground="#CBD5E1" VerticalAlignment="Center"/>
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
                                        <TextBlock Text="&#xE72E;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#CBD5E1" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Kunci" FontSize="11" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button x:Name="BtnQuickSleep" Grid.Column="1" Margin="2" Style="{StaticResource QuickMiniBtn}">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE708;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#CBD5E1" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Tidur" FontSize="11" Foreground="#CBD5E1" VerticalAlignment="Center"/>
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
                                    <TextBlock Text="Short Break" FontSize="12" Foreground="#E2E8F0" VerticalAlignment="Center"/>
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
                                    <TextBlock Text="Focus Time" FontSize="12" Foreground="#E2E8F0" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </Grid>

                    <!-- BOTTOM PAGINATION INDICATOR (6 DOTS FOR 6 CARDS) -->
                    <StackPanel x:Name="PaginationPanel" Orientation="Horizontal" HorizontalAlignment="Center"
                                VerticalAlignment="Bottom" Margin="0,0,0,2">
                        <Border x:Name="Dot0" Width="16" Height="3" CornerRadius="1.5" Background="#FFFFFF" Margin="2.5,0" Cursor="Hand"/>
                        <Border x:Name="Dot1" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#48484A" Margin="2.5,0" Cursor="Hand"/>
                        <Border x:Name="Dot2" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#48484A" Margin="2.5,0" Cursor="Hand"/>
                        <Border x:Name="Dot3" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#48484A" Margin="2.5,0" Cursor="Hand"/>
                        <Border x:Name="Dot4" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#48484A" Margin="2.5,0" Cursor="Hand"/>
                        <Border x:Name="Dot5" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#48484A" Margin="2.5,0" Cursor="Hand"/>
                    </StackPanel>
                </Grid>

                <!-- FLOATING ACTION FEEDBACK TOAST PILL -->
                <Border x:Name="ToastFeedbackPill" Grid.Row="0" Grid.RowSpan="2" HorizontalAlignment="Center"
                        VerticalAlignment="Top" Margin="0,38,0,0" Background="#E6070B14" BorderBrush="#00D2FF"
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
    </Grid>
</Window>
'@

# XAML 2: FULL OCERU DASHBOARD WINDOW (15 Dedicated Destinations)
$dashXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Oceru Dashboard - Ocean Azure Glass"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Width="980" Height="650">
    <Window.Resources>
        <Style x:Key="SidebarNavBtn" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#8E9CB2"/>
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
                                <Setter TargetName="NavBorder" Property="Background" Value="#101C30"/>
                                <Setter Property="Foreground" Value="#00D2FF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ActiveSidebarNavBtn" TargetType="Button">
            <Setter Property="Background" Value="#0C2038"/>
            <Setter Property="Foreground" Value="#00D2FF"/>
            <Setter Property="Height" Value="36"/>
            <Setter Property="Margin" Value="0,2"/>
            <Setter Property="Padding" Value="14,0"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#00D2FF"/>
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

        <Style x:Key="DashCard" TargetType="Border">
            <Setter Property="Background" Value="#080F1E"/>
            <Setter Property="BorderBrush" Value="#172844"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Padding" Value="16"/>
            <Setter Property="Margin" Value="6"/>
        </Style>
    </Window.Resources>

    <!-- Outer Frame with Drop Shadow -->
    <Border CornerRadius="18" Background="#060A14" BorderBrush="#162846" BorderThickness="1.5">
        <Border.Effect>
            <DropShadowEffect BlurRadius="40" ShadowDepth="12" Direction="270" Opacity="0.7" Color="#000000"/>
        </Border.Effect>

        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="44"/> <!-- Modern Title Bar -->
                <RowDefinition Height="*"/>  <!-- Main Content Body -->
            </Grid.RowDefinitions>

            <!-- Custom Drag Title Bar -->
            <Border Grid.Row="0" x:Name="DashTitleBar" Background="#0A1224" CornerRadius="17,17,0,0" BorderBrush="#14233C" BorderThickness="0,0,0,1" Cursor="Hand">
                <Grid Margin="16,0">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Border Width="22" Height="22" CornerRadius="11" Background="#0284C7" Margin="0,0,10,0">
                            <TextBlock Text="O" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="OCERU" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                        <TextBlock Text=" - Ocean Azure Glass Dashboard" FontSize="12" Foreground="#64748B" VerticalAlignment="Center" Margin="6,0,0,0"/>
                    </StackPanel>

                    <!-- Control Buttons -->
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <Button x:Name="BtnDashMin" Width="30" Height="26" Background="Transparent" BorderThickness="0" Cursor="Hand" Margin="0,0,4,0">
                            <TextBlock Text="&#xE921;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#94A3B8"/>
                        </Button>
                        <Button x:Name="BtnDashClose" Width="30" Height="26" Background="Transparent" BorderThickness="0" Cursor="Hand">
                            <TextBlock Text="&#xE711;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#94A3B8"/>
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
                <Border Grid.Column="0" Background="#070E1C" BorderBrush="#122038" BorderThickness="0,0,1,0">
                    <ScrollViewer VerticalScrollBarVisibility="Hidden">
                        <StackPanel Margin="10,12">
                            <TextBlock Text="NAVIGASI UTAMA" FontSize="10" FontWeight="Bold" Foreground="#475569" Margin="10,4,0,8"/>
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

                            <TextBlock Text="PRODUKTIVITAS &amp; SISTEM" FontSize="10" FontWeight="Bold" Foreground="#475569" Margin="10,14,0,8"/>
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

                            <TextBlock Text="PREFERENSI" FontSize="10" FontWeight="Bold" Foreground="#475569" Margin="10,14,0,8"/>
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
                <Grid Grid.Column="1" Background="#050812" Margin="16">
                    <!-- PAGE 1: OVERVIEW -->
                    <Grid x:Name="PageOverview" Visibility="Visible">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <StackPanel Grid.Row="0" Margin="0,0,0,16">
                            <TextBlock Text="Ringkasan Sistem Oceru" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>
                            <TextBlock Text="Status waktu nyata hardware, media, dan fokus Anda di desktop Windows." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                        </StackPanel>
                        <Grid Grid.Row="1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="120"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <Border Grid.Row="0" Grid.Column="0" Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="BEBAN MEMORI RAM" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>
                                    <TextBlock x:Name="DashRamVal" Text="48%" FontSize="32" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,6,0,0"/>
                                    <TextBlock Text="Kernel32 GlobalMemoryStatusEx" FontSize="11" Foreground="#64748B"/>
                                </StackPanel>
                            </Border>
                            <Border Grid.Row="0" Grid.Column="1" Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="BATERAI LAPTOP" FontSize="11" FontWeight="Bold" Foreground="#10B981"/>
                                    <TextBlock x:Name="DashBatVal" Text="85%" FontSize="32" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,6,0,0"/>
                                    <TextBlock x:Name="DashBatStatus" Text="Mengisi Daya" FontSize="11" Foreground="#64748B"/>
                                </StackPanel>
                            </Border>
                            <Border Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="MEDIA AKTIF" FontSize="11" FontWeight="Bold" Foreground="#C084FC"/>
                                    <TextBlock Text="Paper Sky - Lumen Coast" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,8,0,2"/>
                                    <TextBlock Text="Sinkronisasi otomatis dengan Carousel Notch di atas layar." FontSize="12" Foreground="#64748B"/>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </Grid>

                    <!-- PAGE 2: DYNAMIC ISLAND CUSTOMIZATION -->
                    <Grid x:Name="PageIsland" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Kustomisasi Dynamic Island" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>
                            <TextBlock Text="Atur perilaku, ukuran, dan animasi notch di desktop Anda." FontSize="12" Foreground="#64748B" Margin="0,4,0,16"/>
                            <Border Style="{StaticResource DashCard}">
                                <StackPanel>
                                    <TextBlock Text="Bentuk Notch: Concave Wings (Ear Bezel)" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                                    <TextBlock Text="Lengkungan kurva bezier aerodinamis menyatu dengan bezel atas layar monitor." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                    <!-- PAGE 3: MEDIA -->
                    <Grid x:Name="PageMedia" Visibility="Collapsed"><TextBlock Text="Pemutar Media &amp; Lirik" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 4: POMODORO -->
                    <Grid x:Name="PagePomo" Visibility="Collapsed"><TextBlock Text="Pengatur Fokus Pomodoro" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 5: STOPWATCH -->
                    <Grid x:Name="PageStopwatch" Visibility="Collapsed"><TextBlock Text="Stopwatch Presisi" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 6: COUNTDOWN -->
                    <Grid x:Name="PageCountdown" Visibility="Collapsed"><TextBlock Text="Countdown Timer" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 7: MONITOR SISTEM -->
                    <Grid x:Name="PageSysMon" Visibility="Collapsed"><TextBlock Text="Monitor Hardware Mendalam" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 8: NOTIFIKASI -->
                    <Grid x:Name="PageNotif" Visibility="Collapsed"><TextBlock Text="Pusat Riwayat Notifikasi" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 9: CATATAN -->
                    <Grid x:Name="PageNotes" Visibility="Collapsed"><TextBlock Text="Catatan Cepat" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 10: TO-DO -->
                    <Grid x:Name="PageTodo" Visibility="Collapsed"><TextBlock Text="Daftar Tugas Harian" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 11: PAPAN KLIP -->
                    <Grid x:Name="PageClip" Visibility="Collapsed"><TextBlock Text="Riwayat Papan Klip" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 12: PENGATURAN CEPAT -->
                    <Grid x:Name="PageQuickSet" Visibility="Collapsed"><TextBlock Text="Pusat Aksi Cepat" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 13: PELUNCUR CEPAT -->
                    <Grid x:Name="PageQuickLaunch" Visibility="Collapsed"><TextBlock Text="Peluncur Cepat Aplikasi" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 14: PENGATURAN -->
                    <Grid x:Name="PageSettings" Visibility="Collapsed"><TextBlock Text="Pengaturan Aplikasi" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/></Grid>
                    <!-- PAGE 15: TENTANG OCERU -->
                    <Grid x:Name="PageAbout" Visibility="Collapsed">
                        <StackPanel>
                            <TextBlock Text="Tentang Oceru" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>
                            <TextBlock Text="Oceru Dynamic Island Desktop v2.0.0" FontSize="14" Foreground="#00D2FF" Margin="0,8,0,0"/>
                            <TextBlock Text="Desain: Ocean Azure Glass" FontSize="12" Foreground="#94A3B8" Margin="0,4,0,0"/>
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

# Start by Default in Resting Cat Eyes Mode at Top-Center
$window.Left = $eyesLeftPos
$window.Top = 0
$global:islandMode = "eyes" # "eyes", "status", "expanded"
$global:statusIdleTicks = 0
$global:outsideTicks = 0

# Grab Handles: Island Window Views
$eyesGrid = $window.FindName("EyesGrid")
$statusGrid = $window.FindName("StatusGrid")
$expandedGrid = $window.FindName("ExpandedGrid")

# Handles: Resting Eyes
$leftEye = $window.FindName("LeftEye")
$rightEye = $window.FindName("RightEye")
$leftPupilTransform = $window.FindName("LeftPupilTransform")
$rightPupilTransform = $window.FindName("RightPupilTransform")

# Handles: Compact Status Bar (Clock, Weather, Battery)
$compactClockText = $window.FindName("CompactClockText")
$compactBatPct = $window.FindName("CompactBatPct")
$compactBatIcon = $window.FindName("CompactBatIcon")

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
$musicLyricsView = $window.FindName("MusicLyricsView")
$musicTitle = $window.FindName("MusicTitle")
$musicArtist = $window.FindName("MusicArtist")
$musicCurrentTime = $window.FindName("MusicCurrentTime")
$musicRemainingTime = $window.FindName("MusicRemainingTime")
$musicProgressBar = $window.FindName("MusicProgressBar")
$btnMusicNextCard = $window.FindName("BtnMusicNextCard")
$btnToggleLyrics = $window.FindName("BtnToggleLyrics")
$btnBackFromLyrics = $window.FindName("BtnBackFromLyrics")
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
$inputNoteText = $window.FindName("InputNoteText")
$btnSaveNote = $window.FindName("BtnSaveNote")
$todoStatusCount = $window.FindName("TodoStatusCount")
$cbTask1 = $window.FindName("CbTask1")
$cbTask2 = $window.FindName("CbTask2")
$cbTask3 = $window.FindName("CbTask3")

# Card 3: Clipboard & Shelf Handles
$btnClipPrevCard = $window.FindName("BtnClipPrevCard")
$btnClipNextCard = $window.FindName("BtnClipNextCard")
$btnCopyClip1 = $window.FindName("BtnCopyClip1")
$btnCopyClip2 = $window.FindName("BtnCopyClip2")
$shelfDropBorder = $window.FindName("ShelfDropBorder")
$shelfFileCount = $window.FindName("ShelfFileCount")

# Card 4: System & Water Handles
$btnSysPrevCard = $window.FindName("BtnSysPrevCard")
$btnSysNextCard = $window.FindName("BtnSysNextCard")
$sysRamText = $window.FindName("SysRamText")
$sysBatStatusText = $window.FindName("SysBatStatusText")
$btnSysTaskMgr = $window.FindName("BtnSysTaskMgr")
$waterAmountText = $window.FindName("WaterAmountText")
$waterProgressBar = $window.FindName("WaterProgressBar")
$btnAddWater = $window.FindName("BtnAddWater")

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

# TRANSITION CONTROLLER FOR 3 DYNAMIC ISLAND MODES
function Set-IslandMode($mode) {
    if ($global:islandMode -eq $mode) { return }
    $global:islandMode = $mode

    if ($mode -eq "eyes") {
        # Standalone Resting Cat Eyes Pill
        $window.Width = $eyesWidth
        $window.Height = $eyesHeight
        $window.Left = $eyesLeftPos
        $eyesGrid.Visibility = [System.Windows.Visibility]::Visible
        $statusGrid.Visibility = [System.Windows.Visibility]::Collapsed
        $expandedGrid.Visibility = [System.Windows.Visibility]::Collapsed
    }
    elseif ($mode -eq "status") {
        # Compact Status Bar with Clock, Weather, and Battery
        $window.Width = $statusWidth
        $window.Height = $statusHeight
        $window.Left = $statusLeftPos
        $eyesGrid.Visibility = [System.Windows.Visibility]::Collapsed
        $statusGrid.Visibility = [System.Windows.Visibility]::Visible
        $expandedGrid.Visibility = [System.Windows.Visibility]::Collapsed
        $global:statusIdleTicks = 0
    }
    elseif ($mode -eq "expanded") {
        # Full Feature Carousel Notch
        $window.Width = $expandedWidth
        $window.Height = $expandedHeight
        $window.Left = $expandedLeftPos
        $eyesGrid.Visibility = [System.Windows.Visibility]::Collapsed
        $statusGrid.Visibility = [System.Windows.Visibility]::Collapsed
        $expandedGrid.Visibility = [System.Windows.Visibility]::Visible
        $global:outsideTicks = 0
    }
}

# Mouse enter/click event fallbacks
$eyesGrid.Add_MouseEnter({ Set-IslandMode "expanded" })
$eyesGrid.Add_MouseLeftButtonUp({ Set-IslandMode "expanded" })
$statusGrid.Add_MouseEnter({ Set-IslandMode "expanded" })
$statusGrid.Add_MouseLeftButtonUp({ Set-IslandMode "expanded" })

# ACTION FEEDBACK TOAST HELPER
$toastTimer = New-Object System.Windows.Threading.DispatcherTimer
$toastTimer.Interval = [TimeSpan]::FromSeconds(2.5)
$toastTimer.Add_Tick({
    $toastTimer.Stop()
    $toastFeedbackPill.Visibility = [System.Windows.Visibility]::Collapsed
})

function ShowActionFeedback($text, $iconChar = [char]0xE73E, $accentHex = "#00D2FF") {
    $toastFeedbackText.Text = $text
    $toastFeedbackIcon.Text = [string]$iconChar
    $toastFeedbackIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentHex)
    $toastFeedbackPill.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accentHex)
    $toastFeedbackPill.Visibility = [System.Windows.Visibility]::Visible
    $toastTimer.Stop()
    $toastTimer.Start()
}

# CAROUSEL STATE & NAVIGATION (6 CARDS)
$global:activeCardIndex = 0

function SwitchCarouselCard($index) {
    if ($index -lt 0) { $index = 5 }
    if ($index -gt 5) { $index = 0 }
    $global:activeCardIndex = $index

    # Update Header Title
    $titles = @("", "Pomodoro", "Catatan & Tugas", "Papan Klip & Shelf", "Monitor & Air", "Kontrol Cepat")
    $headerTitleText.Text = $titles[$index]

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
            $dotBars[$i].Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
        } else {
            $dotBars[$i].Width = 3.5
            $dotBars[$i].Height = 3.5
            $dotBars[$i].CornerRadius = [System.Windows.CornerRadius]::new(1.75)
            $dotBars[$i].Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#48484A")
        }
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

# CARD 0: MUSIC PLAYER WIRING
$playlist = @(
    @{ title = "Paper Sky"; artist = "Lumen Coast - Summer Flows" },
    @{ title = "Midnight Echoes"; artist = "Azure Horizon - Chillout" },
    @{ title = "Ocean Waves"; artist = "Deep Blue Sound - Calm" }
)
$global:trackIndex = 0

function UpdateMusicDisplay {
    $track = $playlist[$global:trackIndex]
    $musicTitle.Text = $track.title
    $musicArtist.Text = $track.artist
    $global:OceruState.currentMedia.title = $track.title
    $global:OceruState.currentMedia.artist = $track.artist
    Save-OceruState
}

$btnMusicPlayPause.Add_Click({
    $global:OceruState.currentMedia.isPlaying = -not $global:OceruState.currentMedia.isPlaying
    if ($global:OceruState.currentMedia.isPlaying) {
        $musicPlayPauseIcon.Text = [char]0xE769
        ShowActionFeedback "Memutar Musik" ([char]0xE768) "#00D2FF"
    } else {
        $musicPlayPauseIcon.Text = [char]0xE768
        ShowActionFeedback "Musik Dijeda" ([char]0xE769) "#94A3B8"
    }
    Save-OceruState
})

$btnMusicNext.Add_Click({
    $global:trackIndex = ($global:trackIndex + 1) % $playlist.Count
    UpdateMusicDisplay
    ShowActionFeedback "Lagu Berikutnya" ([char]0xE893) "#00D2FF"
})

$btnMusicPrev.Add_Click({
    $global:trackIndex = ($global:trackIndex - 1 + $playlist.Count) % $playlist.Count
    UpdateMusicDisplay
    ShowActionFeedback "Lagu Sebelumnya" ([char]0xE892) "#00D2FF"
})

$btnToggleLyrics.Add_Click({
    $musicPlayerView.Visibility = [System.Windows.Visibility]::Collapsed
    $musicLyricsView.Visibility = [System.Windows.Visibility]::Visible
})

$btnBackFromLyrics.Add_Click({
    $musicLyricsView.Visibility = [System.Windows.Visibility]::Collapsed
    $musicPlayerView.Visibility = [System.Windows.Visibility]::Visible
})

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
        ShowActionFeedback "Fokus Dijeda" ([char]0xE769) "#94A3B8"
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

# CARD 2: NOTES & TO-DO WIRING
$btnSaveNote.Add_Click({
    $txt = $inputNoteText.Text.Trim()
    if ($txt) {
        $newNote = [PSCustomObject]@{ id = [DateTime]::Now.Ticks; title = "Catatan Baru"; content = $txt }
        $global:OceruState.notes += $newNote
        Save-OceruState
        ShowActionFeedback "Catatan Disimpan!" ([char]0xE70B) "#00D2FF"
    }
})

function UpdateTodoProgress {
    $done = 0
    if ($cbTask1.IsChecked) { $done++ }
    if ($cbTask2.IsChecked) { $done++ }
    if ($cbTask3.IsChecked) { $done++ }
    $todoStatusCount.Text = " ($done/3)"
}
$cbTask1.Add_Click({ UpdateTodoProgress })
$cbTask2.Add_Click({ UpdateTodoProgress })
$cbTask3.Add_Click({ UpdateTodoProgress })

# CARD 3: CLIPBOARD & FILE SHELF WIRING
$btnCopyClip1.Add_Click({
    try {
        [System.Windows.Clipboard]::SetText("https://github.com/cubadakanda/dynamic-island")
        ShowActionFeedback "Tautan Disalin!" ([char]0xE77F) "#00D2FF"
    } catch {}
})

$btnCopyClip2.Add_Click({
    try {
        [System.Windows.Clipboard]::SetText("Oceru Dynamic Island Desktop")
        ShowActionFeedback "Teks Disalin!" ([char]0xE77F) "#00D2FF"
    } catch {}
})

$global:shelfFiles = @()
$shelfDropBorder.Add_Drop({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $dropped = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        foreach ($f in $dropped) { $global:shelfFiles += $f }
        $shelfFileCount.Text = "$($global:shelfFiles.Count) file tersimpan"
        ShowActionFeedback "$($dropped.Count) File Ditambahkan!" ([char]0xE8B7) "#F59E0B"
    }
})

# CARD 4: SYSTEM MONITOR & WATER WIRING
$btnSysTaskMgr.Add_Click({
    ShowActionFeedback "Membuka Task Manager..." ([char]0xE9D9) "#38BDF8"
    [System.Diagnostics.Process]::Start("taskmgr.exe")
})

$global:waterCurrent = 1250
$btnAddWater.Add_Click({
    $global:waterCurrent = [Math]::Min(2000, $global:waterCurrent + 250)
    $waterAmountText.Text = " ($($global:waterCurrent) ml)"
    $pct = $global:waterCurrent / 2000
    $waterProgressBar.Width = [Math]::Round(110 * $pct)
    ShowActionFeedback "+250 ml Air Minum (Total $($global:waterCurrent) ml)" ([char]0xE73E) "#38BDF8"
})

# CARD 5: QUICK SETTINGS & AUDIO MASTER WIRING
$btnQuickWifi.Add_Click({
    ShowActionFeedback "Membuka Panel Wi-Fi..." ([char]0xE701) "#0284C7"
    [System.Diagnostics.Process]::Start("explorer.exe", "ms-availablenetworks:")
})

$btnQuickBt.Add_Click({
    ShowActionFeedback "Membuka Bluetooth..." ([char]0xE702) "#0284C7"
    [System.Diagnostics.Process]::Start("explorer.exe", "ms-settings:bluetooth")
})

$btnQuickDnd.Add_Click({
    $global:OceruState.dndEnabled = -not $global:OceruState.dndEnabled
    if ($global:OceruState.dndEnabled) {
        $quickStatusDnd.Text = "Aktif"
        ShowActionFeedback "Jangan Ganggu Aktif" ([char]0xE708) "#A855F7"
    } else {
        $quickStatusDnd.Text = "DND"
        ShowActionFeedback "Jangan Ganggu Nonaktif" ([char]0xE708) "#64748B"
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
        ShowActionFeedback "Mode Game Nonaktif" ([char]0xE7FC) "#64748B"
    }
    Save-OceruState
})

$btnQuickMute.Add_Click({
    $global:OceruState.isMuted = -not $global:OceruState.isMuted
    try { [Win32Helper]::ToggleMute() } catch {}

    if ($global:OceruState.isMuted) {
        $quickIconMute.Text = [char]0xE74F
        ShowActionFeedback "Audio Dibisukan" ([char]0xE74F) "#DC2626"
    } else {
        $quickIconMute.Text = [char]0xE767
        ShowActionFeedback "Audio Aktif" ([char]0xE767) "#10B981"
    }
    Save-OceruState
})

$quickSliderVol.Add_ValueChanged({
    $val = [Math]::Round($quickSliderVol.Value)
    $quickVolPctText.Text = "$val%"
    $global:OceruState.volume = $val
})

$btnQuickLock.Add_Click({
    ShowActionFeedback "Mengunci Layar..." ([char]0xE72E) "#38BDF8"
    try {
        [Win32Helper]::LockWorkStation() | Out-Null
    } catch {
        Start-Process "rundll32.exe" -ArgumentList "user32.dll,LockWorkStation"
    }
})

$btnQuickSleep.Add_Click({
    ShowActionFeedback "Masuk Mode Tidur..." ([char]0xE708) "#C084FC"
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

# FAST DISPATCHER LOOP: EYE TRACKING & THREE-MODE AUTO TRANSITIONS (40ms)
$global:eyeBlinkTick = 0

$fastEyeTimer = New-Object System.Windows.Threading.DispatcherTimer
$fastEyeTimer.Interval = [TimeSpan]::FromMilliseconds(40)

$fastEyeTimer.Add_Tick({
    try {
        $cursorPos = [System.Windows.Forms.Cursor]::Position

        # -----------------------------------------------------------------
        # MODE 1: RESTING CAT EYES PILL (Standalone, Watching Cursor)
        # -----------------------------------------------------------------
        if ($global:islandMode -eq "eyes") {
            $dx = $cursorPos.X - $global:notchCenterX
            $dy = $cursorPos.Y - 18

            # Calculate normalized direction offsets for pupils
            $normX = [Math]::Max(-1.0, [Math]::Min(1.0, $dx / ($screenWidth / 2)))
            $normY = [Math]::Max(-0.2, [Math]::Min(1.0, $dy / $screenHeight))

            $targetX = [Math]::Round($normX * 3.8, 1)
            $targetY = [Math]::Round($normY * 2.5, 1)

            $leftPupilTransform.X = $targetX
            $leftPupilTransform.Y = $targetY
            $rightPupilTransform.X = $targetX
            $rightPupilTransform.Y = $targetY

            # Natural eye blinking every ~3.6s
            $global:eyeBlinkTick = ($global:eyeBlinkTick + 1) % 90
            if ($global:eyeBlinkTick -eq 0) {
                $leftEye.Height = 2
                $rightEye.Height = 2
            } elseif ($global:eyeBlinkTick -eq 3) {
                $leftEye.Height = 16
                $rightEye.Height = 16
            }

            # Instant hover detection on Eyes Pill to Expand
            $inEyes = ($cursorPos.X -ge ($eyesLeftPos - 6)) -and 
                      ($cursorPos.X -le ($eyesLeftPos + $eyesWidth + 6)) -and 
                      ($cursorPos.Y -ge 0) -and 
                      ($cursorPos.Y -le ($eyesHeight + 8))
            
            if ($inEyes) {
                Set-IslandMode "expanded"
            }
        }
        # -----------------------------------------------------------------
        # MODE 2: COMPACT STATUS BAR (Weather, Clock, Battery)
        # -----------------------------------------------------------------
        elseif ($global:islandMode -eq "status") {
            # Hover detection on Status Bar to Expand
            $inStatus = ($cursorPos.X -ge ($statusLeftPos - 6)) -and 
                        ($cursorPos.X -le ($statusLeftPos + $statusWidth + 6)) -and 
                        ($cursorPos.Y -ge 0) -and 
                        ($cursorPos.Y -le ($statusHeight + 8))
            
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
        # MODE 3: EXPANDED CAROUSEL NOTCH (No collapse button!)
        # -----------------------------------------------------------------
        elseif ($global:islandMode -eq "expanded") {
            $inExpanded = ($cursorPos.X -ge ($expandedLeftPos - 10)) -and 
                          ($cursorPos.X -le ($expandedLeftPos + $expandedWidth + 10)) -and 
                          ($cursorPos.Y -ge 0) -and 
                          ($cursorPos.Y -le ($expandedHeight + 14))

            if (-not $inExpanded) {
                $global:outsideTicks++
                # 7 ticks * 40ms = 280ms auto-collapse delay
                if ($global:outsideTicks -ge 7) {
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

# SECONDARY DISPATCHER LOOP (Equalizer, Clock, RAM, Battery, Music Progress)
$global:waveTick = 0
$global:musicProgressSec = 193

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

    # Soundwave Bouncing Equalizer Simulation
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

        # Music Progress Bar
        $global:musicProgressSec = ($global:musicProgressSec + 1) % 256
        $pct = [Math]::Max(0.05, [Math]::Min(1.0, $global:musicProgressSec / 256))
        $musicProgressBar.Width = [Math]::Round(200 * $pct)
        $curSpan = [TimeSpan]::FromSeconds($global:musicProgressSec)
        $remSpan = [TimeSpan]::FromSeconds(256 - $global:musicProgressSec)
        $musicCurrentTime.Text = $curSpan.ToString("mm\:ss")
        $musicRemainingTime.Text = "-" + $remSpan.ToString("mm\:ss")
    } else {
        $waveBar1.Height = 4; $waveBar2.Height = 4; $waveBar3.Height = 4; $waveBar4.Height = 4
    }

    # RAM Monitoring via Kernel32
    try {
        $ram = [Win32Helper]::GetRamLoad()
        $sysRamText.Text = "$ram%"
        $dashRamVal.Text = "$ram%"
    } catch {}

    # Battery Monitoring
    try {
        $power = [System.Windows.Forms.SystemInformation]::PowerStatus
        $batPct = [Math]::Round($power.BatteryLifePercent * 100)
        $isOnline = $power.PowerLineStatus -eq "Online"

        $compactBatPct.Text = "$batPct%"
        $dashBatVal.Text = "$batPct%"
        if ($isOnline) {
            $compactBatIcon.Text = [char]0xEA93
            $sysBatStatusText.Text = "Baterai $batPct% - Mengisi Daya"
            $dashBatStatus.Text = "Mengisi Daya"
        } else {
            $compactBatIcon.Text = [char]0xEBAA
            $sysBatStatusText.Text = "Baterai $batPct% - Daya Laptop"
            $dashBatStatus.Text = "Daya Baterai"
        }
    } catch {}
})

$mainTimer.Start()

# Run Island Application Window
$window.ShowDialog() | Out-Null
