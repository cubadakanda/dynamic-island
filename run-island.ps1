Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

# Embedded Native Win32 Helper for Real Hardware & OS Control
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
}
"@

try {
    Add-Type -TypeDefinition $win32Code -Language CSharp -ErrorAction SilentlyContinue
} catch {}

# Process PID management (ensures clean single-instance and easy shutdown)
if (-not $PSScriptRoot) { $PSScriptRoot = "D:\Project Orizzdev\dynamic-island" }
$pidPath = Join-Path $PSScriptRoot ".oceru.pid"
$pidOld = Join-Path $PSScriptRoot ".island.pid"
if (Test-Path $pidOld) { Remove-Item $pidOld -Force -ErrorAction SilentlyContinue }

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

$screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
$winWidth = 650
$leftPos = [Math]::Round(($screenWidth - $winWidth) / 2)

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Oceru Dynamic Island"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="True"
        ShowInTaskbar="False"
        WindowStartupLocation="Manual"
        Top="0" Width="650" Height="260">
    <Window.Resources>
        <!-- Inactive Tab Icon Button -->
        <Style x:Key="NavIconBtn" TargetType="Button">
            <Setter Property="Background" Value="#0F1420"/>
            <Setter Property="Foreground" Value="#738096"/>
            <Setter Property="Width" Value="32"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="Margin" Value="0,0,4,0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#1A2234"/>
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

        <!-- Active Tab Pill Button -->
        <Style x:Key="ActiveNavBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="Margin" Value="0,0,4,0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#3B82F6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border CornerRadius="8">
                            <Border.Background>
                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                    <GradientStop Color="#3B82F6" Offset="0"/>
                                    <GradientStop Color="#1D4ED8" Offset="1"/>
                                </LinearGradientBrush>
                            </Border.Background>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Control Card Button Style (Ensures reliable WPF Click handling) -->
        <Style x:Key="ControlCardBtn" TargetType="Button">
            <Setter Property="Background" Value="#0C101A"/>
            <Setter Property="BorderBrush" Value="#1A2338"/>
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
                                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#3B82F6"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="CardBorder" Property="Background" Value="#141C2C"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- System Action Pill Button -->
        <Style x:Key="SysActionBtn" TargetType="Button">
            <Setter Property="Background" Value="#0C101A"/>
            <Setter Property="Foreground" Value="#CBD5E1"/>
            <Setter Property="BorderBrush" Value="#1A2338"/>
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
                                <Setter TargetName="BtnBorder" Property="BorderBrush" Value="#60A5FA"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="BtnBorder" Property="Background" Value="#172236"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Preset Duration Pill -->
        <Style x:Key="TimerPill" TargetType="Button">
            <Setter Property="Background" Value="#121826"/>
            <Setter Property="Foreground" Value="#93C5FD"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Margin" Value="2,0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#223048"/>
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
                                <Setter TargetName="PillBorder" Property="Background" Value="#2563EB"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid HorizontalAlignment="Center" VerticalAlignment="Top">
        
        <!-- Main Notch Container (Deep Obsidian Glass Bezel) -->
        <Border x:Name="NotchBorder"
                Background="#07090E"
                BorderBrush="#192233"
                BorderThickness="1,0,1,1"
                CornerRadius="0,0,18,18"
                Width="180" Height="32"
                Cursor="Hand"
                AllowDrop="True">
            <Border.ContextMenu>
                <ContextMenu Background="#0B0F17" Foreground="#E2E8F0" BorderBrush="#1F2A3F" BorderThickness="1">
                    <MenuItem x:Name="MenuReload" Header="Muat Ulang / Reload (F5)" Foreground="#60A5FA" FontWeight="SemiBold"/>
                    <Separator Background="#1F2A3F"/>
                    <MenuItem Header="Pilihan Tema Oceru">
                        <MenuItem x:Name="CtxThemeOled" Header="OLED True Black" Foreground="#CBD5E1"/>
                        <MenuItem x:Name="CtxThemeGlass" Header="Aero Glassmorphism" Foreground="#38BDF8"/>
                        <MenuItem x:Name="CtxThemeCyber" Header="Neon Cyberpunk" Foreground="#F43F5E"/>
                    </MenuItem>
                    <Separator Background="#1F2A3F"/>
                    <MenuItem x:Name="MenuOpenWifi" Header="Buka Pengaturan Wi-Fi" Foreground="#93C5FD"/>
                    <MenuItem x:Name="MenuOpenBt" Header="Buka Pengaturan Bluetooth" Foreground="#93C5FD"/>
                    <Separator Background="#1F2A3F"/>
                    <MenuItem x:Name="MenuOpenFolder" Header="Buka Folder Proyek" Foreground="#CBD5E1"/>
                    <Separator Background="#1F2A3F"/>
                    <MenuItem x:Name="MenuExit" Header="Tutup Oceru Dynamic Island" Foreground="#F87171" FontWeight="SemiBold"/>
                </ContextMenu>
            </Border.ContextMenu>
            <Border.Effect>
                <DropShadowEffect BlurRadius="24" ShadowDepth="5" Opacity="0.88" Color="#000000"/>
            </Border.Effect>

            <Grid>
                <!-- 1. Collapsed State: Weather, Digital Clock & Battery -->
                <Grid x:Name="CollapsedView" VerticalAlignment="Center" Margin="12,0">
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
                    <TextBlock Grid.Column="1" x:Name="ClockText" Text="22:50"
                               Foreground="#FFFFFF" FontWeight="Bold" FontSize="11"
                               HorizontalAlignment="Center" FontFamily="Segoe UI, Consolas"/>
                    
                    <!-- Battery -->
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock x:Name="CollapsedBatIcon" FontFamily="Segoe MDL2 Assets" Text="&#xEBAA;" FontSize="11" Foreground="#38BDF8" Margin="0,0,2,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="CollapsedBatPct" Text="88%" Foreground="#94A3B8" FontSize="9" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    </StackPanel>
                </Grid>

                <!-- 2. Resting State: Cute Glowing Eyes (Video 01:17) -->
                <Grid x:Name="RestingEyesView" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Center">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Border x:Name="LeftEye" Width="6" Height="10" Background="#FFFFFF" CornerRadius="3" Margin="0,0,8,0">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="6" Color="#38BDF8" ShadowDepth="0" Opacity="0.75"/>
                            </Border.Effect>
                        </Border>
                        <Border x:Name="RightEye" Width="6" Height="10" Background="#FFFFFF" CornerRadius="3">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="6" Color="#38BDF8" ShadowDepth="0" Opacity="0.75"/>
                            </Border.Effect>
                        </Border>
                    </StackPanel>
                </Grid>

                <!-- 3. Dynamic Collapsed Toast Popup (Phone-style Island Pill) -->
                <Grid x:Name="ToastView" Visibility="Collapsed" VerticalAlignment="Center" Margin="10,0">
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <TextBlock x:Name="ToastIcon" FontFamily="Segoe MDL2 Assets" Text="&#xE7F6;" FontSize="12" Foreground="#60A5FA" Margin="0,0,6,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="ToastText" Text="Perangkat Terhubung" Foreground="#FFFFFF" FontSize="10" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    </StackPanel>
                </Grid>

                <!-- 4. Expanded Dashboard (Clean, Zero Scrollbars!) -->
                <Grid x:Name="ExpandedView" Visibility="Collapsed" Margin="14,10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Top Bar: Segmented Toolbar + Status Badges & Action Feedback -->
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <!-- Sleek Segmented Navigation (Fits Perfectly Without Scrollbars) -->
                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                            <!-- Tab 1: Control -->
                            <Button x:Name="BtnControl" Style="{StaticResource ActiveNavBtn}">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE770;" FontSize="11" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblControl" Text="Control" FontSize="10" FontWeight="Bold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 2: Music -->
                            <Button x:Name="BtnMusic" Style="{StaticResource NavIconBtn}" ToolTip="Pemutar Musik">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE189;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblMusic" Text="Music" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 3: Lyrics -->
                            <Button x:Name="BtnLyrics" Style="{StaticResource NavIconBtn}" ToolTip="Lirik Sinkron">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE8BD;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblLyrics" Text="Lyrics" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 4: Timer -->
                            <Button x:Name="BtnPomo" Style="{StaticResource NavIconBtn}" ToolTip="Fokus Timer">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE916;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblPomo" Text="Timer" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 5: Clipboard -->
                            <Button x:Name="BtnClip" Style="{StaticResource NavIconBtn}" ToolTip="Riwayat Papan Klip">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE8C8;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblClip" Text="Clipboard" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 6: Notes -->
                            <Button x:Name="BtnTodo" Style="{StaticResource NavIconBtn}" ToolTip="Catatan &amp; To-Do">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE73E;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblTodo" Text="Notes" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                </StackPanel>
                            </Button>

                            <!-- Tab 7: Shelf -->
                            <Button x:Name="BtnShelf" Style="{StaticResource NavIconBtn}" ToolTip="File Shelf">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xED25;" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="LblShelf" Text="Shelf" FontSize="10" FontWeight="Bold" Margin="5,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                                    <TextBlock x:Name="ShelfBadgeCount" Text="" Foreground="#60A5FA" FontWeight="Bold" FontSize="9"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                        <!-- Right Info: In-Notch Feedback Pill, Bluetooth Status & Battery -->
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <!-- In-Notch Action Feedback Pill (Visible immediately on any action) -->
                            <Border x:Name="ExpandedToastPill" Background="#1D4ED8" CornerRadius="7" Padding="7,3" Margin="0,0,6,0" Visibility="Collapsed">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock x:Name="ExpandedToastIcon" FontFamily="Segoe MDL2 Assets" Text="&#xE73E;" FontSize="9" Foreground="#FFFFFF" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="ExpandedToastText" Text="Aksi Berhasil" Foreground="#FFFFFF" FontSize="9" FontWeight="Bold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Border>

                            <!-- Bluetooth Status Pill (Click opens BT Settings) -->
                            <Button x:Name="BtnHeaderBt" Background="#0E1626" BorderBrush="#1E3A8A" BorderThickness="1" Padding="7,3" Margin="0,0,6,0" Cursor="Hand">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="7"/></Style></Button.Resources>
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7F6;" FontSize="9" Foreground="#60A5FA" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="BtBadge" Text="Bluetooth" Foreground="#93C5FD" FontSize="9" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- Battery Status Pill -->
                            <Border Background="#091814" BorderBrush="#065F46" BorderThickness="1" CornerRadius="7" Padding="7,3" Margin="0,0,6,0">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock x:Name="HeaderBatIcon" FontFamily="Segoe MDL2 Assets" Text="&#xEBAA;" FontSize="9" Foreground="#10B981" Margin="0,0,4,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="HeaderBatText" Text="88%" Foreground="#6EE7B7" FontSize="9" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Border>

                            <TextBlock x:Name="DateText" Text="22:50" Foreground="#94A3B8" FontSize="10" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Grid>

                    <!-- Content Panels -->
                    <Grid Grid.Row="1">
                        
                        <!-- TAB 1: CONTROL CENTER (Ultra-Sleek Modern Control Grid) -->
                        <Grid x:Name="PaneControl" Visibility="Visible">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Row 1: 3 Action Cards (Wi-Fi, Bluetooth Devices, Audio) -->
                            <Grid Grid.Row="0" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="1*"/>
                                    <ColumnDefinition Width="1.25*"/>
                                    <ColumnDefinition Width="1.1*"/>
                                </Grid.ColumnDefinitions>

                                <!-- 1. Wi-Fi Card: Click opens native Windows Available Networks flyout -->
                                <Button x:Name="CardWifi" Grid.Column="0" Style="{StaticResource ControlCardBtn}" Margin="0,0,6,0" ToolTip="Klik untuk buka daftar jaringan Wi-Fi Windows">
                                    <Grid VerticalAlignment="Center">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Border x:Name="IconBgWifi" Background="#2563EB" CornerRadius="10" Width="34" Height="34" Margin="0,0,9,0">
                                            <TextBlock x:Name="IconWifi" FontFamily="Segoe MDL2 Assets" Text="&#xE701;" FontSize="13" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Wi-Fi" Foreground="#FFFFFF" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="StatusWifi" Text="Buka Jaringan &#x2197;" Foreground="#93C5FD" FontSize="9" Margin="0,1,0,0"/>
                                        </StackPanel>
                                    </Grid>
                                </Button>

                                <!-- 2. Bluetooth Device Card: Click opens Windows Bluetooth Settings -->
                                <Button x:Name="CardBt" Grid.Column="1" Style="{StaticResource ControlCardBtn}" Margin="0,0,6,0" ToolTip="Klik untuk kelola perangkat Bluetooth">
                                    <Grid VerticalAlignment="Center">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Border x:Name="IconBgBt" Background="#2563EB" CornerRadius="10" Width="34" Height="34" Margin="0,0,9,0">
                                            <TextBlock x:Name="IconBt" FontFamily="Segoe MDL2 Assets" Text="&#xE7F6;" FontSize="13" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Bluetooth" Foreground="#FFFFFF" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="StatusBt" Text="Kelola Perangkat &#x2197;" Foreground="#93C5FD" FontSize="9" Margin="0,1,0,0"/>
                                        </StackPanel>
                                    </Grid>
                                </Button>

                                <!-- 3. Audio Volume Card: Click to Mute/Unmute + Mini Vol Buttons -->
                                <Border x:Name="CardMuteBorder" Grid.Column="2" Background="#0C101A" BorderBrush="#1A2338" BorderThickness="1" CornerRadius="12" Padding="8,6">
                                    <Grid VerticalAlignment="Center">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        
                                        <!-- Main Toggle Mute Area -->
                                        <Button x:Name="CardMute" Grid.Column="0" Background="Transparent" BorderThickness="0" Cursor="Hand" HorizontalAlignment="Left" ToolTip="Klik untuk Mute / Unmute">
                                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                                <Border x:Name="IconBgMute" Background="#1E293B" CornerRadius="9" Width="32" Height="32" Margin="0,0,8,0">
                                                    <TextBlock x:Name="IconMute" FontFamily="Segoe MDL2 Assets" Text="&#xE767;" FontSize="13" Foreground="#CBD5E1" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                </Border>
                                                <StackPanel VerticalAlignment="Center">
                                                    <TextBlock Text="Audio" Foreground="#FFFFFF" FontSize="11" FontWeight="Bold"/>
                                                    <TextBlock x:Name="StatusMute" Text="Normal" Foreground="#94A3B8" FontSize="9" Margin="0,1,0,0"/>
                                                </StackPanel>
                                            </StackPanel>
                                        </Button>

                                        <!-- Mini Volume Up / Down Buttons -->
                                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                            <Button x:Name="BtnVolDown" Background="#161F30" BorderBrush="#24324D" BorderThickness="1" Width="22" Height="22" Margin="0,0,3,0" Cursor="Hand" ToolTip="Kecilkan Volume">
                                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="6"/></Style></Button.Resources>
                                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE74F;" FontSize="9" Foreground="#93C5FD" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Button>
                                            <Button x:Name="BtnVolUp" Background="#161F30" BorderBrush="#24324D" BorderThickness="1" Width="22" Height="22" Cursor="Hand" ToolTip="Besarkan Volume">
                                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="6"/></Style></Button.Resources>
                                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE767;" FontSize="9" Foreground="#93C5FD" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Button>
                                        </StackPanel>
                                    </Grid>
                                </Border>
                            </Grid>

                            <!-- Row 2: Sleek System Action Tiles (Lock, Sleep, Restart, Theme) -->
                            <Grid Grid.Row="1">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <!-- 1: Lock Workstation (Calls Win32 LockWorkStation) -->
                                <Button x:Name="BtnSysLock" Grid.Column="0" Style="{StaticResource SysActionBtn}" Margin="0,0,5,0" ToolTip="Kunci Layar Windows Sekarang">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#172554" CornerRadius="6" Width="20" Height="20" Margin="0,0,7,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE72E;" FontSize="10" Foreground="#60A5FA" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock Text="Kunci Layar" FontSize="10" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- 2: Sleep Mode -->
                                <Button x:Name="BtnSysSleep" Grid.Column="1" Style="{StaticResource SysActionBtn}" Margin="0,0,5,0" ToolTip="Masuk Mode Tidur (Sleep)">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#2E1065" CornerRadius="6" Width="20" Height="20" Margin="0,0,7,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE708;" FontSize="10" Foreground="#C084FC" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock Text="Mode Tidur" FontSize="10" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- 3: Restart with Safe Confirmation -->
                                <Button x:Name="BtnSysRestart" Grid.Column="2" Style="{StaticResource SysActionBtn}" Margin="0,0,5,0" ToolTip="Restart Laptop (Dengan Konfirmasi)">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#451A03" CornerRadius="6" Width="20" Height="20" Margin="0,0,7,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE777;" FontSize="10" Foreground="#FBBF24" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock x:Name="LblRestart" Text="Restart" FontSize="10" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>

                                <!-- 4: Theme Toggle (OLED -> Glass -> Cyberpunk) -->
                                <Button x:Name="BtnThemeSwitch" Grid.Column="3" Style="{StaticResource SysActionBtn}" ToolTip="Ganti Tema Visual Notch">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Background="#064E3B" CornerRadius="6" Width="20" Height="20" Margin="0,0,7,0">
                                            <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE790;" FontSize="10" Foreground="#34D399" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <TextBlock x:Name="LblTheme" Text="Ganti Tema" FontSize="10" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </Grid>
                        </Grid>

                        <!-- TAB 2: MUSIC PLAYER (Video 00:05) -->
                        <Grid x:Name="PaneMusic" Visibility="Collapsed">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="58"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="185"/>
                            </Grid.ColumnDefinitions>

                            <Border Grid.Column="0" CornerRadius="12" Width="54" Height="54" HorizontalAlignment="Left">
                                <Border.Background>
                                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                        <GradientStop Color="#E11D48" Offset="0"/>
                                        <GradientStop Color="#7C3AED" Offset="0.5"/>
                                        <GradientStop Color="#2563EB" Offset="1"/>
                                    </LinearGradientBrush>
                                </Border.Background>
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="12" Color="#E11D48" ShadowDepth="2" Opacity="0.35"/>
                                </Border.Effect>
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE189;" FontSize="20" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>

                            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="10,0">
                                <TextBlock x:Name="TrackTitle" Text="Never Gonna Give You Up" Foreground="#FFFFFF" FontWeight="Bold" FontSize="12" TextTrimming="CharacterEllipsis"/>
                                <TextBlock x:Name="TrackArtist" Text="Rick Astley • YouTube Music" Foreground="#94A3B8" FontSize="9.5" Margin="0,1,0,4"/>
                                
                                <Grid Margin="0,0,0,5">
                                    <ProgressBar x:Name="TrackProgress" Value="42" Maximum="100" Height="3" Background="#161F30" Foreground="#3B82F6" BorderThickness="0"/>
                                </Grid>

                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <Button x:Name="BtnPrev" Background="Transparent" Foreground="#CBD5E1" BorderThickness="0" Margin="0,0,8,0" Cursor="Hand" ToolTip="Lagu Sebelumnya">
                                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE892;" FontSize="13"/>
                                    </Button>
                                    
                                    <Button x:Name="BtnPlay" Width="26" Height="26" Background="#2563EB" BorderThickness="0" Cursor="Hand" ToolTip="Putar / Jeda">
                                        <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="13"/></Style></Button.Resources>
                                        <TextBlock x:Name="PlayIcon" FontFamily="Segoe MDL2 Assets" Text="&#xE768;" FontSize="10" Foreground="#FFFFFF"/>
                                    </Button>
                                    
                                    <Button x:Name="BtnNext" Background="Transparent" Foreground="#CBD5E1" BorderThickness="0" Margin="8,0,10,0" Cursor="Hand" ToolTip="Lagu Selanjutnya">
                                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE893;" FontSize="13"/>
                                    </Button>
                                    
                                    <TextBox x:Name="YtInput" Text="Cari / paste link YouTube..."
                                             Foreground="#64748B" Background="#0C101A" BorderBrush="#1C2438"
                                             Padding="8,3" FontSize="9.5" Width="135" VerticalAlignment="Center">
                                        <TextBox.Resources><Style TargetType="{x:Type Border}"><Setter Property="CornerRadius" Value="6"/></Style></TextBox.Resources>
                                    </TextBox>
                                </StackPanel>
                            </StackPanel>

                            <!-- Synced Lyrics Preview -->
                            <Border Grid.Column="2" Background="#0B0F17" BorderBrush="#1A2234" BorderThickness="1" CornerRadius="10" Padding="10,8">
                                <StackPanel VerticalAlignment="Center">
                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,3">
                                        <TextBlock Text="SYNCED LYRICS" Foreground="#64748B" FontSize="8" FontWeight="Bold"/>
                                        <TextBlock x:Name="WaveAnimText" Text=" &#x266B;" Foreground="#38BDF8" FontSize="9"/>
                                    </StackPanel>
                                    <TextBlock x:Name="MusicLyricMini" Text="Never gonna give you up... never gonna let you down"
                                               Foreground="#38BDF8" FontSize="9.5" FontWeight="SemiBold" TextWrapping="Wrap" LineHeight="13"/>
                                </StackPanel>
                            </Border>

                            <!-- Hidden Web Engine for YouTube Audio -->
                            <WebBrowser x:Name="AudioWebEngine" Width="0" Height="0" Visibility="Collapsed"/>
                        </Grid>

                        <!-- TAB 3: SPLIT SYNCED LYRICS (Karaoke View) -->
                        <Grid x:Name="PaneLyrics" Visibility="Collapsed">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            
                            <Border Grid.Column="0" Background="#0B0F17" BorderBrush="#1A2234" BorderThickness="1" CornerRadius="10" Padding="12,8" Margin="0,0,6,0">
                                <StackPanel VerticalAlignment="Center">
                                    <TextBlock Text="KARAOKE SINKRON" Foreground="#64748B" FontSize="8" FontWeight="Bold" Margin="0,0,0,3"/>
                                    <TextBlock x:Name="LyricLinePast" Text="I just wanna tell you how I'm feeling" Foreground="#64748B" FontSize="9.5" Margin="0,0,0,2"/>
                                    <TextBlock x:Name="LyricLineActive" Text="Gotta make you understand..." Foreground="#38BDF8" FontSize="12" FontWeight="Bold" Margin="0,0,0,2"/>
                                    <TextBlock x:Name="LyricLineNext" Text="Never gonna give you up" Foreground="#94A3B8" FontSize="9.5"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="1" Background="#0B0F17" BorderBrush="#1A2234" BorderThickness="1" CornerRadius="10" Padding="12,8">
                                <StackPanel VerticalAlignment="Center">
                                    <TextBlock Text="AUDIO METADATA" Foreground="#64748B" FontSize="8" FontWeight="Bold" Margin="0,0,0,3"/>
                                    <TextBlock Text="Never Gonna Give You Up" Foreground="#FFFFFF" FontSize="11" FontWeight="Bold"/>
                                    <TextBlock Text="Rick Astley • LRCLIB Synced" Foreground="#94A3B8" FontSize="9.5" Margin="0,1,0,4"/>
                                    <TextBlock Text="Ketuk baris lirik untuk melompat ke bagian musik" Foreground="#64748B" FontSize="8.5"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- TAB 4: TIMER WITH QUICK PRESETS -->
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
                                <Button x:Name="BtnPomoReset" Content="Reset" Background="#141C2C" Foreground="#CBD5E1" FontWeight="Bold" Padding="10,5" BorderThickness="0" Margin="0,0,4,0" Cursor="Hand">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="7"/></Style></Button.Resources>
                                </Button>
                                <Button x:Name="BtnPomoMode" Content="Istirahat" Background="#141C2C" Foreground="#60A5FA" FontWeight="Bold" Padding="10,5" BorderThickness="0" Cursor="Hand">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="7"/></Style></Button.Resources>
                                </Button>
                            </StackPanel>
                        </Grid>

                        <!-- TAB 5: CLIPBOARD HISTORY -->
                        <Grid x:Name="PaneClip" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Grid.Row="0" Text="RIWAYAT PAPAN KLIP (KLIK UNTUK MENYALIN ULANG)" Foreground="#64748B" FontSize="8" FontWeight="Bold" Margin="0,0,0,4"/>
                            <StackPanel Grid.Row="1" x:Name="ClipListPanel">
                                <Button x:Name="BtnClipItem1" Style="{StaticResource ControlCardBtn}" Padding="8,5" Margin="0,0,0,3" ToolTip="Klik untuk salin ke Clipboard">
                                    <TextBlock Text="https://github.com/cubadakanda/dynamic-island" Foreground="#93C5FD" FontSize="9.5"/>
                                </Button>
                                <Button x:Name="BtnClipItem2" Style="{StaticResource ControlCardBtn}" Padding="8,5" Margin="0,0,0,3" ToolTip="Klik untuk salin ke Clipboard">
                                    <TextBlock Text="Oceru Dynamic Island - Smart Desktop Notch" Foreground="#CBD5E1" FontSize="9.5"/>
                                </Button>
                                <Button x:Name="BtnClipItem3" Style="{StaticResource ControlCardBtn}" Padding="8,5" ToolTip="Klik untuk salin ke Clipboard">
                                    <TextBlock Text="Never Gonna Give You Up - Rick Astley" Foreground="#94A3B8" FontSize="9.5"/>
                                </Button>
                            </StackPanel>
                        </Grid>

                        <!-- TAB 6: TO-DO & QUICK NOTES -->
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
                                         Foreground="#64748B" Background="#0B0F17" BorderBrush="#1A2234"
                                         Padding="8,4" FontSize="9.5">
                                    <TextBox.Resources><Style TargetType="{x:Type Border}"><Setter Property="CornerRadius" Value="6"/></Style></TextBox.Resources>
                                </TextBox>
                                <TextBlock Grid.Column="1" x:Name="TodoCounterText" Text="2 dari 3 selesai" Foreground="#10B981" FontSize="9.5" FontWeight="SemiBold" VerticalAlignment="Center" Margin="10,0,0,0"/>
                            </Grid>

                            <StackPanel Grid.Row="1" x:Name="TodoListPanel">
                                <Border Background="#0B0F17" BorderBrush="#1A2234" BorderThickness="1" CornerRadius="6" Padding="7,4" Margin="0,0,0,3">
                                    <StackPanel Orientation="Horizontal">
                                        <CheckBox x:Name="Chk1" IsChecked="True" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                        <TextBlock x:Name="Txt1" Text="Desain UI terinspirasi dari video Dynamic-Island" Foreground="#64748B" TextDecorations="Strikethrough" FontSize="9.5" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Border>
                                <Border Background="#0B0F17" BorderBrush="#1A2234" BorderThickness="1" CornerRadius="6" Padding="7,4" Margin="0,0,0,3">
                                    <StackPanel Orientation="Horizontal">
                                        <CheckBox x:Name="Chk2" IsChecked="True" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                        <TextBlock x:Name="Txt2" Text="Integrasi kontrol audio, Wi-Fi, dan sistem Windows" Foreground="#64748B" TextDecorations="Strikethrough" FontSize="9.5" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Border>
                                <Border Background="#0B0F17" BorderBrush="#1A2234" BorderThickness="1" CornerRadius="6" Padding="7,4">
                                    <StackPanel Orientation="Horizontal">
                                        <CheckBox x:Name="Chk3" IsChecked="False" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                        <TextBlock x:Name="Txt3" Text="Sinkronkan pembaruan fitur ke GitHub" Foreground="#FFFFFF" FontSize="9.5" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </Grid>

                        <!-- TAB 7: FILE SHELF -->
                        <Grid x:Name="PaneShelf" Visibility="Collapsed">
                            <Border BorderBrush="#2563EB" BorderThickness="1.5" CornerRadius="10" Background="#0A0E16" Padding="10">
                                <Grid>
                                    <StackPanel x:Name="ShelfPlaceholder" VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xED25;" FontSize="18" Foreground="#3B82F6" HorizontalAlignment="Center"/>
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
"@

