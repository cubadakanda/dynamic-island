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

# XAML 1: DYNAMIC ISLAND (RESPONSIVE LIQUID NOTCH SILHOUETTE + SMOOTH INTERPOLATION)
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
            <Setter Property="Background" Value="#141C28"/>
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
                                <Setter TargetName="BtnBorder" Property="Background" Value="#202A3A"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Pill Button -->
        <Style x:Key="PillBtn" TargetType="Button">
            <Setter Property="Background" Value="#101824"/>
            <Setter Property="BorderBrush" Value="#202A3A"/>
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
                                <Setter TargetName="PillBorder" Property="Background" Value="#182335"/>
                                <Setter TargetName="PillBorder" Property="BorderBrush" Value="#00D2FF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Quick Mini Button -->
        <Style x:Key="QuickMiniBtn" TargetType="Button">
            <Setter Property="Background" Value="#0E1624"/>
            <Setter Property="BorderBrush" Value="#202A3A"/>
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
                                <Setter TargetName="MiniBorder" Property="Background" Value="#182438"/>
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

    <Grid x:Name="MasterGrid">
        <!-- ======================================================== -->
        <!-- SEAMLESS OBSIDIAN CAPSULE SILHOUETTE                     -->
        <!-- Zero-border capsule flush with top screen bezel          -->
        <!-- ======================================================== -->
        <Border x:Name="NotchBody" Background="#000000" CornerRadius="0,0,18,18"/>

        <!-- ======================================================== -->
        <!-- VIEW 1: RESTING CAT EYES PILL (Standalone, Eyes Only!)    -->
        <!-- ======================================================== -->
        <Grid x:Name="EyesGrid" Visibility="Visible" HorizontalAlignment="Center" VerticalAlignment="Center" Cursor="Hand" Opacity="1">
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
        <Grid x:Name="StatusGrid" Visibility="Collapsed" HorizontalAlignment="Stretch" VerticalAlignment="Center" Cursor="Hand" Margin="16,0,16,0" Opacity="0">
            <!-- Left: Weather -->
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
                <TextBlock Text="&#xE706;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" Margin="0,0,4,0" VerticalAlignment="Center"/>
                <TextBlock Text="28&#176;" FontSize="11" FontWeight="SemiBold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
            </StackPanel>

            <!-- Center: REAL-TIME CLOCK (Replaces Eyes in Status Bar!) -->
            <TextBlock x:Name="CompactClockText" Text="09:35" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"
                       HorizontalAlignment="Center" VerticalAlignment="Center"/>

            <!-- Right: Battery & Mode -->
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                <TextBlock x:Name="CompactBatPct" Text="85%" FontSize="11" Foreground="#9BAAC0" Margin="0,0,4,0" VerticalAlignment="Center"/>
                <TextBlock x:Name="CompactBatIcon" Text="&#xEA93;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" VerticalAlignment="Center"/>
            </StackPanel>
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

            <!-- Center Top Sensor / Camera Dot -->
            <Border Width="6" Height="6" CornerRadius="3" Background="#18181A"
                    HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,3,0,0"/>

            <!-- TOP HEADER ROW (NO COLLAPSE BUTTON!) -->
            <Grid Grid.Row="0" Margin="10,6,10,0">
                <!-- Left: Card Title -->
                <TextBlock x:Name="HeaderTitleText" Text="" FontWeight="SemiBold" FontSize="15" Foreground="#F3F6FC"
                           VerticalAlignment="Center" HorizontalAlignment="Left" Cursor="Hand"/>

                <!-- Center: Green Ring + Date & Time -->
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                    <Border Width="13" Height="13" CornerRadius="6.5" BorderThickness="2" BorderBrush="#10B981"
                            Margin="0,0,7,0" Background="Transparent"/>
                    <TextBlock x:Name="HeaderDateText" Text="Sun 25 Oct 2026 " FontSize="12" Foreground="#9BAAC0" VerticalAlignment="Center"/>
                    <TextBlock x:Name="HeaderTimeText" Text="09:35" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC" VerticalAlignment="Center"/>
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
                                           Foreground="#F3F6FC" TextTrimming="CharacterEllipsis"/>
                                <TextBlock x:Name="MusicArtist" Text="Lumen Coast - Summer Flows" FontSize="12"
                                           Foreground="#9BAAC0" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
                            </StackPanel>

                            <Button x:Name="BtnMusicNextCard" Grid.Column="2" Style="{StaticResource CircleNavBtn}"
                                    HorizontalAlignment="Right" VerticalAlignment="Center">
                                <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
                            </Button>
                        </Grid>

                        <!-- Seekbar -->
                        <Grid Grid.Row="1" VerticalAlignment="Center">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="42"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="46"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="MusicCurrentTime" Grid.Column="0" Text="03:13" FontSize="11" Foreground="#F3F6FC" VerticalAlignment="Center"/>
                            <Grid Grid.Column="1" Margin="6,0" VerticalAlignment="Center">
                                <Border Height="4" CornerRadius="2" Background="#202A3A"/>
                                <Border x:Name="MusicProgressBar" Height="4" CornerRadius="2" Background="#00D2FF" HorizontalAlignment="Left" Width="150"/>
                            </Grid>
                            <TextBlock x:Name="MusicRemainingTime" Grid.Column="2" Text="-01:03" FontSize="11" Foreground="#9BAAC0"
                                       HorizontalAlignment="Right" VerticalAlignment="Center"/>
                        </Grid>

                        <!-- Controls Row -->
                        <Grid Grid.Row="2">
                            <Button x:Name="BtnToggleLyrics" Style="{StaticResource CircleNavBtn}" Width="26" Height="26"
                                    HorizontalAlignment="Left" VerticalAlignment="Center" ToolTip="Lihat Lirik Lagu">
                                <TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#9BAAC0"/>
                            </Button>

                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                                <Button x:Name="BtnMusicPrev" Style="{StaticResource MediaControlBtn}" Margin="0,0,24,0">
                                    <TextBlock Text="&#xE892;" FontFamily="Segoe MDL2 Assets" FontSize="15" Foreground="#F3F6FC"/>
                                </Button>
                                <Button x:Name="BtnMusicPlayPause" Style="{StaticResource MediaControlBtn}" Margin="0,0,24,0">
                                    <TextBlock x:Name="MusicPlayPauseIcon" Text="&#xE769;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="#F3F6FC"/>
                                </Button>
                                <Button x:Name="BtnMusicNext" Style="{StaticResource MediaControlBtn}">
                                    <TextBlock Text="&#xE893;" FontFamily="Segoe MDL2 Assets" FontSize="15" Foreground="#F3F6FC"/>
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
                            <TextBlock Text="&#xE72B;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#9BAAC0"/>
                        </Button>
                        <StackPanel Grid.Row="1" VerticalAlignment="Center" HorizontalAlignment="Center">
                            <TextBlock Text="Gliding high above the quiet morning sky..." FontSize="12" Foreground="#9BAAC0" HorizontalAlignment="Center" Margin="0,2"/>
                            <TextBlock Text="Ocean breeze whispers what you left behind" FontSize="14" FontWeight="Bold" Foreground="#00D2FF" HorizontalAlignment="Center" Margin="0,2"/>
                            <TextBlock Text="Folded wings of paper chasing summer light" FontSize="12" Foreground="#9BAAC0" HorizontalAlignment="Center" Margin="0,2"/>
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
                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
                    </Button>

                    <Grid Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="90"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <!-- Circular Timer Dial -->
                        <Grid Grid.Column="0" Width="82" Height="82" HorizontalAlignment="Center" VerticalAlignment="Center">
                            <Border Width="82" Height="82" CornerRadius="41" BorderThickness="2.5" BorderBrush="#202A3A" Background="#0B101B"/>
                            <Border Width="82" Height="82" CornerRadius="41" BorderThickness="2.5" BorderBrush="#FF5252"
                                    Opacity="0.85" Background="Transparent"/>
                            <Border Width="6" Height="6" CornerRadius="3" Background="#FF5252" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,2,0,0"/>
                            <TextBlock Text="&#xE916;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#FF5252"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Grid>

                        <!-- Timer Typography and Reset -->
                        <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="14,0,0,0">
                            <TextBlock Text="Waktu Fokus" FontSize="12" Foreground="#9BAAC0" Margin="0,0,0,2"/>
                            <TextBlock x:Name="PomoSubtitle" Text="Focus time" FontSize="14" FontWeight="SemiBold" Foreground="#F3F6FC"/>
                            <StackPanel Orientation="Horizontal" Margin="0,2,0,0">
                                <TextBlock x:Name="PomoDisplayTime" Text="25:00" FontFamily="Segoe UI, Consolas" FontSize="30" FontWeight="Bold" Foreground="#F3F6FC"/>
                                <Button x:Name="BtnPomoReset" Style="{StaticResource CircleNavBtn}" Width="24" Height="24" Margin="10,0,0,0" ToolTip="Reset Timer">
                                    <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#9BAAC0"/>
                                </Button>
                            </StackPanel>
                        </StackPanel>
                    </Grid>

                    <Button x:Name="BtnPomoNextCard" Grid.Column="2" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
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
                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
                    </Button>

                    <!-- Left Half: Quick Note Editor -->
                    <Border Grid.Column="1" Background="#0B101B" BorderBrush="#202A3A" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
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
                            <TextBox x:Name="InputNoteText" Grid.Row="1" Background="#060A14" Foreground="#F3F6FC" BorderBrush="#202A3A"
                                     FontSize="11" Margin="0,3" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Hidden"
                                     Text="Meeting project Oceru jam 10 pagi..."/>
                            <Button x:Name="BtnSaveNote" Grid.Row="2" Style="{StaticResource PillBtn}" Padding="8,2" HorizontalAlignment="Right">
                                <TextBlock Text="Simpan" FontSize="10" Foreground="#00D2FF"/>
                            </Button>
                        </Grid>
                    </Border>

                    <!-- Right Half: To-Do Checklist -->
                    <Border Grid.Column="2" Background="#0B101B" BorderBrush="#202A3A" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="22"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Left">
                                <TextBlock Text="&#xE73E;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Tugas Hari Ini" FontSize="12" FontWeight="Bold" Foreground="#10B981" VerticalAlignment="Center"/>
                                <TextBlock x:Name="TodoStatusCount" Text=" (2/3)" FontSize="11" Foreground="#9BAAC0" Margin="4,0,0,0" VerticalAlignment="Center"/>
                            </StackPanel>
                            <StackPanel Grid.Row="1" Margin="0,4,0,0">
                                <CheckBox x:Name="CbTask1" Content="Uji responsivitas Notch" IsChecked="True" Foreground="#F3F6FC" FontSize="11" Margin="0,2"/>
                                <CheckBox x:Name="CbTask2" Content="Sinkronisasi audio &amp; volume" IsChecked="True" Foreground="#F3F6FC" FontSize="11" Margin="0,2"/>
                                <CheckBox x:Name="CbTask3" Content="Cek catatan &amp; to-do list" IsChecked="False" Foreground="#F3F6FC" FontSize="11" Margin="0,2"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <Button x:Name="BtnNotesNextCard" Grid.Column="3" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
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
                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
                    </Button>

                    <!-- Left: Clipboard History -->
                    <Border Grid.Column="1" Background="#0B101B" BorderBrush="#202A3A" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
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
                                        <TextBlock Text="&#xE71B;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="github.com/cubadakanda..." FontSize="11" Foreground="#F3F6FC" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button x:Name="BtnCopyClip2" Style="{StaticResource QuickMiniBtn}" Margin="0,2" HorizontalContentAlignment="Left">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Oceru Dynamic Island" FontSize="11" Foreground="#F3F6FC" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <!-- Right: File Shelf Drop Zone -->
                    <Border x:Name="ShelfDropBorder" Grid.Column="2" Background="#0B101B" BorderBrush="#202A3A" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0" AllowDrop="True">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="22"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Left">
                                <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                <TextBlock Text="File Shelf (Tarik File)" FontSize="12" FontWeight="Bold" Foreground="#F59E0B" VerticalAlignment="Center"/>
                            </StackPanel>
                            <Border Grid.Row="1" BorderBrush="#202A3A" BorderThickness="1" CornerRadius="8" Background="#060A14" Margin="0,3">
                                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xED25;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Lepas file di sini" FontSize="11" Foreground="#9BAAC0" VerticalAlignment="Center"/>
                                    </StackPanel>
                                    <TextBlock x:Name="ShelfFileCount" Text="0 file tersimpan" FontSize="10" Foreground="#9BAAC0" HorizontalAlignment="Center" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </Border>

                    <Button x:Name="BtnClipNextCard" Grid.Column="3" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
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
                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
                    </Button>

                    <!-- Left: System Hardware -->
                    <Border Grid.Column="1" Background="#0B101B" BorderBrush="#202A3A" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                        <StackPanel VerticalAlignment="Center">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock x:Name="SysRamText" Text="48%" FontFamily="Segoe UI, Consolas" FontSize="28" FontWeight="Bold" Foreground="#F3F6FC"/>
                                <TextBlock Text=" RAM" FontSize="14" FontWeight="SemiBold" Foreground="#00D2FF" VerticalAlignment="Bottom" Margin="4,0,0,4"/>
                            </StackPanel>
                            <TextBlock x:Name="SysBatStatusText" Text="Baterai 85% - Mengisi Daya" FontSize="11" Foreground="#9BAAC0" Margin="0,2,0,0"/>
                            <Button x:Name="BtnSysTaskMgr" Style="{StaticResource QuickMiniBtn}" Margin="0,6,0,0" HorizontalAlignment="Left">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Buka Task Manager" FontSize="10" Foreground="#00D2FF" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </Border>

                    <!-- Right: Water Reminder -->
                    <Border Grid.Column="2" Background="#0B101B" BorderBrush="#202A3A" BorderThickness="1" CornerRadius="12" Padding="10,8" Margin="4,0">
                        <StackPanel VerticalAlignment="Center">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE798;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Air Minum" FontSize="12" FontWeight="Bold" Foreground="#00D2FF" VerticalAlignment="Center"/>
                                <TextBlock x:Name="WaterAmountText" Text=" (1.250 ml)" FontSize="11" Foreground="#9BAAC0" Margin="4,0,0,0" VerticalAlignment="Center"/>
                            </StackPanel>
                            <Grid Margin="0,6">
                                <Border Height="5" CornerRadius="2.5" Background="#202A3A"/>
                                <Border x:Name="WaterProgressBar" Height="5" CornerRadius="2.5" Background="#00D2FF" HorizontalAlignment="Left" Width="110"/>
                            </Grid>
                            <Button x:Name="BtnAddWater" Style="{StaticResource PillBtn}" Padding="8,3" HorizontalAlignment="Left">
                                <TextBlock Text="+ 250 ml (1 Gelas)" FontSize="10" Foreground="#F3F6FC"/>
                            </Button>
                        </StackPanel>
                    </Border>

                    <Button x:Name="BtnSysNextCard" Grid.Column="3" Style="{StaticResource CircleNavBtn}" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
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
                        <TextBlock Text="&#xE76B;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
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
                                    <TextBlock Text="Wi-Fi" FontSize="11" Foreground="#F3F6FC" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnQuickBt" Grid.Column="1" Margin="2" Style="{StaticResource QuickMiniBtn}">
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                    <TextBlock Text="&#xE702;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#00D2FF" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Bluetooth" FontSize="11" Foreground="#F3F6FC" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnQuickDnd" Grid.Column="2" Margin="2" Style="{StaticResource QuickMiniBtn}">
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                    <TextBlock Text="&#xE708;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A855F7" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="QuickStatusDnd" Text="DND" FontSize="11" Foreground="#F3F6FC" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnQuickGame" Grid.Column="3" Margin="2" Style="{StaticResource QuickMiniBtn}">
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                    <TextBlock Text="&#xE7FC;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#10B981" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="QuickStatusGame" Text="Game" FontSize="11" Foreground="#F3F6FC" VerticalAlignment="Center"/>
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
                            <TextBlock x:Name="QuickVolPctText" Grid.Column="2" Text="72%" FontSize="11" Foreground="#9BAAC0" VerticalAlignment="Center"/>
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
                                    <TextBlock Text="&#xE72E;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#9BAAC0" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Kunci" FontSize="11" Foreground="#9BAAC0" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnQuickSleep" Grid.Column="1" Margin="2" Style="{StaticResource QuickMiniBtn}">
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                    <TextBlock Text="&#xE708;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#9BAAC0" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Tidur" FontSize="11" Foreground="#9BAAC0" VerticalAlignment="Center"/>
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
                        <TextBlock Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="12" FontWeight="Bold" Foreground="#F3F6FC"/>
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
                                <TextBlock Text="Short Break" FontSize="12" Foreground="#F3F6FC" VerticalAlignment="Center"/>
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
                                <TextBlock Text="Focus Time" FontSize="12" Foreground="#F3F6FC" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </StackPanel>
                </Grid>

                <!-- BOTTOM PAGINATION INDICATOR (6 DOTS FOR 6 CARDS) -->
                <StackPanel x:Name="PaginationPanel" Orientation="Horizontal" HorizontalAlignment="Center"
                            VerticalAlignment="Bottom" Margin="0,0,0,2">
                    <Border x:Name="Dot0" Width="16" Height="3" CornerRadius="1.5" Background="#00D2FF" Margin="2.5,0" Cursor="Hand"/>
                    <Border x:Name="Dot1" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#202A3A" Margin="2.5,0" Cursor="Hand"/>
                    <Border x:Name="Dot2" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#202A3A" Margin="2.5,0" Cursor="Hand"/>
                    <Border x:Name="Dot3" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#202A3A" Margin="2.5,0" Cursor="Hand"/>
                    <Border x:Name="Dot4" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#202A3A" Margin="2.5,0" Cursor="Hand"/>
                    <Border x:Name="Dot5" Width="3.5" Height="3.5" CornerRadius="1.75" Background="#202A3A" Margin="2.5,0" Cursor="Hand"/>
                </StackPanel>
            </Grid>

            <!-- FLOATING ACTION FEEDBACK TOAST PILL -->
            <Border x:Name="ToastFeedbackPill" Grid.Row="0" Grid.RowSpan="2" HorizontalAlignment="Center"
                    VerticalAlignment="Top" Margin="0,38,0,0" Background="#E6060A14" BorderBrush="#00D2FF"
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
        Title="Oceru Dashboard - Ocean Azure Glass"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Width="980" Height="650">
    <Window.Resources>
        <!-- Sidebar Navigation Button (Normal) -->
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

        <!-- Sidebar Navigation Button (Active Selected) -->
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

        <!-- Standard Dashboard Card Container -->
        <Style x:Key="DashCard" TargetType="Border">
            <Setter Property="Background" Value="#080F1E"/>
            <Setter Property="BorderBrush" Value="#172844"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Padding" Value="16"/>
            <Setter Property="Margin" Value="6"/>
        </Style>

        <!-- Primary Cyan Button -->
        <Style x:Key="DashBtnPrimary" TargetType="Button">
            <Setter Property="Background" Value="#0284C7"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
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
                                <Setter TargetName="PBtnBorder" Property="Background" Value="#0369A1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Secondary Dark Outline Button -->
        <Style x:Key="DashBtnSecondary" TargetType="Button">
            <Setter Property="Background" Value="#0E192C"/>
            <Setter Property="BorderBrush" Value="#1C3050"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Foreground" Value="#CBD5E1"/>
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
                                <Setter TargetName="SBtnBorder" Property="Background" Value="#172844"/>
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
            <Setter Property="Background" Value="#0A1426"/>
            <Setter Property="BorderBrush" Value="#182A48"/>
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
                                <Setter TargetName="TileBorder" Property="Background" Value="#122442"/>
                                <Setter TargetName="TileBorder" Property="BorderBrush" Value="#00D2FF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
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

                    <!-- ======================================================== -->
                    <!-- PAGE 0: OVERVIEW                                         -->
                    <!-- ======================================================== -->
                    <Grid x:Name="PageOverview" Visibility="Visible">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel>
                                <StackPanel Margin="0,0,0,14">
                                    <TextBlock Text="Ringkasan Sistem Oceru" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>
                                    <TextBlock Text="Status waktu nyata hardware, media, dan fokus produktivitas Anda di Windows." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
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
                                            <TextBlock Text="Kernel32 Hardware" FontSize="11" Foreground="#64748B"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Battery Card -->
                                    <Border Grid.Column="1" Style="{StaticResource DashCard}">
                                        <StackPanel>
                                            <TextBlock Text="BATERAI" FontSize="11" FontWeight="Bold" Foreground="#10B981"/>
                                            <TextBlock x:Name="DashBatVal" Text="85%" FontSize="28" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,4,0,0"/>
                                            <TextBlock x:Name="DashBatStatus" Text="Mengisi Daya" FontSize="11" Foreground="#64748B"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Focus Pomodoro Card -->
                                    <Border Grid.Column="2" Style="{StaticResource DashCard}">
                                        <StackPanel>
                                            <TextBlock Text="FOKUS POMODORO" FontSize="11" FontWeight="Bold" Foreground="#FF5252"/>
                                            <TextBlock x:Name="DashOverviewPomoTime" Text="25:00" FontSize="28" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,4,0,0"/>
                                            <TextBlock x:Name="DashOverviewPomoStatus" Text="Sesi 3 dari 4" FontSize="11" Foreground="#64748B"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Tasks Card -->
                                    <Border Grid.Column="3" Style="{StaticResource DashCard}">
                                        <StackPanel>
                                            <TextBlock Text="TUGAS HARIAN" FontSize="11" FontWeight="Bold" Foreground="#F59E0B"/>
                                            <TextBlock x:Name="DashOverviewTodoCount" Text="2 / 3 Selesai" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,8,0,0"/>
                                            <Border Height="4" Background="#14243C" CornerRadius="2" Margin="0,8,0,0">
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
                                            <TextBlock Text="MEDIA SEDANG DIPUTAR" FontSize="11" FontWeight="Bold" Foreground="#C084FC"/>
                                            <TextBlock x:Name="DashOverviewMediaTitle" Text="Paper Sky" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,6,0,2"/>
                                            <TextBlock x:Name="DashOverviewMediaArtist" Text="Lumen Coast - Summer Flows" FontSize="12" Foreground="#94A3B8"/>
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
                                    <TextBlock Text="Atur perilaku, interaksi, dimensi, dan animasi notch di desktop Anda." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                                </StackPanel>

                                <!-- Card 1: Mode Realtime & Test Buttons -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="STATUS REAL-TIME DYNAMIC ISLAND" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>
                                        <TextBlock x:Name="DashIslandCurrentModeText" Text="Mode Aktif: Standalone Resting Cat Eyes (88x36 px)" FontSize="15" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,6,0,8"/>
                                        <TextBlock Text="Dynamic Island saat ini aktif melayang di bagian tengah atas layar desktop Anda." FontSize="12" Foreground="#94A3B8"/>
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
                                        <TextBlock Text="DIMENSI &amp; POSISI NOTCH" FontSize="11" FontWeight="Bold" Foreground="#38BDF8"/>
                                        <Grid Margin="0,10,0,0">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <TextBlock Text="Lebar Saat Terbuka" FontSize="12" Foreground="#64748B"/>
                                                <TextBlock Text="560 px (Optimal 6 Kartu)" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,2,0,8"/>
                                                <TextBlock Text="Tinggi Saat Terbuka" FontSize="12" Foreground="#64748B"/>
                                                <TextBlock Text="205 px" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,2,0,0"/>
                                            </StackPanel>
                                            <StackPanel Grid.Column="1">
                                                <TextBlock Text="Posisi Desktop" FontSize="12" Foreground="#64748B"/>
                                                <TextBlock Text="Atas Tengah (Top Center)" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,2,0,8"/>
                                                <TextBlock Text="Lapisan Jendela" FontSize="12" Foreground="#64748B"/>
                                                <TextBlock Text="Topmost Always-on-Top" FontSize="14" FontWeight="SemiBold" Foreground="#10B981" Margin="0,2,0,0"/>
                                            </StackPanel>
                                        </Grid>
                                    </StackPanel>
                                </Border>

                                <!-- Card 3: Silhouette & Visual Polish -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="DESAIN SILUET OBSIDIAN GLASS" FontSize="11" FontWeight="Bold" Foreground="#C084FC"/>
                                        <TextBlock Text="Seamless Obsidian Island Capsule" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,6,0,2"/>
                                        <TextBlock Text="Kapsul obsidian hitam murni (#000000) tanpa garis tepi (seamless bezel-flush). Bebas bayangan blur dan fringe kontur, menyatu sempurna dengan tepi atas layar desktop Windows Anda." FontSize="12" Foreground="#9BAAC0"/>
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
                                    <TextBlock Text="Pemutar Media &amp; Lirik Sinkron" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>
                                    <TextBlock Text="Kontrol pemutaran musik dan lirik sinkron gaya karaoke di desktop Anda." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
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
                                            <Border Width="160" Height="160" CornerRadius="20" Background="#0C1B30" HorizontalAlignment="Center" Margin="0,10,0,14" BorderBrush="#1C365C" BorderThickness="1.5">
                                                <Grid>
                                                    <Border Width="100" Height="100" CornerRadius="50" Background="#0284C7" HorizontalAlignment="Center" VerticalAlignment="Center">
                                                        <Border Width="36" Height="36" CornerRadius="18" Background="#0369A1" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                    </Border>
                                                    <TextBlock Text="&#xE768;" FontFamily="Segoe MDL2 Assets" FontSize="26" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                </Grid>
                                            </Border>

                                            <TextBlock x:Name="DashMediaTitleText" Text="Paper Sky" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center"/>
                                            <TextBlock x:Name="DashMediaArtistText" Text="Lumen Coast - Summer Flows" FontSize="12" Foreground="#94A3B8" HorizontalAlignment="Center" Margin="0,4,0,14"/>

                                            <!-- Progress Bar -->
                                            <Border Height="5" Background="#14243C" CornerRadius="2.5" Margin="10,0,10,6">
                                                <Border x:Name="DashMediaProgressBar" Width="180" HorizontalAlignment="Left" Background="#00D2FF" CornerRadius="2.5"/>
                                            </Border>
                                            <Grid Margin="10,0,10,14">
                                                <TextBlock x:Name="DashMediaCurrentTime" Text="03:13" FontSize="10" Foreground="#64748B" HorizontalAlignment="Left"/>
                                                <TextBlock x:Name="DashMediaRemainingTime" Text="-01:03" FontSize="10" Foreground="#64748B" HorizontalAlignment="Right"/>
                                            </Grid>

                                            <!-- Controls -->
                                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,14">
                                                <Button x:Name="BtnDashMediaPrev" Style="{StaticResource DashBtnSecondary}" Width="42" Height="36" Margin="0,0,8,0">
                                                    <TextBlock Text="&#xE892;" FontFamily="Segoe MDL2 Assets" FontSize="12"/>
                                                </Button>
                                                <Button x:Name="BtnDashMediaPlayPause" Style="{StaticResource DashBtnPrimary}" Width="52" Height="36" Margin="0,0,8,0">
                                                    <TextBlock x:Name="DashMediaPlayIcon" Text="&#xE769;" FontFamily="Segoe MDL2 Assets" FontSize="14"/>
                                                </Button>
                                                <Button x:Name="BtnDashMediaNext" Style="{StaticResource DashBtnSecondary}" Width="42" Height="36">
                                                    <TextBlock Text="&#xE893;" FontFamily="Segoe MDL2 Assets" FontSize="12"/>
                                                </Button>
                                            </StackPanel>

                                            <!-- Playlist Selection -->
                                            <TextBlock Text="DAFTAR PUTAR (PLAYLIST)" FontSize="10" FontWeight="Bold" Foreground="#475569" Margin="0,10,0,6"/>
                                            <Button x:Name="BtnPlayTrack0" Style="{StaticResource DashBtnSecondary}" Margin="0,2" HorizontalContentAlignment="Left">
                                                <TextBlock Text="1. Paper Sky - Lumen Coast" FontSize="11"/>
                                            </Button>
                                            <Button x:Name="BtnPlayTrack1" Style="{StaticResource DashBtnSecondary}" Margin="0,2" HorizontalContentAlignment="Left">
                                                <TextBlock Text="2. Midnight Echoes - Azure Horizon" FontSize="11"/>
                                            </Button>
                                            <Button x:Name="BtnPlayTrack2" Style="{StaticResource DashBtnSecondary}" Margin="0,2" HorizontalContentAlignment="Left">
                                                <TextBlock Text="3. Ocean Waves - Deep Blue Sound" FontSize="11"/>
                                            </Button>
                                        </StackPanel>
                                    </Border>

                                    <!-- Right Column: Synchronized Karaoke Lyrics -->
                                    <Border Grid.Column="1" Style="{StaticResource DashCard}">
                                        <StackPanel>
                                            <TextBlock Text="LIRIK SINKRON (KARAOKE)" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,16"/>
                                            <StackPanel Margin="10,0">
                                                <TextBlock Text="Flying through the open clouds" FontSize="13" Foreground="#475569" Margin="0,6"/>
                                                <Border Background="#0C2038" BorderBrush="#00D2FF" BorderThickness="1" CornerRadius="8" Padding="12,8" Margin="0,6">
                                                    <TextBlock Text=">> Chasing paper sky in the morning light &lt;&lt;" FontSize="14" FontWeight="Bold" Foreground="#00D2FF"/>
                                                </Border>
                                                <TextBlock Text="Waves of blue are drifting by" FontSize="13" Foreground="#8E9CB2" Margin="0,6"/>
                                                <TextBlock Text="Lost in the rhythm of the summer tide" FontSize="13" Foreground="#64748B" Margin="0,6"/>
                                                <TextBlock Text="Every heartbeat feels alive" FontSize="13" Foreground="#475569" Margin="0,6"/>
                                            </StackPanel>
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
                                    <TextBlock Text="Tingkatkan fokus kerja dan belajar dengan teknik interval waktu Pomodoro." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                                </StackPanel>

                                <!-- Large Timer Card -->
                                <Border Style="{StaticResource DashCard}" Padding="24">
                                    <StackPanel HorizontalAlignment="Center">
                                        <TextBlock Text="SESI FOKUS PRODUKTIF" FontSize="11" FontWeight="Bold" Foreground="#FF5252" HorizontalAlignment="Center"/>
                                        <TextBlock x:Name="DashPomoLargeTime" Text="25:00" FontSize="56" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" Margin="0,10,0,4"/>
                                        <TextBlock x:Name="DashPomoStatusText" Text="Siap Memulai Sesi Fokus" FontSize="13" Foreground="#94A3B8" HorizontalAlignment="Center"/>
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
                                    <TextBlock Text="Penghitung waktu presisi milidetik dengan pencatatan putaran (Lap time)." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
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
                                        <TextBlock Text="CATATAN PUTARAN (LAPS)" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,10"/>
                                        <StackPanel x:Name="DashStopwatchLapContainer">
                                            <TextBlock Text="Belum ada putaran dicatat. Tekan 'Catat Putaran' saat stopwatch berjalan." FontSize="12" Foreground="#64748B"/>
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
                                    <TextBlock Text="Hitung mundur waktu fleksibel untuk presentasi, memasak, atau istirahat." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                                </StackPanel>

                                <Border Style="{StaticResource DashCard}" Padding="24">
                                    <StackPanel HorizontalAlignment="Center">
                                        <TextBlock x:Name="DashCountdownTimeText" Text="10:00" FontSize="56" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" Margin="0,6,0,4"/>
                                        <TextBlock x:Name="DashCountdownStatusText" Text="Siap Memulai Countdown" FontSize="13" Foreground="#94A3B8" HorizontalAlignment="Center" Margin="0,0,0,18"/>
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
                                    <TextBlock Text="Diagnostik performa RAM, penyimpanan SSD, prosesor, dan baterai komputer Anda." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
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
                                            <TextBlock x:Name="DashSysMonRamTotal" Text="Total: 16.0 GB" FontSize="12" Foreground="#CBD5E1"/>
                                            <TextBlock x:Name="DashSysMonRamAvail" Text="Tersedia: 8.3 GB" FontSize="12" Foreground="#64748B" Margin="0,2,0,0"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Storage SSD Detailed -->
                                    <Border Grid.Row="0" Grid.Column="1" Style="{StaticResource DashCard}">
                                        <StackPanel>
                                            <TextBlock Text="PENYIMPANAN SISTEM (DRIVE C:)" FontSize="11" FontWeight="Bold" Foreground="#C084FC"/>
                                            <TextBlock x:Name="DashSysMonDiskVal" Text="Total 476 GB, Bebas 182 GB" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,8,0,8"/>
                                            <Border Height="6" Background="#14243C" CornerRadius="3">
                                                <Border x:Name="DashSysMonDiskBar" Width="180" HorizontalAlignment="Left" Background="#C084FC" CornerRadius="3"/>
                                            </Border>
                                        </StackPanel>
                                    </Border>

                                    <!-- Processor Card -->
                                    <Border Grid.Row="1" Grid.Column="0" Style="{StaticResource DashCard}">
                                        <StackPanel>
                                            <TextBlock Text="ARSITEKTUR CPU" FontSize="11" FontWeight="Bold" Foreground="#38BDF8"/>
                                            <TextBlock Text="x64 Native Processor" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,4,0,2"/>
                                            <TextBlock Text="PowerShell Dispatcher Loop 60 FPS" FontSize="12" Foreground="#64748B"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Battery & Power -->
                                    <Border Grid.Row="1" Grid.Column="1" Style="{StaticResource DashCard}">
                                        <StackPanel>
                                            <TextBlock Text="STATUS DAYA LAPTOP" FontSize="11" FontWeight="Bold" Foreground="#10B981"/>
                                            <TextBlock x:Name="DashSysMonBatVal" Text="85%" FontSize="24" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,4,0,2"/>
                                            <TextBlock x:Name="DashSysMonBatStatus" Text="Mengisi Daya (AC Online)" FontSize="12" Foreground="#64748B"/>
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
                                    <TextBlock Text="Kelola riwayat pemberitahuan sistem, pengingat fokus, dan alert Oceru." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
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
                                                <TextBlock Text="Aplikasi aktif dengan desain Ocean Azure Glass di bagian atas desktop Windows Anda." FontSize="12" Foreground="#94A3B8" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <TextBlock Grid.Column="1" Text="Hari ini" FontSize="11" Foreground="#64748B" VerticalAlignment="Top"/>
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
                                                <TextBlock Text="Target Minum Air Harian" FontSize="14" FontWeight="SemiBold" Foreground="#38BDF8"/>
                                                <TextBlock Text="Anda telah mencatat 1250 ml air. Pertahankan target sehat 2000 ml hari ini!" FontSize="12" Foreground="#94A3B8" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <TextBlock Grid.Column="1" Text="15m lalu" FontSize="11" Foreground="#64748B" VerticalAlignment="Top"/>
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
                                    <TextBlock Text="Tulis ide instan. Tersinkronisasi otomatis dengan kartu catatan Dynamic Island." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                                </StackPanel>

                                <!-- Add Note Card -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="BUAT CATATAN BARU" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,10"/>
                                        <TextBox x:Name="InputDashNoteTitle" Background="#0C1B30" Foreground="#FFFFFF" BorderBrush="#1C365C" BorderThickness="1" Padding="10,6" Margin="0,0,0,8" Text="Ide Proyek Oceru"/>
                                        <TextBox x:Name="InputDashNoteContent" Background="#0C1B30" Foreground="#FFFFFF" BorderBrush="#1C365C" BorderThickness="1" Padding="10,6" Height="65" TextWrapping="Wrap" AcceptsReturn="True" Margin="0,0,0,10" Text="Desain Ocean Azure Glass memberikan ketenangan visual dan produktivitas maksimal."/>
                                        <Button x:Name="BtnDashSaveNoteNew" Style="{StaticResource DashBtnPrimary}" HorizontalAlignment="Left">
                                            <TextBlock Text="Simpan Catatan Baru"/>
                                        </Button>
                                    </StackPanel>
                                </Border>

                                <!-- Saved Notes List -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="CATATAN TERSIMPAN" FontSize="11" FontWeight="Bold" Foreground="#CBD5E1" Margin="0,0,0,10"/>
                                        <StackPanel x:Name="DashNotesListContainer">
                                            <Border Background="#0C1B30" BorderBrush="#1C365C" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,4">
                                                <StackPanel>
                                                    <TextBlock Text="Oceru Design Language" FontSize="14" FontWeight="SemiBold" Foreground="#00D2FF"/>
                                                    <TextBlock Text="Ocean Azure Glass dengan midnight navy dan aksen cyan." FontSize="12" Foreground="#94A3B8" Margin="0,4,0,0"/>
                                                </StackPanel>
                                            </Border>
                                            <Border Background="#0C1B30" BorderBrush="#1C365C" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,4">
                                                <StackPanel>
                                                    <TextBlock Text="Shortcut Cepat" FontSize="14" FontWeight="SemiBold" Foreground="#00D2FF"/>
                                                    <TextBlock Text="Arahkan kursor ke Notch atas untuk membuka Oceru Island." FontSize="12" Foreground="#94A3B8" Margin="0,4,0,0"/>
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
                                    <TextBlock Text="Kelola checklist harian Anda dengan pelacakan persentase progres otomatis." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
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
                                            <TextBox Grid.Column="0" x:Name="InputDashTodoText" Background="#0C1B30" Foreground="#FFFFFF" BorderBrush="#1C365C" BorderThickness="1" Padding="10,7" Margin="0,0,8,0" Text="Eksplorasi fitur baru Oceru"/>
                                            <Button Grid.Column="1" x:Name="BtnDashAddTodo" Style="{StaticResource DashBtnPrimary}">
                                                <TextBlock Text="Tambah Tugas"/>
                                            </Button>
                                        </Grid>
                                    </StackPanel>
                                </Border>

                                <!-- Tasks List & Progress -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="STATUS TUGAS HARI INI" FontSize="11" FontWeight="Bold" Foreground="#CBD5E1"/>
                                        <TextBlock x:Name="DashTodoSummaryText" Text="2 dari 3 tugas selesai (67%)" FontSize="15" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,4,0,8"/>
                                        <Border Height="6" Background="#14243C" CornerRadius="3" Margin="0,0,0,14">
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
                                    <TextBlock Text="Akses teks dan tautan yang baru saja disalin. Salin ulang dengan 1-klik ke clipboard Windows." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
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
                                            <TextBlock Text="Teks Biasa" FontSize="11" Foreground="#64748B" Margin="0,2,0,0"/>
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
                                            <TextBlock Text="Teks Biasa" FontSize="11" Foreground="#64748B" Margin="0,2,0,0"/>
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
                                    <TextBlock Text="Kontrol audio master, jaringan nirkabel, mode fokus, dan status daya Windows." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                                </StackPanel>

                                <!-- Audio & Volume Card -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="KONTROL AUDIO MASTER" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>
                                        <Grid Margin="0,10,0,6">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <Slider Grid.Column="0" x:Name="DashQuickVolSlider" Minimum="0" Maximum="100" Value="72" VerticalAlignment="Center"/>
                                            <TextBlock Grid.Column="1" x:Name="DashQuickVolPctText" Text="72%" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center" Margin="14,0,14,0"/>
                                            <Button Grid.Column="2" x:Name="BtnDashQuickMute" Style="{StaticResource DashBtnSecondary}">
                                                <TextBlock x:Name="DashQuickMuteIcon" Text="Mute Audio"/>
                                            </Button>
                                        </Grid>
                                        <Button x:Name="BtnDashOpenSoundSettings" Style="{StaticResource DashBtnSecondary}" HorizontalAlignment="Left" Margin="0,4,0,0">
                                            <TextBlock Text="Buka Pengaturan Suara Windows (ms-settings:sound)"/>
                                        </Button>
                                    </StackPanel>
                                </Border>

                                <!-- Connectivity & Focus Modes -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="KONEKTIVITAS &amp; MODE FOKUS" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,10"/>
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="Auto"/>
                                            </Grid.RowDefinitions>
                                            <Button Grid.Row="0" Grid.Column="0" x:Name="BtnDashQuickWifi" Style="{StaticResource DashBtnSecondary}" Margin="3">
                                                <TextBlock Text="Wi-Fi (Buka Flyout Jaringan)"/>
                                            </Button>
                                            <Button Grid.Row="0" Grid.Column="1" x:Name="BtnDashQuickBt" Style="{StaticResource DashBtnSecondary}" Margin="3">
                                                <TextBlock Text="Bluetooth Settings"/>
                                            </Button>
                                            <Button Grid.Row="1" Grid.Column="0" x:Name="BtnDashQuickDnd" Style="{StaticResource DashBtnSecondary}" Margin="3">
                                                <TextBlock x:Name="DashQuickDndStatus" Text="Mode Jangan Ganggu: Nonaktif"/>
                                            </Button>
                                            <Button Grid.Row="1" Grid.Column="1" x:Name="BtnDashQuickGame" Style="{StaticResource DashBtnSecondary}" Margin="3">
                                                <TextBlock x:Name="DashQuickGameStatus" Text="Mode Game: Nonaktif"/>
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
                                    <TextBlock Text="Buka aplikasi produktivitas dan folder kerja favorit Anda dalam 1-klik." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
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
                                                    <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#38BDF8" HorizontalAlignment="Center"/>
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
                                                    <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#C084FC" HorizontalAlignment="Center"/>
                                                    <TextBlock Text="Task Manager" FontSize="11" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Center"/>
                                                </StackPanel>
                                            </Button>
                                            <Button Grid.Row="1" Grid.Column="0" x:Name="BtnLaunchSettings" Style="{StaticResource AppTileBtn}">
                                                <StackPanel HorizontalAlignment="Center">
                                                    <TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#94A3B8" HorizontalAlignment="Center"/>
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
                                        <TextBlock Text="FOLDER KERJA CEPAT" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,10"/>
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
                                            <TextBox Grid.Column="0" x:Name="InputCustomCommand" Background="#0C1B30" Foreground="#FFFFFF" BorderBrush="#1C365C" BorderThickness="1" Padding="10,7" Margin="0,0,8,0" Text="cmd.exe"/>
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
                                    <TextBlock Text="Kustomisasi tema tampilan, integrasi Windows Startup, dan preferensi privasi." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                                </StackPanel>

                                <!-- Theme Card -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="TEMA DESAIN (OCEAN AZURE GLASS)" FontSize="11" FontWeight="Bold" Foreground="#00D2FF" Margin="0,0,0,8"/>
                                        <RadioButton Content="Ocean Dark (Midnight Navy #060A14 + Cyan #00D2FF)" IsChecked="True" Foreground="#FFFFFF" Margin="0,4"/>
                                        <RadioButton Content="Ocean Azure Light / Aero Glass" IsChecked="False" Foreground="#94A3B8" Margin="0,4"/>
                                        <RadioButton Content="Ikuti Pengaturan Tema Windows" IsChecked="False" Foreground="#94A3B8" Margin="0,4"/>
                                    </StackPanel>
                                </Border>

                                <!-- Windows Startup Card -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="INTEGRASI WINDOWS STARTUP" FontSize="11" FontWeight="Bold" Foreground="#10B981" Margin="0,0,0,8"/>
                                        <TextBlock Text="Aktifkan agar Oceru Dynamic Island otomatis berjalan setiap kali laptop dinyalakan." FontSize="12" Foreground="#94A3B8" Margin="0,0,0,12"/>
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
                                        <TextBlock Text="Kembalikan semua konfigurasi, catatan, dan tugas ke pengaturan awal bawaan pabrik." FontSize="12" Foreground="#94A3B8" Margin="0,0,0,12"/>
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
                                    <TextBlock Text="Informasi rilis, arsitektur sistem, dan diagnostik desktop." FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
                                </StackPanel>

                                <!-- Identity Card -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="IDENTITAS APLIKASI" FontSize="11" FontWeight="Bold" Foreground="#00D2FF"/>
                                        <TextBlock Text="Oceru Dynamic Island Desktop" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,6,0,2"/>
                                        <TextBlock Text="Versi: v2.0.0 (Release Build 2026.10)" FontSize="13" Foreground="#38BDF8"/>
                                        <TextBlock Text="Desain: Ocean Azure Glass" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                                        <TextBlock Text="Lisensi: MIT Open Source License" FontSize="12" Foreground="#10B981" Margin="0,2,0,0"/>
                                    </StackPanel>
                                </Border>

                                <!-- Diagnostics Card -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="ARSITEKTUR &amp; PERFORMA" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,8"/>
                                        <TextBlock Text="UI Engine: Windows Presentation Foundation (WPF) DirectX Direct3D" FontSize="12" Foreground="#CBD5E1" Margin="0,2"/>
                                        <TextBlock Text="Runtime Host: PowerShell .NET CLR Engine (Zero Electron, Zero WebViews)" FontSize="12" Foreground="#CBD5E1" Margin="0,2"/>
                                        <TextBlock Text="Native APIs: user32.dll, kernel32.dll, powrprof.dll via P/Invoke" FontSize="12" Foreground="#CBD5E1" Margin="0,2"/>
                                        <TextBlock x:Name="DashAboutRamFootprint" Text="Pemakaian Memori: ~55 MB (Ultra Ringan)" FontSize="12" Foreground="#10B981" Margin="0,2"/>
                                        <TextBlock Text="Lokasi Instalasi: D:Project Orizzdevdynamic-island" FontSize="12" Foreground="#64748B" Margin="0,2"/>
                                    </StackPanel>
                                </Border>

                                <!-- Links & Actions -->
                                <Border Style="{StaticResource DashCard}">
                                    <StackPanel>
                                        <TextBlock Text="TAUTAN &amp; TINDAKAN CEPAT" FontSize="11" FontWeight="Bold" Foreground="#C084FC" Margin="0,0,0,10"/>
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


