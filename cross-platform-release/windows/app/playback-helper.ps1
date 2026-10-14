# Target player continuous playback helper for Windows. Run: double-click Start.cmd.
# Uses Windows UI Automation (System.Windows.Automation) through the built-in
# Windows PowerShell 5.1 and .NET Framework. No screen coordinates, no third-party libraries.
#
# STATUS: Unconfigured template. Replace target identifiers and labels before use.

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- configuration
$MaxMinutes   = 120      # Maximum runtime in minutes, including pauses and waiting.
$MaxNextCount = 50       # Maximum number of automatic chapter transitions.
$PollSeconds  = 2        # Polling interval in seconds.
$NodeLimit    = 6000     # Maximum UI elements read per pass.

# ASSUMPTION: process names of the Windows client. Not verified; -Inspect lists
# candidate windows so the correct name can be added here or passed via -ProcessName.
$ProcessNames = @('CONFIGURE_PROCESS_NAME')
# Window title fragment used as a fallback to find the client ("Target player").
$TitleHint = 'CONFIGURE_WINDOW_TITLE'

# Accessibility labels for the configured target application.
# Replace placeholder labels with values verified for your target application.
$LabelPage    = 'CONFIGURE_PAGE_LABEL'   # "Student learning page" (web document)
$LabelPlayer  = 'CONFIGURE_PLAYER_LABEL'     # "Video player"
$LabelDetails = 'CONFIGURE_DETAILS_LABEL'       # "Chapter details" heading, followed by the chapter title
$LabelPlay    = 'CONFIGURE_PLAY_LABEL'           # "Play"
$LabelPause   = 'CONFIGURE_PAUSE_LABEL'           # "Pause"
$LabelReplay  = 'CONFIGURE_REPLAY_LABEL'           # "Replay" (shown when playback has ended)
$LabelNext    = 'CONFIGURE_NEXT_LABEL'         # "Next chapter"

# ---------------------------------------------------------------- arguments
$CliArgs = @($args)
# Returns the value after option $i as a positive number, or exits with a clear message.
function Get-PositiveNumber([int]$i, [string]$option) {
    $text = if ($i -lt $CliArgs.Count) { [string]$CliArgs[$i] } else { '' }
    $value = 0.0
    if (-not [double]::TryParse($text, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or $value -le 0) {
        Write-Host "Option $option needs a positive number (got '$text'). Use -Help for usage."; exit 2
    }
    return $value
}
$Inspect = $false
$Help = $false
for ($i = 0; $i -lt $CliArgs.Count; $i++) {
    switch -Regex ($CliArgs[$i]) {
        '^(-|--)inspect$'       { $Inspect = $true }
        '^(-|--)(help|\?)$|^/\?$' { $Help = $true }
        '^(-|--)maxminutes$'    { $i++; $MaxMinutes = Get-PositiveNumber $i '-MaxMinutes' }
        '^(-|--)maxnextcount$'  { $i++; $MaxNextCount = [int][math]::Max(1, [math]::Floor((Get-PositiveNumber $i '-MaxNextCount'))) }
        '^(-|--)pollseconds$'   { $i++; $PollSeconds = Get-PositiveNumber $i '-PollSeconds' }
        '^(-|--)processname$'   {
            $i++
            if ($i -ge $CliArgs.Count -or -not [string]$CliArgs[$i]) { Write-Host 'Option -ProcessName needs a name. Use -Help for usage.'; exit 2 }
            $ProcessNames = @(([string]$CliArgs[$i]) -replace '\.exe$', '') + $ProcessNames
        }
        default { Write-Host "Unknown option: $($CliArgs[$i]). Use -Help for usage."; exit 2 }
    }
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if ($Help) {
    @"
Usage: Start.cmd [-Inspect] [-MaxMinutes N] [-MaxNextCount N] [-PollSeconds N] [-ProcessName NAME]
  -Inspect       Print the controls Target player exposes, without clicking anything.
  -MaxMinutes    Maximum runtime in minutes (default $MaxMinutes).
  -MaxNextCount  Maximum automatic chapter transitions (default $MaxNextCount).
  -PollSeconds   Polling interval in seconds (default $PollSeconds).
  -ProcessName   Target player process name, without .exe, if it is not detected automatically.
While running, press these keys in this console window:
  p = pause automation, r = resume, q = quit. Ctrl+C stops immediately.
"@ | Write-Host
    exit 0
}

if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    Write-Host 'ERROR: The Windows helper requires a Windows operating system.'
    Write-Host ("Detected OS: {0}; PowerShell: {1}" -f [Environment]::OSVersion.VersionString, $PSVersionTable.PSVersion)
    Write-Host 'PowerShell on macOS or Linux cannot provide Windows UI Automation.'
    Write-Host 'Installing PowerShell does not install Windows or make this helper compatible with macOS.'
    Write-Host 'To test the Windows helper, run Start.cmd -Inspect on a Windows PC or in a Windows VM.'
    Write-Host 'On a Mac, use the macOS helper instead.'
    Write-Host 'No application controls were inspected or clicked.'
    exit 1
}

$targetConfiguration = @($ProcessNames) + @($TitleHint, $LabelPage, $LabelPlayer, $LabelDetails, $LabelPlay, $LabelPause, $LabelReplay, $LabelNext)
if (@($targetConfiguration | Where-Object { $_ -like 'CONFIGURE_*' }).Count -gt 0) {
    Write-Host 'No target is configured. Set the process name, window title, and control labels in the script before use.'
    Write-Host 'No application controls were inspected or clicked.'
    exit 2
}

try {
    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
} catch {
    Write-Host 'ERROR: Windows UI Automation (UIAutomationClient) could not be loaded.'
    Write-Host 'Use Windows PowerShell 5.1 (included with Windows 10/11) and .NET Framework 4.x.'
    exit 1
}
Add-Type -Namespace PlaybackHelperNative -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint pid);
'@

