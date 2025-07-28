# Path to marker file
$doneMarker = "C:\Setup\bootstrap.done"

# Skip execution if already done
if (Test-Path $doneMarker) {
    Write-Output "Bootstrap already completed. Exiting."
    exit
}

# Rename and domain join
if ($env:COMPUTERNAME -ne "SQL3") {
    Rename-Computer -NewName "SQL3" -Force
    Restart-Computer -Force
    Exit
}
    
IF (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    $domainName = "rcx-dba.com"
    $domainUser = "rcx-dba\\admin"   # use your domain user here
    $domainPass = ConvertTo-SecureString "Results2025!" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($domainUser, $domainPass)

    Add-Computer -DomainName $domainName -Credential $cred
    Restart-Computer -Force
    exit
}

# Install features (post-reboot)
Install-WindowsFeature -Name Failover-Clustering, RSAT-Clustering-PowerShell -IncludeManagementTools

# Optional: Other features
# Install-WindowsFeature -Name AD-Domain-Services, RSAT-ADDS

# Mark done to prevent rerun
New-Item -Path $doneMarker -ItemType File -Force

# Clean up scheduled task
#Unregister-ScheduledTask -TaskName "BootstrapOnce" -Confirm:$false
