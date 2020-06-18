#Requires -Modules VMware.VimAutomation.Core 

[CmdletBinding(DefaultParameterSetName='vCenter')]
param (
    [Parameter(Mandatory=$true, ParameterSetName='vCenter')]
    [string[]]$vCenter, 
    [string]$ExportPath = '.'
)

Import-Module VMware.VimAutomation.Core

#Collect VM Disk Info
function Get-VMDiskInfo {
    $VMHardDrives = Get-HardDisk -VM $VM
    if ($VMHardDrives.count -eq 0) {$DiskControllerInfo = 'No Disk Configured'; $DiskInfo = 'No Disk Configured'}
    for ($i = 1; $i -le $VMHardDrives.Count ; $i++) {
        $CurrentDisk = $VMHardDrives[$i-1]
        $CurrendHWDevice = $VM.ExtensionData.Config.Hardware.Device | Where-Object -Property key -eq $CurrentDisk.ExtensionData.ControllerKey
        $DiskControllerInfo += "Disk$i : $($CurrendHWDevice.DeviceInfo.Label) ($($CurrendHWDevice.BusNumber):$($CurrentDisk.ExtensionData.UnitNumber))`n"
        $DiskInfo += "Disk$i : $($CurrentDisk.DiskType) $($CurrentDisk.StorageFormat) - $("{0:N2}" -f $CurrentDisk.CapacityGB) GB`n"
    }
    [PSCustomObject]@{
        DiskCount = $VMHardDrives.Count
        DiskController = $DiskControllerInfo.Trim()
        DiskInfo = $DiskInfo.Trim()
    }
}

function Get-VMNICInfo {
    $VMNetworkAdapters = Get-NetworkAdapter -VM $VM
    if ($VMNetworkAdapters.Count -eq 0) {}

    for ($i = 1; $i -le $VMNetworkAdapters.Count ; $i++) {
        $CurrentNIC = $VMNetworkAdapters[$i-1]
        $NICMACAddress += "NIC$i : $($CurrentNIC.MACAddress)`n"
        $NICSwitch += "$((Get-VirtualSwitch -VM $VM).Name)`n"
        $NICVLAN += "NIC$i : $($CurrentNIC.NetworkName)`n"
        $NICType += "NIC$i : $($CurrentNIC.Type)`n"
        $NICIPAddresses += "NIC$i : $(($vm.Guest.Nics | Where-Object -FilterScript {$_.device.name -eq $CurrentNIC.Name}).IPAddress -match "\d{2,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" ) `n"      
    }
    [PSCustomObject]@{
        NICCount = $VMNetworkAdapters.Count
        NICMACAddress = $NICMACAddress.Trim()
        NICSwitch = $NICSwitch.Trim()
        NICVLAN = $NICVLAN.Trim()
        NICType = $NICType.Trim()
        NICIPAddresses = $NICIPAddresses.Trim()
    }

}

Connect-VIServer -server $vCenter -Force
# Connect-VIServer -server SRV-VCENTER.minedu.government.bg -Force


# $VMs = Get-VM -name adminws, oa
$VMs = VMware.VimAutomation.Core\Get-VM 


$VMWresult = foreach ($VM in $VMs) {
    write-host Processing $VM.Name -BackgroundColor DarkGreen
    $VMDiskInfo = Get-VMDiskInfo
    $NICInfo = Get-VMNICInfo
    $Cluster = VMware.VimAutomation.Core\Get-Cluster -VM $VM
    [PSCustomObject]@{
        VMName = $VM.Name
        Cluster = "$($Cluster.ParentFolder)\$($cluster.Name)"
        IsClustered = $true
        State = $VM.PowerState
        CPU = "CoresPerSocket: $($VM.CoresPerSocket)`nNumberCPU: $($VM.NumCpu)"
        MemoryType = 'Static'
        MemoryGB = $VM.MemoryGB
        VMGeneration = ""
        VMVersion = $VM.HardwareVersion
        DiskCount = $VMDiskInfo.DiskCount
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
$timeStamp = Get-Date -Format yyyy-MM-dd
# $VMWresult | Out-GridView
$VMWresult | Export-Csv -Path "$ExportPath\VM_Audit_VMWare_$timeStamp.csv" -NoTypeInformation -Encoding utf8
# $VMWresult | Export-Csv -Path "c:\temp\VM_Audit_VMWare_$timeStamp.csv" -NoTypeInformation -Encoding utf8