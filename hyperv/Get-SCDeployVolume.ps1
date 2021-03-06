function Get-SCDeployVolume{
<# 
.SYNOPSIS  
	Get the best available Volume in a collection of cluster shared volumes
.DESCRIPTION  
	In the absence of a storage cluster then some basic logic is required to find the best available volume in a collection of cluster shared volumes. 
	This will find the volume or multiple volumes with the most available storage as well as greater than 10% free space. This si used for automated builds.
.NOTES  
	Name  			: Get-SCDeployVolume 
	Author     		: Sammy Shuck 
	Github			: https://github.com/ToxicSamN/powershell/blob/master/hyperv/Get-SCDeployVolume.ps1
	Requires   		: Minimum WS2016 and Powershell v5
.EXAMPLE  
	Get-SCDeployVolume -VMMServer "vmmserver.mydomain.net" -Cluster "clustergen01" -Verbose
.EXAMPLE  
	$vmm = Get-SCVMMServer -ComputerName "vmmserver.mydomain.net"
	$cl = Get-SCVMHostCluster -Name "clustergen01" -VMMServer $vmm
	Get-SCDeployVolume -VMMServer $vmm -Cluster $cl -Verbose
#> 
[cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $VMMServer,
        [Parameter(Mandatory=$true)]
        $Cluster
    )

    function Set-VolumeDeployTarget{
    [cmdletbinding()]
		Param(
            [Parameter(Mandatory=$true,ValueFromPipeline)]
            $Volume,
            $Value = $true
        )

        Process{
			Write-Verbose "Flagging volume $($_.VolumePath) to DeployTarget=$($Value)"
            $_.DeployTarget = $Value
        }
    }
       
	if ($VMMServer -isnot [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]){
		Write-Verbose "$($VMMServer) is not of type [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]. Getting SCVMM Server"
    	$vmm = Get-SCVMMServer -ComputerName $VMMServer
	}
    if ($Cluster -isnot [Microsoft.FailoverClusters.PowerShell.ClusterObject] -and $Cluster -isnot [Microsoft.SystemCenter.VirtualMachineManager.ClientObject]){
		Write-Verbose "$($Cluster) is not of type [Microsoft.FailoverClusters.PowerShell.ClusterObject] or [Microsoft.SystemCenter.VirtualMachineManager.ClientObject]. Getting Cluster."
		$cl = Get-SCVMHostCluster -Name $Cluster -VMMServer $vmm
	}
    Write-Verbose "Collecting the Cluster Shared Volumes for cluster $($cl.Name)"
    $cl_vols = Get-ClusterSharedVolume -Cluster $cl
	Write-Output ($cl_vols | ft -AutoSize) | Out-String -Stream | Write-Verbose
    
    Write-Verbose "Collecting Free Space information"
	$vol_info = @{}
    $cl_vols | %{ $vol = $_
        $vol_info[$vol.Name] = New-Object PSObject -Property @{Name=$vol.Name;
        	Id=$vol.Id;
        	VolumePath=$vol.SharedVolumeInfo.FriendlyVolumeName;
        	FreeSpace=$vol.SharedVolumeInfo.Partition.FreeSpace;
        	PercentFree=$vol.SharedVolumeInfo.Partition.PercentFree;
        	DeployTarget=$false}
		Write-Output ($vol_info[$vol.Name] | ft -AutoSize) | Out-String -Stream | Write-Verbose
    }
	Write-Verbose "Evaluating Volume Sizes and Collecting valid Deploy Volumes"
    $vol_info.Values | ?{$_.FreeSpace -eq ($vol_info.Values.FreeSpace | Measure-Object -Maximum).Maximum} | ?{$_.FreeSpace -gt 10} | Set-VolumeDeployTarget
	Write-Output ($vol_info.Values | ?{$_.DeployTarget}) | Out-String -Stream | Write-Verbose
	
	return ($vol_info.Values | ?{$_.DeployTarget}) # may return multiple volumes
}


# Example usage
# $vmm = Get-SCVMMServer -ComputerName "vmmserver.mydomain.net"
# $cl = Get-SCVMHostCluster -Name "clustergen01" -VMMServer $vmm
# Get-SCDeployVolume -VMMServer $vmm -Cluster $cl -Verbose