# Initialize Both Windows
$reader1 = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($islandXaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader1)

$reader2 = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($dashXaml))
$dashWindow = [System.Windows.Markup.XamlReader]::Load($reader2)

# Start by Default in Resting Cat Eyes Mode at Top-Center
$window.Left = $eyesLeftPos
$window.Top = 0
$global:islandMode = "eyes" # "eyes", "status", "expanded"
$global:targetMode = "eyes"
$global:statusIdleTicks = 0
$global:outsideTicks = 0

# Grab Handles: Liquid Background & Views
$notchBody = $window.FindName("NotchBody")
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

# =========================================================================
# FLUID SPRING INTERPOLATION ENGINE FOR BUTTER-SMOOTH EXPAND & COLLAPSE
# 60 FPS DispatcherTimer with Quintic Ease-Out Curve: 1 - (1 - t)^5
# =========================================================================
$global:animTimer = New-Object System.Windows.Threading.DispatcherTimer
$global:animTimer.Interval = [TimeSpan]::FromMilliseconds(16) # ~60 FPS
$global:animSw = [System.Diagnostics.Stopwatch]::new()
$global:animDuration = 270

$global:fromW = $eyesWidth
$global:toW = $eyesWidth
$global:fromH = $eyesHeight
$global:toH = $eyesHeight
$global:fromL = $eyesLeftPos
$global:toL = $eyesLeftPos
$global:fromR = 18
$global:toR = 18