# Parse XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$window.Left = $leftPos
$window.Top = 0

# Get element handles
$notch = $window.FindName("NotchBorder")
$collapsedView = $window.FindName("CollapsedView")
$restingEyesView = $window.FindName("RestingEyesView")
$leftEye = $window.FindName("LeftEye")
$rightEye = $window.FindName("RightEye")

$toastView = $window.FindName("ToastView")
$toastIcon = $window.FindName("ToastIcon")
$toastText = $window.FindName("ToastText")
$expandedView = $window.FindName("ExpandedView")

$clockText = $window.FindName("ClockText")
$weatherSmallText = $window.FindName("WeatherSmallText")
$collapsedBatIcon = $window.FindName("CollapsedBatIcon")
$collapsedBatPct = $window.FindName("CollapsedBatPct")
$headerBatIcon = $window.FindName("HeaderBatIcon")
$headerBatText = $window.FindName("HeaderBatText")
$btBadge = $window.FindName("BtBadge")
$btnHeaderBt = $window.FindName("BtnHeaderBt")

# In-Notch Action Feedback Pill
$expandedToastPill = $window.FindName("ExpandedToastPill")
$expandedToastIcon = $window.FindName("ExpandedToastIcon")
$expandedToastText = $window.FindName("ExpandedToastText")

