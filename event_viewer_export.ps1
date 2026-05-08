[CmdletBinding()]
param(
    [datetime]$StartTime,

    [datetime]$EndTime,

    [ValidateSet('Logon', 'Logoff', 'Both')]
    [string]$Mode = 'Both',

    [string]$OutputDir = 'C:\codex_artifacts',

    [int]$LaunchDelayMs = 5000,

    [switch]$KeepExportedLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$signature = @'
using System;
using System.Runtime.InteropServices;

public static class NativeMethods
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int nWidth, int nHeight, bool bRepaint);
}
'@

Add-Type -TypeDefinition $signature

$targetMap = @{
    Logon  = 7001
    Logoff = 7002
}

function Show-InputForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Event Viewer Image Export'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(440, 260)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.Font = New-Object System.Drawing.Font('Malgun Gothic', 10)

    $label1 = New-Object System.Windows.Forms.Label
    $label1.Location = New-Object System.Drawing.Point(20, 20)
    $label1.Size = New-Object System.Drawing.Size(120, 24)
    $label1.Text = 'StartTime'
    $form.Controls.Add($label1)

    $tbStart = New-Object System.Windows.Forms.TextBox
    $tbStart.Location = New-Object System.Drawing.Point(150, 18)
    $tbStart.Size = New-Object System.Drawing.Size(240, 24)
    $tbStart.Text = (Get-Date).Date.ToString('yyyy-MM-dd 00:00:00')
    $form.Controls.Add($tbStart)

    $label2 = New-Object System.Windows.Forms.Label
    $label2.Location = New-Object System.Drawing.Point(20, 60)
    $label2.Size = New-Object System.Drawing.Size(120, 24)
    $label2.Text = 'EndTime'
    $form.Controls.Add($label2)

    $tbEnd = New-Object System.Windows.Forms.TextBox
    $tbEnd.Location = New-Object System.Drawing.Point(150, 58)
    $tbEnd.Size = New-Object System.Drawing.Size(240, 24)
    $tbEnd.Text = (Get-Date).Date.AddDays(1).AddSeconds(-1).ToString('yyyy-MM-dd HH:mm:ss')
    $form.Controls.Add($tbEnd)

    $label3 = New-Object System.Windows.Forms.Label
    $label3.Location = New-Object System.Drawing.Point(20, 100)
    $label3.Size = New-Object System.Drawing.Size(120, 24)
    $label3.Text = 'Mode'
    $form.Controls.Add($label3)

    $comboMode = New-Object System.Windows.Forms.ComboBox
    $comboMode.Location = New-Object System.Drawing.Point(150, 98)
    $comboMode.Size = New-Object System.Drawing.Size(140, 24)
    $comboMode.DropDownStyle = 'DropDownList'
    [void]$comboMode.Items.AddRange(@('Logoff', 'Logon', 'Both'))
    $comboMode.SelectedIndex = 0
    $form.Controls.Add($comboMode)

    $help = New-Object System.Windows.Forms.Label
    $help.Location = New-Object System.Drawing.Point(20, 135)
    $help.Size = New-Object System.Drawing.Size(390, 36)
    $help.Text = 'Time format: yyyy-MM-dd HH:mm:ss'
    $form.Controls.Add($help)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(220, 175)
    $okButton.Size = New-Object System.Drawing.Size(80, 30)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(310, 175)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)

    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    while ($true) {
        $result = $form.ShowDialog()
        if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
            throw 'Cancelled by user.'
        }

        try {
            $parsedStart = [datetime]::Parse($tbStart.Text)
            $parsedEnd = [datetime]::Parse($tbEnd.Text)
            return [pscustomobject]@{
                StartTime = $parsedStart
                EndTime   = $parsedEnd
                Mode      = [string]$comboMode.SelectedItem
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                'StartTime / EndTime format is invalid. Use yyyy-MM-dd HH:mm:ss',
                'Invalid Input',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
    }
}

