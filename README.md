# hyperv-backup
This script backs up virtual machines that are locally in hyper-v or that are installed in a failover cluster. You can make an automatic backup of all the virtual machines that you have, or a manual mode with the ability to select which virtual machines to backup.

vm-backup-auto-cluster.ps1 - Auto backup of everything in the cluster

vm-backup-auto-local.ps1 - Backup everything that is available locally

vm-backup-manual-cluster.ps1 - Manual backup with a choice of virtual machines. Working with a cluster.

vm-backup-manual-local.ps1 - Manual mode of local virtual machines.


The "backup Root" variable sets the path to backups. The script creates two folders with the previous backup and the current one. If there is no previous one, the current one is created, and if there is a previous one, it is moved to the folder and the current one is created. The script is usually run through the scheduler once a week.