# Tabs
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

# Control Center Elements
$cardWifi = $window.FindName("CardWifi")
$iconBgWifi = $window.FindName("IconBgWifi")
$iconWifi = $window.FindName("IconWifi")
$statusWifi = $window.FindName("StatusWifi")

$cardBt = $window.FindName("CardBt")
$iconBgBt = $window.FindName("IconBgBt")
$iconBt = $window.FindName("IconBt")
$statusBt = $window.FindName("StatusBt")

$cardMuteBorder = $window.FindName("CardMuteBorder")
$cardMute = $window.FindName("CardMute")
$iconBgMute = $window.FindName("IconBgMute")
$iconMute = $window.FindName("IconMute")
$statusMute = $window.FindName("StatusMute")
$btnVolDown = $window.FindName("BtnVolDown")
$btnVolUp = $window.FindName("BtnVolUp")

$btnSysLock = $window.FindName("BtnSysLock")
$btnSysSleep = $window.FindName("BtnSysSleep")
$btnSysRestart = $window.FindName("BtnSysRestart")
$lblRestart = $window.FindName("LblRestart")
$btnThemeSwitch = $window.FindName("BtnThemeSwitch")
$lblTheme = $window.FindName("LblTheme")

# Timer Presets
$btnPill5 = $window.FindName("BtnPill5")
$btnPill10 = $window.FindName("BtnPill10")
$btnPill15 = $window.FindName("BtnPill15")
$btnPill25 = $window.FindName("BtnPill25")
$btnPill45 = $window.FindName("BtnPill45")

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