$UIA = [System.Windows.Automation.AutomationElement]
$CT  = [System.Windows.Automation.ControlType]

function Log([string]$message) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $message)
}

# ---------------------------------------------------------------- app discovery
# Returns all processes belonging to the Target player client (multi-process apps
# such as Electron/CEF clients have several), or an empty array.
function Get-AppProcesses {
    $all = @(Get-Process -ErrorAction SilentlyContinue)
    $byName = @($all | Where-Object { $ProcessNames -contains $_.ProcessName })
    if ($byName.Count -gt 0) { return $byName }
    $byTitle = @($all | Where-Object { $_.MainWindowTitle -like "*$TitleHint*" })
    if ($byTitle.Count -gt 0) {
        $names = @($byTitle | ForEach-Object { $_.ProcessName } | Select-Object -Unique)
        return @($all | Where-Object { $names -contains $_.ProcessName })
    }
    return @()
}

function Test-AppForeground($procs) {
    $hwnd = [PlaybackHelperNative.Native]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) { return $false }
    [uint32]$fgPid = 0
    [void][PlaybackHelperNative.Native]::GetWindowThreadProcessId($hwnd, [ref]$fgPid)
    return [bool]($procs | Where-Object { $_.Id -eq $fgPid })
}

# Top-level UI Automation windows owned by the app processes.
function Get-AppWindows($procs) {
    $windows = @()
    foreach ($p in $procs) {
        $cond = New-Object System.Windows.Automation.PropertyCondition($UIA::ProcessIdProperty, $p.Id)
        $found = $UIA::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
        foreach ($w in $found) { $windows += $w }
    }
    return $windows
}

# ---------------------------------------------------------------- tree reading
# One cached FindAll per subtree keeps cross-process calls low. Results are in
# document (pre-order) order, so the element after the "Chapter details" text is the title.
$cache = New-Object System.Windows.Automation.CacheRequest
$cache.Add($UIA::NameProperty)
$cache.Add($UIA::ControlTypeProperty)
$cache.Add($UIA::HelpTextProperty)
$cache.Add($UIA::IsEnabledProperty)
$cache.Add([System.Windows.Automation.ValuePattern]::ValueProperty)

function New-Node($el) {
    $labels = @()
    foreach ($prop in @($UIA::NameProperty, $UIA::HelpTextProperty, [System.Windows.Automation.ValuePattern]::ValueProperty)) {
        $v = $el.GetCachedPropertyValue($prop, $true)
        if ($v -is [string] -and $v.Trim()) { $labels += $v.Trim() }
    }
    $type = $el.GetCachedPropertyValue($UIA::ControlTypeProperty)
    [pscustomobject]@{ Element = $el; Type = $type; Labels = $labels }
}

function Test-Named($node, [string]$name) { return ($node.Labels -contains $name) }

function Get-Nodes($root) {
    $result = New-Object System.Collections.Generic.List[object]
    $scope = [System.Windows.Automation.TreeScope]::Element -bor [System.Windows.Automation.TreeScope]::Descendants
    $cache.Push()
    try {
        $items = $root.FindAll($scope, [System.Windows.Automation.Condition]::TrueCondition)
    } finally { $cache.Pop() }
    if ($items.Count -gt $NodeLimit) { throw 'incomplete: too many elements' }
    foreach ($el in $items) { $result.Add((New-Node $el)) }
    return $result
}

# Invoke only through the control's own InvokePattern; failures go to the user.
function Invoke-Control($node) {
    try {
        if (-not $node.Element.Current.IsEnabled) { return $false }
        $pattern = $null
        if (-not $node.Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) { return $false }
        $pattern.Invoke()
        return $true
    } catch { return $false }
}

