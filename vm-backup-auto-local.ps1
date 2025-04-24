# Set UTF-8 encoding for correct handling of file paths
chcp 65001 > $null
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# Parameters
$backupRoot = "\\10.0.1.7\VM-Backup"  # Path to backup directory
$subfolderCurrent = "current"  # Name of folder for current backup
$subfolderPrevious = "previous"  # Name of folder for previous backup
$logFile = Join-Path $backupRoot ("vm-backup-log_" + (Get-Date -Format "yyyy-MM-dd") + ".log")  # Path to log file

# Function to write to log
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "Backup of virtual machines started..."

# Get list of all virtual machines on local Hyper-V host
$vms = Get-VM

foreach ($vm in $vms) {
    $vmName = $vm.Name
    $vmBackupPath = Join-Path -Path $backupRoot -ChildPath $vmName
    $currentExportPath = Join-Path -Path $vmBackupPath -ChildPath $subfolderCurrent
    $previousExportPath = Join-Path -Path $vmBackupPath -ChildPath $subfolderPrevious

    Write-Log "Preparing export for VM '$vmName' to $currentExportPath..."

    # Delete previous backup folder if it exists with retry logic
    if (Test-Path $previousExportPath) {
        Write-Log "Deleting previous backup: $previousExportPath"
        $maxAttempts = 3
        $attempt = 1
        $success = $false
        while (-not $success -and $attempt -le $maxAttempts) {
            try {
                Write-Log "Attempt $attempt of $maxAttempts to delete previous backup"
                Get-ChildItem -Path $previousExportPath -Recurse | Remove-Item -Recurse -Force -ErrorAction Stop
                Remove-Item -Path $previousExportPath -Recurse -Force -ErrorAction Stop
                $success = $true
                Write-Log "Successfully deleted previous backup"
            }
            catch {
                Write-Log "Error deleting previous backup (attempt $attempt): $_"
                if ($attempt -eq $maxAttempts) {
                    Write-Log "Failed to delete previous backup after $maxAttempts attempts."
                    $previousContents = Get-ChildItem -Path $previousExportPath -Recurse -ErrorAction SilentlyContinue
                    if ($previousContents) {
                        Write-Log "Contents of previous folder: $($previousContents | ForEach-Object { $_.FullName })"
                    }
                }
                Start-Sleep -Seconds 10  # Delay for large files (2-4 TB)
            }
            $attempt++
        }
    }

    # Wait before moving current to previous
    Write-Log "Waiting 10 seconds before moving current to previous..."
    Start-Sleep -Seconds 10

    # Move current backup to previous with retry logic
    if (Test-Path $currentExportPath) {
        Write-Log "Moving current backup to 'previous'"
        $maxAttempts = 3
        $attempt = 1
        $success = $false
        while (-not $success -and $attempt -le $maxAttempts) {
            try {
                Write-Log "Attempt $attempt of $maxAttempts to move current to previous"
                Rename-Item -Path $currentExportPath -NewName $subfolderPrevious -ErrorAction Stop
                # Verify move was successful
                if (Test-Path $previousExportPath -and -not (Test-Path $currentExportPath)) {
                    $success = $true
                    Write-Log "Successfully moved current backup to previous"
                } else {
                    throw "Verification failed: previous folder not found or current folder still exists"
                }
            }
            catch {
                Write-Log "Error moving current backup to previous (attempt $attempt): $_"
                if ($attempt -eq $maxAttempts) {
                    Write-Log "Failed to move current backup to previous after $maxAttempts attempts."
                }
                Start-Sleep -Seconds 10  # Delay for large files (2-4 TB)
            }
            $attempt++
        }
    }

    # Thoroughly clean or create current folder with retry logic
    if (Test-Path $currentExportPath) {
        Write-Log "Cleaning existing current folder: $currentExportPath"
        $maxAttempts = 3
        $attempt = 1
        $success = $false
        while (-not $success -and $attempt -le $maxAttempts) {
            try {
                Write-Log "Attempt $attempt of $maxAttempts to clean current folder"
                Get-ChildItem -Path $currentExportPath -Recurse | Remove-Item -Recurse -Force -ErrorAction Stop
                $success = $true
                Write-Log "Successfully cleaned current folder"
            }
            catch {
                Write-Log "Error cleaning current folder (attempt $attempt): $_"
                if ($attempt -eq $maxAttempts) {
                    Write-Log "Failed to clean after $maxAttempts attempts. Trying to delete entire current folder..."
                    try {
                        Remove-Item -Path $currentExportPath -Recurse -Force -ErrorAction Stop
                        Write-Log "Current folder fully deleted due to cleaning errors"
                    }
                    catch {
                        Write-Log "Critical error deleting current folder: $_"
                    }
                }
                Start-Sleep -Seconds 10  # Delay for large files (2-4 TB)
            }
            $attempt++
        }
    }

    # Create new current folder
    Write-Log "Creating new current folder: $currentExportPath"
    New-Item -ItemType Directory -Path $currentExportPath -Force | Out-Null

    # Wait for filesystem synchronization
    Write-Log "Waiting 10 seconds for filesystem synchronization..."
    Start-Sleep -Seconds 10

    # Verify current folder is empty before export
    $currentContents = Get-ChildItem -Path $currentExportPath
    if ($currentContents) {
        Write-Log "Warning: current folder is not empty before export: $currentExportPath"
        Write-Log "Contents: $($currentContents | ForEach-Object { $_.Name })"
    } else {
        Write-Log "Current folder is empty and ready for export"
    }

    # Export virtual machine
    try {
        Write-Log "Exporting VM '$vmName' to $currentExportPath..."
        Export-VM -Name $vmName -Path $currentExportPath -ErrorAction Stop
        Write-Log "VM '$vmName' successfully exported to $currentExportPath"
    }
    catch {
        Write-Log "Error exporting VM '$vmName': $_"
    }
}

Write-Log "Backup of all VMs completed."
