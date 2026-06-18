param(
    [double]$RefreshRate = 2,
    [int]$ProcessLimit = 30,
    [ValidateSet('cpu', 'mem', 'pid', 'name')]
    [string]$SortBy = 'cpu',
    [switch]$Once
)

function Install-WinTopCommand {
    if ($env:WINTOP_SKIP_INSTALL -eq '1') {
        return
    }

    $sourcePath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($sourcePath) -or -not (Test-Path -LiteralPath $sourcePath)) {
        return
    }

    $installRoot = Join-Path $env:LOCALAPPDATA 'Programs\WinTop'
    $installedScript = Join-Path $installRoot 'top.ps1'
    $shimPath = Join-Path $installRoot 'top.cmd'
    $sourceFullPath = [System.IO.Path]::GetFullPath($sourcePath)
    $installedFullPath = [System.IO.Path]::GetFullPath($installedScript)
    $pathSeparator = [System.IO.Path]::PathSeparator
    $currentUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $processPath = [Environment]::GetEnvironmentVariable('Path', 'Process')
    $userPathParts = @($currentUserPath -split [regex]::Escape([string]$pathSeparator) | Where-Object { $_ })
    $processPathParts = @($processPath -split [regex]::Escape([string]$pathSeparator) | Where-Object { $_ })
    $hasUserPath = $userPathParts | Where-Object { $_.TrimEnd('\') -ieq $installRoot.TrimEnd('\') }
    $hasProcessPath = $processPathParts | Where-Object { $_.TrimEnd('\') -ieq $installRoot.TrimEnd('\') }
    $needsCopy = -not (Test-Path -LiteralPath $installedScript)
    if (-not $needsCopy -and $sourceFullPath -ine $installedFullPath) {
        try {
            $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFullPath).Hash
            $installedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $installedFullPath).Hash
            $needsCopy = $sourceHash -ne $installedHash
        } catch {
            $needsCopy = $true
        }
    }
    $needsShim = -not (Test-Path -LiteralPath $shimPath)
    $needsPath = -not $hasUserPath

    if (-not ($needsCopy -or $needsShim -or $needsPath)) {
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $installRoot)) {
            New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
        }

        if ($needsCopy) {
            Copy-Item -LiteralPath $sourcePath -Destination $installedScript -Force
        }

        $shimContent = @'
@echo off
where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0top.ps1" %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0top.ps1" %*
)
'@
        Set-Content -LiteralPath $shimPath -Value $shimContent -Encoding ASCII

        if ($needsPath) {
            $newUserPath = if ([string]::IsNullOrWhiteSpace($currentUserPath)) {
                $installRoot
            } else {
                "$currentUserPath$pathSeparator$installRoot"
            }
            [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        }

        if (-not $hasProcessPath) {
            $newProcessPath = if ([string]::IsNullOrWhiteSpace($processPath)) {
                $installRoot
            } else {
                "$processPath$pathSeparator$installRoot"
            }
            [Environment]::SetEnvironmentVariable('Path', $newProcessPath, 'Process')
        }

        Write-Host ''
        Write-Host "WinTop se instalo como 'top'." -ForegroundColor Green
        Write-Host "A partir de ahora podes ejecutarlo con: top" -ForegroundColor Cyan
        if ($needsPath) {
            Write-Host 'Si esta terminal no reconoce el comando, abri una terminal nueva.' -ForegroundColor DarkGray
        }
        Write-Host ''
        Start-Sleep -Seconds 2
    } catch {
        Write-Host ''
        Write-Host "No pude autoinstalar el comando 'top': $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host 'El script va a seguir corriendo como top.ps1.' -ForegroundColor DarkGray
        Write-Host ''
        Start-Sleep -Seconds 2
    }
}

Install-WinTopCommand

