
Param(
[Parameter(Mandatory=$true,Position=1)][string]$vCenter=$null,
[Parameter(Mandatory=$true,Position=2)][string]$Datacenter=$null,
[Parameter(Mandatory=$true,Position=3)][string]$Name=$null,
[Parameter(Mandatory=$false,Position=4)][string]$ReplacingCluster=$null
)
cls

If(-not [string]::IsNullOrEmpty($ReplacingCluster)){
$usrInput = Read-Host "You have indicated that you are replacing cluster $($ReplacingCluster) with $($Name).`nIs this correct? [yes/no]"
If($usrInput -eq "no"){ Write-Host "Exiting Script"; return throw }
}

Write-Host "Loading Script...";
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
cls

"Connecting to $($vCenter)"
$vi = Connect-VIServer -Server $vCenter -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
If([string]::IsNullOrEmpty($vi)){ Write-Error "Unable to connect to $($vCenter)."; return throw }

If(-not [string]::IsNullOrEmpty($ReplacingCluster)){
$oldCl = Get-VmCluster -Name $ReplacingCluster -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($oldCl)){ Write-Host "Unable to find the cluster beinf replaced $($ReplacingCluster)"; Exit 3 }

$annotation = $oldCl | Get-Annotation -CustomAttribute "DeployCluster"
}

$dc = Get-Datacenter -Name $Datacenter -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($dc)){ Write-Host "Unable to find Datacenter $($Datacenter)"; Exit 4 }

$get_cl_location = (Get-VmCluster -Location $dc | ?{$_.Name -notlike "*ncdc*"})[0]
$clParent = $get_cl_location.ParentFolder

$cl = Get-VmCluster -Name $Name -ErrorAction SilentlyContinue
If(-not [string]::IsNullOrEmpty($cl)){ Write-Host "Cluster $($cl.Name) already exists. Exiting Script."; Exit 5 }

$cl = New-VmCluster -Location $clParent -Name $Name -HAAdmissionControlEnabled:$true -DrsEnabled:$true -HAEnabled:$true -DrsAutomationLevel FullyAutomated -HAIsolationResponse DoNothing -HARestartPriority Medium -VMSwapfilePolicy InHostDatastore -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($cl)){ Write-Host "Unable to create new cluster $($Name). Exit Script"; Exit 6 }

If(-not [string]::IsNullOrEmpty($annotation)){ 
	$anno = $cl | Set-Annotation -CustomAttribute "DeployCluster" -Value $annotation.Value
	$anno = $oldCl | Set-Annotation -CustomAttribute "DeploCluster" -Value ""
}Else{
	$count = 0
	$deployClusters = @(Get-VmCluster | Get-Annotation -CustomAttribute "DeployCluster" | ?{$_.Value -ne ""})
	Write-Host "Are you replacing a current Deploy Cluster?" -ForegroundColor Yellow
	Write-Host "Current Deploy Clusters" -ForegroundColor Yellow
	$deployClusters | %{ $count += 1; Write-Host "$($count). Replace $($_.AnnotatedEntity)`t$($_.Value)" -ForegroundColor Yellow }
	$count += 1
	Write-Host "$($count). Not Replacing A Deploy Cluster" -ForegroundColor Yellow
	[int]$usrInput = 0
	[int]$usrInput = Read-Host "`nPlease Select an option. [1-$($count)]" -ErrorAction SilentlyContinue
	
	If($usrInput -ne $count -and $usrInput -ne 0){
		$thisObj = $deployClusters[$usrInput-1]
		$anno = $cl | Set-Annotation -CustomAttribute "DeployCluster" -Value $thisObj.Value
		$anno = $thisObj.AnnotatedEntity | Set-Annotation -CustomAttribute "DeployCluster" -Value ""
	}
}

Disconnect-VIServer -Server $vCenter -Confirm:$false -Force:$true -ErrorAction SilentlyContinue
