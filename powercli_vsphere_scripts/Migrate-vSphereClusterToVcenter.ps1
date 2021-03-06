<#
.SYNOPSIS
	Migrate a vSphere cluster from one vcenter to another vcenter, keeping all settings and 
	configurations of the cluster and ESXi hosts.

.DESCRIPTION
	Migrate-vSphereClusterToVcenter.ps1 will migrate a cluster from vCenter to vCenter. 
	All cluster settings and rules will be maintained across vcenters. Such as DRS rules, HA custom settings ect.
	All esxi host configurations will be maintained. Such as VDS and vSwitch associations and configurations.
	All resource pools and vApps will be maintained.
	Permissions on all objects except ESXi Hosts and Vms will be maintained.
	Datastore clusters and configurations will be maintained.

.EXAMPLE
	Migrate cluster cl0319ucgt001 from vCenter a0319t355 to vCenter y0319t1919
	Migrate-vSphereClusterToVcenter.ps1 -SourceVcenter a0319t355 -Cluster cl0319ucgt001 -DestinationVcenter y0319t1919

.Parameter SourceVcenter
	Specify which vCenter instance to migrate from.

.Parameter Cluster
	Name of cluster in SourceVcenter to migrate.

.Parameter DestinationVcenter
	Specify which vCenter instance to migrate to.
.NOTES
	Author: Sammy Shuck (x3kw)
	IT Group: Unified Computing group (UCG)
	Date: 02/16/2016
	
#>
# This script is a bit of a mess and I am not too proud of it. Various parts have been written separately over time
# Those various parts have been thrown in here to make some-what of a working migration script
# This can be better and does account for many configuration scenarios but it is a massive rewrite and due to 
# time-contraints cannot be done.
#rewrite may happen in python using pyvmomi instead of powercli.
#VC 6.5 has a migration tool to handle this work now and so this is likely not needed any longer.
# VMware support says they have seen issues with the migration tool so this may be back in the "needed" category
Param(
	[Parameter(Mandatory=$True,
                   Position=0)]
	[string]$SourceVcenter=$null,
	[Parameter(Mandatory=$True,
                   Position=1)]
	[string]$Cluster=$null,
	[Parameter(Mandatory=$True,
                   Position=2)]
	[string]$DestinationVcenter=$null
)

cls
$tmp = Get-Date
Function Set-TaskTracer() {
	Param($Entity,$ModifiedObject,$Action,$OriginalConfiguration,$ModifiedConfiguration)
	$pso = New-Object PSObject -Property @{
		Entity=$Entity
		ModifiedObject=$ModifiedObject
		Action=$Action
		OriginalConfiguration=$OriginalConfiguration
		ModifiedConfiguration=$ModifiedConfiguration
	}
	return $pso
}
Function Rollback-Changes([array]$taskTracer){
	$tmpEAP = $ErrorActionPreference
	$ErrorActionPreference = "SilentlyContinue"
	$index = $taskTracer.Count-1
	For($x=$index;$x -ge 0;$x--){ #Need to work backwards, so we need to start at the end of the array and work towards the beginning
		$taskTracer[$x] | %{ $tsk = $_
			Write-Progress -Activity "Rolling Back Changes..." -PercentComplete (100*($x/$index)) -Id 91
			If($tsk.Action -eq "DisableDrsHa"){
				$tmp = $tsk.OriginalConfiguration.Split(",")
				$drs = $tmp[0]; $ha = [System.Convert]::ToBoolean($tmp[1])
				$clObj = Get-VmCluster -Name $cl.Name
				$outNull = $clObj | Set-VmCluster -DrsAutomationLevel $drs -HAEnabled:$ha -Confirm:$false
			}
			ElseIf($tsk.Action -eq "CreateVss"){
				#created a new VSS on Entity so need to remove the VSS
				$outNull = Get-VMHost -Name $tsk.Entity | Get-VirtualSwitch -Standard -Name $tsk.ModifiedObject | Remove-VirtualSwitch -Confirm:$false
			}
			ElseIf($tsk.Action -eq "CreateVssPg"){
				#created a new Vss PG on Entity so need to remove Vss Pg
				$outNull = $tsk.ModifiedObject | Remove-VirtualPortGroup -Confirm:$false
			}
			ElseIf($tsk.Action -eq "VmnicFromVdsToVss"){
				#Added a Vmnic to a Vss from Vds and need to remove from Vss and Add back to Original Vds
				$esxi = Get-VMHost -Name $tsk.Entity
				$pnic = $esxi | Get-VMHostNetworkAdapter -Physical -Name $tsk.ModifiedObject
				$outNull = Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $pnic -DistributedSwitch (Get-VDSwitch -Name $tsk.OriginalConfiguration) -Confirm:$false
			}ElseIf($tsk.Action -eq "RemainingVmnicFromVdsToVss"){
				#Added a Vmnic to a Vss from Vds and need to remove from Vss and Add back to Original Vds and original dvUplink
				$vds = Get-VDSwitch -Name $tsk.OriginalConfiguration
				$esxi = Get-View -ViewType HostSystem -Filter @{"Name"=$tsk.Entity}
				$outNull = Get-VIObjectByVIView -MORef $esxi.MoRef | Get-VMHostNetworkAdapter -Physical -Name $tsk.ModifiedObject.PnicDevice | Remove-VirtualSwitchPhysicalNetworkAdapter -Confirm:$false -ErrorAction SilentlyContinue
				$esxi.UpdateViewData()
				$UplinkPosition = $tsk.ModifiedObject.UplinkPosition
				$outNull = Add-VDSwitchVMHost -VDSwitch $vds -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Confirm:$false
				$esxi.UpdateViewData()
				$vdsUplink = ($esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds.Name}).UplinkPort[$UplinkPosition]
				
				$netConfig = New-Object VMware.Vim.HostNetworkConfig
				$netConfig.ProxySwitch = New-Object VMware.Vim.HostProxySwitchConfig[] (1)
				$netConfig.ProxySwitch[0] = New-Object VMware.Vim.HostProxySwitchConfig
				$netConfig.ProxySwitch[0].ChangeOperation = "edit"
				$netConfig.ProxySwitch[0].uuid = $vds.Key
				$netConfig.ProxySwitch[0].Spec = New-Object VMware.Vim.HostProxySwitchSpec
				$netConfig.ProxySwitch[0].Spec.Backing = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicBacking
				$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (1)
				$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[0] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
				$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[0].PnicDevice = $tsk.ModifiedObject.PnicDevice
				$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[0].UplinkPortKey = $vdsUplink.Key
				
				$netSys = Get-View $esxi.ConfigManager.NetworkSystem
				$netSys.UpdateNetworkConfig($netConfig, "modify") | Out-Null
			}
			ElseIf($tsk.Action -eq "VmkFromVdsToVss"){
				$esxi = Get-VMHost -Name $tsk.Entity
				$vmk = $esxi | Get-VMHostNetworkAdapter -VMKernel -Name $tsk.ModifiedObject
				$outNull = Set-VMHostNetworkAdapter -VirtualNic $vmk -PortGroup $tsk.OriginalConfiguration -Confirm:$false
			}ElseIf($tsk.Action -eq "ConvertTemplateToVm"){
				$outNull = $tsk.ModifiedObject | Set-VM -ToTemplate -Confirm:$false
			}ElseIf($tsk.Action -eq "MigrateVmFromVdsToVss"){
				$outNull = Set-NetworkAdapter -NetworkAdapter $tsk.ModifiedObject -Portgroup (Get-VDPortgroup -Id "DistributedVirtualPortgroup-$($tsk.OriginalConfiguration)") -Confirm:$false
			}
		}
	}
	$ErrorActionPreference = $tmpEAP
}
function Get-ObjectPath ($Object,$ObjType=$null,[array]$ExcludeFolder=@()) {	
	if($Object.Parent -eq $null) {
		return
	} else {
		$objParent = Get-View $Object.Parent
		
		$rtnParent = Get-ObjectPath $objParent -ObjType $ObjType -ExcludeFolder $ExcludeFolder
		
		If(-not [string]::IsNullOrEmpty($ExcludeFolder)){
			If($ExcludeFolder -inotcontains $Object.MoRef -and ($Object.Name -ne "Resources" -and $Object.MoRef -notlike "ResourcePool")){
				$pso = "" | Select Path,Type,IdPath,NewIdPath
				$pso.Path = ($rtnParent.Path + "/" + "$($Object.Name)")
				$pso.Type = $ObjType
				$pso.IdPath = ($rtnParent.IdPath + "/" + $Object.MoRef)
			}Else{ 
				$pso = "" | Select Path,Type,IdPath,NewIdPath
				$pso.Path = ($rtnParent.Path)
				$pso.Type = $ObjType
				$pso.IdPath = ($rtnParent.IdPath)
			}
		}Else{
			$pso = "" | Select Path,Type,IdPath,NewIdPath
			$pso.Path = ($rtnParent.Path + "/" + "$($Object.Name)")
			$pso.Type = $ObjType
			$pso.IdPath = ($rtnParent.IdPath + "/" + $Object.MoRef)
		}
		return $pso
	}
}
function Get-Roles{
  Begin{
    $authMgr = Get-View AuthorizationManager
    $report = @()
  }
  Process{
    foreach($role in $authMgr.roleList){
      $ret = New-Object PSObject
      $ret | Add-Member -Type noteproperty -Name “Name” -Value $role.name
      $ret | Add-Member -Type noteproperty -Name “Label” -Value $role.info.label
      $ret | Add-Member -Type noteproperty -Name “Summary” -Value $role.info.summary
      $ret | Add-Member -Type noteproperty -Name “RoleId” -Value $role.roleId
      $ret | Add-Member -Type noteproperty -Name “System” -Value $role.system
      $ret | Add-Member -Type noteproperty -Name “Privilege” -Value $role.privilege
      $report += $ret
    }
  }
  End{
    return $report
  }
}
function New-VIObjectPermission ($Principal,$Entity,$Role,[switch]$IsGroup=$false,[switch]$Propagate=$false,$ErrorAction="Continue") {
	$tmpEAP = $ErrorActionPreference
	$ErrorActionPreference = $ErrorAction
	$authMgr = Get-View "AuthorizationManager"
	$perm = New-Object VMware.Vim.Permission
	$perm.principal = $Principal
	$perm.group = $IsGroup
	$perm.propagate = $Propagate
	$perm.roleid = If($Role.GetType().Name -eq "AuthorizationRole"){$Role.RoleId}ElseIf($Role.GetType().Name -eq "String"){($authMgr.RoleList | ?{$_.Name -eq $Role}).RoleId}Else{$Role.Id}
	$chk=$null; $chk = $Entity.MoRef
	If([string]::IsNullOrEmpty($chk)){ 
		$authMgr.SetEntityPermissions($Entity.Id,$perm)
		$tmp = $authMgr.RetrieveEntityPermissions($Entity.Id,$false)
	}Else{
		$authMgr.SetEntityPermissions($Entity.MoRef,$perm)
		$tmp = $authMgr.RetrieveEntityPermissions($Entity.MoRef,$false)
	}
	$ErrorActionPreference = $tmpEAP
	return ($tmp | ?{$_.Principal -eq $Principal})
}
function New-XmlNode{
  param($node, $nodeName)
  $tmp = $vInventory.CreateElement($nodeName)
  $node.AppendChild($tmp)
}
function Set-XmlAttribute{
  param($node, $name, $value)
  $node.SetAttribute($name, $value)
}
function Get-XmlNode{
  param($path)
  $vInventory.SelectNodes($path)
}
function Move-VmkernelAdapterToVss{
    Param ($VMHost,$VMHostId,$Interface,[string]$NetworkName,[int]$Vlan,$VirtualSwitch)
    
	If(-not [string]::IsNullOrEmpty($VMHostId)){ $vmhostObj = Get-View -Id $VMHostId }
	Else{
		If(-not [string]::IsNullOrEmpty($VMHost.ExtensionData)){ $vmhostObj = $VMHost.ExtensionData	}
		ElseIf($VMHost -is [string]){ $vmhostObj = Get-View -ViewType HostSystem -Filter @{"Name"=$VMHost} }
	}
	
	If($Interface -is [string]){ $vmk = $Interface }
	Else{ $vmk = $Interface.Name }

    $netSystem = $vmhostObj.Configmanager.NetworkSystem
	
	#Need to create the VMkernel portgroup
    $portGroupSpec = New-Object VMware.Vim.HostPortGroupSpec
    $portGroupSpec.Name = $NetworkName
    $portGroupSpec.VlanId = $Vlan
    $portGroupSpec.vSwitchName = $VirtualSwitch
    $portGroupSpec.Policy = New-Object VMware.Vim.HostNetworkPolicy
	
    $netObj = Get-View -Id $netSystem
    $netObj.AddPortGroup($portGroupSpec)																						
	#$netObj.UpdateViewData()
	
	#move the vmkernel adapter to the vswitch
    $hostNicSpec = New-Object VMware.Vim.HostVirtualNicSpec
    $hostNicSpec.Portgroup = $NetworkName
    
	$netObj = Get-View -Id $netSystem
	$netObj.UpdateVirtualNic($vmk, $hostNicSpec)
	$netObj.UpdateViewData()
	
	return $netObj
}
function Get-InstallPath {
#Function provided by VMware used by PowerCLI to initialize Snapins
# Initialize-PowerCLIEnvironment.ps1
   $regKeys = Get-ItemProperty "hklm:\software\VMware, Inc.\VMware vSphere PowerCLI" -ErrorAction SilentlyContinue
   
   #64bit os fix
   if($regKeys -eq $null){
      $regKeys = Get-ItemProperty "hklm:\software\wow6432node\VMware, Inc.\VMware vSphere PowerCLI"  -ErrorAction SilentlyContinue
   }

   return $regKeys.InstallPath
}
function LoadSnapins(){
   [xml]$xml = Get-Content ("{0}\vim.psc1" -f (Get-InstallPath))
   $snapinList = Select-Xml  "//PSSnapIn" $xml |%{$_.Node.Name }

   $loaded = Get-PSSnapin -Name $snapinList -ErrorAction SilentlyContinue | % {$_.Name}
   $registered = Get-PSSnapin -Name $snapinList -Registered -ErrorAction SilentlyContinue  | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   foreach ($snapin in $registered) {
      if ($loaded -notcontains $snapin) {
         Add-PSSnapin $snapin -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      }

      # Load the Intitialize-<snapin_name_with_underscores>.ps1 file
      # File lookup is based on install path instead of script folder because the PowerCLI
      # shortuts load this script through dot-sourcing and script path is not available.
      $filePath = "{0}Scripts\Initialize-{1}.ps1" -f (Get-InstallPath), $snapin.ToString().Replace(".", "_")
      if (Test-Path $filePath) {
         & $filePath
      }
   }
}
function LoadModules(){
   [xml]$xml = Get-Content ("{0}\vim.psc1" -f (Get-InstallPath))
   $moduleList = Select-Xml  "//PSModule" $xml |%{$_.Node.Name }

   $loaded = Get-Module -Name $moduleList -ErrorAction SilentlyContinue | % {$_.Name}
   $registered = Get-Module -Name $moduleList -ListAvailable -ErrorAction SilentlyContinue  | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   foreach ($module in $registered) {
      if ($loaded -notcontains $module) {
         Import-Module $module -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      }
   }
}
Function Write-Log(){
	Param($Path,$Message)
	If(Test-Path $path){
		Out-File -FilePath $Path -InputObject $Message -Append -Confirm:$false -ErrorAction SilentlyContinue
	}Else{
		Out-File -FilePath $Path -InputObject $Message -Confirm:$false -ErrorAction SilentlyContinue
	}	
}
Function pause ($message){
    # Check if running Powershell ISE
    if ($psISE)
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("$message")
    }
    else
    {
        Write-Host "$message" -ForegroundColor Yellow
		CMD /c pause
		"Continuing..."
        #$x = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp")
    }
}
Function Get-VlanNumericRange([string]$vlanRange){
	$retrn = $vlanRange.Split(",") | %{
		$numRng = New-Object Vmware.Vim.NumericRange -Property @{Start=$_.Split("-")[0];End=$_.Split("-")[1]}
		$numRng
	}
	return $retrn
}
function Set-HAAdmissionControlPolicy{
<#
.SYNOPSIS
Set the Percentage HA Admission Control Policy

.DESCRIPTION
Percentage of cluster resources reserved as failover spare capacity

.PARAMETER  Cluster
The Cluster object that is going to be configurered 

.PARAMETER percentCPU
The percent reservation of CPU Cluster resources

.PARAMETER percentMem
The percent reservation of Memory Cluster resources

.EXAMPLE
PS C:\> Set-HAAdmissionControlPolicy -Cluster $CL -percentCPU 50 -percentMem 50

.EXAMPLE
PS C:\> Get-Cluster | Set-HAAdmissionControlPolicy -percentCPU 50 -percentMem 50

.NOTES
Author: Niklas Akerlund / RTS
Date: 2012-01-19
#>
   param (
   [Parameter(Position=0,Mandatory=$true,HelpMessage="This need to be a clusterobject",
    ValueFromPipeline=$True)]
    $Cluster,
    [int]$percentCPU = 25,
    [int]$percentMem = 25
    )
    
    if(VMware.VimAutomation.Core\Get-Cluster $Cluster){
    
        $spec = New-Object VMware.Vim.ClusterConfigSpecEx
        $spec.dasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
        $spec.dasConfig.admissionControlPolicy = New-Object VMware.Vim.ClusterFailoverResourcesAdmissionControlPolicy
        $spec.dasConfig.admissionControlPolicy.cpuFailoverResourcesPercent = $percentCPU
        $spec.dasConfig.admissionControlPolicy.memoryFailoverResourcesPercent = $percentMem
    
        $Cluster = Get-View $Cluster
        $Cluster.ReconfigureComputeResource_Task($spec, $true)
    }
}
Function New-vDRSVMToHostRule{
<#
.SYNOPSIS
  Creates a new DRS VM to host rule
.DESCRIPTION
  This function creates a new DRS vm to host rule
.NOTES
  Author: Arnim van Lieshout
.PARAMETER VMGroup
  The VMGroup name to include in the rule.
.PARAMETER HostGroup
  The VMHostGroup name to include in the rule.
.PARAMETER Cluster
  The cluster to create the new rule on.
.PARAMETER Name
  The name for the new rule.
.PARAMETER AntiAffine
  Switch to make the rule an AntiAffine rule. Default rule type is Affine.
.PARAMETER Mandatory
  Switch to make the rule mandatory (Must run rule). Default rule is not mandatory (Should run rule)
.EXAMPLE
  PS> New-DrsVMToHostRule -VMGroup "VMGroup01" -HostGroup "HostGroup01" -Name "VMToHostRule01" -Cluster CL01 -AntiAffine -Mandatory
#>

	Param(
		[parameter(mandatory = $true,
		HelpMessage = "Enter a VM DRS group name")]
			[String]$VMGroup,
		[parameter(mandatory = $true,
		HelpMessage = "Enter a host DRS group name")]
			[String]$HostGroup,
		[parameter(mandatory = $true,
		HelpMessage = "Enter a cluster entity")]
			[PSObject]$Cluster,
		[parameter(mandatory = $true,
		HelpMessage = "Enter a name for the group")]
			[String]$Name,
			[Switch]$AntiAffine,
			[Switch]$Mandatory)

    switch ($Cluster.gettype().name) {
   		"String" {$cluster = VMware.VimAutomation.Core\Get-Cluster $cluster | Get-View}
   		"ClusterImpl" {$cluster = $cluster | Get-View}
   		"Cluster" {}
   		default {throw "No valid type for parameter -Cluster specified"}
	}

	$spec = New-Object VMware.Vim.ClusterConfigSpecEx
	$rule = New-Object VMware.Vim.ClusterRuleSpec
	$rule.operation = "add"
	$rule.info = New-Object VMware.Vim.ClusterVmHostRuleInfo
	$rule.info.enabled = $true
	$rule.info.name = $Name
	$rule.info.mandatory = $Mandatory
	$rule.info.vmGroupName = $VMGroup
	if ($AntiAffine) {
		$rule.info.antiAffineHostGroupName = $HostGroup
	}
	else {
		$rule.info.affineHostGroupName = $HostGroup
	}
	$spec.RulesSpec += $rule
	$cluster.ReconfigureComputeResource_Task($spec,$true)
} # New-DrsVMToHostRule -VMGroup "VMGroup01" -HostGroup "HostGroup01" –Name "VMToHostRule01" -Cluster CL01 -AntiAffine –Mandatory
Function New-vDrsHostGroup {
<#
.SYNOPSIS
  Creates a new DRS host group
.DESCRIPTION
  This function creates a new DRS host group in the DRS Group Manager
.NOTES
  Author: Arnim van Lieshout
.PARAMETER VMHost
  The hosts to add to the group. Supports objects from the pipeline.
.PARAMETER Cluster
  The cluster to create the new group on.
.PARAMETER Name
  The name for the new group.
.EXAMPLE
  PS> Get-VMHost ESX001,ESX002 | New-DrsHostGroup -Name "HostGroup01" -Cluster CL01
.EXAMPLE
  PS> New-DrsHostGroup -Host ESX001,ESX002 -Name "HostGroup01" -Cluster (Get-CLuster CL01)
#>

	Param(
		[parameter(valuefrompipeline = $true, mandatory = $true,
		HelpMessage = "Enter a host entity")]
			[PSObject]$VMHost,
		[parameter(mandatory = $true,
		HelpMessage = "Enter a cluster entity")]
			[PSObject]$Cluster,
		[parameter(mandatory = $true,
		HelpMessage = "Enter a name for the group")]
			[String]$Name)

	begin {
	    switch ($Cluster.gettype().name) {
      		"String" {$cluster = VMware.VimAutomation.Core\Get-Cluster $cluster | Get-View}
      		"ClusterImpl" {$cluster = $cluster | Get-View}
      		"Cluster" {}
      		default {throw "No valid type for parameter -Cluster specified"}
		}
		$spec = New-Object VMware.Vim.ClusterConfigSpecEx
		$group = New-Object VMware.Vim.ClusterGroupSpec
		$group.operation = "add"
		$group.Info = New-Object VMware.Vim.ClusterHostGroup
		$group.Info.Name = $Name
	}

	Process {
		switch ($VMHost.gettype().name) {
      		"String" {Get-VMHost -Name $VMHost | %{$group.Info.Host += $_.Extensiondata.MoRef}}
      		"VMHostImpl" {$group.Info.Host += $VMHost.Extensiondata.MoRef}
      		"HostSystem" {$group.Info.Host += $VMHost.MoRef}
      		default {throw "No valid type for parameter -VMHost specified"}
	    }
	}

	End {
		if ($group.Info.Host) {
			$spec.GroupSpec += $group
			$cluster.ReconfigureComputeResource_Task($spec,$true)
		}
		else {
      		throw "No valid hosts specified"
		}
	}
} # Get-VMHost ESX001,ESX002 | New-DrsHostGroup -Name "HostGroup01" -Cluster CL01
Function New-vDrsVmGroup {
<#
.SYNOPSIS
  Creates a new DRS VM group
.DESCRIPTION
  This function creates a new DRS VM group in the DRS Group Manager
.NOTES
  Author: Arnim van Lieshout
.PARAMETER VM
  The VMs to add to the group. Supports objects from the pipeline.
.PARAMETER Cluster
  The cluster to create the new group on.
.PARAMETER Name
  The name for the new group.
.EXAMPLE
  PS> Get-VM VM001,VM002 | New-DrsVmGroup -Name "VmGroup01" -Cluster CL01
.EXAMPLE
  PS> New-DrsVmGroup -VM VM001,VM002 -Name "VmGroup01" -Cluster (Get-CLuster CL01)
#>

	Param(
		[parameter(valuefrompipeline = $true, mandatory = $true,
		HelpMessage = "Enter a vm entity")]
			[PSObject]$VM,
		[parameter(mandatory = $true,
		HelpMessage = "Enter a cluster entity")]
			[PSObject]$Cluster,
		[parameter(mandatory = $true,
		HelpMessage = "Enter a name for the group")]
			[String]$Name)

	begin {
	    switch ($Cluster.gettype().name) {
      		"String" {$cluster = VMware.VimAutomation.Core\Get-Cluster $cluster | Get-View}
      		"ClusterImpl" {$cluster = $cluster | Get-View}
      		"Cluster" {}
      		default {throw "No valid type for parameter -Cluster specified"}
		}
		$spec = New-Object VMware.Vim.ClusterConfigSpecEx
		$group = New-Object VMware.Vim.ClusterGroupSpec
		$group.operation = "add"
		$group.Info = New-Object VMware.Vim.ClusterVmGroup
		$group.Info.Name = $Name
	}

	Process {
		switch ($VM.gettype().name) {
      		"String" {Get-VM -Name $VM | %{$group.Info.VM += $_.Extensiondata.MoRef}}
      		"VirtualMachineImpl" {$group.Info.VM += $VM.Extensiondata.MoRef}
      		"VirtualMachine" {$group.Info.VM += $VM.MoRef}
      		default {throw "No valid type for parameter -VM specified"}
	    }
	}

	End {
		if ($group.Info.VM) {
			$spec.GroupSpec += $group
			$cluster.ReconfigureComputeResource_Task($spec,$true)
		}
		else {
      		throw "No valid VMs specified"
		}
	}
} # Get-VM VM001,VM002 | New-DrsVmGroup -Name "VmGroup01" -Cluster CL01

LoadSnapins
LoadModules
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

cls
$fileOutPath = "C:\temp\$($Cluster)\"
If(-not (Test-Path $fileOutPath)){ $outNull = mkdir $fileOutPath }
$logPath = "$($fileOutPath)$($Cluster)_migration.log"
Write-Host "Log Location : $($logPath)"

Write-Log -Path $logPath -Message "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
Write-Log -Path $logPath -Message "[$(Get-Date)]`tScript Starting"

$hostCred = Get-Credential -UserName root -Message "Please provide the ESXi host root password"

Write-Host "`n`n`n`n`n`n`n`n`n`n`n`n`n" #spacing to show text/errors below the progress bars
$tmp.DateTime #Date when the script executed. this is because we clear the screen after snapins/modules load
[array]$taskTracer = @()