function Show-Info {
    param(
        [string]$Message,
        [string]$Title = 'Event Viewer Image Export'
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-ErrorDialog {
    param(
        [string]$Message,
        [string]$Title = 'Event Viewer Image Export'
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

if (-not $PSBoundParameters.ContainsKey('StartTime') -or -not $PSBoundParameters.ContainsKey('EndTime')) {
    $inputValues = Show-InputForm
    $StartTime = $inputValues.StartTime
    $EndTime = $inputValues.EndTime
    if (-not $PSBoundParameters.ContainsKey('Mode')) {
        $Mode = $inputValues.Mode
    }
}

if ($EndTime -le $StartTime) {
    throw 'EndTime must be later than StartTime.'
}

function New-FileStem {
    param(
        [datetime]$Start,
        [datetime]$End,
        [string]$Suffix
    )

    if ($Start.Date -eq $End.Date) {
        return '{0}_{1}' -f $Start.ToString('yyyy-MM-dd'), $Suffix.ToLowerInvariant()
    }

    return '{0}_to_{1}_{2}' -f $Start.ToString('yyyy-MM-dd_HHmmss'), $End.ToString('yyyy-MM-dd_HHmmss'), $Suffix.ToLowerInvariant()
}

function Get-FilteredEvents {
    param(
        [datetime]$Start,
        [datetime]$End,
        [int]$TargetId
    )

    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = $TargetId; ProviderName = 'Microsoft-Windows-Winlogon' } |
        Where-Object { $_.TimeCreated -ge $Start -and $_.TimeCreated -le $End } |
        Sort-Object TimeCreated -Descending
}

function Export-WindowEvents {
    param(
        [datetime]$Start,
        [datetime]$End,
        [string]$Path,
        [int]$TargetId
    )

    $startUtc = $Start.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $endUtc = $End.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $query = "*[System[Provider[@Name='Microsoft-Windows-Winlogon'] and (EventID=$TargetId) and TimeCreated[@SystemTime>='$startUtc' and @SystemTime<='$endUtc']]]"

    $null = & wevtutil epl System $Path /q:$query
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Failed to export filtered log to $Path"
    }
}

function Wait-EventViewerWindow {
    param(
        [int[]]$ExistingIds,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $window = Get-Process mmc,eventvwr -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 -and $_.Id -notin $ExistingIds } |
            Sort-Object StartTime -Descending |
            Select-Object -First 1

        if ($window) {
            return $window
        }

        Start-Sleep -Milliseconds 500
    }

    throw 'Timed out waiting for the Event Viewer window.'
}

function Test-InteractiveDesktop {
    return [System.Environment]::UserInteractive
}

function Save-WindowScreenshot {
    param(
        [IntPtr]$WindowHandle,
        [string]$OutputPath
    )

    $rect = New-Object NativeMethods+RECT
    $ok = [NativeMethods]::GetWindowRect($WindowHandle, [ref]$rect)
    if (-not $ok) {
        throw 'Unable to read Event Viewer window bounds.'
    }

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) {
        throw 'Invalid Event Viewer window size.'
    }

    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
    $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

try {
    if (-not (Test-InteractiveDesktop)) {
        throw 'This tool must run in an interactive Windows desktop session.'
    }

    $modesToRender = if ($Mode -eq 'Both') { @('Logon', 'Logoff') } else { @($Mode) }
    $saved = New-Object System.Collections.Generic.List[string]
    $missing = New-Object System.Collections.Generic.List[string]

    foreach ($modeName in $modesToRender) {
        $targetId = $targetMap[$modeName]
        $targetEvents = @(Get-FilteredEvents -Start $StartTime -End $EndTime -TargetId $targetId)
        $selected = @($targetEvents | Select-Object -First 1)

        if (-not $selected) {
            $missing.Add("$modeName(ID $targetId)") | Out-Null
            continue
        }

        $stem = New-FileStem -Start $StartTime -End $EndTime -Suffix $modeName
        $evtxPath = Join-Path $OutputDir ($stem + '.evtx')
        $pngPath = Join-Path $OutputDir ($stem + '.png')

        Export-WindowEvents -Start $StartTime -End $EndTime -Path $evtxPath -TargetId $targetId

        $beforeIds = @(Get-Process mmc,eventvwr -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
        Start-Process -FilePath eventvwr.exe -ArgumentList "/l:`"$evtxPath`"" | Out-Null

        Start-Sleep -Milliseconds $LaunchDelayMs
        $windowProc = Wait-EventViewerWindow -ExistingIds $beforeIds

        [NativeMethods]::ShowWindowAsync($windowProc.MainWindowHandle, 5) | Out-Null
        Start-Sleep -Milliseconds 300
        [NativeMethods]::MoveWindow($windowProc.MainWindowHandle, 20, 20, 1600, 980, $true) | Out-Null
        Start-Sleep -Milliseconds 500
        [NativeMethods]::SetForegroundWindow($windowProc.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 1500

        Save-WindowScreenshot -WindowHandle $windowProc.MainWindowHandle -OutputPath $pngPath
        $saved.Add($pngPath) | Out-Null

        try {
            $windowProc.CloseMainWindow() | Out-Null
            Start-Sleep -Milliseconds 500
            if (-not $windowProc.HasExited) {
                $windowProc | Stop-Process -Force
            }
        } catch {
        }

        if (-not $KeepExportedLog) {
            Remove-Item -LiteralPath $evtxPath -ErrorAction SilentlyContinue
        }
    }

    if ($saved.Count -eq 0) {
        throw 'No output file was created because no matching Winlogon event was found in the requested time range.'
    }

    $summary = "Saved PNG file(s):`r`n" + ($saved -join "`r`n")
    if ($missing.Count -gt 0) {
        $summary += "`r`n`r`nNot found:`r`n" + ($missing -join "`r`n")
    }
    Write-Output $saved
    Show-Info -Message $summary
} catch {
    Show-ErrorDialog -Message $_.Exception.Message
    throw
}