function Set-IslandMode($mode) {
    if ($global:targetMode -eq $mode) { return }
    $global:targetMode = $mode
    $global:islandMode = $mode

    # Capture current live dimensions as starting point (enables seamless reversal!)
    $global:fromW = $window.Width
    $global:fromH = $window.Height
    $global:fromL = $window.Left
    $global:fromR = $notchBody.CornerRadius.BottomLeft

    if ($mode -eq "eyes") {
        $global:toW = $eyesWidth
        $global:toH = $eyesHeight
        $global:toL = $eyesLeftPos
        $global:toR = 18
        $global:animDuration = 260
        $eyesGrid.Visibility = [System.Windows.Visibility]::Visible
    }
    elseif ($mode -eq "status") {
        $global:toW = $statusWidth
        $global:toH = $statusHeight
        $global:toL = $statusLeftPos
        $global:toR = 18
        $global:animDuration = 260
        $global:statusIdleTicks = 0
        $statusGrid.Visibility = [System.Windows.Visibility]::Visible
    }
    elseif ($mode -eq "expanded") {
        $global:toW = $expandedWidth
        $global:toH = $expandedHeight
        $global:toL = $expandedLeftPos
        $global:toR = 24
        $global:animDuration = 300
        $global:outsideTicks = 0
        $expandedGrid.Visibility = [System.Windows.Visibility]::Visible
    }

    $global:animSw.Restart()
    $global:animTimer.Start()
}