# Non-blocking key read: p / r / q.
function Read-Command {
    try {
        if ([Console]::KeyAvailable) { return ([string][Console]::ReadKey($true).KeyChar).ToLower() }
    } catch { }
    return $null
}

function Format-Node($node) {
    $name = $node.Type.ProgrammaticName -replace '^ControlType\.', ''
    return "{0}: {1}" -f $name, (($node.Labels | Select-Object -Unique | Sort-Object) -join ' | ')
}

# ASSUMPTION: Chromium-based web content appears as a Document named after the page title.
# UI Automation filters by name in the target process, which is much faster than reading
# every element. A Pane with the same name is used only when no Document matches, so a
# host pane and its document are not counted as two pages.
function Find-Pages($windows) {
    $byName = New-Object System.Windows.Automation.PropertyCondition($UIA::NameProperty, $LabelPage)
    $found = @()
    foreach ($w in $windows) {
        $cache.Push()
        try { $items = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, $byName) } finally { $cache.Pop() }
        foreach ($el in $items) { $found += (New-Node $el) }
    }
    $documents = @($found | Where-Object { $_.Type -eq $CT::Document })
    if ($documents.Count -gt 0) { return $documents }
    return @($found | Where-Object { $_.Type -eq $CT::Pane })
}

# ---------------------------------------------------------------- inspect mode
if ($Inspect) {
    $procs = Get-AppProcesses
    if ($procs.Count -eq 0) {
        Log 'Target player was not found. Windows with titles currently open:'
        Get-Process | Where-Object { $_.MainWindowTitle } |
            ForEach-Object { Write-Host ("  process={0}  title={1}" -f $_.ProcessName, $_.MainWindowTitle) }
        Write-Host 'If Target player is listed, rerun with: Start.cmd -Inspect -ProcessName <process>'
        exit 1
    }
    Log ("Process: {0} (PIDs {1})" -f $procs[0].ProcessName, (($procs | ForEach-Object Id) -join ', '))
    $windows = @(Get-AppWindows $procs)
    if ($windows.Count -eq 0) { Log 'No UI Automation windows found for this process.'; exit 1 }
    try {
        $pages = @(Find-Pages $windows)
        if ($pages.Count -eq 1) {
            Log "Found one '$LabelPage' element. Its labeled controls:"
            foreach ($n in (Get-Nodes $pages[0].Element)) { if ($n.Labels.Count) { Write-Host (Format-Node $n) } }
        } else {
            Log "Found $($pages.Count) '$LabelPage' elements. Printing all labeled controls of the app windows:"
            foreach ($w in $windows) { foreach ($n in (Get-Nodes $w)) { if ($n.Labels.Count) { Write-Host (Format-Node $n) } } }
        }
    } catch {
        Log "Interface reading was incomplete: $($_.Exception.Message)"; exit 1
    }
    Write-Host 'Inspection output can contain course titles. Review it before sharing.'
    exit 0
}

# ---------------------------------------------------------------- main loop
Log 'Open the desired video chapter in Target player and keep Target player in the foreground.'
Log 'Press p to pause automation, r to resume, q to quit (in this window). Ctrl+C stops the script.'

$script:paused = $false
$script:lastMessage = ''
function Status([string]$message) {
    if ($message -ne $script:lastMessage) { Log $message; $script:lastMessage = $message }
}
function Hold([string]$reason) {
    $script:paused = $true
    Log ($reason + '. After resolving this, press r in this window, then return to Target player.')
}
function Wait([double]$s) { Start-Sleep -Milliseconds ([int]($s * 1000)) }

$started = Get-Date
$nextCount = 0
$waitingForChapter = $null
$nextClickedAt = [datetime]::MinValue
$lastPlayAt = [datetime]::MinValue
$unknownSince = $null
$endedSince = $null
$lastChapter = ''
function Since($t) { return ((Get-Date) - $t).TotalSeconds }

