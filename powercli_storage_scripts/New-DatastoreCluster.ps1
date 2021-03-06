
Param(
[Parameter(Mandatory=$true,Position=1)][string]$vCenter=$null,
[Parameter(Mandatory=$true,Position=2)][string]$Datacenter=$null,
[Parameter(Mandatory=$true,Position=3)][string]$Cluster=$null,
[Parameter(Mandatory=$true,Position=4)][string]$Name=$null,
[switch]$EnableVmdkAffinity,
[switch]$DisableVmdkAffinity
)

### testing ###
#$DisableVmdkAffinity = $true
###############

If($EnableVmdkAffinity -and $DisableVmdkAffinity){ Write-Error "Cannot use -EnableVmdkAffinity and -DisableVmdkAffinity. Please choose one option only"; Exit 1 }
If((-not $EnableVmdkAffinity) -and (-not $DisableVmdkAffinity)){ $DisableVmdkAffinity = $true }

Write-Host "Loading Script...";
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
cls

"Connecting to $($vCenter)"
$vi = Connect-VIServer -Server $vCenter -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
If([string]::IsNullOrEmpty($vi)){ Write-Error "Unable to connect to $($vCenter)."; Exit 3}

$cl = Get-VmCluster -Name $Cluster
If([string]::IsNullOrEmpty($cl)){ Write-Host "Unable to find cluster $($Cluster)."; Exit 4 }

If(-not [string]::IsNullOrEmpty($Datacenter)){ $dc = Get-Datacenter -Name $Datacenter -ErrorAction SilentlyContinue }

$dscFolder = Get-Folder -Name $cl.Name -Type Datastore -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($dscFolder)){ $rootFolder = Get-Folder -Name "UCG" -Type Datastore -Location $dc ; $dscFolder = New-Folder -Name $cl.Name -Location $rootFolder -ErrorAction Stop }

$dsc = Get-DatastoreCluster -Name $Name -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($dsc)){ $dsc = New-DatastoreCluster -Name $Name -Location $dscFolder -ErrorAction Stop }

$dsc = $dsc | Set-DatastoreCluster -IOLoadBalanceEnabled:$false -SdrsAutomationLevel Manual -IOLatencyThresholdMillisecond 15 -SpaceUtilizationThresholdPercent 80 -Confirm:$false -ErrorAction Stop
$dscView = $dsc | Get-View

$srm = Get-View StorageResourceManager
$newSpec = New-Object Vmware.Vim.StorageDrsConfigSpec
$newSpec.PodConfigSpec = New-Object Vmware.Vim.StorageDrsPodConfigSpec
If($EnableVmdkAffinity){ $newSpec.PodConfigSpec.DefaultIntraVmAffinity = $true }
ElseIf($DisableVmdkAffinity){ $newSpec.PodConfigSpec.DefaultIntraVmAffinity = $false }
$srm.ConfigureStorageDrsForPod_Task($dscView.MoRef,$newSpec,$true)

Disconnect-VIServer -Server $vCenter -Confirm:$false -Force:$true -ErrorAction SilentlyContinue