$global:animTimer.Add_Tick({
    $elapsed = $global:animSw.ElapsedMilliseconds
    $t = [Math]::Min(1.0, $elapsed / $global:animDuration)

    # Fluid Liquid Cubic Deceleration Curve: 1 - (1 - t)^2.8
    $ease = 1.0 - [Math]::Pow(1.0 - $t, 2.8)

    # Interpolate Window Width, Height, Left, and Corner Radius in real time
    $curW = [Math]::Round($global:fromW + ($global:toW - $global:fromW) * $ease)
    $curH = [Math]::Round($global:fromH + ($global:toH - $global:fromH) * $ease)
    $curL = [Math]::Round($global:fromL + ($global:toL - $global:fromL) * $ease)
    $curR = [Math]::Round($global:fromR + ($global:toR - $global:fromR) * $ease)

    $window.Width = $curW
    $window.Height = $curH
    $window.Left = $curL
    $notchBody.CornerRadius = [System.Windows.CornerRadius]::new(0, 0, $curR, $curR)

    # Cross-fading Opacities between active views during interpolation
    if ($global:targetMode -eq "expanded") {
        # Smoothly fade out compact views
        $compactOp = [Math]::Max(0.0, 1.0 - ($t / 0.28))
        $eyesGrid.Opacity = $compactOp
        $statusGrid.Opacity = $compactOp

        # Smooth progressive fade in of expanded view
        if ($t -ge 0.18) {
            $expandedGrid.Opacity = [Math]::Min(1.0, ($t - 0.18) / 0.82)
        } else {
            $expandedGrid.Opacity = 0.0
        }
    }
    elseif ($global:targetMode -eq "status") {
        # Fade out expanded view
        $expandedGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.35))

        # Fade in status view
        if ($t -ge 0.2) {
            $statusGrid.Opacity = [Math]::Min(1.0, ($t - 0.2) / 0.8)
        }
        $eyesGrid.Opacity = 0.0
    }
    elseif ($global:targetMode -eq "eyes") {
        # Fade out status view
        $statusGrid.Opacity = [Math]::Max(0.0, 1.0 - ($t / 0.35))
        $expandedGrid.Opacity = 0.0

        # Fade in eyes view
        if ($t -ge 0.2) {
            $eyesGrid.Opacity = [Math]::Min(1.0, ($t - 0.2) / 0.8)
        }
    }

    # Completion Cleanup
    if ($t -ge 1.0) {
        $global:animTimer.Stop()
        $window.Width = $global:toW
        $window.Height = $global:toH
        $window.Left = $global:toL
        $notchBody.CornerRadius = [System.Windows.CornerRadius]::new(0, 0, $global:toR, $global:toR)

        if ($global:targetMode -eq "expanded") {
            $expandedGrid.Opacity = 1.0
            $eyesGrid.Visibility = [System.Windows.Visibility]::Collapsed
            $statusGrid.Visibility = [System.Windows.Visibility]::Collapsed
        }
        elseif ($global:targetMode -eq "status") {
            $statusGrid.Opacity = 1.0
            $eyesGrid.Visibility = [System.Windows.Visibility]::Collapsed
            $expandedGrid.Visibility = [System.Windows.Visibility]::Collapsed
        }
        elseif ($global:targetMode -eq "eyes") {
            $eyesGrid.Opacity = 1.0
            $statusGrid.Visibility = [System.Windows.Visibility]::Collapsed
            $expandedGrid.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
})