while ((Since $started) -lt $MaxMinutes * 60) {
    $input_ = Read-Command
    if ($input_ -eq 'q') { break }
    if ($input_ -eq 'p') { $script:paused = $true; Log 'Automation paused. Any currently playing video continues playing.' }
    if ($input_ -eq 'r') {
        $script:paused = $false; $unknownSince = $null; $endedSince = $null
        Log 'Automation resumed. Return to Target player.'
    }
    if ($script:paused) { Wait 0.3; continue }

    $procs = @(Get-AppProcesses)
    if ($procs.Count -eq 0) { Status 'Waiting for Target player to start...'; Wait $PollSeconds; continue }
    # Stop clicking while another application is active.
    if (-not (Test-AppForeground $procs)) {
        Status 'Waiting for Target player to return to the foreground...'; Wait 0.5; continue
    }

    try {
        $pages = @(Find-Pages @(Get-AppWindows $procs))
        if ($pages.Count -ne 1) {
            Status "Open exactly one student learning page; detected $($pages.Count). (Run -Inspect if this persists.)"
            Wait $PollSeconds; continue
        }
        $page = Get-Nodes $pages[0].Element
        $players = @($page | Where-Object { Test-Named $_ $LabelPlayer })
        $headings = @($page | Where-Object { $_.Type -eq $CT::Text -and $_.Labels.Count } | ForEach-Object { $_.Labels[0] })
        $index = [array]::IndexOf($headings, $LabelDetails)
        if ($index -lt 0 -or $index + 1 -ge $headings.Count) {
            # The page may still be loading after a transition; hold only if this persists.
            if ($null -eq $unknownSince) { $unknownSince = Get-Date }
            if ((Since $unknownSince) -gt 20) { Hold 'Cannot identify the chapter title' }
            Wait $PollSeconds; continue
        }
        $chapter = $headings[$index + 1]
        if ($chapter -cne $lastChapter) {
            Log "Current chapter: $chapter"
            $lastChapter = $chapter; $endedSince = $null; $unknownSince = $null
            $lastPlayAt = [datetime]::MinValue
        }
        # Confirm the chapter title changed after clicking Next, then wait for the player.
        if ($null -ne $waitingForChapter) {
            if ($chapter -cne $waitingForChapter) {
                $waitingForChapter = $null; Wait 3
            } elseif ((Since $nextClickedAt) -gt 20) {
                Hold 'The chapter did not change or the course has ended; check manually'
                $waitingForChapter = $null
            } else { Wait $PollSeconds }
            continue
        }
        # Multiple videos, text pages, and quizzes require manual selection.
        if ($players.Count -ne 1) {
            if ($null -eq $unknownSince) { $unknownSince = Get-Date }
            if ((Since $unknownSince) -gt 20) { Hold 'This chapter has no unique recognized player; open a video chapter manually' }
            Wait $PollSeconds; continue
        }
        $buttons = @(Get-Nodes $players[0].Element | Where-Object { $_.Type -eq $CT::Button })
        $replay = @($buttons | Where-Object { Test-Named $_ $LabelReplay })
        $play   = @($buttons | Where-Object { Test-Named $_ $LabelPlay })
        $pause  = @($buttons | Where-Object { Test-Named $_ $LabelPause })

        # A Replay control signals playback ended; observe it for 4 seconds before advancing.
        if ($replay.Count -eq 1 -and $pause.Count -eq 0 -and $play.Count -eq 0) {
            $unknownSince = $null
            if ($null -eq $endedSince) { $endedSince = Get-Date }
            if ((Since $endedSince) -ge 4) {
                if ($nextCount -ge $MaxNextCount) { Log 'Chapter transition limit reached. Exiting.'; break }
                $next = @($page | Where-Object { $_.Type -eq $CT::Button -and (Test-Named $_ $LabelNext) })
                if (-not (Test-AppForeground $procs)) { continue }  # Left the foreground; wait for it.
                if ($next.Count -ne 1) { Hold 'Cannot identify a unique Next Chapter button'; continue }
                # Record the attempt before clicking to avoid duplicate transitions after a timeout.
                $waitingForChapter = $chapter; $nextClickedAt = Get-Date; $endedSince = $null
                if (Invoke-Control $next[0]) {
                    $nextCount++; Log "Video ended. Moving to the next chapter (transition $nextCount)."
                } else { Hold 'The Next Chapter click result is uncertain; inspect the interface' }
            }
        } elseif ($pause.Count -eq 1) {
            $unknownSince = $null; $endedSince = $null
            Status "Playing: $chapter"
        } elseif ($play.Count -eq 1 -and $replay.Count -eq 0) {
            $endedSince = $null; $unknownSince = $null
            # Start each chapter once; later pauses may require user interaction.
            if ($lastPlayAt -eq [datetime]::MinValue) {
                if (-not (Test-AppForeground $procs)) { continue }  # Left the foreground; wait for it.
                $lastPlayAt = Get-Date
                if (Invoke-Control $play[0]) { Log 'Clicked Play.' }
                else { Hold 'Could not click Play' }
            } elseif ((Since $lastPlayAt) -gt 15) {
                Hold 'Video did not start or was paused; check the player and any dialogs'
            }
        } else {
            $endedSince = $null
            if ($null -eq $unknownSince) { $unknownSince = Get-Date }
            if ((Since $unknownSince) -gt 20) { Hold 'Cannot recognize the player state' }
        }
    } catch {
        Hold "Interface reading was incomplete or timed out ($($_.Exception.Message))"
    }
    Wait $PollSeconds
}
Log 'Script stopped. Target player and the current video remain in their existing state.'
