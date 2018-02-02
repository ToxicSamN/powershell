Param(
  [Parameter(Mandatory=$true,Position=0)]
  [string]$vCenter,
  [Parameter(Mandatory=$true,Position=1)]
  [ValidateScript({ 
    If($_.Length -eq 4){ $_ }Else{ throw "Parameter must be a 4-digit number such as 0076. Please check this parameter and try again." }
  })]
  [string]$Store,
  [Parameter(Mandatory=$true,Position=2)]
  $VmName,
  [Parameter(Mandatory=$true,Position=3)]
  [string]$ISOFileName,
  [Parameter(Mandatory=$false,Position=4)]
  [string]$Template = "template_PaloAlto_firewall"
)
Function Get-DeployVMHost {
<#
.SYNOPSIS
    Used for Nordstrom New store VM Deployments to get a VMHost to deploy a VM to.
.DESCRIPTION
    New stores do not have DRS. So a VM can be deployed to any VMHost in the cluster.
	However, in the SIABv2 setup we are specifiying a failover host and unfortunately
	when deploying a VM to the cluster the VM may be deployed to the failover host.
	This only happens in powercli. if the same was attempted in the webClient then the 
	VM would fail to deploy to the failover host. So this function will check the cluster 
	for an HA Admission policy of 'specified failover host' and remove that from the VMHost
	pool and then return a random host out of the available hosts.
.PARAMETER Cluster
    MANDATORY
	Specify a Cluster object. This can be a get-Cluster object or a Get-View -ViewType ClusterComputeResource object only
.EXAMPLE
    Get-DeployVMHost (Get-Cluster -Name "MyvSphereCluster")
.NOTES
    Author: Sammy Shuck
    Date:   June 10, 2016
#>
	Param(
	[ValidateScript({
		If($_ -is [VMware.Vim.ComputeResource] -or $_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ComputeResourceImpl]){
			$_
		}Else{
			throw "Cannot convert from type [$($_.getType().FullName)] to [VMware.Vim.ComputeResource] or [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ComputeResourceImpl]"
		}
	})]
	[Parameter(Mandatory=$true)]
		$Cluster = $null		
	)
	
	Begin{
		$deployVMHost=$null
		If($Cluster -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ComputeResourceImpl]){ 
			try{ $Cluster = Get-View $Cluster } catch { Write-Log -Message $_.Exception.Message -Path "$($UcgLogPath)\Deploy-StoreFirewall.log"; Write-Error $_.Exception.Message; throw $_ }
		}
	}
	Process{
		try{
			If($Cluster.ConfigurationEx.DasConfig.AdmissionControlPolicy -is [VMware.Vim.ClusterFailoverHostAdmissionControlPolicy]){ 
				$VMHostPool = $Cluster.Host | ?{$Cluster.ConfigurationEx.DasConfig.AdmissionControlPolicy.FailoverHosts -notcontains $_ }
			}Else{
				$VMHostPool = $Cluster.Host
			}
			$pickHost = $VMHostPool[(Get-Random -Minimum 0 -Maximum $VMHostPool.Count)]
			$deployVMHost = (Get-VMHost -Id $pickHost)
			
		}
		catch{
      Write-Log -Message $_.Exception.Message -Path "$($UcgLogPath)\Deploy-StoreFirewall.log"
			Write-Error $_.Exception.Message -ErrorAction Stop
		}
	}
	End{
		return $deployVMHost
	}
}
Function Get-DeployDatastore{
  <#
.SYNOPSIS
    Used for Nordstrom New store VM Deployments to get a Datastore to deploy a VM to.
.DESCRIPTION
    New stores do not have an MSA. So a VM can be deployed to vsanDatastore or to the MSA datastores.
.PARAMETER Cluster
    MANDATORY
	Specify a Cluster object. This can be a Get-Cluster object or a Get-View -ViewType ClusterComputeResource object only
.EXAMPLE
    Get-DeployDatastore (Get-Cluster -Name "MyvSphereCluster")
.NOTES
    Author: Sammy Shuck
    Date:   October 12, 2016
#>
	Param(
	[ValidateScript({
		If($_ -is [VMware.Vim.ComputeResource] -or $_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ComputeResourceImpl]){
			$_
		}Else{
			throw "Cannot convert from type [$($_.getType().FullName)] to [VMware.Vim.ComputeResource] or [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ComputeResourceImpl]"
		}
	})]
	[Parameter(Mandatory=$true)]
		$Cluster = $null		
	)
	
	Begin{
		$deployDatastore=$null
		If($Cluster -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ComputeResourceImpl]){ 
			try{ [VMware.Vim.ComputeResource]$Cluster = Get-View $Cluster } catch { Write-Log -Message $_.Exception.Message -Path "$($UcgLogPath)\Deploy-StoreFirewall.log"; Write-Error $_.Exception.Message; throw $_ }
		}
	}
	Process{
		try{
			$dc = Get-VIObjectByVIView -MORef $Cluster.MoRef | Get-Datacenter
      [array]$ds = Get-Datastore -Location $dc | ?{$_.Type -eq "VMFS" -or $_.Type -eq "vsan" -or $_.Type -eq "NFS"}
      [array]$availableDS = @()
      [array]$availableDS = $ds | ?{($_.Name -like "*pci*p2000*" -or $_.Name -like "*vsan*" -or $_.Name -like "*CTR*VM-*") -and ((($_.CapacityGB -as [float]) -gt 900) -and ((($_.FreeSpaceGB -as [float])/($_.CapacityGB -as [float]))*100 -gt 30))}
      If([string]::IsNullOrEmpty($availableDS)){
        throw "No available datastore to deploy to."
      }Else{
        $max = ($availableDS | Measure-Object -Property FreeSpaceGB -Maximum).Maximum
        $deployDatastore = $availableDS | ?{$_.FreeSpaceGB -eq $max}
      }
		}
		catch{
			Write-Log -Message $_.Exception.Message -Path "$($UcgLogPath)\Deploy-StoreFirewall.log"
      Write-Error $_.Exception.Message -ErrorAction Stop
		}
	}
	End{
		return $deployDatastore
	}
}
Function Mount-PaloAltoISO{
  Param(
    [Parameter(Mandatory=$false, Position=0)]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]
    $VM,
    [Parameter(Mandatory=$false, Position=1)]
    $ISOFileName=$null,
    [Parameter(Mandatory=$false, Position=2)]
    $ISOFilePath=$null
  )
  Begin{
    $return = $null
    
    If($ISOFileName){
      $clObj = $VM | Get-VmCluster
      $datastores = $clObj | Get-Datastore | ?{$_.Type -eq "VMFS" -or $_.Type -eq "VSAN" -or $_.Type -eq "NFS"} 
      Foreach($ds in $datastores){
        If(Test-Path "$($ds.DatastoreBrowserPath)\ISO\$($ISOFileName)"){
          $ISOFilePath = "$($ds.DatastoreBrowserPath)\ISO\$($ISOFileName)"
          break
        }
      }
      If([string]::IsNullOrEmpty($ISOFilePath)){
        Write-Log -Message "Cannot find a datastore path for $($ISOFileName). Please ensure the ISO file is located in a directory named 'ISO' on the datastore" -Path "$($UcgLogPath)\Deploy-StoreFirewall.log"
        Write-Error "Cannot find a datastore path for $($ISOFileName). Please ensure the ISO file is located in a directory named 'ISO' on the datastore"  -Category:ObjectNotFound -CategoryActivity "Get-ChildItem" -CategoryReason "ItemNotFoundException" -ErrorAction Stop
      }
    }ElseIf($ISOFilePath){
      #Not an available at this time, so I will just error out here
      Write-Log -Message "Do Not use parameter ISOFilePath" -Path "$($UcgLogPath)\Deploy-StoreFirewall.log"
      Write-Error "Do Not use parameter ISOFilePath"  -Category:ObjectNotFound -CategoryActivity "Get-ChildItem" -CategoryReason "ItemNotFoundException" -ErrorAction Stop
    }Else{
      Write-Log -Message "Cannot process command because of one or more missing mandatory parameters: ISOFileName or ISOFilePath." -Path "$($UcgLogPath)\Deploy-StoreFirewall.log"
      Write-Error "Cannot process command because of one or more missing mandatory parameters: ISOFileName or ISOFilePath." -Category:InvalidArgument -CategoryReason "ParameterBindingException" -CategoryActivity "Mount-PaloAltoISO" -ErrorAction Stop
    }
  }
  Process{
    #The Set-CDDrive will only accept ISO paths of [datastoreName] Folder\ISO.iso instead of something like
    #vmstores:\a0319p1203@443\0864\vsanDatastore\ISO\fwtest.iso. So we have to take the vmstores path and create the accepted path.
    $ds = $ISOFilePath.Split('\')[3]
    $ISOPath = "[$($ds)] ISO\$($ISOFileName)"
    $cd = Get-CDDrive -VM $VM
    $return = Set-CDDrive -CD $cd -IsoPath $ISOPath -StartConnected:$true -Confirm:$false
  }
  End{
    return $return
  }
}
#Add-PSSnapin VM* -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Import-Module UcgModule -ArgumentList vmware -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
#Get-Job | Remove-Job -Confirm:$false
cls
try{
  Connect-VIServer -Server $vCenter -Credential (Login-vCenter) -ErrorAction Stop -WarningAction SilentlyContinue
  $dc = Get-Datacenter | ?{$_.Name -like "*$($Store)*"} #using -like as some datacenters may be labeled -Lab or something. Also, validation for 4 digit store number is in param
  If([string]::IsNullOrEmpty($dc)){ throw "Unable to locate Datacenter $($Store) in Virtual Center $($vCenter)." }
  $tmp = Get-Template -Name $Template -Location $dc -ErrorAction Stop
  $vmhost = Get-DeployVMhost -Cluster (Get-VmCluster -Location $dc)
  $ds = Get-DeployDatastore -Cluster (Get-VmCluster -Location $dc)
  $VM = Get-VM -Name $VmName -ErrorAction SilentlyContinue
  If([string]::IsNullOrEmpty($VM)){
    $VM = New-VM -Template $tmp -Name $VmName -Datastore $ds -VMHost $vmhost -Location ($dc | Get-Folder -Type VM -NoRecursion) -ResourcePool (Get-VmCluster -Location $dc) -Confirm:$false -DiskStorageFormat:Thin -ErrorAction Stop
  }
  
  $outNull = Get-NetworkAdapter -VM $VM | Remove-NetworkAdapter -Confirm:$false -ErrorAction Stop
  $outNull = $vm | New-NetworkAdapter -NetworkName "v12_vFirewall" -StartConnected:$true -Type:Vmxnet3 -Confirm:$false -ErrorAction Stop
  $outNull = $vm | New-NetworkAdapter -NetworkName "v18_vFirewall" -StartConnected:$true -Type:Vmxnet3 -Confirm:$false -ErrorAction Stop
  $outNull = $vm | New-NetworkAdapter -NetworkName "v12_vFirewall" -StartConnected:$true -Type:Vmxnet3 -Confirm:$false -ErrorAction Stop
  $outNull = $vm | New-NetworkAdapter -NetworkName "vFirewall_Trunk" -StartConnected:$true -Type:Vmxnet3 -Confirm:$false -ErrorAction Stop
  
  $outNull = Mount-PaloAltoISO -VM $VM -ISOFileName $ISOFileName
  
  Disconnect-VIServer -Server $vCenter -Confirm:$false -Force:$true -ErrorAction SilentlyContinue
  exit 0
}catch{
  Write-Log -Message $_ -Path "$($UcgLogPath)\Deploy-StoreFirewall.log"
  Write-Error $_
  throw $_
}