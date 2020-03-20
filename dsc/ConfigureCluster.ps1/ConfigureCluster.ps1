#
# Copyright 2020 Microsoft Corporation. All rights reserved."
#

configuration ConfigureCluster
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [String]$ClusterName,

        [Parameter(Mandatory)]
        [String]$NamePrefix,

        [Parameter(Mandatory)]
        [Int]$VMCount,

        [Parameter(Mandatory)]
        [Int]$DataDiskSizeGB,

        [Parameter(Mandatory)]
        [String]$WitnessStorageName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$WitnessStorageKey,

        [Parameter(Mandatory)]
        [String]$ListenerIPAddress,

        [Parameter(Mandatory)]
        [Int]$ListenerProbePort
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, ComputerManagementDsc, ActiveDirectoryDsc

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$($Admincreds.UserName)@${DomainName}", $Admincreds.Password)

    [System.Collections.ArrayList]$Nodes=@()
    For ($count=1; $count -lt $VMCount; $count++) {
        $Nodes.Add($NamePrefix + $Count.ToString())
    }
  
    Node localhost
    {

        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FC"
        }

        WindowsFeature FCCmd
        {
            Name = "RSAT-Clustering-CmdInterface"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FCPS"
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FCCmd"
        }

        WaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            Credential= $DomainCreds
            WaitForValidCredentials = $True
            WaitTimeout = 600
            RestartCount = 3
            DependsOn = "[WindowsFeature]ADPS"
        }

        Computer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[WaitForADDomain]DscForestWait"
        }

        Script CreateCluster
        {
            SetScript = "New-Cluster -Name ${ClusterName} -Node ${env:COMPUTERNAME} -NoStorage "
            TestScript = "(Get-Cluster -ErrorAction SilentlyContinue).Name -eq '${ClusterName}'"
            GetScript = "@{Ensure = if ((Get-Cluster -ErrorAction SilentlyContinue).Name -eq '${ClusterName}') {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
	        DependsOn = "[Computer]DomainJoin"
        }

        Script CloudWitness
        {
            SetScript = "Set-ClusterQuorum -CloudWitness -AccountName ${WitnessStorageName} -AccessKey $($WitnessStorageKey.GetNetworkCredential().Password)"
            TestScript = "(Get-ClusterQuorum).QuorumResource.Name -eq 'Cloud Witness'"
            GetScript = "@{Ensure = if ((Get-ClusterQuorum).QuorumResource.Name -eq 'Cloud Witness') {'Present'} else {'Absent'}}"
            DependsOn = "[Script]CreateCluster"
        }

        Script IncreaseClusterTimeouts
        {
            SetScript = "(Get-Cluster).SameSubnetDelay = 2000; (Get-Cluster).SameSubnetThreshold = 15; (Get-Cluster).CrossSubnetDelay = 3000; (Get-Cluster).CrossSubnetThreshold = 15"
            TestScript = "(Get-Cluster).SameSubnetDelay -eq 2000 -and (Get-Cluster).SameSubnetThreshold -eq 15 -and (Get-Cluster).CrossSubnetDelay -eq 3000 -and (Get-Cluster).CrossSubnetThreshold -eq 15"
            GetScript = "@{Ensure = if ((Get-Cluster).SameSubnetDelay -eq 2000 -and (Get-Cluster).SameSubnetThreshold -eq 15 -and (Get-Cluster).CrossSubnetDelay -eq 3000 -and (Get-Cluster).CrossSubnetThreshold -eq 15) {'Present'} else {'Absent'}}"
            DependsOn = "[Script]CloudWitness"
        }

        foreach ($Node in $Nodes)
        {
            Script "AddClusterNode_${Node}"
            {
                SetScript = "Add-ClusterNode -Name ${Node} -NoStorage"
                TestScript = "'${Node}' -in (Get-ClusterNode).Name"
                GetScript = "@{Ensure = if ('${Node}' -in (Get-ClusterNode).Name) {'Present'} else {'Absent'}}"
                PsDscRunAsCredential = $DomainCreds
                DependsOn = "[Script]IncreaseClusterTimeouts"
            }
        }

        Script FormatSharedDisks
        {
            SetScript = "Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Initialize-Disk -PartitionStyle GPT -PassThru -ErrorAction SilentlyContinue | New-Partition -AssignDriveLetter -UseMaximumSize -ErrorAction SilentlyContinue | Format-Volume -FileSystem NTFS -Confirm:${false}"
            TestScript = "(Get-Disk | Where-Object PartitionStyle -eq 'RAW').Count -eq 0"
            GetScript = "@{Ensure = if ((Get-Disk | Where-Object PartitionStyle -eq 'RAW').Count -eq 0) {'Present'} else {'Absent'}}"
            DependsOn = "[Script]CreateCluster"
        }

        Script AddClusterDisks
        {
            SetScript = "Get-ClusterAvailableDisk | Add-ClusterDisk"
            TestScript = "(Get-ClusterAvailableDisk).Count -eq 0"
            GetScript = "@{Ensure = if ((Get-ClusterAvailableDisk).Count -eq 0) {'Present'} else {'Absent'}}"
            DependsOn = "[Script]FormatSharedDisks"
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $True
        }

    }
}
