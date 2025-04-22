# Parameters
$backupRoot = "\\10.0.1.7\VM-Backup"
$subfolderCurrent = "current"
$subfolderPrevious = "previous"
$logFile = Join-Path $backupRoot ("vm-backup-log_" + (Get-Date -Format "yyyy-MM-dd") + ".log")

# Logging function
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "Backup of virtual machines started..."

# Get all cluster VMs
$vms = Get-ClusterGroup | Where-Object { $_.GroupType -eq 'VirtualMachine' }

# Show list of VMs
Write-Log "Available virtual machines:"
$counter = 1
foreach ($vm in $vms) {
    Write-Host "$counter. $($vm.Name)"
    $counter++
}

# Ask for selection
$selection = Read-Host "Enter the number(s) of VMs to backup, separated by commas (e.g., 1,3,5), or 'all' to backup all VMs"

if ($selection -eq 'all') {
    $selectedVMs = $vms
} else {
    $selectedVMs = @()
    $selectionArray = $selection -split ','

    foreach ($num in $selectionArray) {
        $num = $num.Trim()
        if ($num -match '^\d+$' -and $num -le $vms.Count) {
            $selectedVMs += $vms[$num - 1]
        }
    }
}

# Backup selected VMs
foreach ($vm in $selectedVMs) {
    $vmName = $vm.Name
    $ownerNode = $vm.OwnerNode.Name
    $vmBackupPath = Join-Path -Path $backupRoot -ChildPath $vmName
    $currentExportPath = Join-Path -Path $vmBackupPath -ChildPath $subfolderCurrent
    $previousExportPath = Join-Path -Path $vmBackupPath -ChildPath $subfolderPrevious

    Write-Log "Preparing export for VM '$vmName' on node '$ownerNode'..."

    # Remove previous folder
    if (Test-Path $previousExportPath) {
        Write-Log "Deleting previous backup: $previousExportPath"
        Remove-Item -Path $previousExportPath -Recurse -Force
    }

    # Move current to previous
    if (Test-Path $currentExportPath) {
        Write-Log "Moving current backup to 'previous'"
        Rename-Item -Path $currentExportPath -NewName $subfolderPrevious
    }

    # Create new current folder
    New-Item -ItemType Directory -Path $currentExportPath -Force | Out-Null

    # Export VM
    try {
        Invoke-Command -ComputerName $ownerNode -ScriptBlock {
            param($vmName, $exportPath)
            Export-VM -Name $vmName -Path $exportPath
        } -ArgumentList $vmName, $currentExportPath -ErrorAction Stop

        Write-Log "VM '$vmName' successfully exported to $currentExportPath"
    }
    catch {
        Write-Log "Error exporting VM '$vmName': $_"
    }
}

Write-Log "Backup of selected VMs completed."
