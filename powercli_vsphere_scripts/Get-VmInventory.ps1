# this is an inventory report to get all of the inventory data of all vms so that a vm can be rebuilt if needed
# this is also used for DR purposes since SRDF replication replicates everything as is, we can automate the recovery

$scriptPath = $MyInvocation.MyCommand.Path
$scriptFile = $MyInvocation.MyCommand.Name
$scriptPath = $scriptPath.Replace($scriptFile,"")
$strAry = $scriptPath.Split("\")
$scriptRoot = $scriptPath.Replace($strAry[$strAry.Count-2],"")
$scriptRoot = $scriptRoot.Replace("\\","")
$srdfRdmDeviceIdScript = $scriptRoot+"\storage_scripts\Get-SrdfRdmDeviceId.ps1"

$vcenter = @("319ProdVcenter","870ProdVcenter","319NonProdVcenter","a0319p777","a0870p100","a0319p779","a0319p775","a0319p643","a0319p837","a0864p105")
#$vcenter = @("a0319t355") ## TESTING ONLY ##

Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -WarningAction SilentlyContinue

Disconnect-VIServer -Server $vcenter -Confirm:$false -ErrorAction SilentlyContinue
CLS
Get-Date
$OutputArry = @()
$tOutputArry = @()
$selObj = @('vCenter','VMname','vCPU','Memory','PowerState','DR','VMXPath','DatastoreFolderName')
$totx = 0
$toty = 0
[array]$clusterVMHosts = @()

$vcenter | %{
	$vc = $_; $vc
$vi = Connect-VIServer -Server $vc -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

Get-View -ViewType Datacenter | %{ $dc = $_
	Get-View -ViewType ClusterComputeResource -SearchRoot $dc.MoRef |%{ $cl = $_; $clusterHosts = "" | Select Cluster,VMHosts
		$clusterHosts.Cluster = $cl.Name; $clusterHosts.VMHosts = @()
		Get-View -ViewType HostSystem -SearchRoot $cl.MoRef | %{ $esxi = $_		
			$vmk = $esxi.Config.Network.Vnic | ?{$_.Device -eq "vmk0"}
			If([string]::IsNullOrEmpty($vmk)){ 
				$vmk = $esxi.Config.Network.Vnic | ?{$_.Device -eq "vmk1"}
				If([string]::IsNullOrEmpty($vmk)){ $vmk = $esxi.Config.Network.Vnic | ?{$_.Device -eq "vmk2"} }
			}
			If($cl.Name -like "*pci*" -and ($cl.Name -notlike "*non-pci*" -or $cl.Name -notlike "*nonpci*")) { $environment = "pci"; }Else{ $environment = "nonpci"; }
			$dvpg = Get-View -ViewType DistributedVirtualPortgroup -Filter @{"Key"=$vmk.Spec.DistributedVirtualPort.PortgroupKey} -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
			$hostParams = @{
				Name = $esxi.Name
				IpAddress = $vmk.Spec.Ip.IpAddress
				SubnetMask = $vmk.Spec.Ip.SubnetMask
				DefaultGateway = $esxi.Config.Network.IpRouteConfig.DefaultGateway
				VlanId = $dvpg.Config.DefaultPortConfig.Vlan.VlanId
				Environment = $environment
			}
			$clusterHosts.VMHosts += New-Object PSObject -Property $hostParams
		}
		Get-View -ViewType HostSystem -SearchRoot $cl.MoRef | %{ $esxi = $_
			Get-View -ViewType VirtualMachine -SearchRoot $esxi.MoRef | %{ $vm = $_
			#Get-View -ViewType VirtualMachine -SearchRoot $esxi.MoRef -Filter @{"Name"="f0864p14"} | %{ $vm = $_
				$vmPso = New-Object PSObject
				"   $($vm.Name)"
				$vmPso | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vc -ErrorAction SilentlyContinue
				$vmPso | Add-Member -MemberType NoteProperty -Name "DR" -Value ""
				#region PowerState
				$vmPso | Add-Member -MemberType NoteProperty -Name "PowerState" -Value $vm.Runtime.PowerState
				#endregion
				#region Cpu and memory
				$vmPso | Add-Member -MemberType NoteProperty -Name "VMname" -Value $vm.Name
				$vmPso | Add-Member -MemberType NoteProperty -Name "vCPU" -Value $vm.Config.Hardware.NumCPU
	
				[int]$MemMB = $vm.Config.Hardware.MemoryMB
				$Mem = $MemMB/1024
				$vmPso | Add-Member -MemberType NoteProperty -Name "Memory" -Value $Mem
				#endregion
				#region VM Datastore Folder
				$vmPso | Add-Member -MemberType NoteProperty -Name "VMXPath" -Value $vm.Config.Files.VmPathName
				$folderName = $vm.Config.Files.VmPathName
				$folderName = $folderName.Split(']')[1]
				$folderName = $folderName.Split('/')[0]
				$folderName = $folderName.Substring(1)
				If($vm.Config.Files.VmPathName.EndsWith("vmtx")){$vmPso | Add-Member -MemberType NoteProperty  -Name "Template" -Value "TRUE" }
				$vmPso | Add-Member -MemberType NoteProperty  -Name "DatastoreFolderName" -Value $folderName 
				#endregion
				#region Network Adapters
				$flexible = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualPCNet32]}
				$e1000 = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualE1000]}
				$e1000e = $vm.Config.Hardware.Device | ?{$_ -is [Vmware.Vim.VirtualE1000e]}
				$vmxnet2 = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualVmxnet2]}
				$vmxnet3 = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualVmxnet3]}
				
				[array]$netInfo = @()
				$flexible | ?{$_ -ne $null} | %{
					$net = $_;
					$pso0 = "" | Select netLabel,netMacAddress,netType,netStartConnected,netConnected,netPortgroup,netVlan
					$pso0.netMacAddress = $_.MacAddress
					$pso0.netLabel = $_.DeviceInfo.Label
					$pso0.netType = "flexible"
					$pso0.netStartConnected = $net.Connectable.StartConnected
					$pso0.netConnected = $net.Connectable.Connected
					If($net.Backing -is [VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo]){
						#this is a VDS
						$dvpgKey = $net.Backing.Port.PortgroupKey
						$dvpg = Get-View -Id "DistributedVirtualPortgroup-$($dvpgKey)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
						$pso0.netPortgroup = $dvpg.Name
						$pso0.netVlan = $dvpg.Config.DefaultPortConfig.Vlan.VlanId
					}ElseIf($net.Backing -is [VMware.Vim.VirtualEthernetCardNetworkBackingInfo]){
						#this is a standard vSwitch
						$pso0.netPortgroup = $net.DeviceInfo.Summary
						$pso0.netVlan = (Get-VirtualPortGroup -Standard -Name $net.DeviceInfo.Summary).VlanId
					}
					[array]$netInfo += $pso0; $pso0 = $null;$dvpgKey=$null;$dvpg=$null
				}
				$e1000 | ?{$_ -ne $null} | %{
					$net = $_;
					$pso1 = "" | Select netLabel,netMacAddress,netType,netStartConnected,netConnected,netPortgroup,netVlan
					$pso1.netMacAddress = $_.MacAddress
					$pso1.netLabel = $_.DeviceInfo.Label
					$pso1.netType = "e1000"
					$pso1.netStartConnected = $net.Connectable.StartConnected
					$pso1.netConnected = $net.Connectable.Connected
					If($net.Backing -is [VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo]){
						#this is a VDS
						$dvpgKey = $net.Backing.Port.PortgroupKey
						$dvpg = Get-View -Id "DistributedVirtualPortgroup-$($dvpgKey)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
						$pso1.netPortgroup = $dvpg.Name
						$pso1.netVlan = $dvpg.Config.DefaultPortConfig.Vlan.VlanId
					}ElseIf($net.Backing -is [VMware.Vim.VirtualEthernetCardNetworkBackingInfo]){
						#this is a standard vSwitch
						$pso1.netPortgroup = $net.DeviceInfo.Summary
						$pso1.netVlan = (Get-VirtualPortGroup -Standard -Name $net.DeviceInfo.Summary).VlanId
					}
					[array]$netInfo += $pso1; 
					$pso1 = $null;$net=$null;$dvpgKey=$null;$dvpg=$null
				}
				$e1000e | ?{$_ -ne $null} | %{
					$net = $_;
					$pso2 = "" | Select netLabel,netMacAddress,netType,netStartConnected,netConnected,netPortgroup,netVlan
					$pso2.netMacAddress = $_.MacAddress
					$pso2.netLabel = $_.DeviceInfo.Label
					$pso2.netType = "e1000e"
					$pso2.netStartConnected = $net.Connectable.StartConnected
					$pso2.netConnected = $net.Connectable.Connected
					If($net.Backing -is [VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo]){
						#this is a VDS
						$dvpgKey = $net.Backing.Port.PortgroupKey
						$dvpg = Get-View -Id "DistributedVirtualPortgroup-$($dvpgKey)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
						$pso2.netPortgroup = $dvpg.Name
						$pso2.netVlan = $dvpg.Config.DefaultPortConfig.Vlan.VlanId
					}ElseIf($net.Backing -is [VMware.Vim.VirtualEthernetCardNetworkBackingInfo]){
						#this is a standard vSwitch
						$pso2.netPortgroup = $net.DeviceInfo.Summary
						$pso2.netVlan = (Get-VirtualPortGroup -Standard -Name $net.DeviceInfo.Summary).VlanId
					}
					[array]$netInfo += $pso2; 
					$pso2 = $null;$net=$null;$dvpgKey=$null;$dvpg=$null
				}
				$vmxnet2 | ?{$_ -ne $null} | %{
					$net = $_;
					$pso3 = "" | Select netLabel,netMacAddress,netType,netStartConnected,netConnected,netPortgroup,netVlan
					$pso3.netMacAddress = $_.MacAddress
					$pso3.netLabel = $_.DeviceInfo.Label
					$pso3.netType = "vmxnet2"
					$pso3.netStartConnected = $net.Connectable.StartConnected
					$pso3.netConnected = $net.Connectable.Connected
					If($net.Backing -is [VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo]){
						#this is a VDS
						$dvpgKey = $net.Backing.Port.PortgroupKey
						$dvpg = Get-View -Id "DistributedVirtualPortgroup-$($dvpgKey)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
						$pso3.netPortgroup = $dvpg.Name
						$pso3.netVlan = $dvpg.Config.DefaultPortConfig.Vlan.VlanId
					}ElseIf($net.Backing -is [VMware.Vim.VirtualEthernetCardNetworkBackingInfo]){
						#this is a standard vSwitch
						$pso3.netPortgroup = $net.DeviceInfo.Summary
						$pso3.netVlan = (Get-VirtualPortGroup -Standard -Name $net.DeviceInfo.Summary).VlanId
					}
					[array]$netInfo += $pso3; 
					$pso3 = $null;$net=$null;$dvpgKey=$null;$dvpg=$null
				}
				$vmxnet3 | ?{$_ -ne $null} | %{
					$net = $_;
					$pso4 = "" | Select netLabel,netMacAddress,netType,netStartConnected,netConnected,netPortgroup,netVlan
					$pso4.netMacAddress = $_.MacAddress
					$pso4.netLabel = $_.DeviceInfo.Label
					$pso4.netType = "vmxnet3"
					$pso4.netStartConnected = $net.Connectable.StartConnected
					$pso4.netConnected = $net.Connectable.Connected
					If($net.Backing -is [VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo]){
						#this is a VDS
						$dvpgKey = $net.Backing.Port.PortgroupKey
						$dvpg = Get-View -Id "DistributedVirtualPortgroup-$($dvpgKey)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
						$pso4.netPortgroup = $dvpg.Name
						$pso4.netVlan = $dvpg.Config.DefaultPortConfig.Vlan.VlanId
					}ElseIf($net.Backing -is [VMware.Vim.VirtualEthernetCardNetworkBackingInfo]){
						#this is a standard vSwitch
						$pso4.netPortgroup = $net.DeviceInfo.Summary
						$pso4.netVlan = (Get-VirtualPortGroup -Standard -Name $net.DeviceInfo.Summary).VlanId
					}
					[array]$netInfo += $pso4; 
					$pso4=$null;$net=$null;$dvpgKey=$null;$dvpg=$null
				}
				
				$flexible, $e1000, $e1000e, $vmxnet2, $vmxnet3 = $null,$null,$null,$null,$null
				
				For($y=1;$y -lt $netInfo.Count+1;$y++){
				$lookup = "Network adapter "+($y)
					$netInfo | ?{$_.netLabel -eq $lookup} | %{
						$vmPso | Add-Member -MemberType NoteProperty -Name ("NicLabel"+$y) -Value $_.netLabel
						$vmPso | Add-Member -MemberType NoteProperty -Name ("NicType"+$y) -Value $_.netType
						$vmPso | Add-Member -MemberType NoteProperty -Name ("NicMacAddress"+$y) -Value $_.netMacAddress
						$vmPso | Add-Member -MemberType NoteProperty -Name ("NicPortgroup"+$y) -Value $_.netPortgroup
						$vmPso | Add-Member -MemberType NoteProperty -Name ("NicVlan"+$y) -Value $_.netVlan
						$vmPso | Add-Member -MemberType NoteProperty -Name ("NicStartConnected"+$y) -Value $_.netStartConnected
						$vmPso | Add-Member -MemberType NoteProperty -Name ("NicConnected"+$y) -Value $_.netConnected
					}
					$tmpy = $y
				}
				If($toty -le $tmpy){$toty = $tmpy}
				
				$netInfo = $null
				#endregion
				#region Cluster, Host, Platform
				$vmPso | Add-Member -MemberType NoteProperty -Name "ClusterName" -Value $cl.Name
				$vmPso | Add-Member -MemberType NoteProperty -Name "ESXiHost" -Value $esxi.Name
	
				$OperSys = $vm.Config.GuestFullName
				$platfrm=$null
				If($OperSys -eq $null -or $OperSys -eq ""){ $OperSys = $vm.Config.AlternateGuestName }
				If($OperSys -eq $null -or $OperSys -eq ""){ $OperSys = $vm.Config.GuestId }
				If($OperSys -like "*Microsoft*" -or $OperSys -like "*Win*"){ 
					If($cl.Name -like "*www*" -or $cl.Name -like "*cl0870*" -or $cl.Name -like "*sql03*" -or $cl.Name -like "*sqlpci03*"){
						$platfrm = "wit"
					}Else{$platfrm = "windows"}
				}ElseIf($vm.Name.StartsWith("y0319") -or $vm.Name.StartsWith("y0870") -or $vm.Name.StartsWith("fwm") -or $OperSys -like "*linux*"){
					$platfrm = "linux"
				}Else{$platfrm = "linux"}
				$vmPso | Add-Member -MemberType NoteProperty -Name "Platform" -Value $platfrm
	
				If($vmPso.ClusterName -like "*pci*" -and ($vmPso.ClusterName -notlike "*non-pci*" -or $vmPso.ClusterName -notlike "*nonpci*")) { $pci = "yes"; $nopci = "no"}Else{$pci = "no"; $nopci = "yes"}
				$vmPso | Add-Member -MemberType NoteProperty -Name "Nopci" -Value $nopci
				$vmPso | Add-Member -MemberType NoteProperty -Name "Pci" -Value $pci
				#endregion				
				#region Hard Disks
				$lsiLogic = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualLsiLogicController]}
				$lsiLogicSas = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualLsiLogicSASController]}
				$busLogic = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualBusLogicController]}
				$pvScsi = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.ParaVirtualSCSIController]}
				
				$multiWriter = $vm.Config.ExtraConfig | ?{$_.Value -eq "multi-writer"}
				
				[array]$hdInfo=  @()
				$lsiLogic | ?{$_ -ne $null} | %{
					$scsi = $_; [string]$busNum = $_.BusNumber; $busSharing = $_.SharedBus; $hDisks = $_.Device
					$hDisks | %{
						$pso = "" | Select hdType,hdCapacity,hdLabel,hdLunUuid,hdRdmCompatibilityMode,hdDatastore,hdFileName,hdFolderName,hdVmdk,hdScsiNode,hdScsiController,hdScsiControllerType,hdScsiBusSharing,hdRdmCanonicalName,hdRdmR2CanonicalName,hdRdmGCCanonicalName,hdMultiWrite
						$hdKey = $_
						$hd = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk] -and $_.Key -eq $hdKey}
						$pso.hdType = $hd.Backing.getType()
						[float]$capacityKB = $hd.CapacityInKB
						$pso.hdCapacity = $capacityKB/1048576 #convert from KB to GB
						$pso.hdLabel = $hd.DeviceInfo.Label
						$pso.hdLunUuid,$pso.hdRdmCompatibilityMode,$pso.hdRdmCanonicalName,$pso.hdRdmR2CanonicalName,$pso.hdRdmGCCanonicalName,$pso.hdMultiWrite = $null, $null, $null, $null, $null, $null
						If($hd.Backing -is [VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo]){ 
							$_hd = $null; $_hd = Get-VM -Name $vm.Name | Get-HardDisk | ?{$_.Name -eq $pso.hdLabel}
							$pso.hdLunUuid = $hd.Backing.LunUuid; 
							$pso.hdRdmCompatibilityMode = $hd.Backing.CompatibilityMode;
							$pso.hdRdmCanonicalName = $_hd.ScsiCanonicalName
							$scriptParams = @{naaLookup=$_hd.ScsiCanonicalName.Replace('naa.','')}
							$pso.hdRdmR2CanonicalName = "naa."+(. $srdfRdmDeviceIdScript @scriptParams).R2naa
							$pso.hdRdmGCCanonicalName = "naa."+(. $srdfRdmDeviceIdScript @scriptParams).GCnaa
						}
						$pso.hdFileName = $hd.Backing.FileName
						$pso.hdDatastore = (Get-View -Id $hd.Backing.Datastore).Name;If($pso.hdDatastore -eq $null -or $pso.hdDatastore -eq ""){$pso.hdDatastore = $pso.hdFileName.Split(']')[0].Replace('[','')}
						$hdfolderName,$hdfilenameName,$dsFolderName=$null,$null,$null;$hdfolderName = $pso.hdFileName; $hdfolderName = $hdfolderName.Split(']')[1]; $dsFolderName = $hdfolderName.Split('/')[0]; $hdfilenameName = $hdfolderName.Split('/')[1]
						$pso.hdFolderName = $dsFolderName.Substring(1)
						$pso.hdVmdk = $hdfilenameName
						$pso.hdScsiNode = ($busNum+":"+$hd.UnitNumber)
						$pso.hdScsiController = $scsi.DeviceInfo.Label
						$pso.hdScsiControllerType = $scsi.DeviceInfo.Summary
						$pso.hdScsiBusSharing = $busSharing
						$hdAdvValue = "scsi"+$pso.hdScsiNode+".sharing"
						$pso.hdMultiWrite = ($multiWriter | ?{$_.Key -eq $hdAdvValue}).Key
						[array]$hdInfo += $pso
						$pso = $null; $hd = $null; $hdKey = $null
					}
					$scsi = $null; [string]$busNum = $null; $busSharing = $null; $hDisks = $null
				}
				$lsiLogicSas | ?{$_ -ne $null} | %{
					$scsi = $_; [string]$busNum = $_.BusNumber; $busSharing = $_.SharedBus; $hDisks = $_.Device
					$hDisks | %{
						$pso = "" | Select hdType,hdCapacity,hdLabel,hdLunUuid,hdRdmCompatibilityMode,hdDatastore,hdFileName,hdFolderName,hdVmdk,hdScsiNode,hdScsiController,hdScsiControllerType,hdScsiBusSharing,hdRdmCanonicalName,hdRdmR2CanonicalName,hdRdmGCCanonicalName,hdMultiWrite
						$hdKey = $_
						$hd = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk] -and $_.Key -eq $hdKey}
						$pso.hdType = $hd.Backing.getType()
						[float]$capacityKB = $hd.CapacityInKB
						$pso.hdCapacity = $capacityKB/1048576 #convert from KB to GB
						$pso.hdLabel = $hd.DeviceInfo.Label
						$pso.hdLunUuid,$pso.hdRdmCompatibilityMode,$pso.hdRdmCanonicalName,$pso.hdRdmR2CanonicalName,$pso.hdRdmGCCanonicalName,$pso.hdMultiWrite = $null, $null, $null, $null, $null, $null
						If($hd.Backing -is [VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo]){ 
							$_hd = $null; $_hd = Get-VM -Name $vm.Name | Get-HardDisk | ?{$_.Name -eq $pso.hdLabel}
							$pso.hdLunUuid = $hd.Backing.LunUuid; 
							$pso.hdRdmCompatibilityMode = $hd.Backing.CompatibilityMode;
							$pso.hdRdmCanonicalName = $_hd.ScsiCanonicalName 
							$scriptParams = @{naaLookup=$_hd.ScsiCanonicalName.Replace('naa.','')}
							$pso.hdRdmR2CanonicalName = "naa."+(. $srdfRdmDeviceIdScript @scriptParams).R2naa
							$pso.hdRdmGCCanonicalName = "naa."+(. $srdfRdmDeviceIdScript @scriptParams).GCnaa
						}
						$pso.hdFileName = $hd.Backing.FileName
						$pso.hdDatastore = (Get-View -Id $hd.Backing.Datastore).Name;If($pso.hdDatastore -eq $null -or $pso.hdDatastore -eq ""){$pso.hdDatastore = $pso.hdFileName.Split(']')[0].Replace('[','')}
						$hdfolderName,$hdfilenameName,$dsFolderName=$null,$null,$null;$hdfolderName = $pso.hdFileName; $hdfolderName = $hdfolderName.Split(']')[1]; $dsFolderName = $hdfolderName.Split('/')[0]; $hdfilenameName = $hdfolderName.Split('/')[1]
						$pso.hdFolderName = $dsFolderName.Substring(1)
						$pso.hdVmdk = $hdfilenameName
						$pso.hdScsiNode = ($busNum+":"+$hd.UnitNumber)
						$pso.hdScsiController = $scsi.DeviceInfo.Label
						$pso.hdScsiControllerType = $scsi.DeviceInfo.Summary
						$pso.hdScsiBusSharing = $busSharing
						$hdAdvValue = "scsi"+$pso.hdScsiNode+".sharing"
						$pso.hdMultiWrite = ($multiWriter | ?{$_.Key -eq $hdAdvValue}).Key
						[array]$hdInfo += $pso
						$pso = $null; $hd = $null; $hdKey = $null
					}
					$scsi = $null; [string]$busNum = $null; $busSharing = $null; $hDisks = $null
				}
				$busLogic | ?{$_ -ne $null} | %{
					$scsi = $_; [string]$busNum = $_.BusNumber; $busSharing = $_.SharedBus; $hDisks = $_.Device
					$hDisks | %{
						$pso = "" | Select hdType,hdCapacity,hdLabel,hdLunUuid,hdRdmCompatibilityMode,hdDatastore,hdFileName,hdFolderName,hdVmdk,hdScsiNode,hdScsiController,hdScsiControllerType,hdScsiBusSharing,hdRdmCanonicalName,hdRdmR2CanonicalName,hdRdmGCCanonicalName,hdMultiWrite
						$hdKey = $_
						$hd = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk] -and $_.Key -eq $hdKey}
						$pso.hdType = $hd.Backing.getType()
						[float]$capacityKB = $hd.CapacityInKB
						$pso.hdCapacity = $capacityKB/1048576 #convert from KB to GB
						$pso.hdLabel = $hd.DeviceInfo.Label
						$pso.hdLunUuid,$pso.hdRdmCompatibilityMode,$pso.hdRdmCanonicalName,$pso.hdRdmR2CanonicalName,$pso.hdRdmGCCanonicalName,$pso.hdMultiWrite = $null, $null, $null, $null, $null, $null
						If($hd.Backing -is [VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo]){ 
							$_hd = $null; $_hd = Get-VM -Name $vm.Name | Get-HardDisk | ?{$_.Name -eq $pso.hdLabel}
							$pso.hdLunUuid = $hd.Backing.LunUuid; 
							$pso.hdRdmCompatibilityMode = $hd.Backing.CompatibilityMode;
							$pso.hdRdmCanonicalName = $_hd.ScsiCanonicalName 
							$scriptParams = @{naaLookup=$_hd.ScsiCanonicalName.Replace('naa.','')}
							$pso.hdRdmR2CanonicalName = "naa."+(. $srdfRdmDeviceIdScript @scriptParams).R2naa
							$pso.hdRdmGCCanonicalName = "naa."+(. $srdfRdmDeviceIdScript @scriptParams).GCnaa
						}
						$pso.hdFileName = $hd.Backing.FileName
						$pso.hdDatastore = (Get-View -Id $hd.Backing.Datastore).Name;If($pso.hdDatastore -eq $null -or $pso.hdDatastore -eq ""){$pso.hdDatastore = $pso.hdFileName.Split(']')[0].Replace('[','')}
						$hdfolderName,$hdfilenameName,$dsFolderName=$null,$null,$null;$hdfolderName = $pso.hdFileName; $hdfolderName = $hdfolderName.Split(']')[1]; $dsFolderName = $hdfolderName.Split('/')[0]; $hdfilenameName = $hdfolderName.Split('/')[1]
						$pso.hdFolderName = $dsFolderName.Substring(1)
						$pso.hdVmdk = $hdfilenameName
						$pso.hdScsiNode = ($busNum+":"+$hd.UnitNumber)
						$pso.hdScsiController = $scsi.DeviceInfo.Label
						$pso.hdScsiControllerType = $scsi.DeviceInfo.Summary
						$pso.hdScsiBusSharing = $busSharing
						$hdAdvValue = "scsi"+$pso.hdScsiNode+".sharing"
						$pso.hdMultiWrite = ($multiWriter | ?{$_.Key -eq $hdAdvValue}).Key
						[array]$hdInfo += $pso
						$pso = $null; $hd = $null; $hdKey = $null
					}
					$scsi = $null; [string]$busNum = $null; $busSharing = $null; $hDisks = $null
				}
				$pvScsi | ?{$_ -ne $null} | %{
					$scsi = $_; [string]$busNum = $_.BusNumber; $busSharing = $_.SharedBus; $hDisks = $_.Device
					$hDisks | %{
						$pso = "" | Select hdType,hdCapacity,hdLabel,hdLunUuid,hdRdmCompatibilityMode,hdDatastore,hdFileName,hdFolderName,hdVmdk,hdScsiNode,hdScsiController,hdScsiControllerType,hdScsiBusSharing,hdRdmCanonicalName,hdRdmR2CanonicalName,hdRdmGCCanonicalName,hdMultiWrite
						$hdKey = $_
						$hd = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk] -and $_.Key -eq $hdKey}
						$pso.hdType = $hd.Backing.getType()
						[float]$capacityKB = $hd.CapacityInKB
						$pso.hdCapacity = $capacityKB/1048576 #convert from KB to GB
						$pso.hdLabel = $hd.DeviceInfo.Label
						$pso.hdLunUuid,$pso.hdRdmCompatibilityMode,$pso.hdRdmCanonicalName,$pso.hdRdmR2CanonicalName,$pso.hdRdmGCCanonicalName,$pso.hdMultiWrite = $null, $null, $null, $null, $null, $null
						If($hd.Backing -is [VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo]){ 
							$_hd = $null; $_hd = Get-VM -Name $vm.Name | Get-HardDisk | ?{$_.Name -eq $pso.hdLabel}
							$pso.hdLunUuid = $hd.Backing.LunUuid; 
							$pso.hdRdmCompatibilityMode = $hd.Backing.CompatibilityMode;
							$pso.hdRdmCanonicalName = $_hd.ScsiCanonicalName 
							$scriptParams = @{naaLookup=$_hd.ScsiCanonicalName.Replace('naa.','')}
							$pso.hdRdmR2CanonicalName = "naa."+(. $srdfRdmDeviceIdScript @scriptParams).R2naa
							$pso.hdRdmGCCanonicalName = "naa."+(. $srdfRdmDeviceIdScript @scriptParams).GCnaa
						}
						$pso.hdFileName = $hd.Backing.FileName
						$pso.hdDatastore = (Get-View -Id $hd.Backing.Datastore).Name;If($pso.hdDatastore -eq $null -or $pso.hdDatastore -eq ""){$pso.hdDatastore = $pso.hdFileName.Split(']')[0].Replace('[','')}
						$hdfolderName,$hdfilenameName,$dsFolderName=$null,$null,$null;$hdfolderName = $pso.hdFileName; $hdfolderName = $hdfolderName.Split(']')[1]; $dsFolderName = $hdfolderName.Split('/')[0]; $hdfilenameName = $hdfolderName.Split('/')[1]
						$pso.hdFolderName = $dsFolderName.Substring(1)
						$pso.hdVmdk = $hdfilenameName
						$pso.hdScsiNode = ($busNum+":"+$hd.UnitNumber)
						$pso.hdScsiController = $scsi.DeviceInfo.Label
						$pso.hdScsiControllerType = $scsi.DeviceInfo.Summary
						$pso.hdScsiBusSharing = $busSharing
						$hdAdvValue = "scsi"+$pso.hdScsiNode+".sharing"
						$pso.hdMultiWrite = ($multiWriter | ?{$_.Key -eq $hdAdvValue}).Key
						[array]$hdInfo += $pso
						$pso = $null; $hd = $null; $hdKey = $null
					}
					$scsi = $null; [string]$busNum = $null; $busSharing = $null; $hDisks = $null
				}
	
				For($x=1;$x -lt $hdInfo.Count+1;$x++){
				[bool]$isRep = $false; [bool]$noRep = $false
				$lookup = "Hard disk "+($x)
					$hdInfo | ?{$_.hdLabel -eq $lookup} | %{
						If($_.hdDatastore.EndsWith("_rpl")){ $isRep = $true 
						}Else{
							If($_.hdType.FullName -eq "VMware.Vim.VirtualDiskFlatVer2BackingInfo"){
								$noRep = $true
							}
						}
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskLabel"+$x) -Value $_.hdLabel
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskType"+$x)-Value $_.hdType.FullName
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskCapacity"+$x) -Value $_.hdCapacity
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskDatastore"+$x) -Value $_.hdDatastore
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskFileName"+$x) -Value $_.hdFileName
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskFolderName"+$x) -Value $_.hdFolderName
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskVmdk"+$x) -Value $_.hdVmdk
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskScsiNode"+$x) -Value $_.hdScsiNode
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskScsiController"+$x) -Value $_.hdScsiController
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskScsiControllerType"+$x) -Value $_.hdScsiControllerType
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskScsiBusSharing"+$x) -Value $_.hdScsiBusSharing
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskLunUuid"+$x) -Value $_.hdLunUuid
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskRdmCompatibilityMode"+$x) -Value $_.hdRdmCompatibilityMode
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskRdmCanonicalName"+$x) -Value $_.hdRdmCanonicalName
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskRdmReplicationR2"+$x) -Value $_.hdRdmR2CanonicalName
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskRdmReplicationGC"+$x) -Value $_.hdRdmGCCanonicalName
						$vmPso | Add-Member -MemberType NoteProperty -Name ("DiskMultiWrite"+$x) -Value $_.hdMultiWrite
						$tmpx = $x
					}					
				}
				#if isRep and noRep are both $true then we mark this VM as not being replicated since at least 1 VMDK isn't replicated
				If($isRep -and (-not $noRep)){ $vmPso.DR = "yes" }
				If($dc.Name -eq "0870"){ $vmPso.DR = "yes" }
				If($totx -lt $tmpx){$totx = $tmpx}
				
				$hdInfo = $null
				#endregion
				$tOutputArry += $vmPso				
				$vmPso = $null
			}
		}
		[array]$clusterVMHosts += $clusterHosts
	}
}
Disconnect-VIServer -Server $vc -Confirm:$false -Force:$true
} #end vcenter loop
For($n=1;$n -le $toty;$n++ ){
	[string] $tstr = 'NicPortgroup' + $n
	$selObj += ,$tstr
	[string] $tstr = 'NicVlan' + $n
	$selObj += ,$tstr
	[string] $tstr = 'NicType' + $n
	$selObj += ,$tstr
	[string] $tstr = 'NicMacAddress' + $n
	$selObj += ,$tstr
	[string] $tstr = 'NicStartConnected' + $n
	$selObj += ,$tstr
	[string] $tstr = 'NicConnected' + $n
	$selObj += ,$tstr
}

