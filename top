function Show-Top {
    param (
        [int]$RefreshRate = 5
    )

    # Obtener el número de núcleos de CPU
    $cpuCount = [System.Environment]::ProcessorCount

    while ($true) {
        Clear-Host

        # Imprimir encabezado
        Write-Host "PID  `t Process Name `t`t CPU (%) `t Memory (MB)" -ForegroundColor Green
        Write-Host "---------------------------------------------------------"

        # Obtener procesos y calcular el uso de CPU como porcentaje
        $processes = Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10 | ForEach-Object {
            $cpuPercent = ($_ | Measure-Object -Property CPU -Sum).Sum / $cpuCount
            [PSCustomObject]@{
                Id = $_.Id
                ProcessName = $_.ProcessName
                CPUPercent = [math]::Round($cpuPercent, 2)
                MemoryMB = [math]::Round($_.WorkingSet / 1MB, 2)
            }
        }

        # Imprimir procesos
        foreach ($process in $processes) {
            Write-Host ("{0,-5} {1,-20} {2,10} {3,12}" -f $process.Id, $process.ProcessName, "$($process.CPUPercent)%", $process.MemoryMB)
        }

        Start-Sleep -Seconds $RefreshRate
    }
}

Show-Top
