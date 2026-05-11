[CmdletBinding()]
param(
    [datetime]$StartTime,

    [datetime]$EndTime,

    [ValidateSet('Logon', 'Logoff', 'Both')]
    [string]$Mode = 'Both',

    [string]$OutputDir = 'C:\codex_artifacts'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms

$targetMap = @{
    Logon  = 7001
    Logoff = 7002
}

function Show-InputForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Event Viewer Export'
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
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'Event Viewer Export',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-ErrorDialog {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'Event Viewer Export',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
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

function Build-Query {
    param(
        [datetime]$Start,
        [datetime]$End
    )

    $startUtc = $Start.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $endUtc = $End.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    return "*[System[TimeCreated[@SystemTime>='$startUtc' and @SystemTime<='$endUtc']]]"
}

function Export-RangeLog {
    param(
        [datetime]$Start,
        [datetime]$End,
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }

    $query = Build-Query -Start $Start -End $End
    $null = & wevtutil epl System $Path /q:$query
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Failed to export filtered log to $Path"
    }
}

function Get-EventsForRange {
    param(
        [datetime]$Start,
        [datetime]$End
    )

    Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $Start; EndTime = $End } |
        Sort-Object TimeCreated -Descending
}

function Get-TargetEvent {
    param(
        [System.Collections.IEnumerable]$Events,
        [int]$TargetId
    )

    @($Events | Where-Object { $_.Id -eq $TargetId -and $_.ProviderName -eq 'Microsoft-Windows-Winlogon' } | Select-Object -First 1)
}

function New-InternetShortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath
    )

    $url = "file:///" + ($TargetPath -replace '\\', '/')
    @"
[InternetShortcut]
URL=$url
IconFile=$env:SystemRoot\System32\shell32.dll
IconIndex=220
"@ | Set-Content -LiteralPath $ShortcutPath -Encoding ASCII
}

function Save-GuideFile {
    param(
        [string]$GuidePath,
        [string]$EvtxPath,
        [string]$ShortcutPath,
        [psobject]$TargetEvent,
        [string]$ModeName,
        [datetime]$Start,
        [datetime]$End
    )

    $message = $TargetEvent.FormatDescription()
    if ($null -eq $message) { $message = '' }
    $message = $message -replace "`r?`n", [Environment]::NewLine

    $lines = @(
        'Event Viewer manual-open guide',
        '',
        ('Mode: ' + $ModeName),
        ('Range: ' + $Start.ToString('yyyy-MM-dd HH:mm:ss') + ' ~ ' + $End.ToString('yyyy-MM-dd HH:mm:ss')),
        '',
        '1. Double-click the shortcut below:',
        $ShortcutPath,
        '',
        '2. If the shortcut does not open, double-click this EVTX file directly:',
        $EvtxPath,
        '',
        '3. In Event Viewer, click this target event:',
        ('- Source: Winlogon'),
        ('- Event ID: ' + $TargetEvent.Id),
        ('- Logged: ' + $TargetEvent.TimeCreated.ToString('yyyy-MM-dd tt h:mm:ss')),
        '',
        '4. Check the "General" tab message:',
        $message
    )

    $lines | Set-Content -LiteralPath $GuidePath -Encoding UTF8
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

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

try {
    $allEvents = @(Get-EventsForRange -Start $StartTime -End $EndTime)
    if ($allEvents.Count -eq 0) {
        throw 'No System log events were found in the requested time range.'
    }

    $modesToRender = if ($Mode -eq 'Both') { @('Logon', 'Logoff') } else { @($Mode) }
    $saved = New-Object System.Collections.Generic.List[string]
    $missing = New-Object System.Collections.Generic.List[string]

    foreach ($modeName in $modesToRender) {
        $targetId = $targetMap[$modeName]
        $selectedEvent = @(Get-TargetEvent -Events $allEvents -TargetId $targetId)
        if (-not $selectedEvent) {
            $missing.Add("$modeName(ID $targetId)") | Out-Null
            continue
        }

        $stem = New-FileStem -Start $StartTime -End $EndTime -Suffix $modeName
        $evtxPath = Join-Path $OutputDir ($stem + '.evtx')
        $shortcutPath = Join-Path $OutputDir ($stem + '_open_event_viewer.url')
        $guidePath = Join-Path $OutputDir ($stem + '_guide.txt')

        Export-RangeLog -Start $StartTime -End $EndTime -Path $evtxPath
        New-InternetShortcut -ShortcutPath $shortcutPath -TargetPath $evtxPath
        Save-GuideFile -GuidePath $guidePath -EvtxPath $evtxPath -ShortcutPath $shortcutPath -TargetEvent $selectedEvent[0] -ModeName $modeName -Start $StartTime -End $EndTime

        $saved.Add($evtxPath) | Out-Null
        $saved.Add($shortcutPath) | Out-Null
        $saved.Add($guidePath) | Out-Null
    }

    if ($saved.Count -eq 0) {
        throw 'No output file was created because no matching Winlogon event was found in the requested time range.'
    }

    $summary = "Created file(s):`r`n" + ($saved -join "`r`n")
    if ($missing.Count -gt 0) {
        $summary += "`r`n`r`nNot found:`r`n" + ($missing -join "`r`n")
    }
    $summary += "`r`n`r`nNext: double-click the .url file or the .evtx file to open Event Viewer manually."
    Write-Output $saved
    Show-Info -Message $summary
} catch {
    Show-ErrorDialog -Message $_.Exception.Message
    throw
}