$script:state = @{
    SortBy       = $SortBy
    Filter       = ''
    Previous     = @{}
    PreviousTime = Get-Date
    Message      = 'q quit | h help | c/m/p/n sort | f filter | k kill | +/- rows'
    ProcessLimit = [Math]::Max(5, $ProcessLimit)
    OwnerLookup  = $true
    OwnerCache    = @{}
}

function Get-Bar {
    param(
        [double]$Percent,
        [int]$Width = 20,
        [ConsoleColor]$Low = [ConsoleColor]::Green,
        [ConsoleColor]$Mid = [ConsoleColor]::Yellow,
        [ConsoleColor]$High = [ConsoleColor]::Red
    )

    $value = [Math]::Max(0, [Math]::Min(100, $Percent))
    $filled = [int][Math]::Round(($value / 100) * $Width)
    $empty = $Width - $filled

    if ($value -ge 80) {
        $color = $High
    } elseif ($value -ge 55) {
        $color = $Mid
    } else {
        $color = $Low
    }

    [PSCustomObject]@{
        Text  = ('|' * $filled) + (' ' * $empty)
        Color = $color
    }
}

function Write-ColorParts {
    param([object[]]$Parts)

    foreach ($part in $Parts) {
        if ($null -eq $part.Color) {
            Write-Host $part.Text -NoNewline
        } else {
            Write-Host $part.Text -ForegroundColor $part.Color -NoNewline
        }
    }
    Write-Host ''
}

function Format-Size {
    param([double]$Bytes)

    if ($Bytes -ge 1TB) {
        return ('{0:N1}T' -f ($Bytes / 1TB))
    }
    if ($Bytes -ge 1GB) {
        return ('{0:N1}G' -f ($Bytes / 1GB))
    }
    if ($Bytes -ge 1MB) {
        return ('{0:N0}M' -f ($Bytes / 1MB))
    }
    if ($Bytes -ge 1KB) {
        return ('{0:N0}K' -f ($Bytes / 1KB))
    }
    return ('{0:N0}B' -f $Bytes)
}

function Set-CursorVisibility {
    param([bool]$Visible)

    try {
        [Console]::CursorVisible = $Visible
    } catch {
    }
}

function Clear-Screen {
    try {
        if (-not [Console]::IsOutputRedirected) {
            [Console]::Clear()
        }
    } catch {
    }
}

function Get-ConsoleWidth {
    try {
        return [Math]::Max(80, [Console]::WindowWidth)
    } catch {
        return 100
    }
}

function Get-ConsoleHeight {
    try {
        return [Math]::Max(10, [Console]::WindowHeight)
    } catch {
        return 30
    }
}

function Get-ComputerMemoryBytes {
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
        $computerInfo = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
        return [double]$computerInfo.TotalPhysicalMemory
    } catch {
        return 0
    }
}

function Get-SystemUptime {
    try {
        return [TimeSpan]::FromMilliseconds([Environment]::TickCount64)
    } catch {
    }

    return [TimeSpan]::FromMilliseconds([Math]::Abs([Environment]::TickCount))
}

function Get-OwnerName {
    param([System.Diagnostics.Process]$Process)

    if (-not $script:state.OwnerLookup) {
        return '?'
    }
    if ($script:state.OwnerCache.ContainsKey($Process.Id)) {
        return $script:state.OwnerCache[$Process.Id]
    }

    try {
        $owner = (Get-CimInstance Win32_Process -Filter "ProcessId=$($Process.Id)" -ErrorAction Stop).GetOwner()
        if ($owner.User) {
            $script:state.OwnerCache[$Process.Id] = $owner.User
            return $owner.User
        }
    } catch {
        $script:state.OwnerLookup = $false
    }

    $script:state.OwnerCache[$Process.Id] = '?'
    return '?'
}