For($d=1;$d -le $totx;$d++ ){
	[string] $tstr = 'DiskLabel' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskType' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskCapacity' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskDatastore' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskFileName' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskFolderName' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskVmdk' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskScsiNode' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskScsiController' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskScsiControllerType' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskScsiBusSharing' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskLunUuid' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskRdmCompatibilityMode' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskRdmCanonicalName' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskRdmReplicationR2' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskRdmReplicationGC' + $d
	$selObj += ,$tstr
	[string] $tstr = 'DiskMultiWrite' + $d
	$selObj += ,$tstr
}

$selObj += ,"ClusterName"
$selObj += ,"ESXiHost"
$selObj += ,"Platform"
$selObj += ,"Nopci"
$selObj += ,"Pci"
#$selObj += ,"DR"
$selObj += ,"Template"

$OutputArry = $tOutputArry | Select $selObj
[array]$drReport = @(); $clusterCpu = @{}; $clusterMem = @{}
$OutputArry | ?{$_.DR -eq "yes"} | %{ $thisVm = $_
	$chkKeys = $clusterCpu.Keys | ?{$_ -eq $thisVm.ClusterName }
	If([string]::IsNullOrEmpty($chkKeys)){ $clusterCpu.Add($thisVm.ClusterName,0) }
	[float]$cpu = $clusterCpu[$thisVm.ClusterName]
	$newCpu = $cpu + [int]::Parse($thisVm.vCPU)
	$clusterCpu[$thisVm.ClusterName] = $newCpu
	
	$chkKeys = $clusterMem.Keys | ?{$_ -eq $thisVm.ClusterName }
	If([string]::IsNullOrEmpty($chkKeys)){ $clusterMem.Add($thisVm.ClusterName,0) }
	[float]$mem = $clusterMem[$thisVm.ClusterName]
	$newMem = $mem + [float]::Parse($thisVm.Memory)
	$clusterMem[$thisVm.ClusterName] = $newMem
}
[array]$totVmHosts = @()
$clusterCpu.Keys | %{$obj = $_
	[double]$val1 = $clusterCpu[$obj]
	[double]$val2 = $clusterMem[$obj]
	If($val1 -ge $val2){ [double]$numHosts = [Math]::Ceiling(($val1/160)+1) }#CPU is limiting, 4:1 oversubscription of CPU
	ElseIf($val2 -ge $val1){ [double]$numHosts = [Math]::Ceiling(($val2/512)+1) } #MEM is limiting; 512GB of memory per esxi host
	If($obj -like "*ora*" -or $obj -like "*com*"){ $numHosts = $numHosts + 1 }
	$pso1 = "" | Select Cluster,vCPU,MemoryGB,NumHosts,VMHosts,SubnetMask,DefaultGateway,VlanID,Dns,Environment
	$pso1.Cluster = $obj
	$pso1.vCPU = $val1
	$pso1.MemoryGB = $val2
	$pso1.NumHosts = $numHosts
	[array]$totVmHosts += $numHosts
	[array]$drReport += $pso1
	$pso1 = $null
}

