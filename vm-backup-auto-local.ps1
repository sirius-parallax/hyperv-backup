# Parameters
$backupRoot = "\\10.0.1.7\VM-Backup"  # Путь к каталогу для бекапов
$subfolderCurrent = "current"  # Название папки для текущего бекапа
$subfolderPrevious = "previous"  # Название папки для предыдущего бекапа
$logFile = Join-Path $backupRoot ("vm-backup-log_" + (Get-Date -Format "yyyy-MM-dd") + ".log")  # Путь для лог-файла

# Функция для записи в лог
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "Backup of virtual machines started..."

# Получение списка всех виртуальных машин на локальном хосте Hyper-V
$vms = Get-VM

foreach ($vm in $vms) {
    $vmName = $vm.Name
    $vmBackupPath = Join-Path -Path $backupRoot -ChildPath $vmName
    $currentExportPath = Join-Path -Path $vmBackupPath -ChildPath $subfolderCurrent
    $previousExportPath = Join-Path -Path $vmBackupPath -ChildPath $subfolderPrevious

    Write-Log "Preparing export for VM '$vmName'..."

    # Удаление папки предыдущего бекапа, если она существует
    if (Test-Path $previousExportPath) {
        Write-Log "Deleting previous backup: $previousExportPath"
        Remove-Item -Path $previousExportPath -Recurse -Force
    }

    # Перемещение текущего бекапа в предыдущий
    if (Test-Path $currentExportPath) {
        Write-Log "Moving current backup to 'previous'"
        Rename-Item -Path $currentExportPath -NewName $subfolderPrevious
    }

    # Создание новой папки для текущего бекапа
    New-Item -ItemType Directory -Path $currentExportPath -Force | Out-Null

    # Экспорт виртуальной машины
    try {
        Export-VM -Name $vmName -Path $currentExportPath -ErrorAction Stop
        Write-Log "VM '$vmName' successfully exported to $currentExportPath"
    } catch {
        Write-Log "Error exporting VM '$vmName': $_"
    }
}

Write-Log "Backup of all VMs completed."