function Get-SystemSnapshot {
    $os = $null
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    } catch {
    }

    if ($null -ne $os) {
        $totalMemory = [double]$os.TotalVisibleMemorySize * 1KB
        $freeMemory = [double]$os.FreePhysicalMemory * 1KB
        $usedMemory = $totalMemory - $freeMemory
        $uptime = (Get-Date) - $os.LastBootUpTime
    } else {
        $totalMemory = Get-ComputerMemoryBytes
        $usedMemory = [double]((Get-Process -ErrorAction SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum)
        $freeMemory = [Math]::Max(0, $totalMemory - $usedMemory)
        $uptime = Get-SystemUptime
    }

    $processorRows = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne '_Total' } |
        Sort-Object { [int]$_.Name }

    $cpuRows = @()
    foreach ($row in $processorRows) {
        $cpuRows += [PSCustomObject]@{
            Name    = $row.Name
            Percent = [double]$row.PercentProcessorTime
        }
    }

    if ($cpuRows.Count -eq 0) {
        $cpuRows = @(0..([Environment]::ProcessorCount - 1) | ForEach-Object {
            [PSCustomObject]@{ Name = $_; Percent = 0 }
        })
    }

    [PSCustomObject]@{
        CpuRows        = $cpuRows
        TotalMemory    = $totalMemory
        UsedMemory     = $usedMemory
        FreeMemory     = $freeMemory
        MemoryPercent  = if ($totalMemory -gt 0) { ($usedMemory / $totalMemory) * 100 } else { 0 }
        Uptime         = $uptime
        ProcessorCount = [Environment]::ProcessorCount
    }
}

function Get-ProcessSnapshot {
    param(
        [hashtable]$Previous,
        [datetime]$PreviousTime,
        [int]$ProcessorCount
    )

    $now = Get-Date
    $elapsed = [Math]::Max(0.001, ($now - $PreviousTime).TotalSeconds)
    $processes = Get-Process -ErrorAction SilentlyContinue
    $totalMemory = Get-ComputerMemoryBytes
    $nextPrevious = @{}
    $rows = @()

    foreach ($process in $processes) {
        $cpuSeconds = 0
        try {
            if ($null -ne $process.CPU) {
                $cpuSeconds = [double]$process.CPU
            }
        } catch {
            $cpuSeconds = 0
        }

        $cpuPercent = 0
        if ($Previous.ContainsKey($process.Id)) {
            $delta = $cpuSeconds - [double]$Previous[$process.Id]
            if ($delta -ge 0) {
                $cpuPercent = ($delta / $elapsed / [Math]::Max(1, $ProcessorCount)) * 100
            }
        }

        $nextPrevious[$process.Id] = $cpuSeconds

        $memory = [double]$process.WorkingSet64
        $memoryPercent = if ($totalMemory -gt 0) { ($memory / $totalMemory) * 100 } else { 0 }

        $rows += [PSCustomObject]@{
            PID     = $process.Id
            User    = Get-OwnerName $process
            PRI     = $process.BasePriority
            THR     = $process.Threads.Count
            VIRT    = $process.VirtualMemorySize64
            RES     = $process.WorkingSet64
            CPU     = [Math]::Round([Math]::Max(0, $cpuPercent), 1)
            MEM     = [Math]::Round($memoryPercent, 1)
            Command = $process.ProcessName
        }
    }

    [PSCustomObject]@{
        Rows         = $rows
        Previous     = $nextPrevious
        PreviousTime = $now
        TotalTasks   = $rows.Count
        Running      = ($rows | Where-Object { $_.CPU -gt 0 }).Count
        Threads      = ($rows | Measure-Object THR -Sum).Sum
    }
}

function Select-VisibleProcesses {
    param([object[]]$Rows)

    $visible = $Rows
    if ($script:state.Filter.Trim().Length -gt 0) {
        $needle = $script:state.Filter
        $visible = $visible | Where-Object {
            $_.Command -like "*$needle*" -or $_.User -like "*$needle*" -or "$($_.PID)" -like "*$needle*"
        }
    }

    switch ($script:state.SortBy) {
        'mem'  { $visible | Sort-Object MEM, RES -Descending }
        'pid'  { $visible | Sort-Object PID }
        'name' { $visible | Sort-Object Command, PID }
        default { $visible | Sort-Object CPU, MEM -Descending }
    }
}