# Mouse enter/click event fallbacks
$eyesGrid.Add_MouseEnter({ Set-IslandMode "expanded" })
$eyesGrid.Add_MouseLeftButtonUp({ Set-IslandMode "expanded" })
$statusGrid.Add_MouseEnter({ Set-IslandMode "expanded" })
$statusGrid.Add_MouseLeftButtonUp({ Set-IslandMode "expanded" })
$notchBody.Add_MouseEnter({ if ($global:targetMode -ne "expanded") { Set-IslandMode "expanded" } })
$notchBody.Add_MouseLeftButtonUp({ if ($global:targetMode -ne "expanded") { Set-IslandMode "expanded" } })

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
            $dotBars[$i].Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00D2FF")
        } else {
            $dotBars[$i].Width = 3.5
            $dotBars[$i].Height = 3.5
            $dotBars[$i].CornerRadius = [System.Windows.CornerRadius]::new(1.75)
            $dotBars[$i].Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#202A3A")
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
$btnPlayTrack0 = $dashWindow.FindName("BtnPlayTrack0")
$btnPlayTrack1 = $dashWindow.FindName("BtnPlayTrack1")
$btnPlayTrack2 = $dashWindow.FindName("BtnPlayTrack2")

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
$btnDashQuickWifi = $dashWindow.FindName("BtnDashQuickWifi")
$btnDashQuickBt = $dashWindow.FindName("BtnDashQuickBt")
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
    ShowActionFeedback (if ($global:OceruState.dndEnabled) { "Jangan Ganggu Aktif" } else { "Jangan Ganggu Nonaktif" }) ([char]0xE717) "#C084FC"
})
$btnOverviewWifi.Add_Click({ Start-Process "ms-availablenetworks:" })

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
$btnPlayTrack0.Add_Click({
    $global:trackIndex = 0
    UpdateMusicDisplay
    ShowActionFeedback "Memutar: Paper Sky" ([char]0xE768) "#00D2FF"
})
$btnPlayTrack1.Add_Click({
    $global:trackIndex = 1
    UpdateMusicDisplay
    ShowActionFeedback "Memutar: Midnight Echoes" ([char]0xE768) "#00D2FF"
})
$btnPlayTrack2.Add_Click({
    $global:trackIndex = 2
    UpdateMusicDisplay
    ShowActionFeedback "Memutar: Ocean Waves" ([char]0xE768) "#00D2FF"
})

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
        $lapBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0C1B30")
        $lapBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1C365C")
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
    $defaultTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
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
    $emptyTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#64748B")
    $emptyTb.FontSize = 12
    $emptyTb.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
    $dashNotifListContainer.Children.Add($emptyTb) | Out-Null
    ShowActionFeedback "Riwayat Notifikasi Dibersihkan" ([char]0xE74D) "#94A3B8"
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
    $t2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CBD5E1")
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
        $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0C1B30")
        $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1C365C")
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
        $t2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
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
    ShowActionFeedback "Papan Klip Dibersihkan" ([char]0xE74D) "#94A3B8"
})

