# MoE checking VM Status
$timeStamp = Get-Date -Format yyyy-MM-dd
$ADComputerList = Get-ADComputer -Filter {OperatingSystem -like '*server*'} -Properties Enabled, IPv4Address, LastLogonDate, OperatingSystem, OperatingSystemVersion, CanonicalName | Select-Object -Property Name, DNSHostName, IPv4Address, OperatingSystem, OperatingSystemVersion, LastLogonDate, Enabled, CanonicalName, DistinguishedName
# $ADComputerList | export-csv -Path C:\TEMP\ADComputerList_$timeStamp.csv -NoTypeInformation

Function Get-ADPingWINRM {
    $ADComputerPingWINRM = foreach ($Computer in $ADComputerList) {
        try {
            $pingWINRM = Test-NetConnection -ComputerName $Computer.DNSHostName -CommonTCPPort WINRM -ErrorAction Stop
            if ($pingWINRM.TcpTestSucceeded) {$pingWINRM.PingSucceeded = $true}
            [PSCustomObject]@{
                Name = $Computer.Name
                DNSHostName = $Computer.DNSHostName
                IPv4Address = $Computer.IPv4Address
                Ping = $pingWINRM.PingSucceeded
                WINRM = $pingWINRM.TcpTestSucceeded
                OperatingSystem = $Computer.OperatingSystem
                OperatingSystemVersion = $Computer.OperatingSystemVersion
                LastLogonDate = $Computer.LastLogonDate
                Enabled = $Computer.Enabled
                CanonicalName = $Computer.CanonicalName
                DistinguishedName = $Computer.DistinguishedName
            }
        }
        catch {
            [PSCustomObject]@{
                Name = $Computer.Name
                DNSHostName = $Computer.DNSHostName
                IPv4Address = $Computer.IPv4Address
                Ping = 'ERROR'
                WINRM = $_.Exception.Message
                OperatingSystem = $Computer.OperatingSystem
                OperatingSystemVersion = $Computer.OperatingSystemVersion
                LastLogonDate = $Computer.LastLogonDate
                Enabled = $Computer.Enabled
                CanonicalName = $Computer.CanonicalName
                DistinguishedName = $Computer.DistinguishedName
            }    
        }
    }
    $ADComputerPingWINRM | Export-Csv -Path C:\TEMP\Audit\ADComputerPingWINRM_$timeStamp.csv -NoTypeInformation
}

function Get-ADPingOnly {
    $i = 0 
    $ADComputerPingOnly = foreach ($Computer in $ADComputerList) {
        $i++
        Write-Progress -Activity 'Testing connectivity' -PercentComplete (($1/$ADComputerList.count)*100) -Status "$i of $($ADComputerList.Count)"
        try {
            $ping = Test-Connection -ComputerName $Computer.DNSHostName -Count 1 -Quiet -ErrorAction Stop
            [PSCustomObject]@{
                Name = $Computer.Name
                DNSHostName = $Computer.DNSHostName
                IPv4Address = $Computer.IPv4Address
                Ping = $ping
                # WINRM = $ping.TcpTestSucceeded
                OperatingSystem = $Computer.OperatingSystem
                OperatingSystemVersion = $Computer.OperatingSystemVersion
                LastLogonDate = $Computer.LastLogonDate
                Enabled = $Computer.Enabled
                CanonicalName = $Computer.CanonicalName
                DistinguishedName = $Computer.DistinguishedName
            }
        }
        catch {
            [PSCustomObject]@{
                Name = $Computer.Name
                DNSHostName = $Computer.DNSHostName
                IPv4Address = $Computer.IPv4Address
                Ping = $_.Exception.Message
                OperatingSystem = $Computer.OperatingSystem
                OperatingSystemVersion = $Computer.OperatingSystemVersion
                LastLogonDate = $Computer.LastLogonDate
                Enabled = $Computer.Enabled
                CanonicalName = $Computer.CanonicalName
                DistinguishedName = $Computer.DistinguishedName
            }    
        }
    }
    $ADComputerPingOnly | Export-Csv -Path C:\TEMP\Audit\ADComputerPingOnly_$timeStamp.csv -NoTypeInformation 
}

# Get-ADPingOnly
Get-ADPingWINRM

# List of differences | <= - Missing in AD | => - Missing in VM
$VMComputers = Import-Csv -Path C:\TEMP\Audit\VM_Audit_All_$timeStamp.csv
$ADComputers = Import-Csv -Path C:\TEMP\Audit\ADComputerPingWINRM_$timeStamp.csv

Compare-Object -ReferenceObject $VMComputers.VMName -DifferenceObject $ADComputers.Name | Export-Csv -Path C:\TEMP\Audit\Difference.csv -NoTypeInformation 

function Compare-VMAD {
    $VMComputers = Import-Csv -Path C:\TEMP\Audit\VM_Audit_All_2020-06-18.csv
    $ADComputers = Import-Csv -Path C:\TEMP\Audit\ADComputerPingWINRM_2020-06-19.csv

    $CompareVMAD = foreach ($VM in $VMComputers) {
        if ($ADComputer = $ADComputers | Where-Object -Property Name -eq $vm.VMName) {$match = $true}
        else {$match = 'VM Only'}
        [PSCustomObject]@{
            VM_Cluster = $VM.Cluster
            VM_IsClustered = $VM.IsClustered
            VM_Name = $VM.VMName
            AD_Name = $ADComputer.Name
            Match = $match
            VM_State = $VM.State
            Ping = $ADComputer.Ping
            WINRM = $ADComputer.WINRM
            AD_DNSHostName = $ADComputer.DNSHostName
            VM_OperatingSystem = ''
            AD_OperatingSystem = $ADComputer.OperatingSystem
            VM_OperatingSystemVersion = ''
            AD_OperatingSystemVersion = $ADComputer.OperatingSystemVersion
            AD_LastLogonDate = $ADComputer.LastLogonDate
            AD_Enabled = $ADComputer.Enabled
            VM_CPU = $VM.CPU
            VM_MemoryType = $VM.MemoryType
            VM_MemoryGB = $VM.MemoryGB
            VM_Generation = $VM.VMGeneration
            VM_Version = $VM.VMVersion
            VM_DiskCount = $VM.DiskCount
            VM_DiskController = $VM.DiskController
            VM_DiskInfo = $VM.DiskInfo
            VM_NICCount = $VM.NICCount
            VM_NICMACAddress = $VM.NICMACAddress
            VM_NICSwitch = $VM.NICSwitch
            VM_NICVLAN = $VM.NICVLAN
            VM_NICType = $VM.NICType
            VM_NICIPAddresses = $VM.NICIPAddresses
            AD_IPv4Address = $ADComputer.IPv4Address
            VM_Notes = $VM.VMNotes
            AD_Comment = $ADComputer.comment
            DomainJoined = ''
            InstalledOn = ''
            LastUpdate = ''
            UpdateServer = ''
            AD_CanonicalName = $ADComputer.CanonicalName
            AD_DistinguishedName = $ADComputer.DistinguishedName
        }
    }

    $CompareVMAD | Export-Csv -Path C:\TEMP\Audit\CompareVMAD_$timeStamp.csv -NoTypeInformation -Encoding utf8
}

Compare-VMAD