function Draw-Header {
    param(
        [object]$System,
        [object]$ProcessSnapshot
    )

    $width = Get-ConsoleWidth
    $barWidth = [Math]::Max(8, [Math]::Min(24, [int](($width - 45) / 2)))
    $cpuRows = @($System.CpuRows)
    $half = [Math]::Ceiling($cpuRows.Count / 2)

    Write-Host ('WinTop {0} | sort:{1} rows:{2} filter:"{3}"' -f (Get-Date -Format 'HH:mm:ss'), $script:state.SortBy, $script:state.ProcessLimit, $script:state.Filter) -ForegroundColor Cyan

    for ($i = 0; $i -lt $half; $i++) {
        $left = $cpuRows[$i]
        $leftBar = Get-Bar $left.Percent $barWidth
        $parts = @(
            @{ Text = ('CPU{0,2} [' -f $left.Name); Color = [ConsoleColor]::Gray },
            @{ Text = $leftBar.Text; Color = $leftBar.Color },
            @{ Text = ('] {0,5:N1}%   ' -f $left.Percent); Color = [ConsoleColor]::Gray }
        )

        $rightIndex = $i + $half
        if ($rightIndex -lt $cpuRows.Count) {
            $right = $cpuRows[$rightIndex]
            $rightBar = Get-Bar $right.Percent $barWidth
            $parts += @(
                @{ Text = ('CPU{0,2} [' -f $right.Name); Color = [ConsoleColor]::Gray },
                @{ Text = $rightBar.Text; Color = $rightBar.Color },
                @{ Text = ('] {0,5:N1}%' -f $right.Percent); Color = [ConsoleColor]::Gray }
            )
        }
        Write-ColorParts $parts
    }

    $memBar = Get-Bar $System.MemoryPercent ([Math]::Min(30, [Math]::Max(10, $width - 56)))
    Write-ColorParts @(
        @{ Text = 'Mem  ['; Color = [ConsoleColor]::Gray },
        @{ Text = $memBar.Text; Color = $memBar.Color },
        @{ Text = ('] {0}/{1} {2,5:N1}%' -f (Format-Size $System.UsedMemory), (Format-Size $System.TotalMemory), $System.MemoryPercent); Color = [ConsoleColor]::Gray }
    )

    Write-Host ('Tasks: {0}, {1} thr; {2} active | Uptime: {3:0}d {4:00}:{5:00}:{6:00}' -f $ProcessSnapshot.TotalTasks, $ProcessSnapshot.Threads, $ProcessSnapshot.Running, $System.Uptime.Days, $System.Uptime.Hours, $System.Uptime.Minutes, $System.Uptime.Seconds) -ForegroundColor Cyan
    Write-Host $script:state.Message -ForegroundColor DarkGray
    Write-Host ''
}

function Draw-Processes {
    param([object[]]$Rows)

    $height = Get-ConsoleHeight
    $maxRows = [Math]::Min($script:state.ProcessLimit, $height - 9)
    $nameWidth = [Math]::Max(18, (Get-ConsoleWidth) - 73)

    Write-Host ("{0,6} {1,-12} {2,3} {3,4} {4,8} {5,8} {6,6} {7,6} {8}" -f 'PID', 'USER', 'PRI', 'THR', 'VIRT', 'RES', 'CPU%', 'MEM%', 'COMMAND') -ForegroundColor Black -BackgroundColor Green

    $Rows | Select-Object -First $maxRows | ForEach-Object {
        $command = $_.Command
        if ($command.Length -gt $nameWidth) {
            $command = $command.Substring(0, $nameWidth - 1) + '~'
        }

        $color = [ConsoleColor]::Gray
        if ($_.CPU -ge 50 -or $_.MEM -ge 20) {
            $color = [ConsoleColor]::Red
        } elseif ($_.CPU -ge 15 -or $_.MEM -ge 10) {
            $color = [ConsoleColor]::Yellow
        }

        Write-Host ("{0,6} {1,-12} {2,3} {3,4} {4,8} {5,8} {6,6:N1} {7,6:N1} {8}" -f $_.PID, $_.User, $_.PRI, $_.THR, (Format-Size $_.VIRT), (Format-Size $_.RES), $_.CPU, $_.MEM, $command) -ForegroundColor $color
    }
}