Write-Log -Path $logPath -Message "[$(Get-Date)]`tConnecting to vCenter $($SourceVcenter)"
$vi = Connect-VIServer -Server $SourceVcenter -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
If(-not [string]::IsNullOrEmpty($vi)){ 
	Write-Progress -Activity "Connected to Source vCenter $($vi.Name)" -PercentComplete 100 -Id 90
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tSucessfully Connected to vCenter $($SourceVcenter)"
}
Else{ Write-Log -Path $logPath -Message "[$(Get-Date)]`tFailed to Connect to vCenter $($SourceVcenter)"; Exit 1 }
 
[array]$PermissionReport = @()
[array]$folderReport = @()
[array]$ExcludeFolderList = @()
[array]$resPoolReport = @()
[array]$vAppPoolReport = @()
[array]$resPoolVms = @()
[array]$vAppPoolVms = @()
[array]$allMyVds = @()
[array]$allDsgs = @()
[int]$progress = 0

Write-Progress -Activity "Query Cluster $($Cluster)" -Id 91 -PercentComplete (100*(1/5))
Write-Log -Path $logPath -Message "[$(Get-Date)]`tQuery Cluster $($Cluster)"
$cl = Get-View -ViewType ClusterComputeResource -Filter @{"Name"=$Cluster}
Write-Progress -Activity "Query Cluster $($Cluster)" -Id 91 -PercentComplete (100*(2/5))
Write-Log -Path $logPath -Message "[$(Get-Date)]`tQuery Cluster $($Cluster) ESXi Hosts"
[array]$vmhosts = Get-View -ViewType HostSystem -SearchRoot $cl.MoRef
Write-Progress -Activity "Query Cluster $($Cluster)" -Id 91 -PercentComplete (100*(3/5))
Write-Log -Path $logPath -Message "[$(Get-Date)]`tQuery Cluster $($Cluster) Virtual Machines"
[array]$allVms = Get-View -ViewType VirtualMachine -SearchRoot $cl.MoRef
Write-Log -Path $logPath -Message "[$(Get-Date)]`tQuery Cluster $($Cluster) Templates"
[array]$allTemplates = Get-Template | ?{$vmhosts.Moref -contains $_.ExtensionData.Runtime.Host}
Write-Progress -Activity "Query Cluster $($Cluster)" -Id 91 -PercentComplete (100*(4/5))
Write-Log -Path $logPath -Message "[$(Get-Date)]`tQuery Cluster $($Cluster) Resource Pools"
#When pulling resource pools from Get-View it will pull the cluster since a cluster is a resource pool. So if we exclude the name "Resources" then
# this is excluding the cluster object. Also, VirtualApps are considered Resource pools so we exclude vApps too. 
# We need to use this get view method for efficiency as well as to pull any nested resource pools.
[array]$resPools = Get-View -ViewType ResourcePool -SearchRoot $cl.MoRef | ?{$_.Name -ne "Resources" -and  $_.MoRef -notlike "VirtualApp-resgroup*"}
Write-Progress -Activity "Query Cluster $($Cluster)" -Id 91 -PercentComplete 100 -Completed
Write-Log -Path $logPath -Message "[$(Get-Date)]`tQuery Cluster $($Cluster) Completed"
Write-Progress -Activity "Query Cluster $($Cluster)" -Id 91 -PercentComplete (100*(5/5))
Write-Log -Path $logPath -Message "[$(Get-Date)]`tQuery Cluster $($Cluster) vApps"
[array]$vApps = Get-View -ViewType VirtualApp -SearchRoot $cl.MoRef
Write-Progress -Activity "Query Cluster $($Cluster)" -Id 91 -PercentComplete 100 -Completed
Write-Log -Path $logPath -Message "[$(Get-Date)]`tQuery Cluster $($Cluster) Completed"
[array]$allDsgs = Get-View -ViewType StoragePod
$dc = Get-View -ViewType Datacenter -Filter @{"Name"=(Get-ObjectPath -Object $cl -ObjType "ClusterComputeResource" -ExcludeFolder $ExcludeFolderList).Path.Split("/")[1]}

##########################################################
#  LIST OF EXCLUDED FOLDERS BY ID
	#Exclude the hidden folders for each view
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type VM -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type Datastore -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type Network -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type HostAndCluster -NoRecursion).Id
##########################################################

#region Verify root access on each host (Complete)
#Verify root access
$esxiCount=0
$loginError = @()
$vmhosts | %{ $esxi = $_; $esxiCount++
	Write-Progress -Activity "Verifying root access to the ESXi host $($esxi.Name)" -PercentComplete (100*($esxiCount/$vmhosts.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tVerifying Root Password on host $($esxi.Name)"
	$loginVerify = Connect-VIServer -Server $esxi.Name -Credential $hostCred -ErrorAction SilentlyContinue
	If([string]::IsNullOrEmpty($loginVerify)){
		$loginError += $esxi.Name
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Unable to Connect to the ESXi host $($esxi.Name) with the provided password"
	}
	Disconnect-VIServer -Server $esxi.Name -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}
If(-not [string]::IsNullOrEmpty($loginError)){
	$tmpstr = ""
	$loginError | %{ [string]$tmpstr = "$($tmpstr)$($_)," }
	$host.UI.WriteErrorLine("Unable to Connect to the ESXi hosts $($tmpstr) with the provided password. Please verify the correct root password and re-run this script. You may need to ensure that ALL esxi hosts in the cluster have the same root password`n")
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: SCRIPT EXITING: Exit Code 99"
	Exit 99
}
#the DefaultVIServers variable gets updated when verifying the ESXi Host
# So we need to "reconnect" to vCenter to populate the DefaultVIServers variable so all of the commands work
$vi = Connect-VIServer -Server $SourceVcenter -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92

$clObj = Get-VIObjectByVIView -MORef $cl.MoRef
$taskTracer += Set-TaskTracer -Entity $cl.Name -Action "DisableDrsHa" -OriginalConfiguration "$($clObj.DrsAutomationLevel),$($clObj.HAEnabled)"
$clObj | Set-VmCluster -DrsAutomationLevel:Manual -Confirm:$false | Out-Null

#region Gather Roles (Complete)
#we should pull all of the VI roles and their settings so that we can recreate them in the new vCenter
# We store this in a XML file for simplicity purposes.
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting vCenter Roles"
$vInventory = [xml]"<Inventory><Roles/><Permissions/></Inventory>"
# Roles
$XMLRoles = Get-XmlNode "Inventory/Roles"
Get-Roles | where {-not $_.System} | % {
	$XMLRole = New-XmlNode $XMLRoles "Role"
	Set-XmlAttribute $XMLRole "Name" $_.Name
	Set-XmlAttribute $XMLRole "Label" $_.Label
	Set-XmlAttribute $XMLRole "Summary" $_.Summary
	$_.Privilege | % {
		$XMLPrivilege = New-XmlNode $XMLRole "Privilege"
		Set-XmlAttribute $XMLPrivilege "Name" $_
	}
}
#save the XML file so we can retrieve it later.
$vInventory.Save("$($fileOutPath)$($cl.Name)_ExportRoles.xml")
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting vCenter Roles`t$($fileOutPath)$($cl.Name)_ExportRoles.xml"
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Permissions and path (Complete)
	$esxiCount = 0	
	$permCount = 0
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting vCenter Permissions"
	If(Test-Path "$($fileOutPath)$($vi.Name)_permissionsReport.csv"){ $PermissionReport = Import-Csv "$($fileOutPath)$($vi.Name)_permissionsReport.csv" }
	If([string]::IsNullOrEmpty($PermissionReport)){
		$viprms = Get-VIPermission
		$viprms | %{ $viprm = $_; $permCount++
		Write-Progress -Activity "Gathering VI Permission Information" -PercentComplete (100*($permCount/$viprms.Count)) -Id 91
		If($viprm.EntityId.StartsWith("Folder")){ 
			# The entity ID will look for example like  Folder-group-h685. So if we see the entityid start with Folder we need to do additional evaluations
			# We want to look at the last section, from above that would be h685. This is because the beginning letter tells us what type of folder
			# we are dealing with. For example h685 is a HostAndCluster folder. Below are how to decode the beginning letter.
			#  d = Datacenter
			#  h = HostAndCluster folder
			#  v = VM folder
			#  s = Datastore folder
			#  n = Network folder

			If($viprm.EntityId -eq "Folder-group-d1"){ $Type = "root" }
			Else{ $tmpprm = ($viprm.EntityId.Split("-"))[2].Substring(0,1)
				Switch (($viprm.EntityId.Split("-"))[2].Substring(0,1))
				{
					"h"	{$Type="Folder-HostAndCluster"}
					"v"	{$Type="Folder-VM"}
					"s"	{$Type="Folder-Datastore"}
					"n"	{$Type="Folder-Network"}
				}
			}
		}
		Else{ $Type = ($viprm.EntityId.Split("-"))[0] }
		
		$pso = New-Object PSObject -Property @{
			Entity=$viprm.Entity.Name
			Path=(Get-ObjectPath -Object $viprm.Entity.ExtensionData -ObjType $Type -ExcludeFolder $ExcludeFolderList).Path
			Principal=$viprm.Principal
			Role=$viprm.Role
			Type=$Type
			IsGroup=($viprm.IsGroup -as [Boolean])
			Propagate=($viprm.Propagate -as [Boolean])
		}
		If([string]::IsNullOrEmpty($pso.Path) -and $pso.Entity -eq "Datacenters"){
			#this is a root permission, so lets fill in the "Path" property with /root
			$pso.Path = "/root"
		}
		$PermissionReport += $pso
	}
}
	
	Write-Progress -Activity "Gathering Folder Structure Information for Datacenter/Cluster $($dc.Name)/$($cl.Name)" -PercentComplete (100*(1/2)) -Id 91
	$objPath = Get-ObjectPath -Object $dc -ObjType "Datacenter" -ExcludeFolder $ExcludeFolderList
	Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"
	$folderReport += $objPath
	Write-Progress -Activity "Gathering Folder Structure Information for Datacenter/Cluster $($dc.Name)/$($cl.Name)" -PercentComplete 99 -Id 91
	#get the cluster permissions
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Cluster $($Cluster) Object Path"
	$objPath = Get-ObjectPath -Object $cl -ObjType "ClusterComputeResource" -ExcludeFolder $ExcludeFolderList
	Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"
	$folderReport += $objPath
	Write-Progress -Activity "Gathering Folder Structure Information for Datacenter/Cluster $($dc.Name)/$($cl.Name)" -PercentComplete (100*(2/2)) -Id 91 -Completed
	
	[array]$templateReport = @()
	#loop through the cluster hosts and gather path and permissions
	$vmhosts | %{ $esxi = $_
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting ESXi Host $($esxi.Name) Object Path"
		$esxiCount++
		$vmCount = 0
		$vappCount = 0
		Write-Progress -Activity "Gathering Folder Structure Information for Host $($esxi.Name)" -PercentComplete (100*($esxiCount/$cl.Host.Count)) -Id 91
		$objPath = Get-ObjectPath -Object $esxi -ObjType "HostSystem" -ExcludeFolder $ExcludeFolderList
		Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"
		$folderReport += $objPath
		
		Get-VDSwitch -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) | %{ $vds = $_
			$objPath = Get-ObjectPath -Object $vds.ExtensionData -ObjType "Network" -ExcludeFolder $ExcludeFolderList
			If($folderReport -notcontains $objPath){ Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"; $folderReport += $objPath }
		}
		
		#Write-Progress -Activity "Gathering VM Folder Structure Information on Host $($esxi.Name)" -PercentComplete (100*($esxiCount/$cl.Host.Count)) -Id 91
		#for each host gather all of the VMs and get the VM paths (this tells us the folder heiarchy) and also pull permissions for each VM
		$allVms | ?{$_.Runtime.Host -eq $esxi.MoRef} | %{ $vm = $_
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting VM $($vm.Name) on ESXi Host $($esxi.Name) Object Path"
			$vmCount++
			Write-Progress -Activity "Gathering Folder Structure Information for VM $($vm.Name)" -PercentComplete (100*($vmCount/$esxi.Vm.Count)) -ParentId 91 -Id 92
			#we need to check if this VM is part of a vAPP, because we cannot gather the individual VM path as it is masked by the vAPP
			If(-not [string]::IsNullOrEmpty($vm.ParentVApp)){ 
				$vapp = Get-View $vm.ParentVApp
				$objPath = Get-ObjectPath -Object $vapp -ObjType "vApp" -ExcludeFolder $ExcludeFolderList
				If($folderReport -notcontains $objPath){ Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"; $folderReport += $objPath }
				
				$objPath = (Get-ObjectPath -Object (Get-View $vapp.ParentFolder) -ObjType "vAppVMFolder" -ExcludeFolder $ExcludeFolderList)
				$objPath.Path = $objPath.Path+"/"+"$($vapp.Name)"
				$objPath.IdPath = $objPath.IdPath+"/"+$vapp.MoRef
				If($folderReport -notcontains $objPath){ Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"; $folderReport += $objPath }
				
				$objPath = Get-ObjectPath -Object $vapp -ObjType "vAppVM" -ExcludeFolder $ExcludeFolderList
				$objPath.Path = $objPath.Path+"/"+"$($vm.Name)"
				$objPath.IdPath = $objPath.IdPath+"/"+$vm.MoRef
				If($folderReport -notcontains $objPath){ Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"; $folderReport += $objPath }
				
				If(-not [string]::IsNullOrEmpty($vapp.VAppConfig.Property)){
					#This is a vApp that is configured and deployed by a vendor and has configuration parameters that don't migrate from vCenter to vCenter.
					# Need to alert the user that this cluster can't be migrated with this script. vendor vApps with configuration data need to be migrated manually
					# and the process is somewhat involved.
					$host.UI.WriteErrorLine("A vApp has been discovered that contains configuration data likely from a Vendor.`nThese types of vApps cannot be migrated to a new vCenter automatically.`nThis will have to be a manual migration`n")
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: A vApp has been discovered that contains configuration data likely from a Vendor. These types of vApps cannot be migrated to a new vCenter automatically. This will have to be a manual migration. SCRIPT EXITING: Exit Code 100"
					Exit 100
				}
			}Else{ 
				If(($vm.Config.Template -as [Bool])){
					#Is Template - this doesn't seem to work
					
				}Else{
					$objPath = Get-ObjectPath -Object $vm -ObjType "VirtualMachine" -ExcludeFolder $ExcludeFolderList
					Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"
					$folderReport += $objPath
				}
			}
			
			#Temp Store VM network adapter portgroup
			[array]$vmNetworks += $vm.Network | %{ If($_.Type -eq "DistributedVirtualPortgroup"){ $_.Value } }
		}
		Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Id 92 -Completed
		
		$allTemplates | ?{$_.ExtensionData.Runtime.Host -eq $esxi.MoRef} | %{ $temp = $_
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Template $($temp.Name)on ESXi Host $($esxi.Name) Object Path"
			Write-Progress -Activity "Gathering Folder Structure Information for Template $($temp.Name)" -PercentComplete (100*($vmCount/$esxi.Vm.Count)) -ParentId 91 -Id 92
			$objPath = Get-ObjectPath -Object $temp.ExtensionData -ObjType "Template" -ExcludeFolder $ExcludeFolderList
			Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"
			$folderReport += $objPath
			#this is a tenplate lets go ahead and gather the template info as well
			$tmp = $temp.ExtensionData.LayoutEx.File | ?{$_.Name.EndsWith(".vmx")}
			If([string]::IsNullOrEmpty($tmp)){ $vmxPath = ($temp.ExtensionData.LayoutEx.File | ?{$_.Type -eq "Config"}).Name }
			Else{ $vmxPath = $tmp.Name.Replace(".vmx",".vmtx") }
			$pso = New-Object PSObject -Property @{
				Name="$($temp.Name)"
				VMHost=$esxi.Name
				VmxPath=$vmxPath
			}
			$templateReport += $pso
			[array]$vmNetworks += $temp.ExtensionData.Network | %{ If($_.Type -eq "DistributedVirtualPortgroup"){ $_.Value } }
		}
	}
	Write-Progress -Activity "Waiting ..." -Id 92 -Completed
	$dsCount = 0
	[array]$dsgReport = @()
	#loop through all of the datastrores of the cluster and pull the path and permissions of each datastore object
	$cl.Datastore | %{ $ds = Get-View $_
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Cluster $($Cluster) Datastore $($ds.Name) Object Path"
		$dsCount++
		Write-Progress -Activity "Gathering Folder Structure Information for Datastore $($ds.Name)" -PercentComplete (100*($dsCount/$cl.Datastore.Count)) -Id 91
		$objPath = Get-ObjectPath -Object $ds -ObjType "Datastore" -ExcludeFolder $ExcludeFolderList
		Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($objPath.Path)"
		$folderReport += $objPath
		
		#Datastore Cluster report
		$chk = $null
		$chk = $allDsgs | ?{$_.ChildEntity -contains $_}
		If(-not [string]::IsNullOrEmpty($chk)){
			$chk2 = $null; $chk2 = $dsgReport | ?{$_.Id -eq $chk.MoRef}
			If(-not [string]::IsNullOrEmpty($chk2)){
				#report doesn't already have this dsg so let's add it
				[array]$dsgReport += New-Object PSObject -Property @{Name="$($chk.Name)";Id=$chk.MoRef;DefaultIntraVmAffinity=$chk.PodStorageDrsEntry.StorageDrsConfig.PodConfig.DefaultIntraVmAffinity}
			}
		}
	}

