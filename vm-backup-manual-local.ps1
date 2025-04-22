# Specify the backup path
$backupPath = "\\10.0.1.7\VM-Backup"

# Get the list of all virtual machines on the local host
$vms = Get-VM

# If virtual machines are found
if ($vms.Count -gt 0) {
    # Display the list of virtual machines with numbers
    $vms | ForEach-Object { Write-Host "$($_.Id) - $($_.Name)" }

    # Prompt for selecting virtual machines to back up
    $selection = Read-Host "Enter the numbers of the virtual machines to back up, separated by commas (or 'all' for all)"

    # If 'all' is entered, select all machines
    if ($selection -eq 'all') {
        $selectedVMs = $vms
    } else {
        # Otherwise, select machines by numbers
        $selectedVMs = $selection.Split(',') | ForEach-Object { 
            $vms | Where-Object { $_.Id -eq $_ }
        }
    }

    # Export the selected virtual machines
    foreach ($vm in $selectedVMs) {
        $exportPath = Join-Path $backupPath $vm.Name
        Write-Host "Exporting VM $($vm.Name) to $exportPath"

        # Create the backup
        Export-VM -Name $vm.Name -Path $exportPath -Force
        Write-Host "Backup of VM $($vm.Name) completed."
    }
} else {
    Write-Host "No available virtual machines on this host."
}