function Read-CommandLine {
    param([string]$Prompt)

    Set-CursorVisibility $true
    Write-Host ''
    Write-Host $Prompt -NoNewline -ForegroundColor Cyan
    $value = Read-Host
    Set-CursorVisibility $false
    return $value
}

function Invoke-Key {
    param([ConsoleKeyInfo]$Key)

    switch ($Key.KeyChar) {
        'q' { return $false }
        'c' { $script:state.SortBy = 'cpu'; $script:state.Message = 'Sorting by CPU activity' }
        'm' { $script:state.SortBy = 'mem'; $script:state.Message = 'Sorting by memory usage' }
        'p' { $script:state.SortBy = 'pid'; $script:state.Message = 'Sorting by PID' }
        'n' { $script:state.SortBy = 'name'; $script:state.Message = 'Sorting by process name' }
        '+' { $script:state.ProcessLimit += 5; $script:state.Message = 'Showing more rows' }
        '-' { $script:state.ProcessLimit = [Math]::Max(5, $script:state.ProcessLimit - 5); $script:state.Message = 'Showing fewer rows' }
        'h' { $script:state.Message = 'q quit | c CPU | m MEM | p PID | n name | f filter | k kill PID | +/- rows' }
        'f' {
            $script:state.Filter = Read-CommandLine 'Filter: '
            $script:state.Message = 'Filter updated'
        }
        'k' {
            $pidText = Read-CommandLine 'Kill PID: '
            $targetPid = 0
            if ([int]::TryParse($pidText, [ref]$targetPid)) {
                try {
                    Stop-Process -Id $targetPid -Confirm -ErrorAction Stop
                    $script:state.Message = "Requested stop for PID $targetPid"
                } catch {
                    $script:state.Message = "Could not stop PID ${targetPid}: $($_.Exception.Message)"
                }
            } else {
                $script:state.Message = 'Invalid PID'
            }
        }
    }

    return $true
}

function Show-Top {
    Set-CursorVisibility $false
    try {
        $warmSystem = Get-SystemSnapshot
        $warmProcesses = Get-ProcessSnapshot $script:state.Previous $script:state.PreviousTime $warmSystem.ProcessorCount
        $script:state.Previous = $warmProcesses.Previous
        $script:state.PreviousTime = $warmProcesses.PreviousTime
        Start-Sleep -Milliseconds ([Math]::Max(200, [Math]::Min(1000, [int]($RefreshRate * 1000))))

        while ($true) {
            $system = Get-SystemSnapshot
            $processSnapshot = Get-ProcessSnapshot $script:state.Previous $script:state.PreviousTime $system.ProcessorCount
            $script:state.Previous = $processSnapshot.Previous
            $script:state.PreviousTime = $processSnapshot.PreviousTime
            $visibleProcesses = Select-VisibleProcesses $processSnapshot.Rows

            Clear-Screen
            Draw-Header $system $processSnapshot
            Draw-Processes $visibleProcesses

            if ($Once) {
                return
            }

            $end = (Get-Date).AddSeconds([Math]::Max(0.2, $RefreshRate))
            while ((Get-Date) -lt $end) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if (-not (Invoke-Key $key)) {
                        return
                    }
                    break
                }
                Start-Sleep -Milliseconds 100
            }
        }
    } finally {
        Set-CursorVisibility $true
    }
}

Show-Top