# Clipboard Panel Buttons
$btnClipItem1 = $window.FindName("BtnClipItem1")
$btnClipItem2 = $window.FindName("BtnClipItem2")
$btnClipItem3 = $window.FindName("BtnClipItem3")

# Music Player Elements
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

# Shelf Elements
$shelfPlaceholder = $window.FindName("ShelfPlaceholder")
$shelfItemsList = $window.FindName("ShelfItemsList")

# Pomodoro Elements
$pomoTimer = $window.FindName("PomoTimer")
$pomoStatus = $window.FindName("PomoStatus")
$btnPomoStart = $window.FindName("BtnPomoStart")
$btnPomoReset = $window.FindName("BtnPomoReset")
$btnPomoMode = $window.FindName("BtnPomoMode")

# Context Menu & Hotkeys
function ReloadIsland {
    $script = Join-Path $PSScriptRoot "run-island.ps1"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    $window.Close()
}

$menuReload = $window.FindName("MenuReload")
if ($menuReload) { $menuReload.Add_Click({ ReloadIsland }) }

$menuOpenFolder = $window.FindName("MenuOpenFolder")
if ($menuOpenFolder) {
    $menuOpenFolder.Add_Click({ [System.Diagnostics.Process]::Start("explorer.exe", $PSScriptRoot) })
}