[string] $drDns = "10.12.138.20,10.12.137.20"
$drReport | %{ $thisObj = $_
	$thisObj.Dns = $drDns
	$getVMHosts = ($clusterVMHosts | ?{$_.Cluster -eq $thisObj.Cluster}).VMHosts
	For($x=0; $x -lt $thisObj.NumHosts; $x++){
		$esxi = $getVMHosts[$x]
		If([string]::IsNullOrEmpty($thisObj.VlanID)){
			$thisObj.VlanID = $esxi.VlanId
		}
		If([string]::IsNullOrEmpty($thisObj.SubnetMask)){ $thisObj.SubnetMask = $esxi.SubnetMask }
		If([string]::IsNullOrEmpty($thisObj.DefaultGateway)){ $thisObj.DefaultGateway = $esxi.DefaultGateway }
		If([string]::IsNullOrEmpty($thisObj.Environment)){ $thisObj.Environment = $esxi.Environment }
		
		$esxiHost = $esxi.Name+"/"+$esxi.IpAddress
		If([string]::IsNullOrEmpty($thisObj.VMHosts)){ $thisObj.VMHosts = $esxiHost }
		Else{ $thisObj.VMHosts += (","+$esxiHost) }
	}
}

$thisDate = Get-Date
$path = "\\nord\dr\Software\VMware\Reports\VMInventory\VMInventory"+$thisDate.Month +"_"+ $thisDate.Day +"_"+ $thisDate.Year +".csv"
$chkPath = "\\nord\dr\Software\VMware\Reports\VMInventory\VMInventory*"
$OutputArry | Export-Csv $path -NoTypeInformation -Confirm:$false -Force:$true
$drReport | Export-Csv "\\nord\dr\Software\VMware\Reports\DisasterRecovery\DRHardwareNeeds.csv" -NoTypeInformation -Confirm:$false -Force:$true
$OutputArry | Export-Csv "\\nord\dr\Software\VMware\Reports\DisasterRecovery\VMInventory.csv" -NoTypeInformation -Confirm:$false -Force:$true

Do{
	[array]$files = Get-ChildItem $chkPath | Sort Name
	$tmpFile = $null
	If($files.Count -gt 60){
		$files | %{
			If($_.CreationTime -lt $tmpFile.CreationTime -or $tmpFile -eq $null){ $tmpFile = $_ }
		}
		Remove-Item $tmpFile
	}
}While($files.Count -gt 60)

Get-Date
