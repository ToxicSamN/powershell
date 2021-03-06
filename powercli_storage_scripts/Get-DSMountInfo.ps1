
#Param(
#[Parameter(Mandatory=$true,Position=1)][string]$vCenter=$null,
#[Parameter(Mandatory=$,Position=2)][string]$Cluster=$null,
#[Parameter(Mandatory=$true,Position=3)][string[]]$Datastore=$null
#)

$vCenter = 'a0319p10133'
$Cluster = 'cl0319lint003_deploy'
$Datastore = @('dsxtm03lint003_s001','dsxtm03lint003_s002','dsxtm03lint003_s003')

Import-Module UcgModule -ArgumentList vmware -WarningAction SilentlyContinue
Connect-VIServer -Server $vCenter
$VMHosts = Get-VmCluster -Name $Cluster | Get-VMHost

Function Get-DatastoreMountInfo {
[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$Datastore,
		$VMHosts
)
  Begin{ 
    $AllInfo = @()
  }
	Process {
		$tmp_array = @()
		if($_ -isnot [VMware.Vim.Datastore]){
			$ds = Get-View $_
      
		}else{ $ds = $_ }

		if ($ds.info.Vmfs) {
			$hostviewDSDiskName = $ds.Info.vmfs.extent[0].diskname
			if ($ds.Host) {
				$attachedHosts = $ds.Host | ?{$VMHosts.Id -contains $_.Key}
				Foreach ($VMHost in $attachedHosts) {
					$hostview = Get-View $VMHost.Key
					$hostviewDSState = $VMHost.MountInfo.Mounted
					$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
					$devices = $StorageSys.StorageDeviceInfo.ScsiLun
					Foreach ($device in $devices) {
						$Info = "" | Select Datastore, VMHost, Lun, Mounted, State
						if ($device.canonicalName -eq $hostviewDSDiskName) {
							$hostviewDSAttachState = ""
							if ($device.operationalState[0] -eq "ok") {
								$hostviewDSAttachState = "Attached"
							} elseif ($device.operationalState[0] -eq "off") {
								$hostviewDSAttachState = "Detached"
							} else {
								$hostviewDSAttachState = $device.operationalstate[0]
							}
							$Info.Datastore = $ds.Name
							$Info.Lun = $hostviewDSDiskName
							$Info.VMHost = $hostview.Name
							$Info.Mounted = $HostViewDSState
							$Info.State = $hostviewDSAttachState
							$tmp_array += $Info
						}
					}
				}
			}
		}
		$AllInfo += $tmp_array
	}
  End{
    return $AllInfo
  }
}

Get-Datastore -Name $Datastore | Get-DatastoreMountInfo -VMHosts $VMHosts
