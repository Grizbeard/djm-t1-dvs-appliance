# Launch Mixxx with the Terminal-wide skin at the panel's real size, and leave
# it running to look at.
#
# Three things this handles that launching Mixxx by hand does not:
#
#   * Qt scale factor. This dev machine runs the desktop at 250%, so a 1920x480
#     window is only 768x192 logical pixels - below the skin's minimum size, at
#     which point Qt quietly hands back a much larger window and what you are
#     looking at is not the panel's layout at all. Pinning the scale factor to 1
#     makes logical pixels physical ones.
#
#   * Client area, not window size, and no menu bar inside it. The title bar
#     and frame are drawn by Windows at the system DPI, so they are ~58px of
#     chrome that has nothing to do with Mixxx; this measures the frame and
#     sizes the window so the *client* area is exactly the panel. The menu bar
#     is inside that client area and would take ~28 of the 480 rows, so it is
#     hidden (it still drops down on Alt) - which needs show_menubar_hint 0 as
#     well as hide_menubar 1, because otherwise Mixxx asks on the first launch
#     and writes hide_menubar from the answer. Dismissing that prompt counts as
#     "show", which is how this preview spent a while quietly rendering the
#     skin into 452 rows instead of 480.
#
#   * The skin lives outside any Mixxx res/ tree, so it has to be installed where
#     Mixxx looks for a user skin. This refreshes that copy on every run, which
#     is what makes it useful after an edit.
#
# By default it uses its own settings directory, so your real Mixxx config,
# library and skin choice are left alone. Point -SettingsPath at
# "$env:LOCALAPPDATA\Mixxx" to preview against your own library instead.

param(
    [string]$Scheme = "Btop",
    [int]$Width = 1920,
    [int]$Height = 480,
    [string]$Exe = "C:\Users\jmorken\projects\mixxx-terminal-skin\build\x64_relwithdebinfo\mixxx.exe",
    [string]$ResourcePath = "C:\Users\jmorken\projects\mixxx-terminal-skin\res",
    [string]$SettingsPath = "$env:LOCALAPPDATA\Mixxx-terminal-wide-preview",
    [string[]]$Tracks = @(),
    [switch]$ShowMenuBar
)

$ErrorActionPreference = "Stop"
$skinName = "Terminal-wide"
$skinSource = Join-Path (Split-Path -Parent $PSScriptRoot) "mixxx\skins\$skinName"

if (-not (Test-Path $Exe)) { throw "no Mixxx binary at $Exe" }
if (-not (Test-Path $skinSource)) { throw "no skin at $skinSource" }

# Refresh the installed copy so the launch always shows the current edit.
#
# Copy the *contents* with -Force rather than deleting the directory first.
# Deleting it and copying the source over it is the obvious way to write this
# and it fails silently here: a shell inside the Claude desktop app's container
# cannot really delete a host-side directory, so the delete appears to succeed,
# the directory survives, and Copy-Item then puts the source *inside* it as
# skins/Terminal-wide/Terminal-wide. Mixxx goes on reading the top level, which
# is by then a mixture of old and new files - an edit that does not appear in
# the preview and nothing to say why.
$skinsDir = Join-Path $SettingsPath "skins"
New-Item -ItemType Directory -Force $skinsDir | Out-Null
$skinTarget = Join-Path $skinsDir $skinName
New-Item -ItemType Directory -Force $skinTarget | Out-Null
$nested = Join-Path $skinTarget $skinName
if (Test-Path $nested) { Remove-Item -Recurse -Force $nested -ErrorAction SilentlyContinue }
Copy-Item -Recurse -Force (Join-Path $skinSource "*") $skinTarget

# Then check it actually took, because the failure mode above is invisible.
$stale = @()
foreach ($src in Get-ChildItem -Recurse -File $skinSource) {
    $rel = $src.FullName.Substring($skinSource.Length + 1)
    $dst = Join-Path $skinTarget $rel
    if (-not (Test-Path $dst)) { $stale += $rel; continue }
    if ((Get-Item $dst).LastWriteTime -lt $src.LastWriteTime) { $stale += $rel }
}
if ($stale.Count) {
    Write-Output ("warning: these skin files did not install and the preview " +
        "will show the previous version of them: " + ($stale -join ", "))
} else {
    Write-Output "installed skin matches the source"
}