$menuOpenWifi = $window.FindName("MenuOpenWifi")
if ($menuOpenWifi) {
    $menuOpenWifi.Add_Click({ [System.Diagnostics.Process]::Start("explorer.exe", "ms-availablenetworks:") })
}

$menuOpenBt = $window.FindName("MenuOpenBt")
if ($menuOpenBt) {
    $menuOpenBt.Add_Click({ [System.Diagnostics.Process]::Start("explorer.exe", "ms-settings:bluetooth") })
}

$menuExit = $window.FindName("MenuExit")
if ($menuExit) { $menuExit.Add_Click({ $window.Close() }) }

$window.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::F5 -or ($e.Key -eq [System.Windows.Input.Key]::R -and [System.Windows.Input.Keyboard]::Modifiers -eq [System.Windows.Input.ModifierKeys]::Control)) {
        ReloadIsland
    }
})

$window.Add_Closed({
    if (Test-Path $pidPath) {
        Remove-Item $pidPath -Force -ErrorAction SilentlyContinue
    }
})

# State
$isExpanded = $false
$isToastActive = $false
$currentTab = "control"
$global:wifiActive = $true
$global:isMuted = $false
$global:currentTheme = "oled"
$global:restartArmed = $false

# Timers
$global:idleSeconds = 0
$idleCheckTimer = New-Object System.Windows.Threading.DispatcherTimer
$idleCheckTimer.Interval = [TimeSpan]::FromSeconds(1)

