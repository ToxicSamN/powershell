# created by sammy shuck
Param(
	[string]$vCenter=""
)
cls

Import-Module UcgModule -ArgumentList vmware -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
cls

try{
	#connect to vcenter
	try{
		$vi = Connect-VIServer -Server $vCenter -Credential (Login-vCenter)
	}catch{
		throw "Connect-VIServer : $($_.Exception.Message)"
	}
	
	#ensure the custom attributes are created
	[array]$custAtt = Get-CustomAttribute
	
	$chk=$null;$chk=$custAtt | ?{$_.TargetType -eq "VMhost" -and $_.Name -eq "Stateless Runtime"}
	If([string]::IsNullOrEmpty($chk)){ New-CustomAttribute -Name "Stateless Runtime" -TargetType VMHost -Confirm:$false -ErrorAction Stop | Out-Null }
	
	$chk=$null;$chk=$custAtt | ?{$_.TargetType -eq "VMhost" -and $_.Name -eq "Landmines"}
	If([string]::IsNullOrEmpty($chk)){ New-CustomAttribute -Name "Landmines" -TargetType VMHost -Confirm:$false -ErrorAction Stop | Out-Null }
	
	$chk=$null;$chk=$custAtt | ?{$_.TargetType -eq "VirtualMachine" -and $_.Name -eq "Landmine"}
	If([string]::IsNullOrEmpty($chk)){ New-CustomAttribute -Name "Landmine" -TargetType VirtualMachine -Confirm:$false -ErrorAction Stop | Out-Null }
	
	$chk=$null;$chk=$custAtt | ?{$_.TargetType -eq "VirtualMachine" -and $_.Name -eq "Landmine Description"}
	If([string]::IsNullOrEmpty($chk)){ New-CustomAttribute -Name "Landmine Description" -TargetType VirtualMachine -Confirm:$false -ErrorAction Stop | Out-Null }
	
	$SI = Get-View ServiceInstance
	$CFM = Get-View $SI.Content.CustomFieldsManager
	
	[array]$DrsVmConfig = @()
	Get-View -ViewType ClusterComputeResource | %{ $cl = $_		
		$clConfigEx = $cl.ConfigurationEx
		#the DrsVmConfig will not be null if any setting is set on the VMs other than DEFAULT
		If(-not [string]::IsNullOrEmpty($clConfigEx.DrsVmConfig)){
			#a VM may be set to something other than DEFAULT and so we need to check if this setting is fullyAutomated, otherwise it is a Landmine
			$clConfigEx.DrsVmConfig | ?{$_.Behavior -ne "fullyAutomated" -or $_.Enabled -eq $false} | %{ 
				[array]$DrsVmConfig += $_.Key #"$($_.Key.Type)-$($_.Key.Value)"
			}
		}

		Get-View -ViewType HostSystem -SearchRoot $cl.MoRef | %{ $esxi = $_
			[string]$esxiStateless = $null
			[string]$esxiLandmines = $null
			#Set landmines to FALSE until evaluated. If a landmine is found then the custAtt will be set to TRUE
			[string]$esxiLandmines = "FALSE"
			
			try{
				$esxcli = Get-EsxCli -VMHost (Get-VIObjectByVIView $esxi.MoRef)
				$chk=$null;$chk=$esxcli.system.boot.device.get() | Select BootFileSystemUUID
				#if BootFileSystemUUID is not NULL then the system is booted to a disk/install
				#Otherwise the system is booted Statless via PXE (Auto Deploy)
				If([string]::IsNullOrEmpty($chk.BootFileSystemUUID)){
					[string]$esxiStateless = "TRUE"
				}Else{
					[string]$esxiStateless = "FALSE"
				}
			}catch{
				Write-Log -Path "$($ScriptyServerUNC)\UCG-Logs\Update-CustomAttribute_ErrorLog.log" -Message "[$(Get-Date)]`t$($esxi.Name) : Get-EsxCli : $($_.Exception.Message)"
			}
			Get-View -ViewType VirtualMachine -SearchRoot $esxi.MoRef | %{ $vm = $_
				#Set landmines to FALSE until evaluated. If a landmine is found then the custAtt will be set to a VALUE
				[string]$vmLandmine = $null
				$chk=$null;$chk=$DrsVmConfig | ?{$_ -eq $vm.MoRef}
				If(-not [string]::IsNullOrEmpty($chk)){
          If ($vm.Name -notlike "Z-VRA*" -and $vm.Name -notlike "*-CVM"){
            [string]$esxiLandmines = "TRUE"
            $custField = $CFM.Field | ?{$_.ManagedObjectType -eq "VirtualMachine" -and $_.Name -eq "Landmine"}
            $chk=$null;$chk=$vm.CustomValue | ?{$_.Key -eq $custField.Key}
            [string]$vmLandmine = "$($vmLandmine) | No-vMotion"
          }
				}
				
				$chk=$null;$chk=$vm.Config.ExtraConfig | ?{$_.Value -eq "multi-writer"}
				If(-not [string]::IsNullOrEmpty($chk)){ 
					[string]$esxiLandmines = "TRUE"
					$custField = $CFM.Field | ?{$_.ManagedObjectType -eq "VirtualMachine" -and $_.Name -eq "Landmine"}
					$chk=$null;$chk=$vm.CustomValue | ?{$_.Key -eq $custField.Key}
					[string]$vmLandmine = "$($vmLandmine) | SharedVMDK"
				}
				
				[array]$scsiController=$vm.Config.Hardware.Device | ?{ $_.GetType().BaseType.FullName -eq "VMware.Vim.VirtualSCSIController" }
				$chk=$null;$chk=$scsiController | ?{ $_.SharedBus -ne "noSharing" -and $_.SharedBus.Length -gt 0}
				If(-not [string]::IsNullOrEmpty($chk)){ 
					[string]$esxiLandmines = "TRUE"
					$custField = $CFM.Field | ?{$_.ManagedObjectType -eq "VirtualMachine" -and $_.Name -eq "Landmine"}
					$chk=$null;$chk=$vm.CustomValue | ?{$_.Key -eq $custField.Key}
					[string]$vmLandmine = "$($vmLandmine) | SharedScsiBus"
				}
				
				$vmDisk = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk]}
				$chk=$null;$chk=$vmDisk | ?{$_.Backing -is [VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo]}
				If(-not [string]::IsNullOrEmpty($chk)){ 
					[string]$esxiLandmines = "TRUE"
					$custField = $CFM.Field | ?{$_.ManagedObjectType -eq "VirtualMachine" -and $_.Name -eq "Landmine"}
					$chk=$null;$chk=$vm.CustomValue | ?{$_.Key -eq $custField.Key}
					[string]$vmLandmine = "$($vmLandmine) | RDM"
				}
				
				try{
					$custField = $CFM.Field | ?{$_.ManagedObjectType -eq "VirtualMachine" -and $_.Name -eq "Landmine"}
          If (($vm.CustomValue | ?{ $_.Key -eq $custField.Key}).Value -ne $vmLandmine) { 
            $vm.setCustomValue($custField.Name,$vmLandmine) | Out-Null
            $vm.UpdateViewData()
          }
				}catch{
					Write-Log -Path "$($ScriptyServerUNC)\UCG-Logs\Update-CustomAttribute_ErrorLog.log" -Message "[$(Get-Date)]`t$($vm.Name) : setCustomValue() : $($_.Exception.Message)"
					#throw "$($vm.Name) : setCustomValue() : $($_.Exception.Message)"
				}
			}
			
			try{
				$custField = $CFM.Field | ?{$_.ManagedObjectType -eq "HostSystem" -and $_.Name -eq "Landmines"}
        If (($esxi.CustomValue | ?{ $_.Key -eq $custField.Key}).Value -ne $esxiLandmines) { 
          $esxi.setCustomValue($custField.Name,$esxiLandmines) | Out-Null
          $esxi.UpdateViewData()
        }
				$custField = $CFM.Field | ?{$_.ManagedObjectType -eq "HostSystem" -and $_.Name -eq "Stateless Runtime"}
        If (($esxi.CustomValue | ?{ $_.Key -eq $custField.Key}).Value -ne $esxiStateless) { 
          $esxi.setCustomValue($custField.Name,$esxiStateless) | Out-Null
          $esxi.UpdateViewData()
        }
			}catch{
				Write-Log -Path "$($ScriptyServerUNC)\UCG-Logs\Update-CustomAttribute_ErrorLog.log" -Message "[$(Get-Date)]`t$($esxi.Name) : setCustomValue() : $($_.Exception.Message)"
				#throw "$($esxi.Name) : setCustomValue() : $($_.Exception.Message)"
			}
		}
	}
	
}catch{
	Write-Error $_.Exception.Message
	Write-Log -Path "$($ScriptyServerUNC)\UCG-Logs\Update-CustomAttribute_ErrorLog.log" -Message "[$(Get-Date)]`t$($_.Exception.Message)"
	Exit 1
}
Disconnect-VIServer * -Confirm:$false
