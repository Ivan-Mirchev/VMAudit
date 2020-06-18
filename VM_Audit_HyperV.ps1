[CmdletBinding(DefaultParameterSetName='Cluster')]
param (
    [Parameter(Mandatory=$true, ParameterSetName='Cluster')]
    [string[]]$Cluster, 
    [Parameter(Mandatory=$true, ParameterSetName='Server')]
    [string[]]$Server,
    [string]$ExportPath = '.'
)

If ($Cluster) {$Computer = $Cluster | ForEach-Object -Process {(Get-ClusterNode -Cluster $_).Name}}
elseif ($Server) {$Computer = $Server } 

$HVresult = Invoke-Command -ComputerName $Computer -ScriptBlock { 


#region Functions region

Function Get-VMDiskInfo {
    # Check if no disk is configured. 
    if ($VM.HardDrives.Count -eq 0) {$DiskControllerInfo = 'No Disk Configured'; $DiskInfo = 'No Disk Configured'}

    # loop trough the Disks and collect info
    for ($i=1; $i -le $vm.HardDrives.count; $i++){
        
        # Substract 1 from counter $i to use in array (starting from 0)
        $CurrentDisk = $VM.HardDrives[$i-1]
        
        # Represent infromation for Disk Controller, Type and Number
        $DiskControllerInfo += "Disk$i : $($CurrentDisk.ControllerType) ($($CurrentDisk.ControllerNumber):$($CurrentDisk.ControllerLocation))`n" 
        
        If ($CurrentDisk.Path) {
            # Get VHD details
            $VHD = Get-VHD -Path $CurrentDisk.Path -ErrorAction SilentlyContinue # Handle if VHD could not be found!!
            if ($VHD) {
                # Represent information for VHD Type, Format and Size
                $DiskInfo += "Disk$i : $($VHD.VhdType) $($VHD.VhdFormat) - $($VHD.Size/1GB) GB`n"
            } else {$DiskInfo += "Disk$i : VHD file is missing`n"} 

        } else {$DiskInfo += "Disk$i : Path Not Valid`n"} 

        # DISK PATH
        # CONSIDER WHAT TO DO WITH SNAPSHOTS

    }

    # Return Result
    [PSCustomObject]@{
        DiskCount = $vm.HardDrives.Count
        DiskController = $DiskControllerInfo.Trim()
        DiskInfo = $DiskInfo.Trim()
    }

    }

function Get-VMNICInfo {
    if ($VM.NetworkAdapters.Count -eq 0) {$NICMACAddress = "No NIC Configured"; $NICSwitch = "No NIC Configured"; $NICVLAN = "No NIC Configured"; $NICType = 'No NIC Configured' ; $NICIPAddresses = "No NIC Configured"}
    for ($i=1; $i -le $vm.NetworkAdapters.count; $i++){
        $CurrentNIC = $vm.NetworkAdapters[$i-1]
        $CurrentNICVLAN = Get-VMNetworkAdapterVlan -VMNetworkAdapter $CurrentNIC
        $CurrentNICType = if ($CurrentNIC.IsLegacy) {"Legacy"} elseif ($CurrentNIC.IsSynthetic) {"Synthetic"} else {"Unknown"}
        $NICMACAddress += "NIC$i : $($CurrentNIC.MACAddress)`n"
        $NICSwitch += "NIC$i : $($CurrentNIC.SwitchName)`n"
        $NICVLAN += "NIC$i : VLAN - $($CurrentNICVLAN.AccessVlanId)`n"
        $NICType += "NIC$i : $CurrentNICType`n"
        $NICIPAddresses += if ($CurrentNIC.IPAddresses) {"NIC$i : $($CurrentNIC.IPAddresses -match "\d{2,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")`n"} else {"NIC$i : IP UNAVAILABLE`n"}

    }
    [PSCustomObject]@{
        NICCount = $VM.NetworkAdapters.Count
        NICMACAddress = $NICMACAddress.Trim()
        NICSwitch = $NICSwitch.Trim()
        NICVLAN = $NICVLAN.Trim()
        NICType = $NICType.Trim()
        NICIPAddresses = $NICIPAddresses.Trim()
    }
    }

    #endregion Functions region

    # Start of the script
    Import-Module -Name Hyper-V

    $VMs = Get-VM 

    if (Get-Service -DisplayName 'Cluster Service' -ErrorAction SilentlyContinue) {$ClusterName = Get-Cluster}
    else {$ClusterName = "N/A"}

    foreach ($VM in $VMs) {

        Write-Host Processing: $VM.Name on Server: $VM.ComputerName -BackgroundColor DarkGreen

        $VMDiskInfo = Get-VMDiskInfo
        $NICInfo = Get-VMNICInfo
        $VMMemory = Get-VMMemory -VM $VM

        [PSCustomObject]@{
            VMName = $VM.Name
            Cluster = $ClusterName
            IsClustered = $VM.IsClustered
            State = $VM.State
            CPU = $VM.ProcessorCount
            MemoryType = if ($VMMemory.DynamicMemoryEnabled) {"Dynamic"} else {"Static"}
            MemoryGB = if ($VMMemory.DynamicMemoryEnabled) {"Min: $($VMMemory.Minimum/1GB)`nMax: $($VMMemory.Maximum/1GB)"} else {$VMMemory.Startup/1GB}
            VMGeneration = $VM.Generation
            VMVersion = $VM.Version
            DiskCount = $VMDiskInfo.diskcount
            DiskController = $VMDiskInfo.DiskController
            DiskInfo = $VMDiskInfo.DiskInfo
            NICCount = $NICInfo.NICCount
            NICMACAddress = $NICInfo.NICMACAddress
            NICSwitch = $NICInfo.NICSwitch
            NICVLAN = $NICInfo.NICVLAN
            NICType = $NICInfo.NICType
            NICIPAddresses = $NICInfo.NICIPAddresses
            VMNotes = $VM.Notes.Trim()
        } 
    }

}

# Stop-Process -Name Excel -ErrorAction SilentlyContinue
$timeStamp = Get-Date -Format yyyy-MM-dd

$HVresult | Export-Csv -Path "$ExportPath\VM_Audit_HyperV_$timeStamp.csv" -NoTypeInformation -Encoding utf8
# $HVresult | Out-GridView
<#
    . .\VM_Audit_HyperV.ps1 -Cluster HV-CLS1, HV-CLS2, HV-CLS3, HV-CLS04 -ExportPath C:\TEMP
    Import-Csv -Path C:\TEMP\VM_Audit_HyperV_2020-06-18.csv, C:\TEMP\VM_Audit_VMWare_2020-06-18.csv | Select-Object -ExcludeProperty RunspaceId,PSShowComputerName |Export-Csv -Path C:\TEMP\VM_Audit_All_2020-06-18.csv -Encoding utf8 -NoTypeInformation
    Import-Csv -Path C:\TEMP\VM_Audit_HyperV_2020-06-18.csv, C:\TEMP\VM_Audit_VMWare_2020-06-18.csv | Select-Object -ExcludeProperty RunspaceId,PSShowComputerName |Export-Csv -Path C:\TEMP\VM_Audit_All_2020-06-18_unicode.csv -Encoding Unicode -NoTypeInformation
    PSComputerName	
#>
#invoke-item -Path C:\TEMP\multiline.csv
<#
notepad C:\TEMP\multiline.csv
    invoke-item -Path C:\TEMP\multiline.csv
#>