$blinkTimer = New-Object System.Windows.Threading.DispatcherTimer
$blinkTimer.Interval = [TimeSpan]::FromMilliseconds(3800)

$leaveTimer = New-Object System.Windows.Threading.DispatcherTimer
$leaveTimer.Interval = [TimeSpan]::FromMilliseconds(300)

$toastTimer = New-Object System.Windows.Threading.DispatcherTimer
$toastTimer.Interval = [TimeSpan]::FromMilliseconds(2800)

$expandedToastTimer = New-Object System.Windows.Threading.DispatcherTimer
$expandedToastTimer.Interval = [TimeSpan]::FromMilliseconds(2400)

# Instant Visual Feedback Helper (Works both Collapsed and Expanded!)
function ShowActionFeedback($message, $glyphChar, $colorHex) {
    # 1. Update in-notch expanded feedback pill
    $expandedToastText.Text = $message
    $expandedToastIcon.Text = $glyphChar
    $expandedToastPill.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($colorHex)
    $expandedToastPill.Visibility = [System.Windows.Visibility]::Visible

    $expandedToastTimer.Stop()
    $expandedToastTimer.Start()

    # 2. Also prepare collapsed toast view
    $toastText.Text = $message
    $toastIcon.Text = $glyphChar
    $toastIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($colorHex)

    if (-not $global:isExpanded) {
        $global:isToastActive = $true
        $collapsedView.Visibility = [System.Windows.Visibility]::Collapsed
        $restingEyesView.Visibility = [System.Windows.Visibility]::Collapsed
        $toastView.Visibility = [System.Windows.Visibility]::Visible

        $wAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(180, 280, [TimeSpan]::FromMilliseconds(220))
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
        $wAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(280, 180, [TimeSpan]::FromMilliseconds(220))
        $wAnim.DecelerationRatio = 0.8
        $notch.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $wAnim)
        $toastView.Visibility = [System.Windows.Visibility]::Collapsed
        $collapsedView.Visibility = [System.Windows.Visibility]::Visible
    }
})

# Animation Helpers
function AnimateExpand {
    if ($global:isExpanded) { return }
    $global:isExpanded = $true

    $wAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(180, 620, [TimeSpan]::FromMilliseconds(260))
    $wAnim.DecelerationRatio = 0.85
    $hAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(32, 220, [TimeSpan]::FromMilliseconds(260))
    $hAnim.DecelerationRatio = 0.85

    $notch.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $wAnim)
    $notch.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $hAnim)
    $notch.CornerRadius = New-Object System.Windows.CornerRadius(0, 0, 22, 22)

    $collapsedView.Visibility = [System.Windows.Visibility]::Collapsed
    $restingEyesView.Visibility = [System.Windows.Visibility]::Collapsed
    $toastView.Visibility = [System.Windows.Visibility]::Collapsed
    $expandedView.Visibility = [System.Windows.Visibility]::Visible
}

function AnimateCollapse {
    if (-not $global:isExpanded) { return }
    $global:isExpanded = $false

    $wAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(620, 180, [TimeSpan]::FromMilliseconds(240))
    $wAnim.DecelerationRatio = 0.85
    $hAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(220, 32, [TimeSpan]::FromMilliseconds(240))
    $hAnim.DecelerationRatio = 0.85

    $notch.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $wAnim)
    $notch.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $hAnim)
    $notch.CornerRadius = New-Object System.Windows.CornerRadius(0, 0, 18, 18)

    $expandedView.Visibility = [System.Windows.Visibility]::Collapsed
    if ($global:isToastActive) {
        $toastView.Visibility = [System.Windows.Visibility]::Visible
    } else {
        $collapsedView.Visibility = [System.Windows.Visibility]::Visible
    }
}

# Mouse Hover Handlers
$notch.Add_MouseEnter({
    $leaveTimer.Stop()
    $global:idleSeconds = 0
    $restingEyesView.Visibility = [System.Windows.Visibility]::Collapsed
    AnimateExpand
})

$notch.Add_MouseLeave({
    $leaveTimer.Start()
})

$leaveTimer.Add_Tick({
    $leaveTimer.Stop()
    AnimateCollapse
})

# Resting Eyes Idle Logic
$idleCheckTimer.Add_Tick({
    if (-not $global:isExpanded -and -not $global:isToastActive) {
        $global:idleSeconds++
        # After 5 seconds idle, transition clock to resting eyes
        if ($global:idleSeconds -ge 5) {
            $collapsedView.Visibility = [System.Windows.Visibility]::Collapsed
            $restingEyesView.Visibility = [System.Windows.Visibility]::Visible
        }
    } else {
        $global:idleSeconds = 0
    }
})
$idleCheckTimer.Start()

# Eye Blink Animation
$blinkTimer.Add_Tick({
    if ($restingEyesView.Visibility -eq [System.Windows.Visibility]::Visible) {
        $blinkAnim = New-Object System.Windows.Media.Animation.DoubleAnimation(10, 2, [TimeSpan]::FromMilliseconds(120))
        $blinkAnim.AutoReverse = $true
        $leftEye.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $blinkAnim)
        $rightEye.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $blinkAnim)
    }
})
$blinkTimer.Start()

