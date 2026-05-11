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

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

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
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'Event Viewer Image Export',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-ErrorDialog {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'Event Viewer Image Export',
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

function Get-LevelText {
    param([int]$Id)
    if ($Id -in 6008,7004,7031) { return '오류' }
    if ($Id -in 10016,1014) { return '경고' }
    return '정보'
}

function Get-DisplaySource {
    param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)
    $source = $Event.ProviderName
    if ($source -eq 'Microsoft-Windows-Winlogon') { return 'Winlogon' }
    return $source
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

function Convert-EventToRow {
    param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)

    $description = $Event.FormatDescription()
    if ($null -eq $description) { $description = '' }

    [pscustomobject]@{
        Level      = Get-LevelText -Id $Event.Id
        Time       = $Event.TimeCreated
        Source     = Get-DisplaySource -Event $Event
        EventId    = $Event.Id
        Task       = if ($Event.TaskDisplayName) { $Event.TaskDisplayName } else { '없음' }
        Message    = $description -replace "`r?`n", ' '
        RawEvent   = $Event
    }
}

function Trim-Cell {
    param([string]$Text, [int]$Length)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    if ($Text.Length -le $Length) { return $Text }
    return $Text.Substring(0, [Math]::Max(0, $Length - 3)) + '...'
}

function Save-ViewerStyleImage {
    param(
        [System.Collections.IEnumerable]$Rows,
        [pscustomobject]$Selected,
        [string]$OutputPath,
        [datetime]$Start,
        [datetime]$End
    )

    $rows = @($Rows | Select-Object -First 14)
    $width = 1660
    $height = 960
    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.Clear([System.Drawing.Color]::White)

    $font = New-Object System.Drawing.Font('Malgun Gothic', 11)
    $smallFont = New-Object System.Drawing.Font('Malgun Gothic', 9)
    $titleFont = New-Object System.Drawing.Font('Malgun Gothic', 11, [System.Drawing.FontStyle]::Bold)
    $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(210,210,210))
    $darkBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(110,110,110))
    $selBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(228,228,228))
    $textBrush = [System.Drawing.Brushes]::Black

    $g.FillRectangle($darkBrush, 0, 0, $width, 24)
    $g.DrawString('시스템', $titleFont, [System.Drawing.Brushes]::White, 12, 2)
    $g.DrawString(('이벤트 수: ' + $rows.Count), $smallFont, [System.Drawing.Brushes]::White, 85, 4)

    $filterText = '필터링됨: 로그: System; 원본: 날짜 범위: {0}부터 {1}까지. 이벤트 수: {2}' -f `
        $Start.ToString('yyyy-MM-dd tt h:mm:ss'), $End.ToString('yyyy-MM-dd tt h:mm:ss'), $rows.Count
    $g.DrawString($filterText, $smallFont, $textBrush, 10, 31)

    $headerY = 54
    $g.DrawLine($linePen, 0, $headerY, $width, $headerY)
    $g.DrawString('수준', $font, $textBrush, 14, 59)
    $g.DrawString('날짜 및 시간', $font, $textBrush, 120, 59)
    $g.DrawString('원본', $font, $textBrush, 330, 59)
    $g.DrawString('이벤트 ID', $font, $textBrush, 785, 59)
    $g.DrawString('작업 범주', $font, $textBrush, 875, 59)

    $rowHeight = 27
    $selectedIndex = [Math]::Max(0, [Array]::IndexOf($rows, ($rows | Where-Object { $_.EventId -eq $Selected.EventId -and $_.Time -eq $Selected.Time } | Select-Object -First 1)))
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $y = 84 + ($i * $rowHeight)
        if ($i -eq $selectedIndex) {
            $g.FillRectangle($selBrush, 0, $y - 2, $width, $rowHeight)
        }
        $g.DrawLine($linePen, 0, $y + 23, $width, $y + 23)
        $g.DrawString($rows[$i].Level, $font, $textBrush, 14, $y)
        $g.DrawString($rows[$i].Time.ToString('yyyy-MM-dd tt h:mm:ss'), $font, $textBrush, 120, $y)
        $g.DrawString((Trim-Cell $rows[$i].Source 28), $font, $textBrush, 330, $y)
        $g.DrawString([string]$rows[$i].EventId, $font, $textBrush, 785, $y)
        $g.DrawString((Trim-Cell $rows[$i].Task 10), $font, $textBrush, 875, $y)
    }

    $detailTop = 480
    $g.DrawRectangle($linePen, 0, $detailTop, $width - 1, $height - $detailTop - 1)
    $g.DrawString(('이벤트 {0}, {1}' -f $Selected.EventId, $Selected.Source), $font, $textBrush, 10, $detailTop + 6)
    $g.DrawString('일반', $font, $textBrush, 16, $detailTop + 34)
    $g.DrawString('자세히', $font, $textBrush, 72, $detailTop + 34)
    $g.DrawRectangle($linePen, 24, $detailTop + 64, $width - 48, 360)

    $selectedDescription = $Selected.RawEvent.FormatDescription()
    if ($null -eq $selectedDescription) { $selectedDescription = '' }
    $msg = ($selectedDescription -replace "`r", '') -split "`n"
    $msgY = $detailTop + 78
    foreach ($line in $msg) {
        $clean = $line.Trim()
        if (-not [string]::IsNullOrWhiteSpace($clean)) {
            $g.DrawString($clean, $font, $textBrush, 36, $msgY)
            $msgY += 24
            if ($msgY -gt ($detailTop + 220)) { break }
        }
    }

    $infoY = $detailTop + 438
    $g.DrawString('로그 이름(M):', $font, $textBrush, 32, $infoY)
    $g.DrawString('시스템', $font, $textBrush, 168, $infoY)
    $g.DrawString('원본(S):', $font, $textBrush, 320, $infoY)
    $g.DrawString($Selected.Source, $font, $textBrush, 420, $infoY)

    $g.DrawString('이벤트 ID(E):', $font, $textBrush, 32, $infoY + 38)
    $g.DrawString([string]$Selected.EventId, $font, $textBrush, 168, $infoY + 38)
    $g.DrawString('로그된 날짜(D):', $font, $textBrush, 320, $infoY + 38)
    $g.DrawString($Selected.Time.ToString('yyyy-MM-dd tt h:mm:ss'), $font, $textBrush, 460, $infoY + 38)

    $g.DrawString('수준(L):', $font, $textBrush, 32, $infoY + 76)
    $g.DrawString($Selected.Level, $font, $textBrush, 168, $infoY + 76)
    $g.DrawString('컴퓨터(R):', $font, $textBrush, 320, $infoY + 76)
    $g.DrawString($Selected.RawEvent.MachineName, $font, $textBrush, 460, $infoY + 76)

    $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    $font.Dispose()
    $smallFont.Dispose()
    $titleFont.Dispose()
    $linePen.Dispose()
    $darkBrush.Dispose()
    $selBrush.Dispose()
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

    $rows = @($allEvents | Select-Object -First 14 | ForEach-Object { Convert-EventToRow -Event $_ })
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

        $selectedRow = Convert-EventToRow -Event $selectedEvent[0]
        if (-not ($rows | Where-Object { $_.EventId -eq $selectedRow.EventId -and $_.Time -eq $selectedRow.Time })) {
            $rows = @($selectedRow) + @($rows | Select-Object -First 13)
        }

        $stem = New-FileStem -Start $StartTime -End $EndTime -Suffix $modeName
        $pngPath = Join-Path $OutputDir ($stem + '.png')
        Save-ViewerStyleImage -Rows $rows -Selected $selectedRow -OutputPath $pngPath -Start $StartTime -End $EndTime
        $saved.Add($pngPath) | Out-Null
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