# Mixxx splices the resource path straight into the skin stylesheet and Qt's CSS
# parser eats backslashes inside url(), so pass forward slashes.
$resPathFwd = $ResourcePath.Replace("\", "/")
$hideMenuBar = if ($ShowMenuBar) { "0" } else { "1" }

# Appliance defaults, seeded only where the config has nothing to say yet. The
# skin deliberately does not set these itself: an attribute that re-asserts a
# value on every launch overrides whatever the operator chose, every time. As
# seeds they are defaults; as skin attributes they would be overrides.
#
#   [Controls] PositionDisplay 1        time remaining, which is what the deck's
#                                       time field is sized for
#   effect routing                      unit 1 on deck 1, unit 2 on deck 2
$seeds = @{
    '[Controls]' = @{ 'PositionDisplay' = '1' }
    '[EffectRack1_EffectUnit1]' = @{ 'group_[Channel1]_enable' = '1'; 'group_[Channel2]_enable' = '0' }
    '[EffectRack1_EffectUnit2]' = @{ 'group_[Channel1]_enable' = '0'; 'group_[Channel2]_enable' = '1' }
}

function Add-Seeds([string[]]$lines) {
    $section = ''
    $seen = @{}
    foreach ($line in $lines) {
        if ($line -match '^\[') { $section = $line }
        elseif ($section -and $line -match '^(\S+) ') {
            if (-not $seen.ContainsKey($section)) { $seen[$section] = @{} }
            $seen[$section][$Matches[1]] = $true
        }
    }
    $out = New-Object System.Collections.ArrayList
    $section = ''
    foreach ($line in $lines) {
        if ($line -match '^\[' -and $section -and $seeds.ContainsKey($section)) {
            foreach ($k in $seeds[$section].Keys) {
                if (-not ($seen[$section] -and $seen[$section][$k])) {
                    [void]$out.Add("$k $($seeds[$section][$k])")
                }
            }
        }
        if ($line -match '^\[') { $section = $line }
        [void]$out.Add($line)
    }
    # Sections the config does not have at all.
    foreach ($sec in $seeds.Keys) {
        if (-not $seen.ContainsKey($sec)) {
            [void]$out.Add($sec)
            foreach ($k in $seeds[$sec].Keys) { [void]$out.Add("$k $($seeds[$sec][$k])") }
        }
    }
    return $out
}

$cfgPath = Join-Path $SettingsPath "mixxx.cfg"
if (Test-Path $cfgPath) {
    # Keep an existing library and preferences; only force what this preview is for.
    $cfg = Get-Content $cfgPath
    $cfg = $cfg | Where-Object {
        $_ -notmatch '^(ResizableSkin|Scheme|Path|hide_menubar|show_menubar_hint) '
    }
    $cfg = @("[Config]", "ResizableSkin $skinName", "Scheme $Scheme", "Path $ResourcePath",
             "hide_menubar $hideMenuBar", "show_menubar_hint 0") +
           ($cfg | Where-Object { $_ -ne "[Config]" })
    Set-Content -Path $cfgPath -Value (Add-Seeds $cfg) -Encoding utf8
} else {
    Set-Content -Path $cfgPath -Encoding utf8 -Value @"
[Config]
ResizableSkin $skinName
Scheme $Scheme
Path $ResourcePath
hide_menubar $hideMenuBar
show_menubar_hint 0
[Waveform]
WaveformType 12
[Controls]
PositionDisplay 1
[EffectRack1_EffectUnit1]
group_[Channel1]_enable 1
group_[Channel2]_enable 0
[EffectRack1_EffectUnit2]
group_[Channel1]_enable 0
group_[Channel2]_enable 1
[[Preferences]]
firstrun no
"@
}

# Guarded: a PowerShell session that has already defined these - the screenshot
# harness defines the same ones - cannot add them twice, and an unguarded
# Add-Type takes the whole script down with TYPE_ALREADY_EXISTS.
if (-not ('Win.Dpi' -as [type])) {
    Add-Type -Name Dpi -Namespace Win -MemberDefinition '
        [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
}
[void][Win.Dpi]::SetProcessDPIAware()
if (-not ('Preview' -as [type])) {
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class Preview {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr p);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public const uint WM_CLOSE = 0x0010;
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public class Win { public IntPtr H; public string Title; }
    public static List<Win> ForPid(uint pid) {
        var found = new List<Win>();
        EnumWindows((h, p) => {
            uint wp; GetWindowThreadProcessId(h, out wp);
            if (wp != pid || !IsWindowVisible(h)) return true;
            var sb = new StringBuilder(512); GetWindowTextW(h, sb, sb.Capacity);
            found.Add(new Win { H = h, Title = sb.ToString() });
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
"@
}

# Close any instance already running, and wait for it. Mixxx writes its config
# on a clean exit and nowhere else, so killing it loses every preference and
# skin option changed since it started - which looks exactly like the settings
# not persisting.
$running = Get-Process mixxx -ErrorAction SilentlyContinue
if ($running) {
    foreach ($proc0 in $running) {
        foreach ($w in [Preview]::ForPid([uint32]$proc0.Id)) {
            [void][Preview]::SendMessage($w.H, [Preview]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
        }
    }
    $deadline0 = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline0 -and (Get-Process mixxx -ErrorAction SilentlyContinue)) {
        Start-Sleep -Milliseconds 300
    }
    $stuck = Get-Process mixxx -ErrorAction SilentlyContinue
    if ($stuck) {
        Write-Output "warning: an instance would not close; its settings will not be saved"
        $stuck | ForEach-Object { try { $_.Kill() } catch {} }
        Start-Sleep -Seconds 1
    } else {
        Write-Output "closed the previous instance cleanly; its settings were saved"
    }
}

$env:QT_SCALE_FACTOR = "1"
$env:QT_ENABLE_HIGHDPI_SCALING = "0"

$mixxxArgs = @("--settings-path", "`"$SettingsPath`"", "--resource-path", "`"$resPathFwd`"")
foreach ($t in $Tracks) { $mixxxArgs += "`"$t`"" }
$proc = Start-Process -FilePath $Exe -PassThru -ArgumentList $mixxxArgs
Write-Output "launched pid $($proc.Id), settings $SettingsPath"

# A settings dir with no library root opens a folder picker before the skin ever
# appears; the menu-bar prompt arrives after the main window is already up.
$dismiss = @("Choose music library directory", "Allow Mixxx to hide the menu bar?")
$main = $null
$deadline = (Get-Date).AddSeconds(90)
while ((Get-Date) -lt $deadline) {
    if ($proc.HasExited) { throw "Mixxx exited with code $($proc.ExitCode)" }
    foreach ($w in [Preview]::ForPid([uint32]$proc.Id)) {
        if ($dismiss -contains $w.Title) {
            [void][Preview]::SendMessage($w.H, [Preview]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
            continue
        }
        $r = New-Object Preview+RECT
        [void][Preview]::GetWindowRect($w.H, [ref]$r)
        if (($r.Right - $r.Left) -gt 600) { $main = $w }
    }
    if ($main) { break }
    Start-Sleep -Milliseconds 400
}
if (-not $main) { throw "no Mixxx window appeared within 90s" }

# Let the skin finish laying out, then sweep for the late menu-bar prompt.
Start-Sleep -Seconds 3
foreach ($pass in 1..3) {
    foreach ($w in [Preview]::ForPid([uint32]$proc.Id)) {
        if ($dismiss -contains $w.Title) {
            [void][Preview]::SendMessage($w.H, [Preview]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
        }
    }
    Start-Sleep -Milliseconds 600
}

# Size by the client area. The frame is whatever Windows draws around it, which
# depends on the system DPI and is not something to guess at.
$wr = New-Object Preview+RECT; [void][Preview]::GetWindowRect($main.H, [ref]$wr)
$cr = New-Object Preview+RECT; [void][Preview]::GetClientRect($main.H, [ref]$cr)
$frameW = ($wr.Right - $wr.Left) - ($cr.Right - $cr.Left)
$frameH = ($wr.Bottom - $wr.Top) - ($cr.Bottom - $cr.Top)
[void][Preview]::MoveWindow($main.H, 0, 0, $Width + $frameW, $Height + $frameH, $true)
Start-Sleep -Milliseconds 500
[void][Preview]::GetClientRect($main.H, [ref]$cr)
[void][Preview]::SetForegroundWindow($main.H)

Write-Output "client area $($cr.Right - $cr.Left)x$($cr.Bottom - $cr.Top) (asked for ${Width}x${Height}), scheme $Scheme"
if (-not $ShowMenuBar) {
    Write-Output "menu bar hidden, so the skin has the whole client area - the same canvas it gets fullscreen on the panel"
}
Write-Output "Mixxx is running; close the window when you are done."