# Segmented Tab Switching (Zero Scrollbars, Perfect Sizing!)
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

# 1. REAL WI-FI ACTION: Opens native Windows Available Networks Flyout
$cardWifi.Add_Click({
    ShowActionFeedback "Membuka Panel Wi-Fi..." ([char]0xE701) "#2563EB"
    [System.Diagnostics.Process]::Start("explorer.exe", "ms-availablenetworks:")
})

# 2. REAL BLUETOOTH ACTION: Opens native Windows Bluetooth Settings
function OpenBluetoothSettings {
    ShowActionFeedback "Membuka Bluetooth..." ([char]0xE7F6) "#2563EB"
    [System.Diagnostics.Process]::Start("explorer.exe", "ms-settings:bluetooth")
}
$cardBt.Add_Click({ OpenBluetoothSettings })
$btnHeaderBt.Add_Click({ OpenBluetoothSettings })

# 3. REAL AUDIO VOLUME & MUTE ACTIONS
$cardMute.Add_Click({
    $global:isMuted = -not $global:isMuted
    try {
        [Win32Helper]::ToggleMute()
    } catch {}

    if ($global:isMuted) {
        $iconMute.Text = [char]0xE74F
        $statusMute.Text = "Bisu (Mute)"
        $iconBgMute.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#DC2626")
        ShowActionFeedback "Audio Dibisukan" ([char]0xE74F) "#DC2626"
    } else {
        $iconMute.Text = [char]0xE767
        $statusMute.Text = "Normal"
        $iconBgMute.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
        ShowActionFeedback "Audio Aktif" ([char]0xE767) "#10B981"
    }
})

$btnVolDown.Add_Click({
    try { [Win32Helper]::VolumeDown() } catch {}
    ShowActionFeedback "Volume Turun" ([char]0xE74F) "#60A5FA"
})

$btnVolUp.Add_Click({
    try { [Win32Helper]::VolumeUp() } catch {}
    ShowActionFeedback "Volume Naik" ([char]0xE767) "#60A5FA"
})

# 4. REAL LOCK WORKSTATION ACTION
$btnSysLock.Add_Click({
    ShowActionFeedback "Mengunci Layar..." ([char]0xE72E) "#60A5FA"
    try {
        [Win32Helper]::LockWorkStation() | Out-Null
    } catch {
        Start-Process "rundll32.exe" -ArgumentList "user32.dll,LockWorkStation"
    }
})

# 5. REAL SLEEP MODE ACTION
$btnSysSleep.Add_Click({
    ShowActionFeedback "Masuk Mode Tidur..." ([char]0xE708) "#C084FC"
    Start-Process "rundll32.exe" -ArgumentList "powrprof.dll,SetSuspendState 0,1,0"
})