# -------------------------------------------------------------------------
# DASHBOARD WIRING: PAGE 11 (QUICK SETTINGS)
# -------------------------------------------------------------------------
$dashQuickVolSlider.Add_ValueChanged({
    $val = [Math]::Round($dashQuickVolSlider.Value)
    $dashQuickVolPctText.Text = "$val%"
    $quickVolPctText.Text = "$val%"
    $global:OceruState.volume = $val
})
$btnDashQuickMute.Add_Click({
    [Win32Helper]::ToggleMute()
    $global:OceruState.isMuted = -not $global:OceruState.isMuted
    $dashQuickMuteIcon.Text = if ($global:OceruState.isMuted) { "Unmute Audio" } else { "Mute Audio" }
    ShowActionFeedback "Audio Mute Ditoggle" ([char]0xE74F) "#00D2FF"
})
$btnDashOpenSoundSettings.Add_Click({ Start-Process "ms-settings:sound" })
$btnDashQuickWifi.Add_Click({ Start-Process "ms-availablenetworks:" })
$btnDashQuickBt.Add_Click({ Start-Process "ms-settings:bluetooth" })
$btnDashQuickDnd.Add_Click({
    $global:OceruState.dndEnabled = -not $global:OceruState.dndEnabled
    Save-OceruState
    $dashQuickDndStatus.Text = if ($global:OceruState.dndEnabled) { "Mode Jangan Ganggu: Aktif" } else { "Mode Jangan Ganggu: Nonaktif" }
    ShowActionFeedback $dashQuickDndStatus.Text ([char]0xE717) "#C084FC"
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
        ShowActionFeedback "Menjalankan uninstall.bat..." ([char]0xE74D) "#94A3B8"
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
            $inEyes = ($cursorPos.X -ge ($window.Left - 6)) -and 
                      ($cursorPos.X -le ($window.Left + $window.Width + 6)) -and 
                      ($cursorPos.Y -ge 0) -and 
                      ($cursorPos.Y -le ($window.Height + 8))
            
            if ($inEyes) {
                Set-IslandMode "expanded"
            }
        }
        # -----------------------------------------------------------------
        # MODE 2: COMPACT STATUS BAR (Weather, Clock, Battery)
        # -----------------------------------------------------------------
        elseif ($global:islandMode -eq "status") {
            # Hover detection on Status Bar to Expand
            $inStatus = ($cursorPos.X -ge ($window.Left - 6)) -and 
                        ($cursorPos.X -le ($window.Left + $window.Width + 6)) -and 
                        ($cursorPos.Y -ge 0) -and 
                        ($cursorPos.Y -le ($window.Height + 8))
            
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
            $inExpanded = ($cursorPos.X -ge ($window.Left - 10)) -and 
                          ($cursorPos.X -le ($window.Left + $window.Width + 10)) -and 
                          ($cursorPos.Y -ge 0) -and 
                          ($cursorPos.Y -le ($window.Height + 14))

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
    if ($dashMediaProgressBar -and $musicProgressBar) {
        $dashMediaProgressBar.Width = [Math]::Round(280 * ($global:musicProgressSec / 256.0))
        $dashMediaCurrentTime.Text = [TimeSpan]::FromSeconds($global:musicProgressSec).ToString("mm\:ss")
        $dashMediaRemainingTime.Text = "-" + [TimeSpan]::FromSeconds(256 - $global:musicProgressSec).ToString("mm\:ss")
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
