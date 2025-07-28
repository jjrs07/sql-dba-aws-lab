# PowerShell script to initialize and format disks on an EC2 instance
Get-Disk

Initialize-Disk -Number 1 -PartitionStyle MBR

New-Partition -DiskNumber 1 -UseMaximumSize -AssignDriveLetter

Format-Volume -DriveLetter H -FileSystem NTFS -NewFileSystemLabel "SQLDiskH" -Confirm:$false

Set-Partition -DriveLetter E -NewDriveLetter D



# 2. Create folder for scripts
New-Item -ItemType Directory -Path "C:\Setup" -Force

# 3. Download bootstrap script from S3
Invoke-WebRequest -Uri "https://YOUR-BUCKET-NAME.s3.amazonaws.com/bootstrap.ps1" -OutFile "C:\Setup\bootstrap.ps1"

# 4. Register scheduled task to run script once after login
$Action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -File C:\Setup\bootstrap.ps1'
$Trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "BootstrapOnce" -Action $Action -Trigger $Trigger -RunLevel Highest -User "SYSTEM"