# 6. RESTART WITH SAFE TWO-STEP CONFIRMATION
$restartTimer = New-Object System.Windows.Threading.DispatcherTimer
$restartTimer.Interval = [TimeSpan]::FromSeconds(4)
$restartTimer.Add_Tick({
    $restartTimer.Stop()
    $global:restartArmed = $false
    $lblRestart.Text = "Restart"
    $btnSysRestart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0C101A")
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
        ShowActionFeedback "Laptop Restart Sekarang..." ([char]0xE777) "#EF4444"
        Start-Process "shutdown.exe" -ArgumentList "/r /t 2 /c `"Restart via Oceru Dynamic Island`""
    }
})

# 7. REAL THEME SWITCHER (OLED True Black <-> Aero Glass <-> Neon Cyberpunk)
function ApplyTheme($theme) {
    $global:currentTheme = $theme
    if ($theme -eq "oled") {
        $notch.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#07090E")
        $notch.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#192233")
        $lblTheme.Text = "OLED Black"
        ShowActionFeedback "Tema: OLED True Black" ([char]0xE790) "#3B82F6"
    } elseif ($theme -eq "glass") {
        $notch.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E60C1B2E")
        $notch.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00E5FF")
        $lblTheme.Text = "Aero Glass"
        ShowActionFeedback "Tema: Aero Glass" ([char]0xE790) "#00E5FF"
    } elseif ($theme -eq "cyber") {
        $notch.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0D0518")
        $notch.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF007F")
        $lblTheme.Text = "Cyberpunk"
        ShowActionFeedback "Tema: Cyberpunk" ([char]0xE790) "#FF007F"
    }
}

$btnThemeSwitch.Add_Click({
    if ($global:currentTheme -eq "oled") { ApplyTheme("glass") }
    elseif ($global:currentTheme -eq "glass") { ApplyTheme("cyber") }
    else { ApplyTheme("oled") }
})

$ctxOled = $window.FindName("CtxThemeOled")
if ($ctxOled) { $ctxOled.Add_Click({ ApplyTheme("oled") }) }
$ctxGlass = $window.FindName("CtxThemeGlass")
if ($ctxGlass) { $ctxGlass.Add_Click({ ApplyTheme("glass") }) }
$ctxCyber = $window.FindName("CtxThemeCyber")
if ($ctxCyber) { $ctxCyber.Add_Click({ ApplyTheme("cyber") }) }

# 8. TIMER PRESETS
function SetTimerMinutes($mins) {
    $global:pomoSeconds = $mins * 60
    $pomoTimer.Text = [TimeSpan]::FromSeconds($global:pomoSeconds).ToString("mm\:ss")
    ShowActionFeedback "Timer: $mins Menit" ([char]0xE916) "#38BDF8"
}

$btnPill5.Add_Click({ SetTimerMinutes(5) })
$btnPill10.Add_Click({ SetTimerMinutes(10) })
$btnPill15.Add_Click({ SetTimerMinutes(15) })
$btnPill25.Add_Click({ SetTimerMinutes(25) })
$btnPill45.Add_Click({ SetTimerMinutes(45) })

# 9. TO-DO & NOTES LOGIC
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
            $b.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0B0F17")
            $b.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1A2234")
            $b.BorderThickness = New-Object System.Windows.Thickness(1)
            $b.CornerRadius = New-Object System.Windows.CornerRadius(6)
            $b.Padding = New-Object System.Windows.Thickness(7, 4, 7, 4)
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

# 10. REAL CLIPBOARD RE-COPY ACTION
function CopyClipText($text) {
    try {
        [System.Windows.Clipboard]::SetText($text)
        ShowActionFeedback "Tersalin ke Clipboard!" ([char]0xE8C8) "#38BDF8"
    } catch {}
}

$btnClipItem1.Add_Click({ CopyClipText("https://github.com/cubadakanda/dynamic-island") })
$btnClipItem2.Add_Click({ CopyClipText("Oceru Dynamic Island - Smart Desktop Notch") })
$btnClipItem3.Add_Click({ CopyClipText("Never Gonna Give You Up - Rick Astley") })

# 11. DRAG AND DROP FILE SHELF
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
            $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#121724")
            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A3348")
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
            $icon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#60A5FA")
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
        ShowActionFeedback "$($files.Count) File Ditambahkan!" ([char]0xED25) "#38BDF8"
    }
})

# 12. MUSIC PLAYER & YOUTUBE AUDIO ENGINE
$isPlaying = $false
$lyricsList = @(
    "Never gonna give you up... never gonna let you down",
    "Never gonna run around and desert you",
    "Never gonna make you cry, never gonna say goodbye",
    "Never gonna tell a lie and hurt you",
    "We've known each other for so long, your heart's been aching"
)
$lyricIndex = 0

$btnPlay.Add_Click({
    $global:isPlaying = -not $global:isPlaying
    if ($global:isPlaying) {
        $playIcon.Text = [char]0xE769 # Pause icon
        $btnPlay.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EAB308")
        ShowActionFeedback "Memutar Musik" ([char]0xE189) "#38BDF8"
    } else {
        $playIcon.Text = [char]0xE768 # Play icon
        $btnPlay.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2563EB")
        ShowActionFeedback "Musik Dijeda" ([char]0xE768) "#94A3B8"
    }
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
            $global:isPlaying = $true
            $playIcon.Text = [char]0xE769
            $btnPlay.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EAB308")
            ShowActionFeedback "Memutar Audio YouTube!" ([char]0xE189) "#38BDF8"

            # If user pasted a real URL, load in audio engine or open
            if ($inputQuery -match "^https?://") {
                try {
                    $audioWebEngine.Navigate($inputQuery)
                } catch {
                    [System.Diagnostics.Process]::Start("explorer.exe", $inputQuery)
                }
            } else {
                # Search on YouTube
                $searchUrl = "https://www.youtube.com/results?search_query=" + [System.Uri]::EscapeDataString($inputQuery)
                [System.Diagnostics.Process]::Start("explorer.exe", $searchUrl)
            }
        }
    }
})

# 13. POMODORO ENGINE
$pomoSeconds = 25 * 60
$pomoRunning = $false
$pomoMode = "focus"

$pomoTimerEngine = New-Object System.Windows.Threading.DispatcherTimer
$pomoTimerEngine.Interval = [TimeSpan]::FromSeconds(1)

$pomoTimerEngine.Add_Tick({
    if ($global:pomoSeconds -gt 0) {
        $global:pomoSeconds--
        $pomoTimer.Text = [TimeSpan]::FromSeconds($global:pomoSeconds).ToString("mm\:ss")
    } else {
        $pomoTimerEngine.Stop()
        ShowActionFeedback "Waktu Fokus Selesai!" ([char]0xE916) "#10B981"
    }
})

$btnPomoStart.Add_Click({
    $global:pomoRunning = -not $global:pomoRunning
    if ($global:pomoRunning) {
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
})

$btnPomoReset.Add_Click({
    $pomoTimerEngine.Stop()
    $global:pomoRunning = $false
    $btnPomoStart.Content = "Mulai"
    $btnPomoStart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
    $global:pomoSeconds = if ($global:pomoMode -eq "focus") { 25 * 60 } else { 5 * 60 }
    $pomoTimer.Text = [TimeSpan]::FromSeconds($global:pomoSeconds).ToString("mm\:ss")
    ShowActionFeedback "Timer Direset" ([char]0xE916) "#60A5FA"
})

$btnPomoMode.Add_Click({
    $pomoTimerEngine.Stop()
    $global:pomoRunning = $false
    $btnPomoStart.Content = "Mulai"
    $btnPomoStart.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
    if ($global:pomoMode -eq "focus") {
        $global:pomoMode = "break"
        $pomoStatus.Text = "WAKTU ISTIRAHAT"
        $pomoStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
        $btnPomoMode.Content = "Mode Fokus"
        $global:pomoSeconds = 5 * 60
        ShowActionFeedback "Mode Istirahat (5m)" ([char]0xE916) "#38BDF8"
    } else {
        $global:pomoMode = "focus"
        $pomoStatus.Text = "FOKUS AKTIF"
        $pomoStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
        $btnPomoMode.Content = "Istirahat"
        $global:pomoSeconds = 25 * 60
        ShowActionFeedback "Mode Fokus (25m)" ([char]0xE916) "#10B981"
    }
    $pomoTimer.Text = [TimeSpan]::FromSeconds($global:pomoSeconds).ToString("mm\:ss")
})

# 14. REAL-TIME HARDWARE & BATTERY MONITOR
$musicProgressVal = 42
$waveState = 0
$monitorTimer = New-Object System.Windows.Threading.DispatcherTimer
$monitorTimer.Interval = [TimeSpan]::FromSeconds(1)

$monitorTimer.Add_Tick({
    $now = Get-Date
    $clockText.Text = $now.ToString("HH:mm")

    # 1. Real-time Battery Check
    try {
        $power = [System.Windows.Forms.SystemInformation]::PowerStatus
        $batPct = [Math]::Round($power.BatteryLifePercent * 100)
        $isOnline = $power.PowerLineStatus -eq "Online"

        $collapsedBatPct.Text = "$batPct%"
        $headerBatText.Text = "$batPct%"

        if ($isOnline) {
            $collapsedBatIcon.Text = [char]0xEA93 # Charging lightning
            $collapsedBatIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
            $headerBatIcon.Text = [char]0xEA93
        } else {
            $collapsedBatIcon.Text = [char]0xEBAA # Battery
            $collapsedBatIcon.Foreground = if ($batPct -lt 25) { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444") } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8") }
            $headerBatIcon.Text = [char]0xEBAA
        }
    } catch {}

    # 2. Music lyrics simulation & equalizer
    if ($global:isPlaying) {
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
            if ($global:waveState -eq 0) { $waveAnimText.Text = " |||" }
            elseif ($global:waveState -eq 1) { $waveAnimText.Text = " | |" }
            else { $waveAnimText.Text = " || " }
        }
    }
})

$monitorTimer.Start()

# Run Window
$window.ShowDialog() | Out-Null