#export the permissions to a csv
$PermissionReport | Export-Csv "$($fileOutPath)$($vi.Name)_permissionsReport.csv" -NoTypeInformation
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting vCenter Permissions`t$($fileOutPath)$($vi.Name)_permissionsReport.csv"
#export the object path information to a csv
$folderReport | Export-Csv "$($fileOutPath)$($cl.Name)_objectPathReport.csv" -NoTypeInformation
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Object Paths for Cluster, ESXi Hosts, VMs, Datastores`t$($fileOutPath)$($cl.Name)_objectPathReport.csv"
#export template report
$templateReport | Export-Csv "$($fileOutPath)$($cl.Name)_templateReport.csv" -NoTypeInformation
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Template Information`t$($fileOutPath)$($cl.Name)_templateReport.csv"
$dsgReport | Export-Csv "$($fileOutPath)$($cl.Name)_datastoreClusterReport.csv" -NoTypeInformation
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Template Information`t$($fileOutPath)$($cl.Name)_datastoreClusterReport.csv"
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Gather Cluster Settings (Complete)
	Write-Progress -Activity "Gathering Cluster Settings Information for Cluster $($cl.Name)" -PercentComplete (100*(1/2)) -Id 91
	Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Id 92 -ParentId 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Cluster $($Cluster) Settings"
	$cl.ConfigurationEx | %{
		Write-Progress -Activity "Gathering Cluster Configuration, HA, DRS, Admission Control, and EVC for Cluster $($cl.Name)" -PercentComplete 99 -Id 92 -ParentId 91
		$cInfo = New-Object -Type PSObject -Property @{
			ClusterName = "$($cl.Name)"
			HAEnabled = $_.DasConfig.Enabled
			DRSEnabled = $_.DrsConfig.Enabled
			DRSDefaultVmBehavior = $_.DrsConfig.DefaultVmBehavior
			DRSVmotionRate = $_.DrsConfig.VmotionRate
			VmSwapPlacement = $_.VmSwapPlacement
			AdmissionControlEnabled = $_.DasConfig.AdmissionControlEnabled
			VmHostMonitoring = $_.DasConfig.HostMonitoring
			VmMonitoring = $_.DasConfig.VmMonitoring
			HBDatastoreCandidatePolicy = $_.DasConfig.HBDatastoreCandidatePolicy
			CurrentEVCModeKey = $cl.Summary.CurrentEVCModeKey
		}
		"AdmissionControlPolicy,FailoverLevel,CpuFailoverResourcesPercent,MemoryFailoverResourcesPercent,DrsVmNamesManual,DrsVmNamesPartial,DrsVmNamesDisabled".Split(",") | %{Add-Member -InputObject $cInfo -MemberType NoteProperty -Name $_ -Value $null}
		Switch($_){
			{$_.DasConfig.AdmissionControlPolicy -is [VMware.Vim.ClusterFailoverLevelAdmissionControlPolicy]} {
				$cInfo.AdmissionControlPolicy = $_.DasConfig.AdmissionControlPolicy.GetType().Name
				$cInfo.FailoverLevel = $_.DasConfig.AdmissionControlPolicy.FailoverLevel
				break;
			}
			{$_.DasConfig.AdmissionControlPolicy -is [VMware.Vim.ClusterFailoverResourcesAdmissionControlPolicy]} {
				$cInfo.AdmissionControlPolicy = $_.DasConfig.AdmissionControlPolicy.GetType().Name
				$cInfo.CpuFailoverResourcesPercent = $_.DasConfig.AdmissionControlPolicy.CpuFailoverResourcesPercent
				$cInfo.MemoryFailoverResourcesPercent = $_.DasConfig.AdmissionControlPolicy.MemoryFailoverResourcesPercent
				break;
			}
		}
			If($_.DrsVmConfig -ne $null){
				$cInfo.DrsVmNamesManual = ($_.DrsVmConfig | ?{$_.Behavior -eq "manual"} | %{ 
					Get-View -Property Name -Id $_.Key -ErrorAction SilentlyContinue | %{
						"$($_.Name)"
					}
					}) -join ","
				$cInfo.DrsVmNamesPartial = ($_.DrsVmConfig | ?{$_.Behavior -eq "partiallyAutomated"} | %{ 
					Get-View -Property Name -Id $_.Key -ErrorAction SilentlyContinue | %{
						"$($_.Name)"
					}
					}) -join ","
				$cInfo.DrsVmNamesDisabled = ($_.DrsVmConfig | %{
					$drsStat = $_.Enabled
					If(-not $drsStat){
						Get-View -Property Name -Id $_.Key -ErrorAction SilentlyContinue | %{
							"$($_.Name)"
						}
					}
					}) -join ","
			}			
			
			$cInfo | Select ClusterName,HAEnabled,DRSEnabled,DRSVmotionRate,AdmissionControlEnabled,vmHostMonitoring,VmMonitoring,HBDatastoreCandidatePolicy,AdmissionControlPolicy,FailoverLevel,CpuFailoverResourcesPercent,MemoryFailoverResourcesPercent,VmSwapPlacement,DrsVmNamesManual,DrsVmNamesPartial,DrsVmNamesDisabled,CurrentEVCModeKey,DRSDefaultVmBehavior
	} | Export-Csv "$($fileOutPath)$($cl.Name)_clusterSettings.csv" -NoTypeInformation
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Cluster $($Cluster) Settings`t$($fileOutPath)$($cl.Name)_clusterSettings.csv"
	
	#get additional HA details
	[array]$haAdvancedReport = @()
	If(-not [string]::IsNullOrEmpty($cl.ConfigurationEx.DasVmConfig)){
		$cl.ConfigurationEx.DasVmConfig | %{ $das = $_; [bool]$commitChanges=$false
			$pso = New-Object PSObject -Property @{
				Vm=(Get-View -Id $das.Key).Name
				VmId=$das.Key
				ClusterName="$($cl.Name)"
				RestartPriority=$das.RestartPriority
				PowerOffOnIsolation=$das.PowerOffOnIsolation
				DasRestartPriority=$null
				IsolationResponse=$null
				Enabled=$null
				VmMonitoring=$null
				ClusterSettings=$null
				FailureInterval=$null
				MinUpTime=$null
				MaxFailures=$null
				MaxFailureWindow=$null
			}
			$das.DasSettings | ?{-not [string]::IsNullOrEmpty($_.RestartPriority) -and $_.RestartPriority -ne "clusterRestartPriority"} | %{ $obj = $_
				[bool]$commitChanges=$true
				$pso.DasRestartPriority=$obj.RestartPriority
			}
			$das.DasSettings | ?{-not [string]::IsNullOrEmpty($_.IsolationResponse) -and $_.IsolationResponse -ne "clusterIsolationResponse"} | %{ $obj = $_
				[bool]$commitChanges=$true
				$pso.IsolationResponse=$obj.IsolationResponse
			}
			$das.DasSettings| ?{(-not [string]::IsNullOrEmpty($_.VmToolsMonitoringSettings.Enabled)) -or (-not [string]::IsNullOrEmpty($_.VmToolsMonitoringSettings.VmMonitoring))} | %{ $obj = $_
				[bool]$commitChanges=$true
				$pso.Enabled=$obj.VmToolsMonitoringSettings.Enabled;
				$pso.VmMonitoring=$obj.VmToolsMonitoringSettings.VmMonitoring;
				$pso.ClusterSettings=$obj.VmToolsMonitoringSettings.ClusterSettings;
				$pso.FailureInterval=$obj.VmToolsMonitoringSettings.FailureInterval;
				$pso.MinUpTime=$obj.VmToolsMonitoringSettings.MinUpTime;
				$pso.MaxFailures=$obj.VmToolsMonitoringSettings.MaxFailures;
				$pso.MaxFailureWindow=$obj.VmToolsMonitoringSettings.MaxFailureWindow
			}
			
			If($commitChanges){ [array]$haAdvancedReport += $pso }
		}
		
		$haAdvancedReport | Select Vm,VmId,RestartPriority,PowerOffOnIsolation,DasRestartPriority,IsolationResponse,Enabled,VmMonitoring,ClusterSettings,FailureInterval,MinUpTime,MaxFailures,MaxFailureWindow | Export-Csv "$($fileOutPath)$($cl.Name)_clusterHAadvanced.csv" -NoTypeInformation -ErrorAction SilentlyContinue
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collectin Cluster $($Cluster) Advanced HA settings`t$($fileOutPath)$($cl.Name)_clusterHAadvanced.csv"
	}
	
	Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Id 92 -ParentId 91
	Write-Progress -Activity "Gathering Cluster Settings Information for Cluster $($cl.Name)" -PercentComplete (100*(2/2)) -Id 91
	Write-Progress -Activity "Checking for DRS rules for cluster $($cl.Name)" -PercentComplete 99 -Id 92 -ParentId 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Cluster $($Cluster) DRS Rules"
	# if the cluster has any DRS rules
    if ($cl.ConfigurationEx.Rule -ne $null) {
		Write-Progress  -Activity "Gathering Cluster Data Post Migration : DRS Rules, DRS Groups, VM DRS Overrides ..." -PercentComplete 99 -Id 92 -ParentId 91
        $cl.ConfigurationEx.Rule | %{
            $oRuleInfo = New-Object -Type PSObject -Property @{
                ClusterName = "$($cl.Name)"
                RuleName = "$($_.Name)"
                RuleType = $_.GetType().Name
                bRuleEnabled = $_.Enabled
                bMandatory = $_.Mandatory
            } 

            # add members to the output object, to be populated in a bit
            "bKeepTogether,VMNames,VMGroupName,VMGroupMembers,AffineHostGrpName,AffineHostGrpMembers,AntiAffineHostGrpName,AntiAffineHostGrpMembers,DrsVmNamesManual".Split(",") | %{Add-Member -InputObject $oRuleInfo -MemberType NoteProperty -Name $_ -Value $null}

            # switch statement based on the object type of the .NET view object
            switch ($_){
                # if it is a ClusterVmHostRuleInfo rule, get the VM info from the cluster View object
                #   a ClusterVmHostRuleInfo item "identifies virtual machines and host groups that determine virtual machine placement"
                {$_ -is [VMware.Vim.ClusterVmHostRuleInfo]} {
                    $oRuleInfo.VMGroupName = "$($_.VmGroupName)"
                    # get the VM group members' names
					$chk=$null; $chk = ($cl.ConfigurationEx.Group | ?{($_ -is [VMware.Vim.ClusterVmGroup]) -and ($_.Name -eq $oRuleInfo.VMGroupName)}).Vm
					If(-not [string]::IsNullOrEmpty($chk)){
                    	$oRuleInfo.VMGroupMembers = (Get-View -Property Name -Id ($cl.ConfigurationEx.Group | ?{($_ -is [VMware.Vim.ClusterVmGroup]) -and ($_.Name -eq $oRuleInfo.VMGroupName)}).Vm | %{$_.Name}) -join ","
					}
					$oRuleInfo.AffineHostGrpName = $_.AffineHostGroupName
                    # get affine hosts' names
                    $chk=$null;$chk = ($cl.ConfigurationEx.Group | ?{($_ -is [VMware.Vim.ClusterHostGroup]) -and ($_.Name -eq $oRuleInfo.AffineHostGrpName)}).Host
					If(-not [string]::IsNullOrEmpty($chk)){
						$oRuleInfo.AffineHostGrpMembers = if ($_.AffineHostGroupName -ne $null) {(Get-View -Property Name -Id ($cl.ConfigurationEx.Group | ?{($_ -is [VMware.Vim.ClusterHostGroup]) -and ($_.Name -eq $oRuleInfo.AffineHostGrpName)}).Host -ErrorAction SilentlyContinue | %{$_.Name}) -join ","}
					}
					$oRuleInfo.AntiAffineHostGrpName = $_.AntiAffineHostGroupName
                    # get anti-affine hosts' names
                    $chk=$null;$chk = ($cl.ConfigurationEx.Group | ?{($_ -is [VMware.Vim.ClusterHostGroup]) -and ($_.Name -eq $oRuleInfo.AntiAffineHostGrpName)}).Host
					If(-not [string]::IsNullOrEmpty($chk)){
						$oRuleInfo.AntiAffineHostGrpMembers = if ($_.AntiAffineHostGroupName -ne $null) {(Get-View -Property Name -Id ($cl.ConfigurationEx.Group | ?{($_ -is [VMware.Vim.ClusterHostGroup]) -and ($_.Name -eq $oRuleInfo.AntiAffineHostGrpName)}).Host -ErrorAction SilentlyContinue | %{$_.Name}) -join ","}
					}
                    break;
                } 
                # if ClusterAffinityRuleSpec (or AntiAffinity), get the VM names (using Get-View)
                {($_ -is [VMware.Vim.ClusterAffinityRuleSpec]) -or ($_ -is [VMware.Vim.ClusterAntiAffinityRuleSpec])} {
                    $oRuleInfo.VMNames = if ($_.Vm.Count -gt 0) {(Get-View -Property Name -Id $_.Vm -ErrorAction SilentlyContinue | %{"$($_.Name)"}) -join ","}
                } 
                {$_ -is [VMware.Vim.ClusterAffinityRuleSpec]} {
                    $oRuleInfo.bKeepTogether = $true
                } 
                {$_ -is [VMware.Vim.ClusterAntiAffinityRuleSpec]} {
                    $oRuleInfo.bKeepTogether = $false
                } 
                default {"none of the above"}
            } 
            $oRuleInfo
        } | Export-Csv "$($fileOutPath)$($cl.Name)_clusterRules.csv" -NoTypeInformation -ErrorAction SilentlyContinue
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Cluster $($Cluster) DRS Rules`t$($fileOutPath)$($cl.Name)_clusterRules.csv"
    } 
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Gather Custom Attributes and Tags (not Complete - NEED TO TEST GATHERING AND SORTNG OUT TAGS)
#Unsure if custom attributes follow when a host is moved to a new vcenter. My initial thought is that custom attributes are a vcenter
#  level setting and if you chnage the vCenter then the attributes disappear. I will need to test this when I have a chance
#need to pull custom attributes for every object I can.
#valid target types are
#  VirtualMachine
#  ResourcePool
#  Folder
#  VMHost
#  Cluster
#  Datacenter
#  $null ( these are global attributes for all target types)

#need to pull vCenter Tags so I can recreate them in the new vcenter.
#Get-Tag
[array]$customAttributeReport = @()
[array]$MoTypes = @()

#let's pull the custom fields and their managed object type so that we can then pull each objects values
#going through the serviceInstance Custom fields manager is the easier option to pull this data. Alternatively we can pul it via Get-CustomAttribute
# but this way is more efficient

Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Id 92 -ParentId 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Custom Attributes"

$SI = Get-View ServiceInstance
$CFM = Get-View $SI.Content.CustomFieldsManager
$CFM.Field | %{ $cfd = $_
	$pso = New-Object PSObject -Property @{
		Key=$cfd.Key
		Name="$($cfd.Name)"
		Type=$cfd.Type
		ManagedObjectType=$cfd.ManagedObjectType
		FieldDefPriviledgesCreate=$cfd.FieldDefPrivileges.CreatePrivilege
		FieldDefPriviledgesRead=$cfd.FieldDefPrivileges.ReadPrivilege
		FieldDefPriviledgesUpdate=$cfd.FieldDefPrivileges.UpdatePrivilege
		FieldDefPriviledgesDelete=$cfd.FieldDefPrivileges.DeletePrivilege
		FieldInstancePriviledgesCreate=$cfd.FieldInstancePrivileges.CreatePrivilege
		FieldInstancePriviledgesRead=$cfd.FieldInstancePrivileges.ReadPrivilege
		FieldInstancePriviledgesUpdate=$cfd.FieldInstancePrivileges.UpdatePrivilege
		FieldInstancePriviledgesDelete=$cfd.FieldInstancePrivileges.DeletePrivilege
	}
	[array]$customAttributeReport += $pso # we will store the fields info so that we can rebuild these same fields in the new vCenter
	#Let's store the Object types so that we only query releavnt objects and not every single object of which some may not have custom field
	If($MoTypes -notcontains $pso.ManagedObjectType){ [array]$MoTypes += $pso.ManagedObjectType }
}
$customAttributeReport | ?{$_.ManagedObjectType -ne "ScheduledTask"} | Export-Csv "$($fileOutPath)$($cl.Name)_customAttributeReport.csv" -NoTypeInformation
If(-not [string]::IsNullOrEmpty($MoTypes)){
	[array]$objCustomValues = @()
	[array]$MoRef = @()
	#Loop through each type and pull all data for that type
	$MoTypes | %{ $MoType = $_
		If($MoType -eq "Datacenter"){ [array]$MoRef += $dc }
		ElseIf( $MoType -eq "Cluster"){ [array]$MoRef += $cl }
		ElseIf( $MoType -eq "ClusterComputeResource"){ [array]$MoRef += $cl }
		ElseIf( $MoType -eq "HostSystem"){ [array]$MoRef += $vmhosts }
		ElseIf( $MoType -eq "VirtualMachine"){ [array]$MoRef += $allVms }
		ElseIf($MoType -eq "ComputeResource"`
			-or $MoType -eq "Datastore"`
			-or $MoType -eq "DistributedVirtualPortgroup"`
			-or $MoType -eq "DistributedVirtualSwitch"`
			-or $MoType -eq "Folder"`
			-or $MoType -eq "Network"`
			-or $MoType -eq "OpaqueNetwork"`
			-or $MoType -eq "ResourcePool"`
			-or $MoType -eq "StoragePod"`
			-or $MoType -eq "VirtualApp"`
			-or $MoType -eq "VmwareDistributedVirtualSwitch"
		){ [array]$MoRef += Get-View -ViewType $MoType -SearchRoot $cl.MoRef -ErrorAction SilentlyContinue }
		[int]$morefCount = 0
		If(-not [string]::IsNullOrEmpty($MoRef)){
			$MoRef | %{ $obj = $_
				$morefCount++
				Write-Progress -Activity "Gathering Custom Attribute Values for $($obj.Name)" -PercentComplete (100*($morefCount/$MoRef.Count)) -Id 91
				$fieldsCount = 0
				[array]$Fields = $customAttributeReport | ?{$_.ManagedObjectType -eq $MoType}
				$Fields | %{ $objCf = $_
				$fieldsCount++
					Write-Progress -Activity "Gathering Custom Attribute $($objCf.Name) Value for $($obj.Name)" -PercentComplete (100*($fieldsCount/$Fields.Count)) -Id 92 -ParentId 91 -ErrorAction SilentlyContinue
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tGathering Custom Attribute $($objCf.Name) Value for $($obj.Name)"
					$obj.CustomValue | ?{$_.Key -eq $objCf.Key} | %{ $cv = $_
						Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($obj.Name) Custom Attribute $($objCf.Name) Value $($cv.Value)"
						$pso = New-Object PSObject -Property @{
							Key=$cv.Key
							Name="$($objCf.Name)"
							Value=$cv.Value
							ManagedObjectType=$objCf.ManagedObjectType
							Entity="$($obj.Name)"
						}
						[array]$objCustomValues += $pso
					}
				}
			}
		}
	}
}
$objCustomValues | Export-Csv "$($fileOutPath)$($cl.Name)_objCustomAttributeReport.csv" -NoTypeInformation
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Custom Attributes`t$($fileOutPath)$($cl.Name)_objCustomAttributeReport.csv"
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Id 92 -ParentId 91

##########################################
# Need to test for vCenter TAGs
# vCenter tags not supported in vCenter 5.0, only 5.5+
##########################################

#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Gather resource Pool information including VMs in each resource pool (Complete)
If(-not [string]::IsNullOrEmpty($resPools)){
	Write-Progress -Activity "Gathering Resource Pool Information for Cluster $($cl.Name)" -PercentComplete 99 -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Resource Pool Configurations"
	[int]$resPoolCount = 0
	$resPoolReport = @()
	$resPoolVms = @()

	$resPools | %{ $rp = $_
		$resPoolCount++
		#Write-Progress -Activity "Gathering Resource Pool Settings for Resource Pool $($rp.Name)" -PercentComplete (100*($resPoolCount/$resPools.Count)) -Id 92 -ParentId 91
		$pso = New-Object PSObject -Property @{
			Name="$($rp.Name)";
			CpuReservation=$rp.Config.CpuAllocation.Reservation;
			CpuExpanndableReservation=$rp.Config.CpuAllocation.ExpandableReservation;
			CpuLimit=$rp.Config.CpuAllocation.Limit;
			CpuShares=$rp.Config.CpuAllocation.Shares.Shares;
			CpuSharesLevel=$rp.Config.CpuAllocation.Shares.Level;
			CpuOverheadLimit=$rp.Config.CpuAllocation.OverheadLimit;
			MemReservation=$rp.Config.MemoryAllocation.Reservation;
			MemExpanndableReservation=$rp.Config.MemoryAllocation.ExpandableReservation;
			MemLimit=$rp.Config.MemoryAllocation.Limit;
			MemShares=$rp.Config.MemoryAllocation.Shares.Shares;
			MemSharesLevel=$rp.Config.MemoryAllocation.Shares.Level;
			MemOverheadLimit=$rp.Config.MemoryAllocation.OverheadLimit
		}
		$resPoolReport += $pso
		
		$rp.Vm | %{ $tmpvm = $_; $vm = $allVms | ?{$_.MoRef -eq $tmpvm}
			$pso = New-Object PSObject -Property @{
				ResourcePool="$($rp.Name)";
				VM="$($vm.Name)";
			}
			$resPoolVms += $pso
		}	
	}
	Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Id 92 -ParentId 91
	$resPoolReport | Export-Csv "$($fileOutPath)$($cl.Name)_resourcePoolReport.csv" -NoTypeInformation
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Resource Pool Configurations`t$($fileOutPath)$($cl.Name)_resourcePoolReport.csv"
	$resPoolVms | Export-Csv "$($fileOutPath)$($cl.Name)_resourcePoolVms.csv" -NoTypeInformation
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Resource Pool VMs`t$($fileOutPath)$($cl.Name)_resourcePoolVms.csv"
}
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Gather vApp Pool information including VMs in each vApp pool (Complete)
If(-not [string]::IsNullOrEmpty($vApps)){
	Write-Progress -Activity "Gathering vApp Pool Information for Cluster $($cl.Name)" -PercentComplete 99 -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting vApp Pool Configurations"
	[int]$progress = 0
	$vAppPoolReport = @()
	$vAppPoolVms = @()

	$vApps | %{ $vapp = $_; $progress++
		Write-Progress -Activity "Gathering vApp Pool Settings for Resource Pool $($vApp.Name)" -PercentComplete (100*($progress/$vApps.Count)) -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting vApp Pool $($vapp.name) Settings"
		$pso = New-Object PSObject -Property @{
			Name="$($vapp.Name)";
			CpuReservation=$vapp.Config.CpuAllocation.Reservation;
			CpuExpanndableReservation=$vapp.Config.CpuAllocation.ExpandableReservation;
			CpuLimit=$vapp.Config.CpuAllocation.Limit;
			CpuShares=$vapp.Config.CpuAllocation.Shares.Shares;
			CpuSharesLevel=$vapp.Config.CpuAllocation.Shares.Level;
			CpuOverheadLimit=$vapp.Config.CpuAllocation.OverheadLimit;
			MemReservation=$vapp.Config.MemoryAllocation.Reservation;
			MemExpanndableReservation=$vapp.Config.MemoryAllocation.ExpandableReservation;
			MemLimit=$vapp.Config.MemoryAllocation.Limit;
			MemShares=$vapp.Config.MemoryAllocation.Shares.Shares;
			MemSharesLevel=$vapp.Config.MemoryAllocation.Shares.Level;
			MemOverheadLimit=$vapp.Config.MemoryAllocation.OverheadLimit
		}
		$vAppPoolReport += $pso
		
		$vapp.Vm | %{ $tmpvm = $_; $vm = $allVms | ?{$_.MoRef -eq $tmpvm}
			$pso = New-Object PSObject -Property @{
				vAppPool="$($vapp.Name)";
				VM="$($vm.Name)";
				StartOrder=($vapp.vAppConfig.EntityConfig | ?{$_.Key -eq $tmpvm}).StartOrder;
				StartDelay=($vapp.vAppConfig.EntityConfig | ?{$_.Key -eq $tmpvm}).StartDelay;
				WaitingForguest=($vapp.vAppConfig.EntityConfig | ?{$_.Key -eq $tmpvm}).WaitingForguest;
				StartAction=($vapp.vAppConfig.EntityConfig | ?{$_.Key -eq $tmpvm}).StartAction;
				StopDelay=($vapp.vAppConfig.EntityConfig | ?{$_.Key -eq $tmpvm}).StopDelay;
				StopAction=($vapp.vAppConfig.EntityConfig | ?{$_.Key -eq $tmpvm}).StopAction;
				DestroyWithParent=($vapp.vAppConfig.EntityConfig | ?{$_.Key -eq $tmpvm}).DestroyWithParent;
			}
			$vAppPoolVms += $pso
		}	
	}
	Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Id 92 -ParentId 91
	$vAppPoolReport | Export-Csv "$($fileOutPath)$($cl.Name)_vAppPoolReport.csv" -NoTypeInformation
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting vApp Pool Configurations`t$($fileOutPath)$($cl.Name)_vAppPoolReport.csv"
	$vAppPoolVms | Export-Csv "$($fileOutPath)$($cl.Name)_vAppPoolVms.csv" -NoTypeInformation
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting vApp Pool VMs`t$($fileOutPath)$($cl.Name)_vAppPoolVms.csv"
}
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Gather VDS and portgroup settings (Complete)
# we will just grab portgroup and vlan info to create the vSwitch
# the new VDS in the new vCenter will be created when the new vCenter is created
# we will just need to build new portgroups if the source portgroup doesn't exist in the destination vds
# there are too many variables to account for in code to create a new VDS. 
# In newer versions of vSphere (5.1+) we can just export the VDS and portgroups and then import them into the new vcenter 
# with Export-VDSwitch and Import-VDswitch. However in 5.0 this doesn't exist and can't be done. Since this script is being written
# to migrate from 5.0 vCenter to 5.5+ then we won't worry about the VDS as much in code. This section will be rewritten for future migrations
# to incorporate the new cmdlets.
Write-Progress -Activity "Gathering Distributed Portgroup Information for Cluster $($cl.Name)" -PercentComplete 99 -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Distributed Virtual Portgroups"
$dvpgReport = @()
$networks = ($vmhosts.Network | Select -Unique)
#$dvpgTotal = ($vmhosts.Network | Select -Unique)
$dvpgCount = 0
$networks | ?{$_ -like "DistributedVirtualPortGroup*" } | %{ $dvpg = Get-View $_
# pull only the dvpg's. The $cl.Network will show both dvpg and standard vswitch pg and for migration purposes we only care about the dvpg's
	$dvpgCount ++
	#exclude the DVUplinks pg since this gets created when the new vds is created. It is possible that uplinks have been renamed from the default naming, in which this will need to be updated.
	If($dvpg.Name -notlike "*DVUplinks*"){ 
	Write-Progress -Activity "Gathering Settings for Distributed Portgroup $($dvpg.Name)" -PercentComplete (100*($dvpgCount/$networks.Count)) -Id 92 -ParentId 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tGathering Settings for Distributed Portgroup $($dvpg.Name)"
		[string]$vlanTrunk = $null
		If(($dvpg.Config.DefaultPortConfig.Vlan.VlanId.GetType()).FullName -like "*NumericRange*"){
		#check if this is a numeric range which means the pg is set as a vlan trunk and not a single specific vlan ID
			$vlanId = 4095 #for vSwitches you set the pg as 4095 for trunk ranges, but in dvpg you specify the vlans such as 1,8,10-13. 
			[array]$trunk = @()
			$dvpg.Config.DefaultPortConfig.Vlan.VlanId | %{ $tmpdvpg = $_
			# lets pull the set vlan trunk ranges on the dvpg so we can restore them in the new vcenter if they don't exist
				$trunk += "$($tmpdvpg.Start)-$($tmpdvpg.End)"
			}
			$trunk | %{ 
				If([string]::IsNullOrEmpty($vlanTrunk)){ $vlanTrunk = $_ }
				Else{ [string]$vlanTrunk = "$($vlanTrunk),$($_)" }
			}
			Write-Log -Path $logPath -Message "[$(Get-Date)]`t`tDistributed Portgroup $($dvpg.Name) : VLAN Trunk $($vlanTrunk)"
		}Else{
			$vlanId = $dvpg.Config.DefaultPortConfig.Vlan.VlanId
			Write-Log -Path $logPath -Message "[$(Get-Date)]`t`tDistributed Portgroup $($dvpg.Name) : VLAN Id $($vlanId)"
		}
		#form the PSObject. There is a Vds  property but also a VdsName. The reasoning for this is if there is an issue during the migration process than
		# we need to be able to export the information to a CSV to preserve the information. We can't export an object with additional properties to CSV
		# So when exporting we don't export Vds but we will export the name along with all of the other properties. If the script is re-ran then these files
		# will be imported back in to the script and Vds will be populated at that time so the migration can continue.
		If($dvpg.Name -like "*%2f*"){ (Get-VIObjectByVIView -MORef $dvpg.MoRef) | Set-VDPortgroup -Name $dvpg.Name.Replace("%2f","_"); $dvpg.UpdateViewData() }
		$tmpVds = (Get-VDSwitch -Id $dvpg.Config.DistributedVirtualSwitch)
		$pso = New-Object PSObject -Property @{
			Name="$($dvpg.Name)";
			Id=$dvpg.Key
			NumPorts=$dvpg.Config.NumPorts;
			Description=$dvpg.Config.Description;
			Type=$dvpg.Config.Type;
			UplinkOrder=$dvpg.Config.DefaultPortConfig.UplinkTeamingPolicy.UplinkPortOrder
			AutoExpand=$dvpg.Config.AutoExpand;
			VlanId=$vlanId
			VlanTrunk=$vlanTrunk
			Vds=$tmpVds
			VdsName="$($tmpVds.Name)"
			VdsVersion=$tmpVds.Version
		}
		#$pso.VdsName=$pso.Vds.Name
		$dvpgReport += $pso
	}
}

#dedup $dvpgReport to get the number of standard switches needed. I am using a hash table to do this
$tmpEAP = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
$dedupVdsHsh = @{}
$VdsToVssHsh = @{}
$vssCount = 0
$dvpgReport | %{ $obj = $_
	$dedupVdsHsh.Add($obj.VdsName,$obj.Vds)
	If($VdsToVssHsh.Keys -notcontains "$($obj.VdsName)"){ $vssCount++
		$VdsToVssHsh.Add("$($obj.VdsName)","vSwitchMigrate$($vssCount)")
	}
}
$ErrorActionPreference = $tmpEAP

Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Distributed Virtual Portgroup Uplink Configurations"
[HashTable]$ActiveUplink = @{}
[HashTable]$StandbyUplink = @{}
[array]$SingleUplink = @()
$dedupVdsHsh.Keys | %{ $ActiveUplink.Add($_,@()); $StandbyUplink.Add($_,@()) }
$dvpgReport | %{ $pg = $_
	$ActiveUplink[$pg.Vds.Name] += $pg.UplinkOrder.ActiveUplinkPort
	$StandbyUplink[$pg.Vds.Name] += $pg.UplinkOrder.StandbyUplinkPort
	If($pg.UplinkOrder.ActiveUplinkPort.Count -eq 1 -and $pg.UplinkOrder.StandbyUplinkPort.Count -eq 0){
		#Check to see if there is only a single Active uplink and no standby uplinks
		#If we find a portgroup like this then we are forced to use the "spare" vmnic that isn't being used
		#So we will have to find all of the vmnic on each esxi host for that VDS that maps to that unused uplink
		Write-Warning "Found a single uplink only configuration on Portgroup : $($pg.Name)"
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tWARNING: Found a single uplink only configuration on Portgroup : $($pg.Name)"
		#form the PSObject. There is a Vds  property but also a VdsName. The reasoning for this is if there is an issue during the migration process than
		# we need to be able to export the information to a CSV to preserve the information. We can't export an object with additional properties to CSV
		# So when exporting we don't export Vds but we will export the name along with all of the other properties. If the script is re-ran then these files
		# will be imported back in to the script and Vds will be populated at that time so the migration can continue.
		$pso = New-Object PSObject -Property @{
			PortgroupName="$($pg.Name)"
			ActiveUplink=$pg.UplinkOrder.ActiveUplinkPort[0]
			UnusedUplink=($pg.Vds.ExtensionData.Config.UplinkPortPolicy.UplinkPortName | ?{$_ -ne $pg.UplinkOrder.ActiveUplinkPort[0]})
			Vds = "$($pg.Vds.Name)"
			VdsName=""
		}
		$pso.VdsName=$pso.Vds
		[array]$SingleUplink += $pso
	}
}
If($SingleUplink.Count -ge 1){
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting Distributed Virtual Portgroup Single Uplink Only Configurations"
	$dedupVdsHsh.Keys | %{ $vdsName = $_	
		#There is a Single uplink.
		# Lets check to ensure that we don't have a situation where 1 pg uses only uplink 1 and another pg uses only uplink 2. This would obviously cause an issue and we need to stop the script if this happens to prevent any outages
		$SingleUplink  | ?{$_.VdsName -eq $vdsName} | %{ $obj = $_
			$chk = $null
			$chk = $SingleUplink | ?{$_.VdsName -eq $vdsName -and $_.ActiveUplink -eq $obj.UnusedUplink}
			If(-not [string]::IsNullOrEmpty($chk)){
				# HOUSTON...WE HAVE A PROBLEM!
				$host.UI.WriteErrorLine("There are portgroups that use only 1 Active uplink. However, these portgroups are using different single-active uplinks, this may cause an outage if an uplink is removed. Please review. Script Exiting ...")
				"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
				"          Please Review           "
				"              Below               "
				$SingleUplink  | ?{$_.VdsName -eq $vdsName} | Select Vds,PortgroupName,ActiveUplink,UnusedUplink | Format-Table -AutoSize
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Distributed Virtual Portgroup Single Uplink Only Configurations"
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: There are portgroups that use only 1 Active uplink. However, these portgroups are using different single-active uplinks, this may cause an outage if an uplink is removed"
				$result = $SingleUplink  | ?{$_.VdsName -eq $vdsName} | Select Vds,PortgroupName,ActiveUplink,UnusedUplink | Format-Table -AutoSize | Out-String
				Write-Log -Path $logPath -Message "$($result)"
				Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Script Exiting with Failure Code 1"
				Exit 1 #exit because we don't want to continue and break things
			}
		}
	}
}

Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Id 92
$dvpgReport | Select Name,Id,NumPorts,Description,Type,AutoExpand,VlanId,VlanTrunk,VdsName,VdsVersion | Export-Csv "$($fileOutPath)$($cl.Name)_dvpgreport.csv" -NoTypeInformation
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting Distributed Virtual Portgroups Information`t$($fileOutPath)$($cl.Name)_dvpgreport.csv"
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Gather host VMkernel and vmnic information (Complete)
#need to pull the VMKernel interfaces and determine if they are on a VDS or standard switch.
# if they are on standard switch then we don't care because it doesn't need to be migrated. Only vmk's on vds we care about.
$vmkReport = @()
$vmnicReport = @()
$esxiCount = 0
$vmhosts | %{ $esxi = $_
	#get the VMKernel information that sits on a dvpg not standard pg
	$esxiCount++
	Write-Progress -Activity "Gathering VMKernel and vmNic Information for Host $($esxi.Name)" -PercentComplete (100*($esxiCount/$cl.Host.Count)) -Id 91
	$vmkCount = 0
	$esxi.Config.Network.Vnic | ?{ -not [string]::IsNullOrEmpty($_.Spec.DistributedVirtualPort) } | %{ $vmk = $_; $vmkCount++
		Write-Progress -Activity "Gathering Information for VMKernel $($vmk.Device)" -PercentComplete (100*($vmkCount/$esxi.Config.Network.Vnic.Count)) -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting ESXi Host $($esxi.Name) VMKernel Adapter $($vmk.Device) Information"
		$NicType = @()
		$esxi.Config.VirtualNicManagerInfo.NetConfig | ?{-not [string]::IsNullOrEmpty($_.SelectedVnic)} | %{ $vnic=$_
			$chk = $vnic.SelectedVnic | ?{$_ -like "*$($vmk.Key)"}
			If(-not [string]::IsNullOrEmpty($chk)){
				$NicType += $vnic.NicType
			}
		}
		$vmkType = ""
		$NicType | %{ 
			If([string]::IsNullOrEmpty($vmkType)){ [string]$vmkType= $_ }
			Else{[string]$vmkType = "$($vmkType),$($_)"}
		}
		#form the PSObject. There is DvPg and Vds but also a DvPgName and VdsName. The reasoning for this is if there is an issue during the migration process than
		# we need to be able to export the information to a CSV to preserve the information. We can't export an object with additional properties to CSV
		# So when exporting we don't export DvPg and Vds but we will export the names along with all of the other properties. If the script is re-ran then these files
		# will be imported back in to the script and DvPg and Vds will be populated at that time so the migration can continue.
		$pso = New-Object PSObject -Property @{
			VMHost="$($esxi.Name)";
			VMHostId=$esxi.MoRef
			Device=$vmk.Device;
			VmkKey=$vmk.Key
			Type=$vmkType
			Mtu=$vmk.Spec.Mtu;
			DvPg=(Get-VDPortgroup -Id ("DistributedVirtualPortgroup-$($vmk.Spec.DistributedVirtualPort.PortgroupKey)"));
			DvPgName=""
			DvPgVlan=""
			Vds=(Get-VDSwitch -RelatedObject (Get-VDPortgroup -Id ("DistributedVirtualPortgroup-$($vmk.Spec.DistributedVirtualPort.PortgroupKey)")))
			VdsName=""
			Vss=$null
		}
		$pso.DvPgName="$($pso.DvPg.Name)"
		$pso.DvPgVlan=$pso.DvPg.VlanConfiguration.VlanId
		$pso.VdsName="$($pso.Vds.Name)"
		$pso.Vss=$VdsToVssHsh["$($pso.Vds.Name)"]
		$vmkReport += $pso
	}
	
	#get vmnic info for VDS only, we don't care about standard switches so we use the ProxySwitch property
	$esxi.Config.Network.ProxySwitch | %{ $vds = $_; $vmnicCount = 0
		$vds.Spec.Backing.PnicSpec | %{ $pnic = $_ ;$vmnicCount++
			Write-Progress -Activity "Gathering Information for vmNic $($pnic.PnicDevice)" -PercentComplete (100*($vmnicCount/$vds.Pnic.Count)) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tCollecting ESXi Host $($esxi.Name) Physical Nic Adapter $($pnic.PnicDevice) Information"
			$tmp = $vds.UplinkPort | ?{$_.Key -eq $pnic.UplinkPortKey}
			$pso = New-Object PSObject -Property @{
				VMHost="$($esxi.Name)"
				Vmnic=$pnic.PnicDevice
				UplinkPortKey=$pnic.UplinkPortKey
				UplinkPortgroupKey=$pnic.UplinkPortgroupKey
				UplinkName=$tmp.Value
				UplinkPosition=([array]::IndexOf($vds.UplinkPort,$tmp))
				Vds="$($vds.DvsName)"
			}
			$vmnicReport += $pso
		}
	}
}

#Look for Single VMNICs on a VDS and stop the script
[array]$tmpVDSlist = $vmnicReport.Vds | Select -Unique
[array]$tmpEsxiList = $vmnicReport.VMHost | Select -Unique
[string[]]$errStr = @()
$tmpVDSlist | %{ $vds = $_
	$tmpEsxiList | %{ $esxi = $_
		[array]$parse = $vmnicReport | ?{$_.Vds -eq $vds -and $_.VMHost -eq $esxi}
		If($parse.Count -le 1){
			#ESXi host has 1 or less VMNICs on this VDS
			[string[]]$errStr += "ESXi Host $($esxi) only has $($parse.Count) vmnics on VDS $($vds)."
		}
	}
}
If(-not [string]::IsNullOrEmpty($errStr)){
	$host.UI.WriteErrorLine("There are ESXi Hosts that have 1 or less Active VMNICs. This may cause an outage if a VMNIC is removed. Please review. Script Exiting ...")
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: There are ESXi Hosts that have 1 or less Active VMNICs. This may cause an outage if a VMNIC is removed. Please review. Script Exiting ..."
	$errStr | %{ 
		$host.UI.WriteErrorLine("$($_)")
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: $($_)"
	}
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Script Exiting with Failure Code 25"
	exit 25
}

$vmkReport | Select VMHost,VMHostId,Device,VmkKey,Type,Mtu,DvPgName,DvPgVlan,VdsName,Vss | Export-Csv "$($fileOutPath)$($cl.Name)_vmkReport.csv" -NoTypeInformation
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting ESXi Host VMKernel Adapter Information`t$($fileOutPath)$($cl.Name)_vmkReport.csv"
$vmnicReport | Select VMHost,Vmnic,UplinkPortKey,UplinkPortgroupKey,UplinkName,UplinkPosition,Vds | Export-Csv "$($fileOutPath)$($cl.Name)_vmnicReport.csv" -NoTypeInformation
Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Collecting ESXi Host Physical Nic Adapter Information`t$($fileOutPath)$($cl.Name)_vmnicReport.csv"
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Disable Cluster DRS and HA
Write-Progress -Activity "Disabling DRS and HA on cluster $($cl.Name)" -PercentComplete 90 -Id 91
$clObj = Get-VIObjectByVIView -MORef $cl.MoRef
$taskTracer += Set-TaskTracer -Entity $cl.Name -Action "DisableDrsHa" -OriginalConfiguration "$($clObj.DrsAutomationLevel),$($clObj.HAEnabled)"
$clObj | Set-VmCluster -DrsAutomationLevel:Manual -HAEnabled:$false -Confirm:$false | Out-Null
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region create standard switches for each host with vds and portgroup and vmkernel and vmnic information (Complete)
#Disconnect-VIServer * -Confirm:$false
#exit 0 # keep this here so nothing happens to a real vCenter or VMhost
$VssHsh = @{}
$esxiCount = 0
$RecoveryValues = @{}
$vmhosts | %{ $esxi = $_; $esxiCount++
	Write-Progress -Activity "Creating New vSwitches and Portgroups for VMHost $($esxi.Name)" -PercentComplete (100*($esxiCount/$vmhosts.Count)) -Id 91
	$RecoveryValues.Add($esxi.Name,@())
	$vssCount = 0
	$dedupVdsHsh.Keys | %{ $vssCount++
		$vssName = $VdsToVssHsh["$($_)"]
		Write-Progress -Activity "Creating vSwitch $($vssName) on VMhost $($esxi.Name)" -PercentComplete (100*($vssCount/$dedupVdsHsh.Keys.Count)) -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCreating New Virtual Standard Switch $($vssName) on Host $($esxi.Name)"
		#I will standardize on 1024 ports as it is highly unlikely this number of ports is too small
		#I will standardize on MTU 9000 as there could be amix of 1500 and 9000 portgroups. For VSS you cannot set MTU per portgroup.
		#I am also adding _migrate to the VSS to indicate this is a migration switch only
		#For VSS, the Name cannot be longer than 31 characters
		$NewVss = New-VirtualSwitch -Name ("$($vssName)") -NumPorts 1024 -Mtu 9000 -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Confirm:$false
		If([string]::IsNullOrEmpty($NewVss)){ #The variable didn't set during the creation so I will run Get-VirtualSwitch
			$NewVss = Get-VirtualSwitch -Standard -Name ("$($vssName)") -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef)
		}Else{ $taskTracer += Set-TaskTracer -Entity $esxi.Name -ModifiedObject $NewVss.Name -Action "CreateVss" -OriginalConfiguration $null -ModifiedConfiguration $NewVss.Name }
		$VssHsh.Add("$($esxi.Name)|$($vssName)",$NewVss) #create a hash table that stores the virtual switch object for each host and each vSwitch
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Creating New Virtual Standard Switch $($vssName) on Host $($esxi.Name)"
	}
}
Write-Progress -Activity "Waiting..." -Completed -Id 92

#create standard virtual portgroups
$pgCount = 0
$vmNetworks | Select -Unique | %{ $obj = $_; $pgCount++
	$pg = $dvpgReport | ?{$_.Id -eq $obj}
	[string]$vssName = $VdsToVssHsh["$($pg.VdsName)"]
	Write-Progress -Activity "Creating Portgroup $($pg.Name)_m on vSwitch $($vssName)" -PercentComplete (100*($pgCount/$dvpgReport.Count)) -Id 91
	$result = $vmhosts | Select Name,MoRef | Format-Table -AutoSize | Out-String
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCreating New Virtual Standard Switch Portgroup $($pg.Name)_m on Hosts:"
	Write-Log -Path $logPath -Message "$($result)"
	#$vss = $VssHsh["$($esxi.Name)|$($pg.Vds)_migrate"] #recall the vSwitch
	$vlanId = If([string]::IsNullOrEmpty($pg.VlanTrunk)){ ($pg.VlanId -as [int]) }Else{ 4095 }
	$newPg = Get-VIObjectByVIView -MORef $vmhosts.MoRef | Get-VirtualSwitch -Name "$($vssName)" -Standard | New-VirtualPortGroup -Name ("$($pg.Name)_m") -VLanId $vlanId -Confirm:$false -ErrorAction SilentlyContinue
	If([string]::IsNullOrEmpty($newPg)){
		$newPg = Get-VIObjectByVIView -MORef $vmhosts.MoRef | Get-VirtualSwitch -Name "$($vssName)" -Standard | Get-VirtualPortGroup -Name ("$($pg.Name)_m") -ErrorAction SilentlyContinue
	}Else{ $taskTracer += Set-TaskTracer -Entity "$($vssName)" -ModifiedObject $newPg -Action "CreateVssPg" -OriginalConfiguration $null -ModifiedConfiguration $newPg.Name }
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Creating New Virtual Standard Switch Portgroup $($pg.Name)_m"
	######## NEED A VALIDATION STEP HERE ###########
	
}
$vmhosts.UpdateViewData() #update the View data since have now added a VSS and portgroups

#Now we need to remove 1 vmnic from the VDS and move it to the appropriate VSS
#Before we do this we need to check all of the dvpgs to ensure there is either an Active/Active, or Active/Standby, or Unused/Unused uplink setup.
#Each portgroup can be set individually so there are a number of possibilities and we need to find the uplink that we can remove that will 
#   minimize any potential impacts to Guest VMs and VMkernels.
#We need to ensure that if there is a portgroup with only a single uplink then we are forced to use the other vmnic.
#If all portgroups resolve as either active/active or active/standby then we will use the standby vmnic uplink.
#I have already counted the number of times a vmnic uplink is used as active and as standby and now need to choose the uplink that will have minimal impact
#If the numbers are equal then I will choose the lower priority uplink
#Once I identify the uplink to use I can then identify per host what vmnic maps to that uplink
$esxiCount = 0
$vmhosts | %{ $esxi = $_; $esxiCount++
	Write-Progress -Activity "Migrating ESXi Host $($esxi.Name) physical nic to standard switch" -PercentComplete (100*($esxiCount/$vmhosts.Count)) -Id 91
	$dedupVdsHsh.Keys | %{ $vds = $_
		[string]$vssName = $VdsToVssHsh["$($vds)"]
		$chk = $null
		$chk = $SingleUplink | ?{$_.VdsName -eq $vds}
		If(-not [string]::IsNullOrEmpty($chk)){
			#single uplink so we need to use the unused uplink for these vds
			$tmp = ($SingleUplink | ?{$_.VdsName -eq $vds})[0]
			$tmp.UnusedUplink | %{ $uu = $_
				$esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $tmp.VdsName} | %{ $obj = $_
					$vdsUplinkKey = ($obj.UplinkPort | ?{$_.Value -eq $uu}).Key
					$pnic = $obj.Spec.Backing.PnicSpec | ?{$_.UplinkPortKey -eq $vdsUplinkKey}
					$recoveryStr = "esxcfg-vswitch -P $($pnic.PnicDevice) -V $($pnic.UplinkPortKey) $($vds)"
					$RecoveryValues[$esxi.Name] += $recoveryStr
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating ESXi Host $($esxi.Name) Physical Nic $($pnic.PnicDevice) to VSS $($vssName)"
					$rmvmnic = Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter (Get-VMHostNetworkAdapter -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Name $pnic.PnicDevice) -Confirm:$false
					$setVss = Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $VssHsh["$($esxi.Name)|$($vssName)"] -VMHostPhysicalNic (Get-VMHostNetworkAdapter -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Name $pnic.PnicDevice) -Confirm:$false
					$taskTracer += Set-TaskTracer -Entity $esxi.Name -ModifiedObject $pnic.PnicDevice -Action "VmnicFromVdsToVss" -OriginalConfiguration $vds -ModifiedConfiguration $VssHsh["$($esxi.Name)|$($vssName)"].Name
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tCompleted Migrating ESXi Host $($esxi.Name) Physical Nic $($pnic.PnicDevice) to VSS $($vssName)"
				}
			}
		}Else{
			#Need to determine which vmnic is best to move by evaluating ActiveUplinks and StandbyUplinks
			$au = $ActiveUplink[$vds] | Select -Unique
			$su = $StandbyUplink[$vds] | Select -Unique
			
			If([string]::IsNullOrEmpty($su)){
				#No Standby vmnic so lets pick the lower priority vmnic
				$vdsUplinkPortPolicy = $dedupVdsHsh[$vds].ExtensionData.Config.UplinkPortPolicy
				$tmp = $vdsUplinkPortPolicy.UplinkPortName[$vdsUplinkPortPolicy.UplinkPortName.Count-1]
				$esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds} | %{ $obj = $_
					$vdsUplinkKey = ($obj.UplinkPort | ?{$_.Value -eq $tmp}).Key
					$pnic = $obj.Spec.Backing.PnicSpec | ?{$_.UplinkPortKey -eq $vdsUplinkKey}
					$recoveryStr = "esxcfg-vswitch -P $($pnic.PnicDevice) -V $($pnic.UplinkPortKey) $($vds)"
					$RecoveryValues[$esxi.Name] += $recoveryStr
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating ESXi Host $($esxi.Name) Physical Nic $($pnic.PnicDevice) to VSS $($vssName)"
					$rmvmnic = Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter (Get-VMHostNetworkAdapter -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Name $pnic.PnicDevice) -Confirm:$false
					$setVss = Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $VssHsh["$($esxi.Name)|$($vssName)"] -VMHostPhysicalNic (Get-VMHostNetworkAdapter -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Name $pnic.PnicDevice) -Confirm:$false
					$taskTracer += Set-TaskTracer -Entity $esxi.Name -ModifiedObject $pnic.PnicDevice -Action "VmnicFromVdsToVss" -OriginalConfiguration $vds -ModifiedConfiguration $VssHsh["$($esxi.Name)|$($vssName)"].Name
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Migrating ESXi Host $($esxi.Name) Physical Nic $($pnic.PnicDevice) to VSS $($vssName)"
				}
				
			}Else{
				#we have a mix of active and standby
				#Let's iterate through the standby and see what is best to use by counting which uplink is used as standby the most
				$storeUplink = $null
				[int]$storeUplinkCount = 0
				$su | %{ $obj = $_
					[array]$tmpa=$null
					$tmpa = $StandbyUplink[$vds] | ?{$_ -eq $obj}
					If($tmpa.Count -ge $storeUplinkCount){ $storeUplinkCount = $tmpa.Count; $storeUplink = $obj }
				}
				$esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds} | %{ $obj = $_
					$vdsUplinkKey = ($obj.UplinkPort | ?{$_.Value -eq $storeUplink}).Key
					$pnic = $obj.Spec.Backing.PnicSpec | ?{$_.UplinkPortKey -eq $vdsUplinkKey}
					$recoveryStr = "esxcfg-vswitch -P $($pnic.PnicDevice) -V $($pnic.UplinkPortKey) $($vds)"
					$RecoveryValues[$esxi.Name] += $recoveryStr
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating ESXi Host $($esxi.Name) Physical Nic $($pnic.PnicDevice) to VSS $($vssName)"
					$rmvmnic = Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter (Get-VMHostNetworkAdapter -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Name $pnic.PnicDevice) -Confirm:$false
					$setVss = Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $VssHsh["$($esxi.Name)|$($vssName)"] -VMHostPhysicalNic (Get-VMHostNetworkAdapter -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Name $pnic.PnicDevice) -Confirm:$false
					$taskTracer += Set-TaskTracer -Entity $esxi.Name -ModifiedObject $pnic.PnicDevice -Action "VmnicFromVdsToVss" -OriginalConfiguration $vds -ModifiedConfiguration $VssHsh["$($esxi.Name)|$($vssName)"].Name
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Migrating ESXi Host $($esxi.Name) Physical Nic $($pnic.PnicDevice) to VSS $($vssName)"
				}
			}
		}
		#region Verify ESXi Host Connectivity
		#Need to verify we can still communicate with the ESXi host after removing a vmnic from the VDS
		# If we cannot communicate to the esxi host then we will need to re-add the vmnic to the VDS and re-evaluate the plan
		# esxcfg-vswitch -P vmnic -V unused_dvPort_ID dvSwitch      # add a vDS uplink
		# http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1008127
		
		$connected = $true
		Write-Progress -Activity "Verifying Connectivity has not been lost." -PercentComplete 95 -Id 92 -ParentId 91
		Sleep -Seconds 5 # lets pause for a couple of seconds before we test
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tVerifying Host $($esxi.Name) Connectivity"
		$chk = $null
		$chk = Test-Connection -ComputerName $esxi.Name -ErrorAction SilentlyContinue
		
		If([string]::IsNullOrEmpty($chk)){
			Write-Host "HOST CONNECTIVITY HAS BEEN LOST!!! VMs may be affected!"
			Write-Host "  For recovery please follow the below steps:"
			Write-Host "
			    1. Login to the DCUI via lights-out management
			    2. Enable ESXi Shell
			    3. Press Alt+F1 to access the ESXi Shell
			    4. Login using root credentials
			    5. Run the following Command(s)"
				$RecoveryValues[$esxi.Name]
				"`n`nPlease review KB Article http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1008127`n"
				
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: HOST CONNECTIVITY HAS BEEN LOST!!! VMs may be affected!"
				Write-Log -Path $logPath -Message "Recovery Steps for $($esxi.Name)"
				Write-Log -Path $logPath -Message "1. Login to the DCUI via lights-out management"
				Write-Log -Path $logPath -Message "2. Enable ESXi Shell"
				Write-Log -Path $logPath -Message "3. Press Alt+F1 to access the ESXi Shell"
				Write-Log -Path $logPath -Message "4. Login using root credentials"
				Write-Log -Path $logPath -Message "5. Run the following Command(s)"
				Write-Log -Path $logPath -Message "$($RecoveryValues[$($esxi.Name)])"
				Write-Log -Path $logPath -Message "Please review KB Article http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1008127"
				
				Write-Warning "Rolling back changes. Please verify all changes have been rolled back prior to running this script again."
				Write-Progress -Activity "Rolling Back Changes" -PercentComplete 95 -Id 91
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tRolling Back All Changes"
				Rollback-Changes $taskTracer
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Rolling Back All Changes"
				Exit 2
		}Else{ Write-Host "Esxi host $($esxi.Name) connectivity verified after moving physical NIC." -BackgroundColor DarkGreen;Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Verifying Host $($esxi.Name) Connectivity" }
		Write-Progress -Activity "Verifying Connectivity has not been lost." -Completed -Id 92
		#endregion
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Move VMKernels to standard vSwitch (Complete)
#Need to move the VMKernels on VDS to VSS
	$vmkCount = 0
	$vmkReport | %{ $vmk = $_; $vmkCount++
		#[string]$vssName = $VdsToVssHsh["$($vmk.VdsName)"]
		Write-Progress  -Activity "Migrating VMkernel Interface $($vmk.Device) on Host $($vmk.VMHost) to the Standard switch $($vmk.Vss)" -PercentComplete (100*($vmkCount/$vmkReport.Count)) -Id 91
	 	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating VMKernel Adapter $($vmk.Device) on Host $($vmk.VMHost) to VSS $($vmk.Vss)"
		$rtrn = Move-VmkernelAdapterToVss -VMHostId $vmk.VMHostId -Interface $vmk.Device -NetworkName ("$($vmk.Type)-$($vmk.Device)-v$($vmk.DvPg.VlanConfiguration.VlanId)") -VirtualSwitch $vmk.Vss -Vlan $vmk.DvPg.VlanConfiguration.VlanId
		$taskTracer += Set-TaskTracer -Entity $vmk.VMHost -ModifiedObject $vmk.Device -Action "VmkFromVdsToVss" -OriginalConfiguration $vmk.DvPg  -ModifiedConfiguration ("$($vmk.Type)-$($vmk.Device)-v$($vmk.DvPg.VlanConfiguration.VlanId)")
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Migrating VMKernel Adapter $($vmk.Device) on Host $($vmk.VMHost) to VSS $($vmk.Vss)"
		
		Write-Progress -Activity "Verifying Connectivity has not been lost." -PercentComplete 95 -Id 92 -ParentId 91
		$tmp = $vmhosts | ?{$_.MoRef -eq $vmk.VMHostId}
		Sleep -Seconds 5
		$chk = $null
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tVerifying Host $($vmk.VMHost) Connectivity"
		$chk = Test-Connection -ComputerName $vmk.VMHost -ErrorAction SilentlyContinue
		If([string]::IsNullOrEmpty($chk)){
			Write-Host "HOST CONNECTIVITY HAS BEEN LOST!!! VMs should NOT be affected at this time as this outagae is due to VMKernel migrations, however, host connectivity needs to be restored"
			Write-Host "This script is exiting due to this issue and to prevent any further issues with other hosts"
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: HOST CONNECTIVITY HAS BEEN LOST!!! VMs should NOT be affected at this time as this outagae is due to VMKernel migrations, however, host connectivity needs to be restored"
			Rollback-Changes $taskTracer
			Exit 3
		}Else{ Write-Host "Esxi host $($vmk.VMHost) connectivity verified after moving VMKernel Adapter." -BackgroundColor DarkGreen;Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Verifying Host $($vmk.VMHost) Connectivity" }
		Write-Progress -Activity "Verifying Connectivity has not been lost." -Completed -Id 92
	}
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Move VMs to the standard switch (Complete)
[array]$vmnaChanged = @()
[int]$vmnaCount = 0
$allVmsNas = Get-VIObjectByVIView -MORef $allVms.MoRef | Get-NetworkAdapter
$vmnaTotal = ($allVmsNas | ?{$_.ExtensionData.Backing.GetType().Name -eq "VirtualEthernetCardDistributedVirtualPortBackingInfo"}).Count
$allVmsNas | ?{$_.ExtensionData.Backing.GetType().Name -eq "VirtualEthernetCardDistributedVirtualPortBackingInfo"} | %{ $vmna = $_; $vmnaCount++
	Write-Progress  -Activity "Migrating VM Network Adapter $($vmna.Name) on VM $($vmna.Parent.Name) to VSS" -PercentComplete (100*($vmnaCount/$vmnaTotal)) -Id 91
	$pso = New-Object PSObject -Property @{
		VmName=$vmna.Parent.Name
		VmId=$vmna.ParentId
		VmNaLabel=$vmna.ExtensionData.DeviceInfo.Label
		Original=$vmna.NetworkName
		OriginalId=$vmna.ExtensionData.Backing.Port.PortgroupKey
		Modified=$null
		ModifiedId=$null
	}
	If(-not [string]::IsNullOrEmpty($vmna.NetworkName)){
		$tmpName = "$($vmna.NetworkName)_m"
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving VM $($vmna.Parent.Name) from DvPg $($pso.Original) to VSS Pg $($tmpName)"
		$tmpvmna = Set-NetworkAdapter -NetworkAdapter $vmna -NetworkName $tmpName -Confirm:$false
		If($tmpvmna.NetworkName -ne $tmpName){
			#the changing of the network adapter failed log it and output to the user and pause
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Changing Network Adapter $($pso.VmNaLabel) for VM $($vmna.Parent.Name)"
			$host.UI.WriteErrorLine("Failed to change the network adapter $($pso.VmNaLabel) for VM $($vmna.Parent.Name)")
			Write-Warning "Pausing the script until this VM is addressed. Press Any Key to Continue with the script..."
			pause
			$tmpvmna = Get-NetworkAdapter -Id $vmna.Id
		}Else{ $taskTracer += Set-TaskTracer -Entity $vmna.Parent.Name -ModifiedObject $tmpvmna -Action "MigrateVmFromVdsToVss" -ModifiedConfiguration $tmpvmna.NetworkName -OriginalConfiguration $pso.OriginalId }
		$pso.Modified=$tmpvmna.NetworkName
		$pso.ModifiedId=$tmpvmna.ExtensionData.Backing.Network
		[array]$vmnaChanged += $pso
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Convert Templates to VM and Move to standard switch (Complete)
[array]$failConvert = @()
[int]$tempCount = 0
If($allTemplates.Count -gt 0){
	$allTemplates | %{ $temp = $_; $tempCount++
		#convert Template to VM
		$conVm = $null
		Write-Progress  -Activity "Converting Template $($temp.Name) to VM" -PercentComplete (100*($tempCount/$allTemplates.Count)) -Id 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tConverting Template $($temp.Name) to VM"
		$conVm = Set-Template -Template $temp -ToVM -Confirm:$false -ErrorAction SilentlyContinue
		If([string]::IsNullOrEmpty($conVm)){
			#sometime the first attempt to convert a template fails, but the next try is successful
			Sleep -Seconds 10
			$conVm = Set-Template -Template $temp -ToVM -Confirm:$false -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($conVm)){
				#if it fails again then we can continue as we still have the template path info and can re-register the Template in VC
				#However, lets Log this and track it in an array
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Converting template $($temp.Name) to VM"
				[array]$failConvert += $temp
			}Else{ $taskTracer += Set-TaskTracer -Entity $temp.Name -ModifiedObject $conVm -Action "ConvertTemplateToVm"; $allVms += $conVm.ExtensionData }
		}Else{ $taskTracer += Set-TaskTracer -Entity $temp.Name -ModifiedObject $conVm -Action "ConvertTemplateToVm"; $allVms += $conVm.ExtensionData }
		#after the attempt to convert VM lets check if convert was OK and modify the network
		If(-not [string]::IsNullOrEmpty($conVm)){
			[int]$vmnaCount = 0
			$vmnas = $conVm | Get-NetworkAdapter
			$vmnaTotal = ($vmnas | ?{$_.ExtensionData.Backing.GetType().Name -eq "VirtualEthernetCardDistributedVirtualPortBackingInfo"}).Count
			$vmnas | ?{$_.ExtensionData.Backing.GetType().Name -eq "VirtualEthernetCardDistributedVirtualPortBackingInfo"} | %{ $vmna = $_; $vmnaCount++
				Write-Progress  -Activity "Migrating VM Network Adapter $($vmna.Name) on VM $($vmna.Parent.Name) to VSS" -PercentComplete (100*($vmnaCount/$vmnaTotal)) -Id 92 -ParentId 91
				$pso = New-Object PSObject -Property @{
					VmName=$vmna.Parent.Name
					VmId=$vmna.ParentId
					VmNaLabel=$vmna.ExtensionData.DeviceInfo.Label
					Original=$vmna.NetworkName
					OriginalId=$vmna.ExtensionData.Backing.Port.PortgroupKey
					Modified=$null
					ModifiedId=$null
				}
				If(-not [string]::IsNullOrEmpty($vmna.NetworkName)){
					$tmpName = "$($vmna.NetworkName)_m"
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving VM $($vmna.Parent.Name) from DvPg $($pso.Original) to VSS Pg $($tmpName)"
					$tmpvmna = Set-NetworkAdapter -NetworkAdapter $vmna -NetworkName $tmpName -Confirm:$false
					If($tmpvmna.NetworkName -ne $tmpName){
						#the changing of the network adapter failed log it and output to the user and pause
						Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Changing Network Adapter $($pso.VmNaLabel) for VM $($vmna.Parent.Name)"
						$host.UI.WriteErrorLine("Failed to change the network adapter $($pso.VmNaLabel) for VM $($vmna.Parent.Name)")
						Write-Warning "Pausing the script until this VM is addressed. Press Any Key to Continue with the script..."
						pause
						$tmpvmna = Get-NetworkAdapter -Id $vmna.Id
					}Else{ $taskTracer += Set-TaskTracer -Entity $vmna.Parent.Name -ModifiedObject $tmpvmna -Action "MigrateVmFromVdsToVss" -ModifiedConfiguration $tmpvmna.NetworkName -OriginalConfiguration $pso.OriginalId }
					$pso.Modified=$tmpvmna.NetworkName
					$pso.ModifiedId=$tmpvmna.ExtensionData.Backing.Network
					[array]$vmnaChanged += $pso
				}
				Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
			}
		}
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Verify no VMs or VMKernels are on the VDS (Complete)
Write-Progress  -Activity "Verifying VMs have moved to VSS" -PercentComplete 35 -Id 91
$allVms.UpdateViewData()
$vmhosts.UpdateViewData()
$tmpVms = Get-View $vmhosts.Vm #using this method because the host property .vm holds template objects as well
Do{
	[array]$tmp = @()
	[array]$tmp = $tmpVms | ?{$_.Network.Type -eq "DistributedVirtualPortgroup"}
	$tmp | %{ $vm=$_
		#VM has an interface that is not on the VDS
		Write-Host "ERROR : VM $($vm.Name) is not completely migrated to the vSwitch. It still has an interface on the VDS." -ForegroundColor Red -BackgroundColor Black
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: VM $($vm.Name) is not completely migrated to the vSwitch."
		Write-Host "Pausing until these VMs have been moved to the vSwitch. Please manually migrate these VMs to the vSwitch." -ForegroundColor Cyan -BackgroundColor Black
		pause
	}
	$tmpVms.UpdateViewData()
	[array]$tmp = $tmpVms | ?{$_.Network.Type -eq "DistributedVirtualPortgroup"}
}While(-not [string]::IsNullOrEmpty($tmp))

Write-Progress  -Activity "Verifying ESXi Hosts have moved to vSwitch" -PercentComplete 50 -Id 91
Do{
	[array]$tmp = @()
	[array]$tmp = $vmhosts | ?{$_.Config.Network.Vnic.Spec.DistributedVirtualPort -ne $null}
	$tmp | %{ $esxi=$_
		#VmHost has an interface that is not on the VDS
		Write-Host "ERROR : ESXi Host $($esxi.Name) is not completely migrated to the vSwitch. It still has a VMKernel interface on the VDS." -ForegroundColor Red -BackgroundColor Black
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: ESXi Host $($esxi.Name) is not completely migrated to the vSwitch."
		Write-Host "Pausing until these VMHosts have been moved to the vSwitch. Please manually migrate these VMHosts to the vSwitch." -ForegroundColor Cyan -BackgroundColor Black
		pause
	}
	$vmhosts.UpdateViewData()
	[array]$tmp = $vmhosts | ?{$_.Config.Network.Vnic.Spec.DistributedVirtualPort -ne $null}
}While(-not [string]::IsNullOrEmpty($tmp))
$tmpVms=$null
$tmp=$null
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Move remianing vmnics to VSS (Complete)
[array]$vmnicLastout = @()
$esxiCount = 0
$vmhosts | %{ $esxi = $_; $esxiCount++
	Write-Progress -Activity "Migrating ESXi Host $($esxi.Name) physical nic to standard switch" -PercentComplete (100*($esxiCount/$vmhosts.Count)) -Id 91
	$dedupVdsHsh.Keys | %{ $vds = $_
		$vssName = $VdsToVssHsh["$($vds)"]
		$esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds} | %{ $obj = $_
			$obj.Spec.Backing.PnicSpec | %{ $pnic = $_
				#need to save off the $pnicSpec for the rollback portion if needed
				#the rollback portion will assign the vmnic to the exact same dvUplink, so we need to preserve this data n $pso
				$pso = $vmnicReport | ?{$_.VMHost -eq $esxi.Name -and $_.Vmnic -eq $pnic.PnicDevice}
				[array]$vmnicLastout += $pso
				$recoveryStr = "esxcfg-vswitch -P $($pnic.PnicDevice) -V $($pnic.UplinkPortKey) $($vds)"
				$RecoveryValues[$esxi.Name] += $recoveryStr
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating ESXi Host $($esxi.Name) Physical Nic $($pnic.PnicDevice) to VSS $($vssName)"
				$rmvmnic = Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter (Get-VMHostNetworkAdapter -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Name $pnic.PnicDevice) -Confirm:$false
				$setVss = Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $VssHsh["$($esxi.Name)|$($vssName)"] -VMHostPhysicalNic (Get-VMHostNetworkAdapter -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Name $pnic.PnicDevice) -Confirm:$false
				$taskTracer += Set-TaskTracer -Entity $esxi.Name -ModifiedObject $pso -Action "RemainingVmnicFromVdsToVss" -OriginalConfiguration $vds -ModifiedConfiguration $VssHsh["$($esxi.Name)|$($vssName)"].Name
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Migrating ESXi Host $($esxi.Name) Physical Nic $($pnic.PnicDevice) to VSS $($vssName)"
				
				#region Verify ESXi Host Connectivity
				#Need to verify we can still communicate with the ESXi host after removing a vmnic from the VDS
				# If we cannot communicate to the esxi host then we will need to re-add the vmnic to the VDS and re-evaluate the plan
				# esxcfg-vswitch -P vmnic -V unused_dvPort_ID dvSwitch      # add a vDS uplink
				# http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1008127
				
				$connected = $true
				Write-Progress -Activity "Verifying Connectivity has not been lost." -PercentComplete 95 -Id 92 -ParentId 91
				Sleep -Seconds 5 # lets pause for a couple of seconds before we test
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tVerifying Host $($esxi.Name) Connectivity"
				$chk = $null
				$chk = Test-Connection -ComputerName $esxi.Name -ErrorAction SilentlyContinue
				
				If([string]::IsNullOrEmpty($chk)){
					Write-Host "HOST CONNECTIVITY HAS BEEN LOST!!! VMs may be affected!"
					Write-Host "  For recovery please follow the below steps:"
					Write-Host "
					    1. Login to the DCUI via lights-out management
					    2. Enable ESXi Shell
					    3. Press Alt+F1 to access the ESXi Shell
					    4. Login using root credentials
					    5. Run the following Command(s)"
						$RecoveryValues[$esxi.Name]
						"`n`nPlease review KB Article http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1008127`n"
						
						Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: HOST CONNECTIVITY HAS BEEN LOST!!! VMs may be affected!"
						Write-Log -Path $logPath -Message "Recovery Steps for $($esxi.Name)"
						Write-Log -Path $logPath -Message "1. Login to the DCUI via lights-out management"
						Write-Log -Path $logPath -Message "2. Enable ESXi Shell"
						Write-Log -Path $logPath -Message "3. Press Alt+F1 to access the ESXi Shell"
						Write-Log -Path $logPath -Message "4. Login using root credentials"
						Write-Log -Path $logPath -Message "5. Run the following Command(s)"
						Write-Log -Path $logPath -Message "$($RecoveryValues[$($esxi.Name)])"
						Write-Log -Path $logPath -Message "Please review KB Article http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1008127"
						
						Write-Warning "Rolling back changes. Please verify all changes have been rolled back prior to running this script again."
						Write-Progress -Activity "Rolling Back Changes" -PercentComplete 95 -Id 91
						Write-Log -Path $logPath -Message "[$(Get-Date)]`tRolling Back All Changes"
						Rollback-Changes $taskTracer
						Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Rolling Back All Changes"
						Exit 2
				}Else{ Write-Host "Esxi host $($esxi.Name) connectivity verified after moving physical NIC." -BackgroundColor DarkGreen;Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Verifying Host $($esxi.Name) Connectivity" }
				Write-Progress -Activity "Verifying Connectivity has not been lost." -Completed -Id 92
				#endregion
		
			}
		}
	}
}
$vmhosts.UpdateViewData()
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Removing ESXi Hosts from VDS (Needs Testing)
$esxiCount = 0
$vmhosts | %{ $esxi = $_; $esxiCount++
	Write-Progress -Activity "Removing ESXi Host $($esxi.Name) from VDS" -PercentComplete (100*($esxiCount/$vmhosts.Count)) -Id 91
	[array]$allMyVds = Get-VIObjectByVIView -MORef $esxi.MoRef | Get-VDSwitch
	[int]$vdsCount = 0
	$allMyVds | %{ $vds = $_; $vdsCount++
		Write-Progress -Activity "Removing from VDS $($vds.Name)" -PercentComplete (100*($vdsCount/$allMyVds.Count)) -Id 92 -ParentId 91
		$outNull = Remove-VDSwitchVMHost -VDSwitch $vds -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Confirm:$false
	}
	Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
}
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Remove vApps
Write-Progress -Activity "Removing vApps in Cluster $($cl.Name)" -PercentComplete 95 -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tRemoving vApps in Cluster $($cl.Name)"
$clObj = Get-VIObjectByVIView -MORef $cl.MoRef
$outNull = $clObj | Get-VApp | Get-VM | Move-VM -Confirm:$false -Destination $clObj -ErrorAction SilentlyContinue
$outNull = $clObj | Get-VApp | Remove-VApp -Confirm:$false -ErrorAction SilentlyContinue
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Disable DRS to Remove Resource Pools
Write-Progress -Activity "Disabling DRS/HA on Cluster $($cl.Name)" -PercentComplete 95 -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tDisabling DRS/HA on Cluster $($cl.Name)"
$clObj = Get-VIObjectByVIView -MORef $cl.MoRef
$outNull = $clObj | Set-VmCluster -DrsEnabled:$false -HAEnabled:$false -Confirm:$false
#endregion
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 91
Write-Progress -Activity "Waiting ..." -PercentComplete 0 -Completed -Id 92
#region Disconnect SourceVcenter and Connect to DestinationVcenter
Write-Progress -Activity "Attempting to Disconnect from vCenter $($SourceVcenter)" -PercentComplete 50 -Id 90
Do{
	#sometimes the disconnect doesn't work first and so we have to try again and again until it actually does disconnect
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAttempting to Disconnect from vCenter $($SourceVcenter)"
	Disconnect-VIServer -Server $vi.Name -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Sleep -Seconds 10
}While($vi.IsConnected)
Write-Progress -Activity "Disconnected from vCenter $($SourceVcenter)" -PercentComplete 100 -Id 90
Write-Log -Path $logPath -Message "[$(Get-Date)]`tConnecting to vCenter $($DestinationVcenter)"
Write-Progress -Activity "Connecting to vCenter $($DestinationVcenter)" -PercentComplete 50 -Id 90
Do{
	#sometimes the Connect doesn't work first and so we have to try again and again until it actually does connect
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAttempting to Connect to vCenter $($DestinationVcenter)"
	$vi = Connect-VIServer -Server $DestinationVcenter -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Sleep -Seconds 10
}While(-not $vi.IsConnected)
Write-Progress -Activity "Connected to vCenter $($DestinationVcenter)" -PercentComplete 100 -Id 90
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region get DC and Folder Exclusions
$tmpDc = $dc
$dcObj = Get-Datacenter -Name $dc.Name -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($dcObj)){ $dcObj = New-Datacenter -Name $dc.Name -Location (Get-Folder -NoRecursion) }
$dc = $dcObj.ExtensionData
##########################################################
#  LIST OF EXCLUDED FOLDERS BY ID
	#Exclude the hidden folders for each view
	[array]$ExcludeFolderList = @()
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type VM -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type Datastore -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type Network -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type HostAndCluster -NoRecursion).Id
##########################################################
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Restore Cluster Object
Write-Progress -Activity "Restoring Cluster $($Cluster) on Destination vCenter $($vi.Name)" -PercentComplete 95 -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Cluster $($Cluster) on Destination vCenter $($vi.Name)"
$clObj = Get-VmCluster -Name $Cluster -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($clObj)){
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tCluster not found. Creating Cluster $($Cluster) on Destination vCenter $($vi.Name)"
	$clObj = New-VmCluster -Location (Get-VIObjectByVIView -MORef $dc.MoRef) -Name $Cluster -DrsEnabled -DrsAutomationLevel Manual -HAEnabled -HAAdmissionControlEnabled -VMSwapfilePolicy InHostDatastore
	$cl = Get-View -Id $clObj.Id
}Else{ $cl = Get-View -Id $clObj.Id }
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Restore Folder Structures
$progressCount = 0
$folderReport | %{ $obj = $_; $progressCount++
	Write-Progress -Activity "Restoring Datacenter/Folder Structures $($obj.Path)" -PercentComplete (100*($progressCount/$folderReport.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Datacenter/Folder Structures $($obj.Path)"
	#split the paths as arrays. Index 0 will always be blank
	$aryPath = $obj.Path.Split("/")
	$aryIdPath = $obj.IdPath.Split("/")
	$obj.NewIdPath = ""
	
	$parentObj = $null
	#"$($obj.Path)`t$($obj.IdPath)"
	(1..($aryPath.Count - 1)) | %{ [int]$index = $_
		If($aryIdPath[$index].StartsWith("Datacenter")){
			Write-Progress -Activity "Restoring Datacenter $($aryPath[$($index)])" -PercentComplete (100*($index/($aryPath.Count-1))) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Datacenter $($aryPath[$($index)])"
			#If($aryPath[$index] -eq "0319"){ $aryPath[$index] = "TestDc"} #TESTING ONLY 
			#Object is a datacenter
			#check if Datacenter exists, if not then create it
			$parentObj = Get-Datacenter -Name $aryPath[$index] -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($parentObj)){ $parentObj = New-Datacenter -Name $aryPath[$index] -Location (Get-Folder -NoRecursion) -ErrorAction SilentlyContinue -Confirm:$false }
		}
		ElseIf($aryIdPath[$index].StartsWith("Folder-group-h")){
			Write-Progress -Activity "Restoring Hosts And Clusters Folder $($aryPath[$($index)])" -PercentComplete (100*($index/($aryPath.Count-1))) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Hosts And Clusters Folder $($aryPath[$($index)])"
			#object is a HostAndCluster folder
			#Check if Object exists, if not then create it
			#use a $chk Variable to preserve the parentObj
			$chk=$null; $chk=$parentObj | Get-Folder -Type HostAndCluster -Name $aryPath[$index] -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($chk)){
				#need to check if parentObj is a Datacenter or a Folder as it changes the command structure
				If($parentObj.Id.StartsWith("Datacenter")){ $parentObj = $parentObj | Get-Folder -Type HostAndCluster -NoRecursion | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
				Else{ $parentObj = $parentObj | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
			}Else{ 
				If($chk.Count -gt 1){ 
					#returned multiple folders of the same name, so we have to find the right one
					$chk2 = $null
					If($parentObj.Id.StartsWith("Datacenter")){ $chk2 = $chk | ?{ $ExcludeFolderList -contains $_.ParentId } }
					Else{ $chk2 = $chk | ?{$_.ParentId -eq $parentObj.Id } }
					
					If([string]::IsNullOrEmpty($chk2)){
						#folder doesn't exist so let's create it
						If($parentObj.Id.StartsWith("Datacenter")){ $parentObj = $parentObj | Get-Folder -Type HostAndCluster -NoRecursion | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
						Else{ $parentObj = $parentObj | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
					}Else{ $parentObj = $chk2 }
				}Else{ $parentObj = $chk }
			}
		}
		ElseIf($aryIdPath[$index].StartsWith("Folder-group-v")){
			Write-Progress -Activity "Restoring Virtual Machine Folder $($aryPath[$($index)])" -PercentComplete (100*($index/($aryPath.Count-1))) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Virtual Machine Folder $($aryPath[$($index)])"
			#object is a VM folder
			#Check if Object exists, if not then create it
			#use a $chk Variable to preserve the parentObj
			$chk=$null; $chk=$parentObj | Get-Folder -Type VM -Name $aryPath[$index] -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($chk)){
				#need to check if parentObj is a Datacenter or a Folder as it changes the command structure
				If($parentObj.Id.StartsWith("Datacenter")){ $parentObj = $parentObj | Get-Folder -Type VM -NoRecursion | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
				Else{ $parentObj = $parentObj | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
			}Else{ 
				If($chk.Count -gt 1){ 
					#returned multiple folders of the same name, so we have to find the right one
					$chk2 = $null
					If($parentObj.Id.StartsWith("Datacenter")){ $chk2 = $chk | ?{ $ExcludeFolderList -contains $_.ParentId } }
					Else{ $chk2 = $chk | ?{$_.ParentId -eq $parentObj.Id } }
					
					If([string]::IsNullOrEmpty($chk2)){
						#folder doesn't exist so let's create it
						If($parentObj.Id.StartsWith("Datacenter")){ $parentObj = $parentObj | Get-Folder -Type VM -NoRecursion | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
						Else{ $parentObj = $parentObj | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
					}Else{ $parentObj = $chk2 }
				}Else{ $parentObj = $chk }
			}
		}
		ElseIf($aryIdPath[$index].StartsWith("Folder-group-s")){
			Write-Progress -Activity "Restoring Datastore Folder $($aryPath[$($index)])" -PercentComplete (100*($index/($aryPath.Count-1))) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Datastore Folder $($aryPath[$($index)])"
			#object is a Datastore folder
			#Check if Object exists, if not then create it
			#use a $chk Variable to preserve the parentObj
			$chk=$null; $chk=$parentObj | Get-Folder -Type Datastore -Name $aryPath[$index] -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($chk)){
				#need to check if parentObj is a Datacenter or a Folder as it changes the command structure
				If($parentObj.Id.StartsWith("Datacenter")){ $parentObj = $parentObj | Get-Folder -Type Datastore -NoRecursion | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
				Else{ $parentObj = $parentObj | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
			}Else{ 
				If($chk.Count -gt 1){ 
					#returned multiple folders of the same name, so we have to find the right one
					$chk2 = $null
					If($parentObj.Id.StartsWith("Datacenter")){ $chk2 = $chk | ?{ $ExcludeFolderList -contains $_.ParentId } }
					Else{ $chk2 = $chk | ?{$_.ParentId -eq $parentObj.Id } }
					
					If([string]::IsNullOrEmpty($chk2)){
						#folder doesn't exist so let's create it
						If($parentObj.Id.StartsWith("Datacenter")){ $parentObj = $parentObj | Get-Folder -Type Datastore -NoRecursion | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
						Else{ $parentObj = $parentObj | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
					}Else{ $parentObj = $chk2 }
				}Else{ $parentObj = $chk }
			}
		}
		ElseIf($aryIdPath[$index].StartsWith("Folder-group-n")){
			Write-Progress -Activity "Restoring Network Folder $($aryPath[$($index)])" -PercentComplete (100*($index/($aryPath.Count-1))) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Network Folder $($aryPath[$($index)])"
			#object is a Network folder
			#Check if Object exists, if not then create it
			#use a $chk Variable to preserve the parentObj
			$chk=$null; $chk=$parentObj | Get-Folder -Type Network -Name $aryPath[$index] -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($chk)){
				#need to check if parentObj is a Datacenter or a Folder as it changes the command structure
				If($parentObj.Id.StartsWith("Datacenter")){ $parentObj = $parentObj | Get-Folder -Type Network -NoRecursion | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
				Else{ $parentObj = $parentObj | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
			}Else{ 
				If($chk.Count -gt 1){ 
					#returned multiple folders of the same name, so we have to find the right one
					$chk2 = $null
					If($parentObj.Id.StartsWith("Datacenter")){ $chk2 = $chk | ?{ $ExcludeFolderList -contains $_.ParentId } }
					Else{ $chk2 = $chk | ?{$_.ParentId -eq $parentObj.Id } }
					
					If([string]::IsNullOrEmpty($chk2)){
						#folder doesn't exist so let's create it
						If($parentObj.Id.StartsWith("Datacenter")){ $parentObj = $parentObj | Get-Folder -Type Network -NoRecursion | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
						Else{ $parentObj = $parentObj | New-Folder -Name $aryPath[$index] -ErrorAction SilentlyContinue }
					}Else{ $parentObj = $chk2 }
				}Else{ $parentObj = $chk }
			}
		}
		ElseIf($aryIdPath[$index].StartsWith("StoragePod")){
			Write-Progress -Activity "Restoring Datastore Cluster $($aryPath[$($index)])" -PercentComplete (100*($index/($aryPath.Count-1))) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Datastore Cluster $($aryPath[$($index)])"
			#object is a Datastore Cluster
			#Check if Object exists, if not then create it
			#use a $chk Variable to preserve the parentObj
			$chk=$null; $chk=$parentObj | Get-DatastoreCluster -Name $aryPath[$index] -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($chk)){
				$parentObj = $parentobj | New-DatastoreCluster -Name $aryPath[$index] -ErrorAction SilentlyContinue
				$parentObj | Set-DatastoreCluster -SdrsAutomationLevel Manual | Out-Null
				
				$dsgOld = $dsgReport | ?{$_.Name -eq $parentObj.Name}
				If(-not [string]::IsNullOrEmpty($dsgOld)){ [bool]$dsgAffinity = [System.Convert]::ToBoolean($dsgOld.DefaultIntraVmAffinity) }Else{ [bool]$dsgAffinity = $true }
				
				$dscView = Get-View $parentObj
				$srm = Get-View StorageResourceManager
				$newSpec = New-Object Vmware.Vim.StorageDrsConfigSpec
				$newSpec.PodConfigSpec = New-Object Vmware.Vim.StorageDrsPodConfigSpec
				$newSpec.PodConfigSpec.DefaultIntraVmAffinity = $dsgAffinity
				$srm.ConfigureStorageDrsForPod_Task($dscView.MoRef,$newSpec,$true) | Out-Null
			}Else{ $parentObj = $chk }
		}
		Write-Progress -Activity "Waiting..." -Completed -Id 92
	}
	$obj.NewIdPath = (Get-ObjectPath -Object (Get-View $parentObj) -ObjType $obj.Type -ExcludeFolder $ExcludeFolderList).IdPath
	Write-Progress -Activity "Waiting..." -Completed -Id 92
}
$folderReport | Export-Csv "$($fileOutPath)$($cl.Name)_objectPathReport.csv" -NoTypeInformation
Write-Progress -Activity "Restoring Datacenter/Folder Structures $($obj.Path)" -Completed -Id 91
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Restore Roles and Folder Permissions
# Define Xpaths for the roles and the permissions
$XMLfile = "$($fileOutPath)$($cl.Name)_ExportRoles.xml"
$vInventory = New-Object XML
$vInventory.Load($XMLfile)
$XpathRoles = "Inventory/Roles/Role"
$XpathPermissions = "Inventory/Permissions/Permission"

$progressCount = 1
Write-Progress -Activity "Restoring vCenter Roles" -PercentComplete (100*($progressCount/($vInventory.SelectNodes($XpathRoles).Count))) -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring vCenter Roles"
$viPrivs = Get-VIPrivilege

# Create hash table with the current roles
$authMgr = Get-View AuthorizationManager
$roleHash = @{}
$authMgr.RoleList | % {
	$roleHash[$_.Name] = $_
}
$progressCount = 0
$vInventory.SelectNodes($XpathRoles) | % {
	$progressCount++
	Write-Progress -Activity "Restoring vCenter Role $($_.Name)" -PercentComplete (100*($progressCount/($vInventory.SelectNodes($XpathRoles).Count))) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring vCenter Role $($_.Name)"
	#Compare current roles with pulled Roles
	#If pulled role doesn't already exist then create it
	if(-not $roleHash.ContainsKey($_.Name)){
		$privArray = @()
		#create an array of Permissions for this role
		$_.Privilege | % { $priv = $_
			$privArray += $viPrivs | ?{$_.Id -eq $priv.Name}
		}
		#create the role
		$roleHash[$_.Name] = New-VIRole -Name ("$($_.Name)") -Privilege $privArray -Confirm:$false -ErrorAction SilentlyContinue
		If([string]::IsNullOrEmpty($roleHash["NonUCGAdministrator"])){
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Creating vCenter Role $($_.Name)"
		}Else{
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Creating vCenter Role $($_.Name)"
		}
	}
}
Write-Progress -Activity "Waiting..." -Completed -Id 91

$progressCount = 0
$permCount = ($PermissionReport | ?{(-not [string]::IsNullOrEmpty($_.Path) -and $_.Path.StartsWith("/$($dc.Name)/")) -or $_.Type -eq "root"}).Count
$PermissionReport | ?{(-not [string]::IsNullOrEmpty($_.Path) -and $_.Path.StartsWith("/$($dc.Name)/")) -or $_.Type -eq "root"} | %{ $obj = $_; $progressCount++
	Write-Progress -Activity "Restoring Object $($obj.Path) Permissions $($obj.Principal)" -PercentComplete (100*($progressCount/$permCount)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Object $($obj.Path) Permissions $($obj.Principal)"
	$entity = $null
	If($obj.Type -eq "root"){ $entity = Get-Folder -NoRecursion } # TESTING ONLY - REMOVE Get-Datacenter cmdlet and add Get-Folder -NoRecursion
	ElseIf($obj.Type -eq "Datacenter"){ $entity =$dc } # TESTING ONLY - REMOVE -Name TestDc
	ElseIf($obj.Type -eq "ClusterComputeResource"){ $entity =$cl }
	ElseIf($obj.Type -eq "StoragePod"){ $entity = Get-DatastoreCluster -Name $obj.Entity }
	ElseIf($obj.Type -like "Folder*"){
		#$obj.Path = $obj.Path.Replace("/0319/","/TestDc/") # TESTING ONLY
		Get-Folder -Name $obj.Entity -Type ($obj.Type.Replace("Folder-","")) -ErrorAction SilentlyContinue | %{ $fldr = $_
			$fldrPath = Get-ObjectPath -Object $fldr.ExtensionData -ObjType ($obj.Type.Replace("Folder-","")) -ExcludeFolder $ExcludeFolderList
			If($obj.Path -eq $fldrPath.Path){
				#"FOUND THE RIGHT FOLDER:`n$($obj.Path)`t`t$($fldrPath.Path)`t`t$($obj.Type)`t`t$($obj.Principal)"
				$entity = $fldr
			}
		}
	}
	
	If(-not [string]::IsNullOrEmpty($entity)){
		$obj.IsGroup = If($obj.IsGroup -eq "TRUE"){ $true }ELSE{ $false }
		$obj.Propagate = If($obj.Propagate -eq "TRUE"){ $true }ELSE{ $false }
		$tmp = New-VIObjectPermission -Entity $entity -Principal $obj.Principal -Role $roleHash[$obj.Role] -IsGroup:$obj.IsGroup -Propagate:$obj.Propagate -ErrorAction SilentlyContinue
		If([string]::IsNullOrEmpty($tmp)){
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Restoring Object $($obj.Path) Permissions $($obj.Principal)"
		}Else{
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Restoring Object $($obj.Path) Permissions $($obj.Principal)"
		}
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Restore DvPg's in VDS
Write-Progress -Activity "Restoring Destination VDS" -PercentComplete 99 -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Destination VDS"
$vds = $null
$progressCount = 0
$dvpgReport | %{ $obj = $_; $progressCount++
	If($vds.Name -ne $obj.VdsName){
		$vds = $null
		$vds = Get-VDSwitch -Name $obj.VdsName -ErrorAction SilentlyContinue
		If([string]::IsNullOrEmpty($vds)){
			#VDS doesn't exist so create it
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tCreating VDS $($obj.VdsName)"
			$newVds = New-VDSwitch -Version $obj.VdsVersion -Name $obj.VdsName -Location (Get-VIObjectByVIView -MORef $dc.MoRef) -Mtu 9000 -LinkDiscoveryProtocol CDP -LinkDiscoveryProtocolOperation Both -NumUplinkPorts $obj.Vds.NumUplinkPorts -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($newVds)){ #VDS creation failed
				#lets loop until the user actually creates the VDS manually
				Do{
					$host.UI.WriteErrorLine("Failed to create the new VDS $($obj.VdsName) in the Destination vCenter $($vi.Name). Please create the VDS manually before continuing.")
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tFailed to create the new VDS $($obj.VdsName) in the Destination vCenter $($vi.Name). Please create the VDS manually before continuing."
					pause
					$vds = Get-VDSwitch -Name $obj.VdsName -ErrorAction SilentlyContinue
				}While([string]::IsNullOrEmpty($vds))
				$vds | Set-VDSwitch -Mtu 9000 -ErrorAction SilentlyContinue
			}
			Else{ $vds = $newVds }
		}Else{ $vds | Set-VDSwitch -Mtu 9000 -ErrorAction SilentlyContinue }
	}
	
	#Determine if this is a single vlan or a vlan trunk range
	If(-not [string]::IsNullOrEmpty($obj.VlanId) -and [string]::IsNullOrEmpty($obj.VlanTrunk)){ #single VLAN
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring VDS Portgroup $($obj.Name) with VlanID $($obj.VlanId)"
		#check if the portgroup exists or not. If not then create it
		$chk=$null;
		$chk = Get-VDPortgroup -VDSwitch $vds | ?{$_.ExtensionData.Config.DefaultPortConfig.Vlan.VlanId -eq $obj.VlanId}
		If([string]::IsNullOrEmpty($chk)){
			Write-Progress -Activity "Restoring VDS Portgroup $($obj.Name)" -PercentComplete (100*($progressCount/$dvpgReport.Count)) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tPortgroup not found. Creating VDS Portgroup $($obj.Name) with VlanID $($obj.VlanId)"
			#portgroup doesn't esxist with the reqquired vlan id, so create the portgroup
			$newPg = $vds | New-VDPortgroup -Name $obj.Name -VlanId $obj.VlanId -Notes $obj.Description -NumPorts $obj.NumPorts -Confirm:$false
			#$newPg | Set-VDPortgroup -Name $newPg.Name.Replace("_$($obj.VdsName)","_ucs") | Out-Null
		}
	}ElseIf(-not [string]::IsNullOrEmpty($obj.VlanTrunk)){ #vlan Trunk Range
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring VDS Portgroup $($obj.Name) with VlanTrunk $($obj.VlanTrunk)"
		#check if the portgroup exists or not. If not then create it
		$vlanRanges = Get-VlanNumericRange $obj.VlanTrunk
		$chk=$null;
		$chk = Get-VDPortgroup -VDSwitch $vds | ?{[string]::IsNullOrEmpty((Compare-Object -ReferenceObject $_.ExtensionData.Config.DefaultPortConfig.Vlan.VlanId -DifferenceObject $vlanRanges))}
		If([string]::IsNullOrEmpty($chk)){
			Write-Progress -Activity "Restoring VDS Portgroup $($obj.Name)" -PercentComplete (100*($progressCount/$dvpgReport.Count)) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tPortgroup not found. Creating VDS Portgroup $($obj.Name) with VlanTrunk $($obj.VlanTrunk)"
			#portgroup doesn't esxist with the reqquired vlan id, so create the portgroup
			$newPg = $vds | New-VDPortgroup -Name $obj.Name -VlanTrunkRange $obj.VlanTrunk -Notes $obj.Description -NumPorts $obj.NumPorts -Confirm:$false
			#$newPg | Set-VDPortgroup -Name $newPg.Name.Replace("_$($obj.VdsName)","_ucs") | Out-Null
		}
	}
}

#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Restore Custom Attribute Fields
$SI = Get-View ServiceInstance
$CFM = Get-View $SI.Content.CustomFieldsManager
$progressCount = 0
[array]$customAttributes = Import-Csv "$($fileOutPath)$($cl.Name)_customAttributeReport.csv"
$customAttributes | %{ $obj = $_; $progressCount++
	Write-Progress -Activity "Restoring Custom Attribute Field $($obj.Name)" -PercentComplete (100*($progressCount/$customAttributes.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Custom Attribute Field $($obj.Name)"
	$chk = $null; $chk = $CFM.Field | ?{$_.Name -eq $obj.Name -and $_.ManagedObjectType -eq $obj.ManagedObjectType}
	If([string]::IsNullOrEmpty($chk)){
		#The custom attribute field is not in the vcenter so we need to now create it
		If([string]::IsNullOrEmpty($obj.FieldDefPriviledgesCreate)){$fieldDefPriv = $null}
		Else{
			$fieldDefPriv = New-Object VMware.Vim.PrivilegePolicyDef
				$fieldDefPriv.CreatePrivilege = $obj.FieldDefPriviledgesCreate
				$fieldDefPriv.DeletePrivilege = $obj.FieldDefPriviledgesDelete
				$fieldDefPriv.ReadPrivilege = $obj.FieldDefPriviledgesRead
				$fieldDefPriv.UpdatePrivilege = $obj.FieldDefPriviledgesUpdate
		}
		If([string]::IsNullOrEmpty($obj.FieldInstancePriviledgesCreate)){$instDefPriv = $null}
		Else{
			$instDefPriv = New-Object VMware.Vim.PrivilegePolicyDef
				$instDefPriv.CreatePrivilege = $obj.FieldInstancePriviledgesCreate
				$instDefPriv.DeletePrivilege = $obj.FieldInstancePriviledgesDelete
				$instDefPriv.ReadPrivilege = $obj.FieldInstancePriviledgesRead
				$instDefPriv.UpdatePrivilege = $obj.FieldInstancePriviledgesUpdate
		}
		$CFM.AddCustomFieldDef($obj.Name,$obj.ManagedObjectType,$fieldDefPriv,$instDefPriv)
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Recreate the Cluster resource pools
If($resPoolReport.Count -gt 0){
	Write-Progress -Activity "Restoring Cluster Resource pools on Destination vCenter $($vi.Name)" -PercentComplete 95 -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Cluster Resource pools on Destination vCenter $($vi.Name)"

	$progress = 0
	$resPoolReport | %{ $res = $_; $progress++
	#There is a strange issue in PowerCLI where if you pass a [STRING] variable to -MemSharesLeve and -CpuSharesLevel of new-resourcePool you get an 
	#  error about not having the correct object type. Unfortunately PowerCLI/Powershell doesn't have the capability as of this 
	#  writing to specifically create that type with New-Object.
	# The strange part is that if you run the cmdlet independently in powershell utilizing a [string] variable everything works fine, however in this
	#  script it will not work. I can't explain the behavior so this is the workaround... a lot more code with various IF/ELSE statements.
		Write-Progress -Activity "Restoring Cluster Resource pool $($res.Name)" -PercentComplete (100*($progress/$resPoolReport.Count)) -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Cluster Resource pool $($res.Name)"
		If($res.CpuSharesLevel -eq "Custom" -and $res.MemSharesLevel -eq "Custom" ){
			$destRP = New-ResourcePool -Name $res.Name `
				-Location $clObj `
				-NumCpuShares $res.CpuShares `
				-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
				-CpuLimitMhz $res.CpuLimit `
				-CpuReservationMhz $res.CpuReservation `
				-CpuSharesLevel:Custom `
				-NumMemShares $res.MemShares `
				-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
				-MemLimitGB $res.MemLimit `
				-MemReservationGB $res.MemReservation `
				-MemSharesLevel:Custom `
				-Confirm:$false `
				-ErrorAction SilentlyContinue
		}
		ElseIf($res.CpuSharesLevel -eq "Custom" -and $res.MemSharesLevel -ne "Custom" ){
			If($res.MemSharesLevel -eq "low"){
				$destRP = New-ResourcePool -Name $res.Name `
					-Location $clObj `
					-NumCpuShares $res.CpuShares `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
					-CpuLimitMhz $res.CpuLimit `
					-CpuReservationMhz $res.CpuReservation `
					-CpuSharesLevel:Custom `
					-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
					-MemLimitGB $res.MemLimit `
					-MemReservationGB $res.MemReservation `
					-MemSharesLevel:Low `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
			ElseIf($res.MemSharesLevel -eq "normal"){
				$destRP = New-ResourcePool -Name $res.Name `
					-Location $clObj `
					-NumCpuShares $res.CpuShares `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
					-CpuLimitMhz $res.CpuLimit `
					-CpuReservationMhz $res.CpuReservation `
					-CpuSharesLevel:Custom `
					-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
					-MemLimitGB $res.MemLimit `
					-MemReservationGB $res.MemReservation `
					-MemSharesLevel:Normal `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
			ElseIf($res.MemSharesLevel -eq "high"){
				$destRP = New-ResourcePool -Name $res.Name `
					-Location $clObj `
					-NumCpuShares $res.CpuShares `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
					-CpuLimitMhz $res.CpuLimit `
					-CpuReservationMhz $res.CpuReservation `
					-CpuSharesLevel:Custom `
					-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
					-MemLimitGB $res.MemLimit `
					-MemReservationGB $res.MemReservation `
					-MemSharesLevel:High `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
		}
		ElseIf($res.CpuSharesLevel -ne "Custom" -and $res.MemSharesLevel -eq "Custom" ){
			If($res.CpuSharesLevel -eq "low"){
				$destRP = New-ResourcePool -Name $res.Name `
					-Location $clObj `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
					-CpuLimitMhz $res.CpuLimit `
					-CpuReservationMhz $res.CpuReservation `
					-CpuSharesLevel:Low `
					-NumMemShares $res.MemShares `
					-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
					-MemLimitGB $res.MemLimit `
					-MemReservationGB $res.MemReservation `
					-MemSharesLevel:Custom `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
			ElseIf($res.CpuSharesLevel -eq "normal"){
				$destRP = New-ResourcePool -Name $res.Name `
					-Location $clObj `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
					-CpuLimitMhz $res.CpuLimit `
					-CpuReservationMhz $res.CpuReservation `
					-CpuSharesLevel:Normal `
					-NumMemShares $res.MemShares `
					-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
					-MemLimitGB $res.MemLimit `
					-MemReservationGB $res.MemReservation `
					-MemSharesLevel:Custom `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
			ElseIf($res.CpuSharesLevel -eq "high"){
				$destRP = New-ResourcePool -Name $res.Name `
					-Location $clObj `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
					-CpuLimitMhz $res.CpuLimit `
					-CpuReservationMhz $res.CpuReservation `
					-CpuSharesLevel:High `
					-NumMemShares $res.MemShares `
					-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
					-MemLimitGB $res.MemLimit `
					-MemReservationGB $res.MemReservation `
					-MemSharesLevel:Custom `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
		}
		Else{
			If($res.CpuSharesLevel -eq "low"){
				If($res.MemSharesLevel -eq "low"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:Low `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:Low `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($res.MemSharesLevel -eq "normal"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:Low `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:Normal `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($res.MemSharesLevel -eq "high"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:Low `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:High `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
			}
			ElseIf($res.CpuSharesLevel -eq "normal"){
				If($res.MemSharesLevel -eq "low"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:Normal `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:Low `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($res.MemSharesLevel -eq "normal"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:Normal `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:Normal `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($res.MemSharesLevel -eq "high"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:Normal `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:High `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
			}
			ElseIf($res.CpuSharesLevel -eq "high"){
				If($res.MemSharesLevel -eq "low"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:High `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:Low `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($res.MemSharesLevel -eq "normal"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:High `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:Normal `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($res.MemSharesLevel -eq "high"){
					$destRP = New-ResourcePool -Name $res.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($res.CpuExpanndableReservation)) `
						-CpuLimitMhz $res.CpuLimit `
						-CpuReservationMhz $res.CpuReservation `
						-CpuSharesLevel:High `
						-MemExpandableReservation:([System.Convert]::ToBoolean($res.MemExpanndableReservation)) `
						-MemLimitGB $res.MemLimit `
						-MemReservationGB $res.MemReservation `
						-MemSharesLevel:High `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
			}
		}
		$rp = Get-ResourcePool -Name $res.Name -Location $clObj -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
		If(-not [string]::IsNullOrEmpty($rp)){
			#ResourcePool created
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Restored Cluster Resource Pool $($res.Name)"
		}Else{
			#ResourcePool not created
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Restoring Cluster Resource Pool $($res.Name)"
		}
	}
	[array]$resPools = Get-View -ViewType ResourcePool -SearchRoot $cl.MoRef | ?{$_.Name -ne "Resources"}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Recreate the Cluster vApp pools
If($vAppPoolReport.Count -gt 0){
	Write-Progress -Activity "Restoring Cluster vApp pools on Destination vCenter $($vi.Name)" -PercentComplete 95 -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Cluster vApp pools on Destination vCenter $($vi.Name)"

	$progress = 0
	$vAppPoolReport | %{ $vapp = $_; $progress++
		Write-Progress -Activity "Restoring Cluster vApp pool $($vapp.Name)" -PercentComplete (100*($progress/$vAppPoolReport.Count)) -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tRestoring Cluster vApp pool $($vapp.Name)"
		
		If($vapp.CpuLimit -eq -1){ $cpuLimit = $null }Else{ $cpuLimit=$vapp.CpuLimit }
		If($vapp.MemLimit -eq -1){ $memLimit = $null }Else{ $memLimit=$vapp.CpuLimit }
		
		If($vapp.CpuSharesLevel -eq "Custom" -and $vapp.MemSharesLevel -eq "Custom" ){
			$destva = New-VApp -Name $vapp.Name `
				-Location $clObj `
				-NumCpuShares $vapp.CpuShares `
				-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
				-CpuReservationMhz $vapp.CpuReservation `
				-CpuSharesLevel:Custom `
				-NumMemShares $vapp.MemShares `
				-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
				-MemReservationGB $vapp.MemReservation `
				-MemSharesLevel:Custom `
				-Confirm:$false `
				-ErrorAction SilentlyContinue
		}
		ElseIf($vapp.CpuSharesLevel -eq "Custom" -and $vapp.MemSharesLevel -ne "Custom" ){
			If($vapp.MemSharesLevel -eq "low"){
				$destva = New-VApp -Name $vapp.Name `
					-Location $clObj `
					-NumCpuShares $vapp.CpuShares `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
					-CpuReservationMhz $vapp.CpuReservation `
					-CpuSharesLevel:Custom `
					-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
					-MemReservationGB $vapp.MemReservation `
					-MemSharesLevel:Low `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
			ElseIf($vapp.MemSharesLevel -eq "normal"){
				$destva = New-VApp -Name $vapp.Name `
					-Location $clObj `
					-NumCpuShares $vapp.CpuShares `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
					-CpuReservationMhz $vapp.CpuReservation `
					-CpuSharesLevel:Custom `
					-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
					-MemReservationGB $vapp.MemReservation `
					-MemSharesLevel:Normal `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
			ElseIf($vapp.MemSharesLevel -eq "high"){
				$destva = New-VApp -Name $vapp.Name `
					-Location $clObj `
					-NumCpuShares $vapp.CpuShares `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
					-CpuReservationMhz $vapp.CpuReservation `
					-CpuSharesLevel:Custom `
					-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
					-MemReservationGB $vapp.MemReservation `
					-MemSharesLevel:High `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
		}
		ElseIf($vapp.CpuSharesLevel -ne "Custom" -and $vapp.MemSharesLevel -eq "Custom" ){
			If($vapp.CpuSharesLevel -eq "low"){
				$destva = New-VApp -Name $vapp.Name `
					-Location $clObj `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
					-CpuReservationMhz $vapp.CpuReservation `
					-CpuSharesLevel:Low `
					-NumMemShares $vapp.MemShares `
					-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
					-MemReservationGB $vapp.MemReservation `
					-MemSharesLevel:Custom `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
			ElseIf($vapp.CpuSharesLevel -eq "normal"){
				$destva = New-VApp -Name $vapp.Name `
					-Location $clObj `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
					-CpuReservationMhz $vapp.CpuReservation `
					-CpuSharesLevel:Normal `
					-NumMemShares $vapp.MemShares `
					-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
					-MemReservationGB $vapp.MemReservation `
					-MemSharesLevel:Custom `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
			ElseIf($vapp.CpuSharesLevel -eq "high"){
				$destva = New-VApp -Name $vapp.Name `
					-Location $clObj `
					-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
					-CpuReservationMhz $vapp.CpuReservation `
					-CpuSharesLevel:High `
					-NumMemShares $vapp.MemShares `
					-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
					-MemReservationGB $vapp.MemReservation `
					-MemSharesLevel:Custom `
					-Confirm:$false `
					-ErrorAction SilentlyContinue
			}
		}
		Else{
			If($vapp.CpuSharesLevel -eq "low"){
				If($vapp.MemSharesLevel -eq "low"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:Low `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:Low `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($vapp.MemSharesLevel -eq "normal"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:Low `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:Normal `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($vapp.MemSharesLevel -eq "high"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:Low `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:High `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
			}
			ElseIf($vapp.CpuSharesLevel -eq "normal"){
				If($vapp.MemSharesLevel -eq "low"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:Normal `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:Low `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($vapp.MemSharesLevel -eq "normal"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:Normal `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:Normal `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($vapp.MemSharesLevel -eq "high"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:Normal `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:High `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
			}
			ElseIf($vapp.CpuSharesLevel -eq "high"){
				If($vapp.MemSharesLevel -eq "low"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:High `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:Low `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($vapp.MemSharesLevel -eq "normal"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:High `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:Normal `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
				ElseIf($vapp.MemSharesLevel -eq "high"){
					$destva = New-VApp -Name $vapp.Name `
						-Location $clObj `
						-CpuExpandableReservation:([System.Convert]::ToBoolean($vapp.CpuExpanndableReservation)) `
						-CpuReservationMhz $vapp.CpuReservation `
						-CpuSharesLevel:High `
						-MemExpandableReservation:([System.Convert]::ToBoolean($vapp.MemExpanndableReservation)) `
						-MemReservationGB $vapp.MemReservation `
						-MemSharesLevel:High `
						-Confirm:$false `
						-ErrorAction SilentlyContinue
				}
			}
		}
		
		$va = Get-VApp -Name $vapp.Name -Location $clObj -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
		If(-not [string]::IsNullOrEmpty($va)){
			#vAppPool created
			If(-not [string]::IsNullOrEmpty($cpuLimit)){ $va | Set-VApp -CpuLimitMhz $cpuLimit -Confirm:$false -ErrorAction SilentlyContinue }
			If(-not [string]::IsNullOrEmpty($memLimit)){ $va | Set-VApp -MemLimitGB $memLimit -Confirm:$false -ErrorAction SilentlyContinue }
			
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Restored Cluster vApp Pool $($vapp.Name)"
		}Else{
			#vAppPool not created
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: Restoring Cluster vApp Pool $($vapp.Name)"
		}
	}
	[array]$vApps = Get-View -ViewType VirtualApp -SearchRoot $cl.MoRef
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Disconnect DestinationVcenter and Connect back to SourceVcenter
Write-Progress -Activity "Attempting to Disconnect from vCenter $($DestinationVcenter)" -PercentComplete 50 -Id 90
Do{
	#sometimes the disconnect doesn't work first and so we have to try again and again until it actually does disconnect
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAttempting to Disconnect from vCenter $($DestinationVcenter)"
	Disconnect-VIServer -Server $vi.Name -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Sleep -Seconds 10
}While($vi.IsConnected)
Write-Progress -Activity "Disconnected from vCenter $($DestinationVcenter)" -PercentComplete 100 -Id 90
Write-Log -Path $logPath -Message "[$(Get-Date)]`tConnecting to vCenter $($SourceVcenter)"
Write-Progress -Activity "Connecting to vCenter $($SourceVcenter)" -PercentComplete 50 -Id 90
Do{
	#sometimes the Connect doesn't work first and so we have to try again and again until it actually does connect
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAttempting to Connect to vCenter $($SourceVcenter)"
	$vi = Connect-VIServer -Server $SourceVcenter -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Sleep -Seconds 10
}While(-not $vi.IsConnected)
Write-Progress -Activity "Connected to vCenter $($SourceVcenter)" -PercentComplete 100 -Id 90
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Disconnect ESXi Hosts from vCenter
$esxiCount = 0
$vmhosts | %{ $esxi = $_ ; $esxiCount++
	Write-Progress -Activity "Disconnecting ESXi Host $($esxi.Name) from vCenter $($SourceVcenter)" -PercentComplete (100*($esxiCount/$vmhosts.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tDisconnecting ESXi Host $($esxi.Name) from vCenter $($SourceVcenter)"
	$outNull = Set-VMHost -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -State Disconnected -Confirm:$false
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Disconnect SourceVcenter and Connect to DestinationVcenter
Write-Progress -Activity "Attempting to Disconnect from vCenter $($SourceVcenter)" -PercentComplete 50 -Id 90
Do{
	#sometimes the disconnect doesn't work first and so we have to try again and again until it actually does disconnect
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAttempting to Disconnect from vCenter $($SourceVcenter)"
	Disconnect-VIServer -Server $vi.Name -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Sleep -Seconds 10
}While($vi.IsConnected)
Write-Progress -Activity "Disconnected from vCenter $($SourceVcenter)" -PercentComplete 100 -Id 90
Write-Log -Path $logPath -Message "[$(Get-Date)]`tConnecting to vCenter $($DestinationVcenter)"
Write-Progress -Activity "Connecting to vCenter $($DestinationVcenter)" -PercentComplete 50 -Id 90
Do{
	#sometimes the Connect doesn't work first and so we have to try again and again until it actually does connect
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAttempting to Connect to vCenter $($DestinationVcenter)"
	$vi = Connect-VIServer -Server $DestinationVcenter -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Sleep -Seconds 10
}While(-not $vi.IsConnected)
Write-Progress -Activity "Connected to vCenter $($DestinationVcenter)" -PercentComplete 100 -Id 90
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region get DC and Folder Exclusions and Cluster Object
$tmpDc = $dc
$dcObj = Get-Datacenter -Name $dc.Name -ErrorAction SilentlyContinue
If([string]::IsNullOrEmpty($dcObj)){ $dcObj = New-Datacenter -Name $dc.Name -Location (Get-Folder -NoRecursion) }
$dc = $dcObj.ExtensionData
$cl = Get-View -ViewType ClusterComputeResource -Filter @{"Name"=$cl.Name}
$clObj = Get-VIObjectByVIView -MORef $cl.MoRef
##########################################################
#  LIST OF EXCLUDED FOLDERS BY ID
	#Exclude the hidden folders for each view
	[array]$ExcludeFolderList = @()
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type VM -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type Datastore -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type Network -NoRecursion).Id
	[array]$ExcludeFolderList += (Get-VIObjectByVIView -MORef $dc.MoRef | Get-Folder -Type HostAndCluster -NoRecursion).Id
##########################################################
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Add ESXi Hosts to Destination vCenter and cluster (Complete)
$esxiCount = 0
$vmhosts | %{ $esxi = $_ ; $esxiCount++
	Write-Progress -Activity "Adding ESXi Host $($esxi.Name) to vCenter $($DestinationVcenter)" -PercentComplete (100*($esxiCount/$vmhosts.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAdding ESXi Host $($esxi.Name) to vCenter $($DestinationVcenter)"
	$outNull = Add-VMHost -Name $esxi.Name -Location $clObj -Credential $hostCred -Force:$true -Confirm:$false
}
$cl.UpdateViewData()
$vmhosts = Get-View -ViewType HostSystem -SearchRoot $cl.MoRef
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Set HA Admission Control Policy (Complete)
Write-Log -Path $logPath -Message "[$(Get-Date)]`tSetting Cluster HA Admission Control Policy on Cluster $($cl.Name)"
$NumberOfHostsInCluster = $vmhosts.Count
$HostPercentage = 100/$NumberOfHostsInCluster
$HAPercentageValue = [math]::Ceiling($HostPercentage)
$outNull = $clObj | Set-HAAdmissionControlPolicy -percentCPU $HAPercentageValue -percentMem $HAPercentageValue
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Set DRS Rules (Complete)
$contents = $null
If(Test-Path "$($fileOutPath)$($cl.Name)_clusterRules.csv"){
	$contents = Import-Csv "$($fileOutPath)$($cl.Name)_clusterRules.csv" -ErrorAction SilentlyContinue | Sort ClusterName
}
If(-not [string]::IsNullOrEmpty($contents)){
	$currContents = $contents | ?{$_.ClusterName -eq $Cluster} | %{
		#$clObj = Get-VmCluster -Name $_.ClusterName
		If($_ -ne $null -and $_ -ne ""){
			If($_.RuleType -eq "ClusterVmHostRuleInfo"){
				[array]$aVm = $_.VMGroupMembers.Split(",")
				[array]$aVmHost = $_.AffineHostGrpMembers.Split(",")
				$hostGroupName = ($_.AffineHostGrpName -as [string])
				$AntiAffine = $false
				If([string]::IsNullOrEmpty($aVmHost)){
					#not Afiinity group so get Anti-Affinity group members
					[array]$aVmHost = $_.AntiAffineHostGrpMembers.Split(",")
					$hostGroupName = ($_.AntiAffineHostGrpName -as [string])
					$AntiAffine = $true
				}
				#do something with host groups/rule and vm groups/rule
				Write-Host "Configuring Cluster DRS Group Rules for $($_.VMGroupMembers)"
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring Cluster DRS Group Rules for $($_.VMGroupMembers)"
				Get-VM $aVm -ErrorAction SilentlyContinue | New-vDrsVmGroup -Name $_.VMGroupName -Cluster $clObj
				Get-VMHost $aVmHost -ErrorAction SilentlyContinue | New-vDrsHostGroup -Name $hostGroupName -Cluster $clObj
				If($_.bMandatory -eq "TRUE"){ $Mandatory = $true}Else{$Mandatory = $false }
				New-vDRSVMToHostRule -VMGroup $_.VMGroupName -HostGroup $hostGroupName -Name $_.RuleName -Cluster $clObj -Mandatory:$Mandatory -AntiAffine:$AntiAffine
			}Else{
				#do something with basic Affinity and Anti-Affinity rules
				Write-Host "Configuring Cluster DRS Rules for $($_.VMNames)"
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring Cluster DRS Rules for $($_.VMNames)"
				[array]$aVm = $_.VMNames.Split(",")
				If($_.bKeepTogether -like "*TRUE*"){
					New-DrsRule -Name $_.RuleName -VM (Get-VM $aVm) -Cluster $clObj -KeepTogether:$true -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
				}Else{
					New-DrsRule -Name $_.RuleName -VM (Get-VM $aVm) -Cluster $clObj -KeepTogether:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
				}
			}
		}
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Query VMs to get updated data
$allVms = Get-View -ViewType VirtualMachine -SearchRoot $cl.MoRef
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Add ESXi Hosts and standby vmnics to VDS (not Complete)
$progress = 0
$vmhosts.UpdateViewData()
$vmhosts | %{ $esxi = $_; $progress++
	Write-Progress -Activity "Migrating ESXi $($esxi.Name) standby vmnics to VDS" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating ESXi $($esxi.Name) standby vmnics to VDS"
	[int]$progress2 = 0
	$vmnicLastout | ?{$_.VMHost -eq $esxi.Name} | %{ $vmnic = $_; $progress2++
		Write-Progress -Activity "Migrating vmnic $($vmnic.Vmnic) to VDS $($vmnic.Vds)" -PercentComplete (100*($progress2/$vmnicLastout.Count)) -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating vmnic $($vmnic.Vmnic) to VDS $($vmnic.Vds)"
		$chk = $null
		$chk = $esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vmnic.Vds}
		If([string]::IsNullOrEmpty($chk)){
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tESXi Host has not been added to VDS $($vmnic.Vds). Adding host to VDS."
			#ESXi Host has not been added to the VDS yet, so add the host without adding the physical adapters yet
			$outNull = Add-VDSwitchVMHost -VDSwitch (Get-VDSwitch -Name $vmnic.Vds) -VMHost (Get-VIObjectByVIView -MORef $esxi.MoRef) -Confirm:$false
			$esxi.UpdateViewData()
			$vds = $esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vmnic.Vds}
			######## Check if $vds is NULL, if so pause and notify user ###########
			If([string]::IsNullOrEmpty($vds)){
				#pause loop waiting for the user to add the esxi host to the VDS
				Do{
					$host.UI.WriteErrorLine("Failed to add ESXi host $($esxi.Name) to the new VDS $($vmnic.Vds) in the Destination vCenter $($vi.Name). Please manually add the ESXi Host to the VDS $($vmnic.Vds) but DO NOT add any physical NICs to the switch.")
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tFailed to add ESXi host $($esxi.Name) to the new VDS $($vmnic.Vds) in the Destination vCenter $($vi.Name). Please manually add the ESXi Host to the VDS $($vmnic.Vds) but DO NOT add any physical NICs to the switch."
					pause
					$esxi.UpdateViewData()
					$vds = $esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vmnic.Vds}
				}While([string]::IsNullOrEmpty($vds))
			}
		}Else{ $vds = $chk }
		
		#remove the physical vmnic from the standard switch
		$outNull = Get-VIObjectByVIView -MORef $esxi.MoRef | Get-VMHostNetworkAdapter -Physical -Name $vmnic.Vmnic | Remove-VirtualSwitchPhysicalNetworkAdapter -Confirm:$false -ErrorAction SilentlyContinue
		$esxi.UpdateViewData()
		######## Check if physical NIC has been removed from VSS ###########
		
		#Add the physical vmnic to the VDS
		$UplinkPosition = [System.Convert]::ToInt32($vmnic.UplinkPosition)
		$vdsUplink = ($esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds.DvsName}).UplinkPort[$UplinkPosition]
		
		Write-Progress -Activity "Migrating vmnic $($vmnic.Vmnic) to VDS $($vmnic.Vds) Uplink $($UplinkPosition)" -PercentComplete (100*($progress2/$vmnicLastout.Count)) -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating vmnic $($vmnic.Vmnic) to VDS $($vmnic.Vds) Uplink $($UplinkPosition) $($vdsUplink.Value)"
		
		$netConfig = New-Object VMware.Vim.HostNetworkConfig
		$netConfig.ProxySwitch = New-Object VMware.Vim.HostProxySwitchConfig[] (1)
		$netConfig.ProxySwitch[0] = New-Object VMware.Vim.HostProxySwitchConfig
		$netConfig.ProxySwitch[0].ChangeOperation = "edit"
		$netConfig.ProxySwitch[0].uuid = $vds.DvsUuid
		$netConfig.ProxySwitch[0].Spec = New-Object VMware.Vim.HostProxySwitchSpec
		$netConfig.ProxySwitch[0].Spec.Backing = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicBacking
		#This method of adding vmnics to the VDS causes a complete reconfiguration and only applies the uplink setting as given in the HostNetworkConfig
		# So I have to check and add any existing uplink configs to the new object so that I have the complete desired configuration
		If(-not [string]::IsNullOrEmpty($vds.Spec.Backing.PnicSpec)){
			$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec = $vds.Spec.Backing.PnicSpec
			$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec += New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (1)
		}Else{ 
			$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (1)
		}
		$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[($netConfig.ProxySwitch[0].Spec.Backing.PnicSpec).Count-1] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
		$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[($netConfig.ProxySwitch[0].Spec.Backing.PnicSpec).Count-1].PnicDevice = $vmnic.Vmnic
		$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[($netConfig.ProxySwitch[0].Spec.Backing.PnicSpec).Count-1].UplinkPortKey = $vdsUplink.Key
		
		$netSys = Get-View $esxi.ConfigManager.NetworkSystem
		$netSys.UpdateNetworkConfig($netConfig, "modify") | Out-Null
		$esxi.UpdateViewData()
		######## Verify if the vmnic has moved, if not pause and notify the user ###########
		$chk = $null
		$chk = ($esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds.DvsName}).Spec.Backing.PnicSpec | ?{$_.PnicDevice -eq $vmnic.Vmnic}
		If([string]::IsNullOrEmpty($chk)){
			#Physical NIC didn't get added to the VDS. Pause loop until the user manually adds the Physical Nic to the uplink
			Do{
				$host.UI.WriteErrorLine("Failed to add ESXi host $($esxi.Name) vmnic $($vmnic.Vmnic) to the new VDS $($vmnic.Vds) in the Destination vCenter $($vi.Name). `nPlease manually add the ESXi Host vmnic $($vmnic.Vmnic) to the VDS $($vmnic.Vds) uplink $($vdsUplink.Value) but DO NOT add any other physical NICs to the switch.")
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tFailed to add ESXi host $($esxi.Name) vmnic $($vmnic.Vmnic) to the new VDS $($vmnic.Vds) in the Destination vCenter $($vi.Name). `nPlease manually add the ESXi Host vmnic $($vmnic.Vmnic) to the VDS $($vmnic.Vds) uplink $($vdsUplink.Value) but DO NOT add any other physical NICs to the switch."
				pause
				$esxi.UpdateViewData()
				$chk = $null
				$chk = ($esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds.DvsName}).Spec.Backing.PnicSpec | ?{$_.PnicDevice -eq $vmnic.Vmnic}
			}While([string]::IsNullOrEmpty($chk))
		}
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Migrate VMKernels back to VDS
$vmkReport | %{ $vmk = $_
	Write-Progress -Activity "Migrating VMHost $($vmk.VMHost) VMKernel adapter $($vmk.Device) to VDS." -PercentComplete 95 -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating VMHost $($vmk.VMHost) VMKernel adapter $($vmk.Device) to VDS."
	$esxi = $vmhosts | ?{$_.Name -eq $vmk.VMHost}
	$vmkObj = Get-VIObjectByVIView -MORef $esxi.MoRef | Get-VMHostNetworkAdapter -VMKernel -Name $vmk.Device
	$pg = Get-VDPortgroup -VDSwitch $vmk.VdsName | ?{$_.VlanConfiguration.VlanId -eq $vmk.DvPgVlan}
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating VMHost $($vmk.VMHost) VMKernel adapter $($vmk.Device) to Portgroup $($pg.Name)."
	$outNull = Set-VMHostNetworkAdapter -VirtualNic $vmkObj -PortGroup $pg -Confirm:$false
	#region Verify Host Connectivity
		Write-Progress -Activity "Verifying Connectivity has not been lost." -PercentComplete 95 -Id 92 -ParentId 91
		#$tmp = $esxi
		Sleep -Seconds 5
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tVerifying Host $($vmk.VMHost) Connectivity"
		$chk = $null
		$chk = Test-Connection -ComputerName $vmk.VMHost -ErrorAction SilentlyContinue
		If([string]::IsNullOrEmpty($chk)){
			Do{
				Write-Host "HOST CONNECTIVITY HAS BEEN LOST!!! VMs should NOT be affected at this time as this outagae is due to VMKernel migrations, however, host connectivity needs to be restored"
				Write-Host "This script is pasuing due to this issue and to prevent any further issues with other hosts. Please Restore the VMKernel and manually migrate this VMkernel to the VDS before continuing."
				Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: HOST CONNECTIVITY HAS BEEN LOST!!! VMs should NOT be affected at this time as this outagae is due to VMKernel migrations, however, host connectivity needs to be restored"
				pause
				$chk = $null
				$chk = Test-Connection -ComputerName $vmk.VMHost -ErrorAction SilentlyContinue
			}While([string]::IsNullOrEmpty($chk))
		}Else{ Write-Host "Esxi host $($vmk.VMHost) connectivity verified after moving VMKernel Adapter." -BackgroundColor DarkGreen;Write-Log -Path $logPath -Message "[$(Get-Date)]`tCOMPLETE: Verifying Host $($vmk.VMHost) Connectivity" }
		Write-Progress -Activity "Verifying Connectivity has not been lost." -Completed -Id 92
	#endregion
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Migrate VMs back to VDS
$progress=0
$vmnaChanged | %{ $vmna = $_; $progress++
	Write-Progress -Activity "Migrating VM $($vmna.VmName) Network Adapter $($vmna.VmNaLabel) to VDS" -PercentComplete (100*($progress/$vmnaChanged.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating VM $($vmna.VmName) Network Adapter $($vmna.VmNaLabel) to VDS"
	$vm = $allVms | ?{$_.Name -eq $vmna.VmName}
	$na = Get-VIObjectByVIView -MORef $vm.MoRef | Get-NetworkAdapter -Name $vmna.VmNaLabel
	$obj = $dvpgReport | ?{$_.Id -eq $vmna.OriginalId}
	If(-not [string]::IsNullOrEmpty($obj.VlanTrunk)){
		$vlanRanges = Get-VlanNumericRange -vlanRange $obj.VlanTrunk
		$dvpg = Get-VDSwitch -Name $obj.VdsName | Get-VDPortgroup | ?{[string]::IsNullOrEmpty((Compare-Object -ReferenceObject $_.ExtensionData.Config.DefaultPortConfig.Vlan.VlanId -DifferenceObject $vlanRanges))}
	}Else{
		$dvpg = Get-VDSwitch -Name $obj.VdsName | Get-VDPortgroup | ?{$_.VlanConfiguration.VlanId -eq $obj.VlanId}
	}
	Write-Progress -Activity "Moving $($na.Name) to Portgroup $($dvpg.Name) on VDS $($obj.VdsName)" -PercentComplete 50 -Id 92 -ParentId 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving $($na.Name) to Portgroup $($dvpg.Name) on VDS $($obj.VdsName)"
	$outNull = $na | Set-NetworkAdapter -NetworkName $dvpg.Name	-Confirm:$false
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Verify VSS is empty (need to test the logic on a NUTANIX cluster)
Write-Progress  -Activity "Verifying VMs have moved to VDS" -PercentComplete 35 -Id 91

[array]$onlyModifyVm = $vmnaChanged | %{ "$($_.VmName)" } #there may be a case where we started out with Vms on an existing VSS so we don't want to modiy those
[array]$onlyModifyNa = $vmnaChanged | %{ "$($_.VmName)|$($_.VmNaLabel)" } #there may be a case where we started out with Vms on an existing VSS so we don't want to modiy those

$allVms.UpdateViewData()
$vmhosts.UpdateViewData()
[array]$tmp = @()
$tmpVms = Get-View $vmhosts.Vm #using this method because the host property .vm holds template objects as well
Do{
	[bool]$stop = $false
	[array]$tmp = @()
	[array]$tmp = $tmpVms | ?{$_.Network.Type -eq "Network" -and $onlyModifyVm -contains $_.Name}
	$tmp | %{ $vm=$_
		$nas = $null
		$nas = Get-VIObjectByVIView -MORef $vm.MoRef | Get-NetworkAdapter | ?{ $onlyModifyNa -contains "$($_.Parent.Name)|$($_.Name)"}
		If(-not [string]::IsNullOrEmpty($nas)){
			#need to loop through and check if there is a vNic still on Standard VSS portgroup
			$nas | %{ $obj = $_
				If($obj.ExtensionData.Backing.GetType().Name -eq "VirtualEthernetCardNetworkBackingInfo"){
					Write-Host "ERROR : VM $($vm.Name) is not completely migrated to the VDS. It still has an interface on the vSwitch." -ForegroundColor Red -BackgroundColor Black
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: VM $($vm.Name) is not completely migrated to the VDS."
					[bool]$stop = $true
				}
			}
		}
	}
	If($stop){
		Write-Host "Pausing until these VMs have been moved to the VDS. Please manually migrate these VMs to the VDS." -ForegroundColor Cyan -BackgroundColor Black
		pause
		$allVms.UpdateViewData()
	}
}While($stop)

Write-Progress  -Activity "Verifying ESXi Hosts have moved to VDS" -PercentComplete 50 -Id 91
Do{
	[array]$tmp = @()
	[array]$onlyModify = $vmkReport | %{ "$($_.VMHost)-$($_.Device)" }
	$vmhosts | %{ $esxi=$_
		If($esxi.Config.Network.Vnic.Spec.Portgroup -ne $null){ 
			#there is a vmk on a standard portgroup
			#lets check if it is a vmk that needs to remian on VSS
			$esxi.Config.Network.Vnic | %{
				If($_.Spec.Portgroup -ne $null -and $onlyModify -contains "$($esxi.Name)-$($_.Device)"){
					$pso = New-Object PSObject -Property @{VmHost=$esxi.Name;VMKernel=$_.Device;Portgroup=$_.Spec.Portgroup}
					[array]$tmp +=$pso
				}
			}
		}
	}
	If(-not [string]::IsNullOrEmpty($tmp)){
		$tmp | %{ $esxi=$_
			#VmHost has an interface that is not on the VDS
			Write-Host "ERROR : ESXi Host $($esxi.VmHost) is not completely migrated to the VDS. It still has a VMKernel interface on a vSwitch that started out on VDS." -ForegroundColor Red -BackgroundColor Black
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tERROR: ESXi Host $($esxi.VmHost) is not completely migrated to the VDS."
		}
		Write-Host "Pausing until these VMHosts have been moved to the VDS. Please manually migrate these VMHosts to the VDS." -ForegroundColor Cyan -BackgroundColor Black
		pause
		$vmhosts.UpdateViewData()
		[array]$tmp = @()
		$vmhosts | %{ $esxi=$_
			If($esxi.Config.Network.Vnic.Spec.Portgroup -ne $null){ 
				#there is a vmk on a standard portgroup
				#lets check if it is a vmk that needs to remian on VSS
				$esxi.Config.Network.Vnic | %{
					If($_.Spec.Portgroup -ne $null -and $onlyModify -contains "$($esxi.Name)-$($_.Device)"){
						$pso = New-Object PSObject -Property @{VmHost=$esxi.Name;VMKernel=$_.Device;Portgroup=$_.Spec.Portgroup}
						[array]$tmp +=$pso
					}
				}
			}
		}
	}
}While(-not [string]::IsNullOrEmpty($tmp))
$tmpVms=$null
$tmp=$null
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Move Remaining Vmnics to VDS
$progress = 0
$vmhosts.UpdateViewData()
$allMyVds = Get-View -ViewType DistributedVirtualSwitch
$vmhosts | %{ $esxi = $_; $progress++
	Write-Progress -Activity "Migrating ESXi $($esxi.Name) remaining vmnics to VDS" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating ESXi $($esxi.Name) remaining vmnics to VDS"
	[int]$progress2 = 0
	$vmnicReport | ?{$_.VMHost -eq $esxi.Name} | %{ $vmnic = $_; $progress2++
		$chk = $null
		$chk = $esxi.Config.Network.Vswitch | %{ $_.Pnic | ?{$_ -eq "key-vim.host.PhysicalNic-$($vmnic.Vmnic)"} }	
		If(-not [string]::IsNullOrEmpty($chk)){
			Write-Progress -Activity "Migrating vmnic $($vmnic.Vmnic) to VDS $($vmnic.Vds)" -PercentComplete (100*($progress2/$vmnicReport.Count)) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating vmnic $($vmnic.Vmnic) to VDS $($vmnic.Vds)"
			$vds = $esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vmnic.Vds}
			
			#remove the physical vmnic from the standard switch
			$outNull = Get-VIObjectByVIView -MORef $esxi.MoRef | Get-VMHostNetworkAdapter -Physical -Name $vmnic.Vmnic | Remove-VirtualSwitchPhysicalNetworkAdapter -Confirm:$false -ErrorAction SilentlyContinue
			$esxi.UpdateViewData()
			######## Check if physical NIC has been removed from VSS ###########
			
			#Add the physical vmnic to the VDS
			$UplinkPosition = [System.Convert]::ToInt32($vmnic.UplinkPosition)
			$vdsUplink = ($esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds.DvsName}).UplinkPort[$UplinkPosition]
			
			Write-Progress -Activity "Migrating vmnic $($vmnic.Vmnic) to VDS $($vmnic.Vds) Uplink $($UplinkPosition)" -PercentComplete (100*($progress2/$vmnicLastout.Count)) -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tMigrating vmnic $($vmnic.Vmnic) to VDS $($vmnic.Vds) Uplink $($UplinkPosition) $($vdsUplink.Value)"
			
			$netConfig = New-Object VMware.Vim.HostNetworkConfig
			$netConfig.ProxySwitch = New-Object VMware.Vim.HostProxySwitchConfig[] (1)
			$netConfig.ProxySwitch[0] = New-Object VMware.Vim.HostProxySwitchConfig
			$netConfig.ProxySwitch[0].ChangeOperation = "edit"
			$netConfig.ProxySwitch[0].uuid = $vds.DvsUuid
			$netConfig.ProxySwitch[0].Spec = New-Object VMware.Vim.HostProxySwitchSpec
			$netConfig.ProxySwitch[0].Spec.Backing = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicBacking
			#This method of adding vmnics to the VDS causes a complete reconfiguration and only applies the uplink setting as given in the HostNetworkConfig
			# So I have to check and add any existing uplink configs to the new object so that I have the complete desired configuration
			If(-not [string]::IsNullOrEmpty($vds.Spec.Backing.PnicSpec)){
				$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec = $vds.Spec.Backing.PnicSpec
				$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec += New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (1)
			}Else{ 
				$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (1)
			}
			$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[($netConfig.ProxySwitch[0].Spec.Backing.PnicSpec).Count-1] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
			$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[($netConfig.ProxySwitch[0].Spec.Backing.PnicSpec).Count-1].PnicDevice = $vmnic.Vmnic
			$netConfig.ProxySwitch[0].Spec.Backing.PnicSpec[($netConfig.ProxySwitch[0].Spec.Backing.PnicSpec).Count-1].UplinkPortKey = $vdsUplink.Key
		
			$netSys = Get-View $esxi.ConfigManager.NetworkSystem
			$netSys.UpdateNetworkConfig($netConfig, "modify") | Out-Null
			$esxi.UpdateViewData()
			######## Verify if the vmnic has moved, if not pause and notify the user ###########
			$chk = $null
			$chk = ($esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds.DvsName}).Spec.Backing.PnicSpec | ?{$_.PnicDevice -eq $vmnic.Vmnic}
			If([string]::IsNullOrEmpty($chk)){
				#Physical NIC didn't get added to the VDS. Pause loop until the user manually adds the Physical Nic to the uplink
				Do{
					$host.UI.WriteErrorLine("Failed to add ESXi host $($esxi.Name) vmnic $($vmnic.Vmnic) to the new VDS $($vmnic.Vds) in the Destination vCenter $($vi.Name). `nPlease manually add the ESXi Host vmnic $($vmnic.Vmnic) to the VDS $($vmnic.Vds) uplink $($vdsUplink.Value) but DO NOT add any other physical NICs to the switch.")
					Write-Log -Path $logPath -Message "[$(Get-Date)]`tFailed to add ESXi host $($esxi.Name) vmnic $($vmnic.Vmnic) to the new VDS $($vmnic.Vds) in the Destination vCenter $($vi.Name). `nPlease manually add the ESXi Host vmnic $($vmnic.Vmnic) to the VDS $($vmnic.Vds) uplink $($vdsUplink.Value) but DO NOT add any other physical NICs to the switch."
					pause
					$esxi.UpdateViewData()
					$chk = $null
					$chk = ($esxi.Config.Network.ProxySwitch | ?{$_.DvsName -eq $vds.DvsName}).Spec.Backing.PnicSpec | ?{$_.PnicDevice -eq $vmnic.Vmnic}
				}While([string]::IsNullOrEmpty($chk))
			}
		}
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Remove VSS
Write-Progress -Activity "Removing Migration Standard Switches" -PercentComplete 50 -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tRemoving Migration Standard Switches"
	$outNull = Get-VIObjectByVIView -MORef $vmhosts.MoRef | Get-VirtualSwitch -Standard | ?{$_.Name -like "vSwitchMigrate*"} | Remove-VirtualSwitch -Confirm:$false
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Move Datastore Objects to the proper location
$progress=0
$folderReport | ?{$_.Type -eq "Datastore"} | %{ $obj = $_; $progress++
	Write-Progress -Activity "Moving Datastores to Proper Folders" -PercentComplete (100*($progress/($folderReport | ?{$_.Type -eq "Datastore"}).Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving Datastores to Proper Folders"
	$tmpPath = $obj.Path.Split("/")
	$tmpIdPath = $obj.NewIdPath.Split("/")
	
	If($tmpIdPath[$tmpIdPath.Count-1].StartsWith("StoragePod")){
		#IsDsCluster
		Write-Progress -Activity "Moving Datastore $($tmpPath[$($tmpPath.Count)-1]) to Datastore Cluster $($tmpPath[$($tmpPath.Count)-2])" -PercentComplete 50 -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving Datastore $($tmpPath[$($tmpPath.Count)-1]) to Datastore Cluster $($tmpPath[$($tmpPath.Count)-2])"
		$dscl = Get-DatastoreCluster -Id $tmpIdPath[$tmpIdPath.Count-1] -Server $destVI
		$ds = Get-Datastore -Name $tmpPath[$tmpPath.Count-1] -Server $destVI
		$outNull = Move-Datastore -Datastore $ds -Destination $dscl
	}Else{
		Write-Progress -Activity "Moving Datastore $($tmpPath[$($tmpPath.Count)-1]) to Datastore Folder $($tmpPath[$($tmpPath.Count)-2])" -PercentComplete 50 -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving Datastore $($tmpPath[$($tmpPath.Count)-1]) to Datastore Folder $($tmpPath[$($tmpPath.Count)-2])"
		$dsName = $tmpPath[$tmpPath.Count-1]
		If($tmpIdPath[$tmpIdPath.Count-1].StartsWith("Datacenter")){ $fldr = Get-VIObjectByVIView -MORef $dc.MoRef }
		Else{ $fldr = Get-Folder -Id $tmpIdPath[$tmpIdPath.Count-1] }
		$outNull = Move-Datastore -Datastore $dsName -Destination $fldr
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Move VMs to the proper location
$progress=0
$folderReport | ?{$_.Type -eq "VirtualMachine" -or $_.Type -eq "Template"} | %{ $obj = $_; $progress++
	$tmpPath = $obj.Path.Split("/")
	$tmpIdPath = $obj.NewIdPath.Split("/")
	Write-Progress -Activity "Moving VM $($tmpPath[$($tmpPath.Count)-1]) to VM Folder $($tmpPath[$($tmpPath.Count)-2])" -PercentComplete (100*($progress/($folderReport | ?{$_.Type -eq "VirtualMachine" -or $_.Type -eq "Template"}).Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving VM $($tmpPath[$($tmpPath.Count)-1]) to VM Folder $($tmpPath[$($tmpPath.Count)-2])"
	Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($obj.NewIdPath)"
	$vm = Get-VM -Name ($tmpPath[$tmpPath.Count-1])
	If($tmpIdPath[$tmpIdPath.Count-1].StartsWith("Datacenter-datacenter")){ $fldr = Get-VIObjectByVIView -MORef $dc.MoRef }
	Else{ $fldr = Get-Folder -Id ($tmpIdPath[$tmpIdPath.Count-1]) }
	Write-Log -Path $logPath -Message "[$(Get-Date)]`t`t$($fldr.Name)"
	$outNull = Move-VM -VM $vm -Destination $fldr -Confirm:$false
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Convert Templates back to Templates
$progress=0
$folderReport | ?{$_.Type -eq "Template"} | %{ $obj = $_; $progress++
	$tmpPath = $obj.Path.Split("/")
	$tmpIdPath = $obj.NewIdPath.Split("/")
	Write-Progress -Activity "Converting VM $($tmpPath[$($tmpPath.Count)-1]) to Template" -PercentComplete (100*($progress/($folderReport | ?{$_.Type -eq "Template"}).Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tConverting VM $($tmpPath[$($tmpPath.Count)-1]) to Template"
	$tmpl = Get-VM -Name ($tmpPath[$tmpPath.Count-1]) | Set-VM -ToTemplate -Confirm:$false
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Move VMs to proper Resource Pools
$progress=0
[array]$resPools = Get-View -ViewType ResourcePool -SearchRoot $cl.MoRef | ?{$_.Name -ne "Resources"}
$resPoolVms | %{ $obj = $_; $progress++
	Write-Progress -Activity "Moving VM $($obj.VM) to resource Pool $($obj.ResourcePool)" -PercentComplete (100*($progress/$resPoolVms.Count)) -Id 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving VM $($obj.VM) to resource Pool $($obj.ResourcePool)"
	$rp = $resPools | ?{$_.Name -eq $obj.ResourcePool}
	$vm = $allVms | ?{$_.Name -eq $obj.VM}
	If(-not [string]::IsNullOrEmpty($rp)){
		$outNull = Move-VM -VM (Get-VIObjectByVIView -MORef $vm.MoRef) -Destination (Get-VIObjectByVIView -MORef $rp.MoRef) -Confirm:$false
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Move VMs to proper vApp Pools
$progress=0
[array]$vApps = Get-View -ViewType VirtualApp -SearchRoot $cl.MoRef
If(-not [string]::IsNullOrEmpty($vApps)){
	$vAppPoolVms | %{ $obj = $_; $progress++
		Write-Progress -Activity "Moving VM $($obj.VM) to vApp Pool $($obj.vAppPool)" -PercentComplete (100*($progress/$vAppPoolVms.Count)) -Id 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tMoving VM $($obj.VM) to vApp Pool $($obj.vAppPool)"
		$vapp = $vApps | ?{$_.Name -eq $obj.vAppPool}
		$vm = $allVms | ?{$_.Name -eq $obj.VM}
		If(-not [string]::IsNullOrEmpty($vapp)){
			$outNull = Move-VM -VM (Get-VIObjectByVIView -MORef $vm.MoRef) -Destination (Get-VIObjectByVIView -MORef $vapp.MoRef) -Confirm:$false
		}
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Configure vApp Startup/Shutdown Settings
$progress=0
[array]$vApps = Get-View -ViewType VirtualApp -SearchRoot $cl.MoRef
If(-not [string]::IsNullOrEmpty($vApps)){
	$vApps | %{ $vapp = $_; $progress++
		Write-Progress -Activity "Setting VM Startup/Shutdown policy for vApp Pool $($vapp.Name)" -PercentComplete (100*($progress/$vApps.Count)) -Id 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tSetting VM Startup/Shutdown policy for vApp Pool $($vapp.Name)"
		$coSpec = New-Object Vmware.Vim.VAppConfigSpec
		$coSpec.EntityConfig = $vapp.vAppConfig.EntityConfig | %{ $ent = $_
			$vm = $vAppPoolVms | ?{$_.VM -eq $ent.Tag}
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tSetting VM $($vm.VM) Startup/Shutdown policy for vApp Pool $($vapp.Name)"
			$ent.StartOrder = $vm.StartOrder
			Write-Log -Path $logPath -Message "`tSetting VM $($vm.VM) vApp Group $($vm.StartOrder)"
			$ent.StartAction = $vm.StartAction
			Write-Log -Path $logPath -Message "`tSetting VM $($vm.VM) vApp Start Action $($vm.StartAction)"
			$ent.StartDelay = $vm.StartDelay
			Write-Log -Path $logPath -Message "`tSetting VM $($vm.VM) vApp Start Delay $($vm.StartDelay)"
			$ent.StopAction = $vm.StopAction
			Write-Log -Path $logPath -Message "`tSetting VM $($vm.VM) vApp Stop Action $($vm.StopAction)"
			$ent.StopDelay = $vm.StopDelay
			Write-Log -Path $logPath -Message "`tSetting VM $($vm.VM) vApp Stop Delay $($vm.StopDelay)"
			$ent.WaitingForGuest = $vm.WaitingForGuest
			Write-Log -Path $logPath -Message "`tSetting VM $($vm.VM) vApp Wait For VMTools $($vm.WaitingForGuest)"
			$ent.DestroyWithParent = $vm.DestroyWithParent
			Write-Log -Path $logPath -Message "`tSetting VM $($vm.VM) vApp Destroy With Parent $($vm.DestroyWithParent)"
			$ent
		}
		$vapp.UpdateVAppConfig($coSpec)
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Set DRS and HA advanced configurations and enable DRS
Write-Progress -Activity "Configuring the Cluster with DRS and HA settings" -PercentComplete 80 -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring the Cluster with DRS and HA settings"
$outNull = Get-VIObjectByVIView -MORef $cl.MoRef | Set-VmCluster -DrsEnabled:$true -DrsAutomationLevel Manual -Confirm:$false
$contents = $null
If(Test-Path "$($fileOutPath)$($cl.Name)_clusterSettings.csv"){
	$contents = Import-Csv "$($fileOutPath)$($cl.Name)_clusterSettings.csv" | Sort ClusterName
}
If(Test-Path "$($fileOutPath)$($cl.Name)_clusterHAadvanced.csv"){
	$haAdvancedReport = Import-Csv "$($fileOutPath)$($cl.Name)_clusterHAadvanced.csv" -ErrorAction SilentlyContinue
}

$contents | ?{$_.ClusterName -eq $Cluster} | %{
	$currContents = $_
	$cl.UpdateViewData()
	Switch($_){
		{$_.DRSEnabled -eq $true} { $drs = $true }
		{$_.DRSEnabled -eq $false} {$drs = $false}
		{$_.HAEnabled -eq $true} { $ha = $true }
		{$_.HAEnabled -eq $false} {$ha = $false}
		{$_.AdmissionControlEnabled -eq $true} { $ace = $true }
		{$_.AdmissionControlEnabled -eq $false} {$ace = $false}
		{$_.VmSwapPlacement -eq "vmDirectory"} {$vmSwap = "WithVM"}
		{$_.VmSwapPlacement -eq "hostLocal"} {$vmSwap = "InHostDatastore"}
	}
	
	$outNull = Get-VIObjectByVIView -MORef $cl.MoRef | Set-Cluster -DrsEnabled:$drs -HAEnabled:$ha -HAAdmissionControlEnabled:$ace -VMSwapfilePolicy:$vmSwap -Confirm:$false
	$cl.UpdateViewData()
	
	#Set Cluster Settings via .NET
	$clusterConfigSpec = New-Object Vmware.Vim.ClusterConfigSpecEx
	$dasConfig = $cl.ConfigurationEx.DasConfig
	$drsConfig = $cl.ConfigurationEx.DrsConfig
	$dasVmConfig = $cl.ConfigurationEx.DasVmConfig
	
	#ClusterDasConfig configuration
	Write-Progress -Activity "Configuring Cluster HA Setting : Datastore Heartbeat allFeasibleDs" -PercentComplete 90 -Id 92 -ParentId 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring Cluster HA Setting : Datastore Heartbeat allFeasibileDs"
	$dasConfig.HBDatastoreCandidatePolicy = "allFeasibleDs"
	
	Write-Host "Configuring Cluster HA Setting : HA Admission Control Policy"
	$ACPobjType = "Vmware.Vim."+$_.AdmissionControlPolicy
	$dasConfig.AdmissionControlPolicy = New-Object $ACPobjType
	Switch($_){
		{$_.AdmissionControlPolicy -eq "ClusterFailoverLevelAdmissionControlPolicy"} {
			$dasConfig.AdmissionControlPolicy.FailoverLevel = $_.FailoverLevel
		}
		{$_.AdmissionControlPolicy -eq "ClusterFailoverResourcesAdmissionControlPolicy"} {
			$dasConfig.AdmissionControlPolicy.CpuFailoverResourcesPercent = $_.CpuFailoverResourcesPercent
			$dasConfig.AdmissionControlPolicy.MemoryFailoverResourcesPercent = $_.MemoryFailoverResourcesPercent
		}
	}
	
	$clusterConfigSpec.DasConfig = $dasConfig
	
	#########################################
	# VM DRS Overrides
	$clusterConfigSpecEx = $null
	$clusterConfigSpecEx = New-Object Vmware.Vim.ClusterConfigSpecEx
	#$drsVmConfig = $clView.ConfigurationEx.DrsVmConfig
	
	If($_.DrsVmNamesManual -ne "" -and $_.DrsVmNamesManual -ne $null) {
		$_.DrsVmNamesManual.Split(",") | %{
			Write-Progress -Activity "Configuring Cluster DRS VM Override for VM $($_) to Manual" -PercentComplete 90 -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring Cluster DRS VM Override for VM $($_) to Manual"
			If($drsVmConfig -eq $null){ $drsVmConfig = New-Object Vmware.Vim.ClusterDrsVmConfigSpec }
			$vmView = Get-View -ViewType VirtualMachine -Property Name -Filter @{"Name" = $_}
			If($vmView.Count -gt 1) {$tmp = $_; $vmView = $vmView | ?{$_.Name -eq $tmp} }
			$clDrsVmConfigInfo = New-Object Vmware.Vim.ClusterDrsVmConfigInfo
			$clDrsVmConfigInfo.Enabled = $true
			$clDrsVmConfigInfo.Behavior = "manual"
			$clDrsVmConfigInfo.Key = $vmView.MoRef
			
			$drsVmConfig.Info = $clDrsVmConfigInfo
			$clusterConfigSpecEx.DrsVmConfigSpec = $drsVmConfig
			$outNull = $cl.ReconfigureComputeResource($clusterConfigSpecEx,$true)
		}
	}
	If($_.DrsVmNamesPartial -ne "" -and $_.DrsVmNamesPartial -ne $null) {
		$_.DrsVmNamesPartial.Split(",") | %{
			Write-Progress -Activity "Configuring Cluster DRS VM Override for VM $($_) to Partially Automated" -PercentComplete 90 -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring Cluster DRS VM Override for VM $($_) to Partially Automated"
			If($drsVmConfig -eq $null){ $drsVmConfig = New-Object Vmware.Vim.ClusterDrsVmConfigSpec }
			$vmView = Get-View -ViewType VirtualMachine -Property Name -Filter @{"Name" = $_}
			If($vmView.Count -gt 1) {$tmp = $_; $vmView = $vmView | ?{$_.Name -eq $tmp} }
			$clDrsVmConfigInfo = New-Object Vmware.Vim.ClusterDrsVmConfigInfo
			$clDrsVmConfigInfo.Enabled = $true
			$clDrsVmConfigInfo.Behavior = "partiallyAutomated"
			$clDrsVmConfigInfo.Key = $vmView.MoRef
			
			$drsVmConfig.Info = $clDrsVmConfigInfo
			$clusterConfigSpecEx.DrsVmConfigSpec = $drsVmConfig
			$outNull = $cl.ReconfigureComputeResource($clusterConfigSpecEx,$true)
		}
	}
	If($_.DrsVmNamesDisabled -ne "" -and $_.DrsVmNamesDisabled -ne $null) {
		$_.DrsVmNamesDisabled.Split(",") | %{
			Write-Progress -Activity "Configuring Cluster DRS VM Override for VM $($_) to Fully Automated" -PercentComplete 90 -Id 92 -ParentId 91
			Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring Cluster DRS VM Override for VM $($_) to Fully Automated"
			If($drsVmConfig -eq $null){ $drsVmConfig = New-Object Vmware.Vim.ClusterDrsVmConfigSpec }
			$vmView = Get-View -ViewType VirtualMachine -Property Name -Filter @{"Name" = $_}
			If($vmView.Count -gt 1) {$tmp = $_; $vmView = $vmView | ?{$_.Name -eq $tmp} }
			$clDrsVmConfigInfo = New-Object Vmware.Vim.ClusterDrsVmConfigInfo
			$clDrsVmConfigInfo.Enabled = $false
			$clDrsVmConfigInfo.Behavior = "fullyAutomated"
			$clDrsVmConfigInfo.Key = $vmView.MoRef
			
			$drsVmConfig.Info = $clDrsVmConfigInfo
			$clusterConfigSpecEx.DrsVmConfigSpec = $drsVmConfig
			$outNull = $cl.ReconfigureComputeResource($clusterConfigSpecEx,$true)
		}
	}
	
	#ClusterDrsConfig configuration
	Write-Progress -Activity "Configuring Cluster DRS Setting VM DRS Default Behavior of $($_.DRSDefaultVmBehavior) and DRS Agression of $($_.DRSVmotionRate)" -PercentComplete 90 -Id 92 -ParentId 91
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring Cluster DRS Setting VM DRS Default Behavior of $($_.DRSDefaultVmBehavior) and DRS Agression of $($_.DRSVmotionRate)"
	$drsConfig.DefaultVmBehavior = $_.DRSDefaultVmBehavior
	$drsConfig.VmotionRate = $_.DRSVmotionRate
	
	$clusterConfigSpec.DrsConfig = $drsConfig
	#########################################
	
	#########################################
	# VM HA Advanced
	If([string]::IsNullOrEmpty($dasVmConfig)){
		$dasVmConfig = New-Object Vmware.Vim.ClusterDasVmConfigSpec	
	}

	#$haAdvancedReport = Import-Csv "C:\temp\cl0319ucgt001\cl0319ucgt001_clusterHAadvanced.csv"
	If(-not [string]::IsNullOrEmpty($haAdvancedReport)){
		$haAdvancedReport | %{ $obj = $_
			$obj.VmId = (Get-View -ViewType VirtualMachine -SearchRoot $cl.MoRef -Filter @{"Name"=$obj.Vm}).MoRef
			$chk = $null
			$chk = $dasVmConfig | ?{$_.Key -eq $obj.VmId}
			If(-not [string]::IsNullOrEmpty($chk)){
				$dasVmConfig | ?{$_.Key -eq $obj.VmId} | %{ $das = $_
					If(-not [string]::IsNullOrEmpty($obj.RestartPriority)){$das.RestartPriority = $obj.RestartPriority}
					If(-not [string]::IsNullOrEmpty($obj.PowerOffOnIsolation)){$das.PowerOffOnIsolation = [System.Convert]::ToBoolean($obj.PowerOffOnIsolation)}
					If(-not [string]::IsNullOrEmpty($obj.DasRestartPriority)){$das.DasSettings.RestartPriority = $obj.DasRestartPriority}
					If(-not [string]::IsNullOrEmpty($obj.IsolationResponse)){$das.DasSettings.IsolationResponse = $obj.IsolationResponse}
					If(-not [string]::IsNullOrEmpty($obj.Enabled)){$das.DasSettings.VmToolsMonitoringSettings.Enabled = [System.Convert]::ToBoolean($obj.Enabled) }
					If(-not [string]::IsNullOrEmpty($obj.VmMonitoring)){$das.DasSettings.VmToolsMonitoringSettings.VmMonitoring = $obj.VmMonitoring}
					If(-not [string]::IsNullOrEmpty($obj.ClusterSettings)){$das.DasSettings.VmToolsMonitoringSettings.ClusterSettings = [System.Convert]::ToBoolean($obj.ClusterSettings)}
					If(-not [string]::IsNullOrEmpty($obj.FailureInterval)){$das.DasSettings.VmToolsMonitoringSettings.FailureInterval = [System.Convert]::ToInt64($obj.FailureInterval)}
					If(-not [string]::IsNullOrEmpty($obj.MinUpTime)){$das.DasSettings.VmToolsMonitoringSettings.MinUpTime = [System.Convert]::ToInt64($obj.MinUpTime)}
					If(-not [string]::IsNullOrEmpty($obj.MaxFailures)){$das.DasSettings.VmToolsMonitoringSettings.MaxFailures = [System.Convert]::ToInt64($obj.MaxFaiures)}
					If(-not [string]::IsNullOrEmpty($obj.MaxFailureWindow)){$das.DasSettings.VmToolsMonitoringSettings.MaxFailureWindow = [System.Convert]::ToInt64($obj.MaxFailureWindow)}
					$clDasVmConfigSpec = New-Object Vmware.Vim.ClusterDasVmConfigSpec
					$clDasVmConfigSpec.Info = $das
					$clDasVmConfigSpec.Operation = "edit"
					$clusterConfigSpec.DasVmConfigSpec += $clDasVmConfigSpec
				}
			}Else{
				$das = New-Object Vmware.Vim.ClusterDasVmConfigInfo
				$das.DasSettings = New-Object Vmware.Vim.ClusterDasVmSettings
				$das.Key = $obj.VmId
				If(-not [string]::IsNullOrEmpty($obj.RestartPriority)){$das.RestartPriority = $obj.RestartPriority}
				If(-not [string]::IsNullOrEmpty($obj.PowerOffOnIsolation)){$das.PowerOffOnIsolation = [System.Convert]::ToBoolean($obj.PowerOffOnIsolation)}
				If(-not [string]::IsNullOrEmpty($obj.DasRestartPriority)){$das.DasSettings.RestartPriority = $obj.DasRestartPriority}
				If(-not [string]::IsNullOrEmpty($obj.IsolationResponse)){$das.DasSettings.IsolationResponse = $obj.IsolationResponse}
				If(-not [string]::IsNullOrEmpty($obj.Enabled)){
					$das.DasSettings.VmToolsMonitoringSettings = New-Object Vmware.Vim.ClusterVmToolsMonitoringSettings
					$das.DasSettings.VmToolsMonitoringSettings.Enabled = [System.Convert]::ToBoolean($obj.Enabled) 
				}
				If(-not [string]::IsNullOrEmpty($obj.VmMonitoring)){$das.DasSettings.VmToolsMonitoringSettings.VmMonitoring = $obj.VmMonitoring}
				If(-not [string]::IsNullOrEmpty($obj.ClusterSettings)){$das.DasSettings.VmToolsMonitoringSettings.ClusterSettings = [System.Convert]::ToBoolean($obj.ClusterSettings)}
				If(-not [string]::IsNullOrEmpty($obj.FailureInterval)){$das.DasSettings.VmToolsMonitoringSettings.FailureInterval = [System.Convert]::ToInt64($obj.FailureInterval)}
				If(-not [string]::IsNullOrEmpty($obj.MinUpTime)){$das.DasSettings.VmToolsMonitoringSettings.MinUpTime = [System.Convert]::ToInt64($obj.MinUpTime)}
				If(-not [string]::IsNullOrEmpty($obj.MaxFailures)){$das.DasSettings.VmToolsMonitoringSettings.MaxFailures = [System.Convert]::ToInt64($obj.MaxFaiures)}
				If(-not [string]::IsNullOrEmpty($obj.MaxFailureWindow)){$das.DasSettings.VmToolsMonitoringSettings.MaxFailureWindow = [System.Convert]::ToInt64($obj.MaxFailureWindow)}
				$clDasVmConfigSpec = New-Object Vmware.Vim.ClusterDasVmConfigSpec
				$clDasVmConfigSpec.Info = $das
				$clDasVmConfigSpec.Operation = "add"
				$clusterConfigSpec.DasVmConfigSpec += $clDasVmConfigSpec
			}
		}
	}
	
	#Reconfigure the cluster
	$outNull = $cl.ReconfigureComputeResource($clusterConfigSpec,$true)
	
	#Configure EVC Mode
	If(-not [string]::IsNullOrEmpty($_.CurrentEVCModeKey)){
		Write-Progress -Activity "Configuring Cluster EVC Mode to $($_.CurrentEVCModeKey)" -PercentComplete 90 -Id 92 -ParentId 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tConfiguring Cluster EVC Mode to $($_.CurrentEVCModeKey)"
		Get-VIObjectByVIView -MORef $cl.MoRef | Set-VmCluster -EVCMode $_.CurrentEVCModeKey -Confirm:$false
		Sleep -Seconds 3
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Set Custom Attributes
$SI = Get-View ServiceInstance
$CFM = Get-View $SI.Content.CustomFieldsManager
$progress=0
If(-not [string]::IsNullOrEmpty($objCustomValues)){
	$objCustomValues | %{ $obj = $_; $progress++
		Write-Progress -Activity "Modifying Custom Attribute $($obj.Name) to $($obj.Value) for $($obj.Entity)" -PercentComplete (100*($progress/$objCustomValues.Count)) -Id 91
		Write-Log -Path $logPath -Message "[$(Get-Date)]`tModifying Custom Attribute $($obj.Name) to $($obj.Value) for $($obj.Entity)"
		$objView = Get-View -ViewType $obj.ManagedObjectType -Filter @{"Name"=$obj.Entity}
		$custField = $CFM.Field | ?{$_.Name -eq $obj.Name -and $_.ManagedObjectType -eq $obj.ManagedObjectType}
		$outNull = $objView.setCustomValue($custField.Name,$obj.Value)
	}
}
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region Disconnect DestinationVcenter and Connect back to SourceVcenter
Write-Progress -Activity "Attempting to Disconnect from vCenter $($DestinationVcenter)" -PercentComplete 50 -Id 90
Do{
	#sometimes the disconnect doesn't work first and so we have to try again and again until it actually does disconnect
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAttempting to Disconnect from vCenter $($DestinationVcenter)"
	Disconnect-VIServer -Server $vi.Name -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Sleep -Seconds 10
}While($vi.IsConnected)
Write-Progress -Activity "Disconnected from vCenter $($DestinationVcenter)" -PercentComplete 100 -Id 90
Write-Log -Path $logPath -Message "[$(Get-Date)]`tConnecting to vCenter $($SourceVcenter)"
Write-Progress -Activity "Connecting to vCenter $($SourceVcenter)" -PercentComplete 50 -Id 90
Do{
	#sometimes the Connect doesn't work first and so we have to try again and again until it actually does connect
	Write-Log -Path $logPath -Message "[$(Get-Date)]`tAttempting to Connect to vCenter $($SourceVcenter)"
	$vi = Connect-VIServer -Server $SourceVcenter -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Sleep -Seconds 10
}While(-not $vi.IsConnected)
Write-Progress -Activity "Connected to vCenter $($SourceVcenter)" -PercentComplete 100 -Id 90
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
#region remove old artifacts from old vCenter
Write-Progress -Activity "Removing old cluster from old vCenter $($SourceVcenter)" -PercentComplete 50 -Id 91
Write-Log -Path $logPath -Message "[$(Get-Date)]`tRemoving old cluster from old vCenter $($SourceVcenter)"
$outNull = Get-VmCluster -Name $Cluster | Remove-VmCluster -Confirm:$false
#endregion
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91

Disconnect-VIServer * -Confirm:$false
Write-Progress -Activity "Waiting ..." -Completed -Id 92
Write-Progress -Activity "Waiting ..." -Completed -Id 91
Write-Progress -Activity "Waiting ..." -Completed -Id 90
Write-Host "Script Complete!!"
Write-Log -Path $logPath -Message "[$(Get-Date)]`tScript Complete!"
(Get-Date).DateTime