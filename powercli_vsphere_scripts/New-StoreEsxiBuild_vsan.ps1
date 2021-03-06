#created by sammy shuck
# date mar 2017
# modified by scott

Param(
	[parameter(Mandatory = $true)]
	[string]$vCenter=$null,
	[parameter(Mandatory = $true)]
	[array]$VMHost=$null,
	[parameter(Mandatory = $true)]
	[string]$Cluster=$null,
	[parameter(Mandatory = $true)]
	[string]$Datacenter=$null
)
Function SetVmwareCmdletAlias(){
<#
.SYNOPSIS
	Create an alias for the Cluster cmdlets for VMware.
	
.DESCRIPTION
	Creates an Alias to VMware <verb>-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then these cmdlets will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority.

.EXAMPLE
	PS C:\> SetVmwareCmdletAlias
#>
	New-Alias -Description "This is an Alias to VMware New-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then this cmdlet will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority." -Name New-VmCluster -Value VMware.VimAutomation.Core\New-Cluster -Force:$true -Confirm:$false -PassThru:$true -Scope Global | Out-Null
	New-Alias -Description "This is an Alias to VMware Get-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then this cmdlet will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority." -Name Get-VmCluster -Value VMware.VimAutomation.Core\Get-Cluster -Force:$true -Confirm:$false -PassThru:$true -Scope Global | Out-Null
	New-Alias -Description "This is an Alias to VMware Set-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then this cmdlet will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority." -Name Set-VmCluster -Value VMware.VimAutomation.Core\Set-Cluster -Force:$true -Confirm:$false -PassThru:$true -Scope Global | Out-Null
	New-Alias -Description "This is an Alias to VMware Remove-Cluster cmdlet. If Microsoft FailoverClusters Module is loaded then this cmdlet will not work because both Vmware and Microsoft use the same Verb-Noun combination and Microsoft usually takes priority." -Name Remove-VmCluster -Value VMware.VimAutomation.Core\Remove-Cluster -Force:$true -Confirm:$false -PassThru:$true -Scope Global | Out-Null
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
   $snapinList += "VMware.VumAutomation"

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
Function New-ProfileDefferedPolicyOptionParameter(){
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		$HostProfileRequiredInput
	)
	Begin{
		$pdpop = New-Object VMWare.Vim.ProfileDeferredPolicyOptionParameter
	}
	Process{
		#create the ProfileDeferredPolicyOptionParameter objec
		$HostProfileRequiredInput | %{ $obj = $_
			$tmp = $obj.Key.Split(".")
			$policyId = $tmp[$tmp.Count-2]
			$paramKey = $tmp[$tmp.Count-1]
			$profilePath = $obj.Key.Replace(".$($policyId).$($paramKey)","")
			
			$profPath = New-Object VMWare.Vim.ProfilePropertyPath
				$profPath.ProfilePath = $profilePath
				$profPath.PolicyId = $policyId
			$pdpop.InputPath = $profPath
			
			$paramKV = New-Object VMWare.Vim.KeyAnyValue
				$paramKv.Key = $paramKey
				#leave the value alone to be set by the user
			$pdpop.Parameter += $paramKV
		}
	}
	End{ 
		return $pdpop 
	}
}
Function Validate-Datacenter{
  Param(
    [string]$Datacenter
   )
   Begin{
    $dc,$dcObj = $null,$null
   }
   Process{
    try{
      Write-Progress -Activity "Checking for Datacenter $($Datacenter)" -PercentComplete 50 -Id 91
      $dc = Get-View -ViewType Datacenter -Filter @{"Name"=$Datacenter}
      If([string]::IsNullOrEmpty($dc)){ 
	      Write-Progress -Activity "Creating Datacenter $($Datacenter)" -PercentComplete 99 -Id 92 -ParentId 91
	      $dcObj = New-Datacenter -Name $Datacenter -Location (Get-Folder -NoRecursion) -Confirm:$false -ErrorAction Stop 
	      $dc = $dcObj | Get-View
	      Write-Progress -Activity "Creating Datacenter $($Datacenter)" -Completed -Id 92
      }
    }catch{
      throw $_
    }
   }
   End{
    Write-Progress -Activity "Creating Datacenter $($Datacenter)" -Completed -Id 92
    Write-Progress -Activity "Checking for Datacenter $($Datacenter)" -PercentComplete 50 -Id 91
    return $dc
   }
}
Function Validate-Cluster{
  Param(
    [string]$Cluster
  )
  Begin{
    $cl,$clObj = $null,$null
  }
  Process{
    try{
      Write-Progress -Activity "Checking for Cluster $($Cluster)" -PercentComplete 50 -Id 91
      $cl = Get-View -ViewType ClusterComputeResource -Filter @{"Name"=$Cluster}
      If([string]::IsNullOrEmpty($cl)){ 
        Write-Progress -Activity "Creating Cluster $($Cluster)" -PercentComplete 99 -Id 92 -ParentId 91
        $clObj = New-VmCluster -Name $Cluster -VsanEnabled:$true -VsanDiskClaimMode:Automatic -HAAdmissionControlEnabled:$true -HAEnabled:$true -HAFailoverLevel 1 -Location (Get-VIObjectByVIView -MORef $dc.MoRef) -Confirm:$false -ErrorAction Stop
        $cl = $clObj | Get-View
      }
      
      Write-Progress -Activity "Checking and Repairng Cluster $($Cluster) Configuration" -PercentComplete 50 -Id 91
      Get-VIObjectByVIView -MORef $cl.MoRef | Set-VmCluster -DrsEnabled:$false -VsanEnabled:$true -VsanDiskClaimMode:Automatic -HAEnabled:$true -HAAdmissionControlEnabled:$true -HAFailoverLevel 1 -Confirm:$false -ErrorAction Stop | Out-Null
      $cl.UpdateViewData()
      
    }catch{
      throw $_
    }
  }
  End{
    Write-Progress -Activity "Creating Cluster $($Cluster)" -Completed -Id 92
    Write-Progress -Activity "Checking for Cluster $($Cluster)" -Completed -Id 91
    return $cl
  }
}
Function Configure-VMHost{
  Param(
    [array]$VMHost,
    $RootCredentials
  )
  Begin{
    [array]$vmhosts = @()
    [int]$progress = 0
  }
  Process{
    try{
      $VMHost | %{$thisObj = $_; $progress++
      	Write-Progress -Activity "Configuring ESXi Host $($thisObj)." -PercentComplete (100*($progress/$VMHost.Count)) -Id 91
      	#initialize the PSObject that will be used for the remainder of the script
        $pso = New-Object PSObject -Property @{Name=$thisObj;Mgmt=$null;MgmtSM=$null;vMotion=$null;vMotionSM="255.255.255.0";EsxiObj=$null}
      	
      	Write-Progress -Activity "Verifying ESXi Host $($thisObj) is online and pinging." -PercentComplete 50 -Id 92 -ParentId 91
      	$chk = Test-Connection -ComputerName $thisObj -ErrorAction SilentlyContinue
      	If([string]::IsNullOrEmpty($chk)){
      		throw "Error:2`tESXi host $($thisObj) appears to be offline.`nExiting..."
      	}
      	Write-Progress -Activity "CONFIRMED: ESXi Host $($thisObj) is online and pinging." -PercentComplete 100 -Id 92 -ParentId 91
      	
      	#The vMotion IPs are a set standard since it is only layer2
      	$pso.Mgmt = ($chk | ?{-not [string]::IsNullOrEmpty($_.IPV4Address)})[0].IPV4Address
      	If($thisObj.EndsWith("01.nordstrom.net")){ $pso.vMotion = "192.168.14.21" } 
      	ElseIf($thisObj.EndsWith("02.nordstrom.net")){ $pso.vMotion = "192.168.14.22" }
      	ElseIf($thisObj.EndsWith("03.nordstrom.net")){ $pso.vMotion = "192.168.14.23" }
      	ElseIf($thisObj.EndsWith("04.nordstrom.net")){ $pso.vMotion = "192.168.14.24" }
      	ElseIf($thisObj.EndsWith("05.nordstrom.net")){ $pso.vMotion = "192.168.14.25" }
      	ElseIf($thisObj.EndsWith("06.nordstrom.net")){ $pso.vMotion = "192.168.14.26" }
        ElseIf($thisObj.EndsWith("07.nordstrom.net")){ $pso.vMotion = "192.168.14.27" }
        ElseIf($thisObj.EndsWith("08.nordstrom.net")){ $pso.vMotion = "192.168.14.28" }
        ElseIf($thisObj.EndsWith("09.nordstrom.net")){ $pso.vMotion = "192.168.14.29" }
      	
      	#check if ESXi Host is in vCenter
      	Write-Progress -Activity "Adding ESXi Host $($thisObj) to vCenter Datacenter root $($dc.Name)." -PercentComplete 50 -Id 93 -ParentId 91
      	$esxi = Get-View -ViewType HostSystem -Filter @{"Name"=$pso.Name}
      	If([string]::IsNullOrEmpty($esxi)){
      		#host is not added to vCenter, so let's add it
      		$pso.EsxiObj = Add-VMHost -Name $pso.Name -Credential $RootCredentials -Location (Get-VIObjectByVIView -MORef $dc.MoRef) -Force:$true -Confirm:$false
      		If(-not [string]::IsNullOrEmpty($pso.EsxiObj)){
      			#ESXi Host added to vCenter
      			#Now lets place it in Maintenance Mode
      			$pso.EsxiObj | Set-VMHost -State:Maintenance -Confirm:$false | Out-Null
      			Write-Progress -Activity "ESXi Host $($thisObj) has been added to vCenter Datacenter root $($dc.Name)." -PercentComplete 100 -Id 93 -ParentId 91
      		}Else{
      			#host didn't add to vCenter so let's exit
      			throw "Error:3`tESXi host $($thisObj) didn't successfully add to vCenter`nPlease ensure the ROOT credentials are correct.`nYou may need to add this esxi host manually.`nExiting..."
      		}
      	}Else{
      		#ESXi Host is already in vCenter so let's make sure it is in Maintenance Mode and ensure it has moved to the root of the datacenter and not in the cluster
      		$pso.EsxiObj = (Get-VIObjectByVIView -MORef $esxi.MoRef)
      		$pso.EsxiObj | Set-VMHost -State:Maintenance -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
      		$pso.EsxiObj | Move-VMHost -Destination (Get-VIObjectByVIView -MORef $dc.MoRef) -Confirm:$false | Out-Null
      		Write-Progress -Activity "ESXi Host $($thisObj) has been added to vCenter Datacenter root $($dc.Name)." -PercentComplete 100 -Id 93 -ParentId 91
      	}
      	$vmk = $pso.EsxiObj | Get-VMHostNetworkAdapter | ?{$_.Name -eq "vmk0"}
      	$pso.MgmtSM = $vmk.SubnetMask
      	Write-Progress -Activity "Configuring ESXi Host $($thisObj)." -Completed -Id 91
        Write-Progress -Activity "CONFIRMED: ESXi Host $($thisObj) is online and pinging." -Completed -Id 92
      	Write-Progress -Activity "Adding ESXi Host $($thisObj) to vCenter Datacenter root $($dc.Name)." -Completed -Id 93
      	[array]$vmhosts += $pso
      }
    }catch{
      throw $_
    }
  }
  End{
    return $vmhosts
  }
}
Function Prompt-HostProfile{
  #Prompt User for the Host Profile to be used
  Begin{
    [String[]]$strOut = $null
    [string]$usrInput = $null
    $chk = $null
    [int]$hpCount = 0
  }
  Process{
    try{
      [array]$hostProfile = Get-VMHostProfile
      $hostProfile | %{ $hpCount++; $strOut += "`n$($hpCount). $($_.Name)"}
      Write-Host "`nWhich Host Profile should be used for these ESXi Hosts?"
      Write-Host $strOut
      $usrInput = Read-Host -Prompt "Select the item number. "
      $hp = Validate-UserInput -usrInput $usrInput -Object $hostProfile
    }catch{
      throw $_
    }
  }
  End{
    return $hp
  }
}
Function Validate-UserInput{
  Param(
    [string]$usrInput,
    $Object
  )
  Begin{
    $chk = $null
  }
  Process{
    try{
      #check to ensure the user input something
      If([string]::IsNullOrEmpty($usrInput)){ 
      	#Invalid selection
      	throw "Error:4`tInvalid Selection`nExiting..."
      }
      #Check to make sure the slection is a valid selection
      $chk = $Object[($usrInput -as [int])-1]
      If([string]::IsNullOrEmpty($chk)){ 
      	#Invalid selection
      	throw "Error:5`tInvalid Selection. Item $($usrInput) doesn't exist.`nExiting..."
      }
    }catch{
      throw $_
    }
  }
  End{
    return $chk
  }
}
Function Apply-HostProfile{
  Param(
    $hp,
    $vmhosts
  )
  Begin{
    [int]$progress = 0
  }
  Process{
    try{
      $vmhosts | %{$esxi = $_; $progress++
      	Write-Progress -Activity "Associating/Applying host profile $($hp.Name) with Esxi Host $($esxi.Name)" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 91 -ErrorAction SilentlyContinue
      	Apply-VMHostProfile -Entity $esxi.EsxiObj -Profile $hp -Confirm:$false -AssociateOnly:$true | Out-Null
      	$answerFile = Get-VMHostProfileRequiredInput -VMHost $esxi.EsxiObj | Sort Key
      	If(-not [string]::IsNullOrEmpty($answerFile)){
        # THIS WAS PLAN B FOR CREATING AN ANSWER FILE. It is a little bit more robust
      		$hpm = Get-View HostProfileManager
      		$answerFileSpec = New-Object VMware.Vim.AnswerFileOptionsCreateSpec
      		
      		$tmp = $answerFile | ?{$_.Key -like "*DnsConfig*.HostName"} | Sort Key
      		If(-not [string]::IsNullOrEmpty($tmp)){
      			$polParam = $tmp | New-ProfileDefferedPolicyOptionParameter
      			$tmp | %{ $obj = $_
      				#$esxi.Name.Split(".")[0]
      				($polParam.Parameter | ?{$_.Key -eq "address"}).Value = $esxi.Name.Split(".")[0]
      			}
      			$polParam.InputPath
      			$polParam.Parameter
      			$answerFileSpec.UserInput += $polParam
      		}
      		
      		$tmp = $answerFile | ?{$_.Key -like "*Management*.address" -or $_.Key -like "*Management*.subnetmask"} | Sort Key
      		If(-not [string]::IsNullOrEmpty($tmp)){
      			$polParam = $tmp | New-ProfileDefferedPolicyOptionParameter
      			$tmp | %{ $obj = $_
      				If($_.Key -like "*Management*.address"){
      					#$esxi.Mgmt
      					($polParam.Parameter | ?{$_.Key -eq "address"}).Value = $esxi.Mgmt
      				}Else{
      					#$esxi.MgmtSM 
      					($polParam.Parameter | ?{$_.Key -eq "subnetmask"}).Value = $esxi.MgmtSM
      				}
      			}
      			$polParam.InputPath
      			$polParam.Parameter
      			$answerFileSpec.UserInput += $polParam
      		}
      		
      		$tmp = $answerFile | ?{$_.Key -like "*Vmotion*.address" -or $_.Key -like "*Vmotion*.subnetmask"} 
      		If(-not [string]::IsNullOrEmpty($tmp)){
      			$polParam = $tmp | New-ProfileDefferedPolicyOptionParameter
      			$tmp | %{ $obj = $_
      				If($_.Key -like "*Vmotion*.address"){
      					#$esxi.vMotion
      					($polParam.Parameter | ?{$_.Key -eq "address"}).Value = $esxi.vMotion
      				}Else{
      					#$esxi.vMotionSM
      					($polParam.Parameter | ?{$_.Key -eq "subnetmask"}).Value = $esxi.vMotionSM
      				}
      			}
      			$polParam.InputPath
      			$polParam.Parameter
      			$answerFileSpec.UserInput += $polParam
      		}
      		$hpm.UpdateAnswerFile($esxi.EsxiObj.ExtensionData.MoRef, $answerFileSpec) | Out-Null
      		$hpm.CheckAnswerFileStatus($esxi.EsxiObj.ExtensionData.MoRef) | Out-Null
      		
      		#check to ensure the answer file was applied
      		$chkAnswerFile = Get-VMHostProfileRequiredInput -VMHost $esxi.EsxiObj | Sort Key
      		If([string]::IsNullOrEmpty($chkAnswerFile)){
      			#the answer file was applied and we can now continue with applying the HP
      			$outNull = Apply-VMHostProfile -Entity $esxi.EsxiObj -Profile $hp -Confirm:$false -ErrorAction Stop
      			Test-VMHostProfileCompliance -VMHost $esxi.EsxiObj | Out-Null
      		}Else{
      			#The answerfile was not created and so I will exit here
      			throw $Error[0]
      		}
      	}#end If
      	Else{ #Host Profile Answer File is already set, so let's apply the host profile
      		$outNull = Apply-VMHostProfile -Entity $esxi.EsxiObj -Profile $hp -Confirm:$false -ErrorAction Stop
      		Test-VMHostProfileCompliance -VMHost $esxi.EsxiObj | Out-Null
      	}
      	$esxi.EsxiObj | Get-VMHostNetworkAdapter -VMKernel -Name "vmk1" | Set-VMHostNetworkAdapter -VMotionEnabled:$true -VsanTrafficEnabled:$true -Confirm:$false | Out-Null
      }
    }catch{
      throw $_
    }
  }
  End{
    return $null
  }
}
Function Apply-VUMBaselines{
  Param(
    $vmhosts
  )
  Begin{
    [array]$vumTasks = @()
    [int]$progress = 0
  }
  Process{
    try{
      $vmhosts | %{$esxi = $_; $progress++
      	Write-Progress -Activity "Associating/Applying VUM Baselines on Esxi Host $($esxi.Name)" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 91 -ErrorAction SilentlyContinue
      	$vumBL = Get-Baseline -Entity $esxi.EsxiObj -Inherit:$true
      	Scan-Inventory -Entity $esxi.EsxiObj -UpdateType HostPatch -Confirm:$false
      	[array]$vumBLtoApply = Get-Compliance -Entity $esxi.EsxiObj | ?{$_.Status -ne "Compliant"} | %{$_.Name}
      	If(-not [string]::IsNullOrEmpty($vumBLtoApply)){
      		Remediate-Inventory `
      		-ClusterDisableHighAvailability:$true `
      		-ClusterDisableFaultTolerance:$true `
      		-ClusterDisableDistributedPowerManagement:$true `
      		-ClusterEnableParallelRemediation:$true `
      		-Entity $esxi.EsxiObj `
      		-Baseline $vumBL `
      		-HostFailureAction:Retry `
      		-HostNumberOfRetries 2 `
      		-HostDisableMediaDevices:$true `
      		-Confirm:$false `
      		-RunAsync `
      		| Out-Null
      		[array]$vumTasks += Get-Task |?{$_.ObjectId -eq $esxi.EsxiObj.Id -and $_.Name -eq "Remediate entity"}
      	}
      }
      Write-Progress -Activity "Associating/Applying VUM Baselines on Esxi Host $($esxi.Name)" -Completed -Id 91
    }catch{
      throw $_
    }
  }
  End{
    return $vumTasks
  }
}
Function Track-VUMProcess{
  Param(
    $vumTasks
  )
  try{
    If(-not [string]::IsNullOrEmpty($vumTasks)){
    	[bool]$tskRun = $true
    	Write-Progress -Activity "Waiting for Applying VUM Baselines on Esxi Hosts" -PercentComplete 50 -Id 91 -ErrorAction SilentlyContinue
    	Do{
    		$vumTasks = Get-Task -Id $vumTasks.Id -ErrorAction SilentlyContinue
    		$chk=$null
    		$chk = $vumTasks | ?{$_.State -ne "Success" -and $_.State -ne "Running"}
    		If(-not [string]::IsNullOrEmpty($chk)){[bool]$tskError=$true}Else{$tskError=$false}
    		$chk=$null
    		$chk = $vumTasks | ?{ $_.State -eq "Running"}
    		If([string]::IsNullOrEmpty($chk)){$tskRun=$false}
    	}While($tskRun)
    	If($tskError){
    		#Remediation Failed on at least 1 host, so stop the script
    		throw "Error:6`tAt least 1 ESXi hosts failed VUM Patch remediation.`nExiting..."
    	}
      Write-Progress -Activity "Waiting for Applying VUM Baselines on Esxi Hosts" -Completed -Id 91
    }
  }catch{
    throw $_
  }
}
Function Get-ESXiLicense{
  Param(
    $vmhosts
  )
    $esxiVersion = $vmhosts.EsxiObj.Version | Select -Unique
    $lm = Get-View (Get-View ServiceInstance).Content.LicenseManager
    [array]$esxiLicenses = $lm.Licenses | %{ 
    	$chk=$null
    	$chk = $_.Properties | ?{($_.Key -eq "ProductName" -and $_.Value -like "*ESX*")}; 
    	If(-not [string]::IsNullOrEmpty($chk)){ 
    		$chk=$null
    		$chk = $_.Properties | ?{($_.Key -eq "ProductVersion" -and $_.Value -like "$($esxiVersion.Split('.')[0])*")}
    		If(-not [string]::IsNullOrEmpty($chk)){ $_ }
    	}
    }
    return $esxiLicenses
}
Function Get-VSANLicense{
  param(
    $vmhosts
  )
  $esxiVersion = $vmhosts.EsxiObj.Version | Select -Unique
  $lm = Get-View (Get-View ServiceInstance).Content.LicenseManager
  [array]$vsanLicenses = $lm.Licenses | %{ 
  	$chk=$null
  	$chk = $_.Properties | ?{($_.Key -eq "ProductName" -and $_.Value -like "*VSAN*")}; 
  	If(-not [string]::IsNullOrEmpty($chk)){ 
  		$_
  	}
  }
  return $vsanLicenses
}
Function Prompt-ESXiLicense{
  Param(
    $esxiLicenses
  )
  Begin{
    [String[]]$strOut = $null
	  [string]$usrInput = $null
	  $chk = $null
	  [int]$lkCount = 0
  }
  Process{
    try{
      $esxiLicenses | %{ $lkCount++; $strOut += "`n$($lkCount). $($_.LicenseKey)`t$($_.Name)"}
    	Write-Host "`nWhich License Key should be used for these ESXi Hosts?"
    	Write-Host $strOut
    	$usrInput = Read-Host -Prompt "Select the item number. "
    	$lk = Validate-UserInput $usrInput $esxiLicenses
    }catch{
      throw $_
    }
  }
  End{
    return $lk
  }
}
Function Prompt-VSANLicense{
  Param(
    $vsanLicenses
  )
  Begin{
    [String[]]$strOut = $null
	  [string]$usrInput = $null
	  $chk = $null
	  [int]$lkCount = 0
  }
  Process{
    try{
      $vsanLicenses | %{ $lkCount++; $strOut += "`n$($lkCount). $($_.LicenseKey)`t$($_.Name)"}
    	Write-Host "`nWhich License Key should be used for VSAN?"
    	Write-Host $strOut
    	$usrInput = Read-Host -Prompt "Select the item number. "
    	$lk = Validate-UserInput $usrInput $vsanLicenses
    }catch{
      throw $_
    }
  }
  End{
    return $lk
  }
}
Function Assign-ClusterLicense{
  Param(
    $cl,
    $lk
  )
   try{
    Write-Progress -Activity "Setting up Bulk Licensing for Cluster $($cl.Name)" -PercentComplete 50 -Id 91
    $ldm = Get-LicenseDataManager
    $lm = Get-View (Get-View ServiceInstance).Content.LicenseManager
    $lam = Get-View $lm.LicenseAssignmentManager
    try{ 
      $lam.UpdateAssignedLicense($cl.MoRef.Value,$lk.LicenseKey,$null) | Out-Null 
    }catch{ 
      Write-Error $_
      Write-Warning "Unable to Assign the license key $($lk.LicenseKey) | $($lk.Name) to the cluster."
    }
    Write-Progress -Activity "Setting up Bulk Licensing for Cluster $($cl.Name)" -Completed -Id 91
  }catch{
    throw $_
  }
}
Function Set-RemoteDiskLocal{
  Param(
    $vmhosts
  )
  try{
    Write-Progress -Activity "Claiming Remote disks as Local" -PercentComplete 50 -Id 91
    [int]$progress = 0
    [array]$return = @()
    $vmhosts | %{ $esxi = $_; $progress++
      Write-Progress -Activity "Claiming Remote disks on $($esxi.Name)" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 92 -ParentId 91
      $esxcli = Get-EsxCli -VMHost $esxi.EsxiObj
      Write-Host "Marking Local Dell PERC Controller disks as LOCAL"
      Get-VMHostHba -VMHost $esxi.EsxiObj | ?{$_.Model -like "*Dell*PERC*" -or $_.Model -like "MegaRAID SAS* Controller*"} | Get-ScsiLun -LunType disk | %{ $localDisk = $_
        $canonical = $localDisk.CanonicalName
        $satpreturn = ($esxcli.storage.nmp.satp.rule.list() | ?{$_.Device -eq $canonical -and $_.options -eq "enable_local"})
        If([string]::IsNullOrEmpty($satpreturn)){
          $satp = ($esxcli.storage.nmp.device.list() | ?{$_.Device -eq $canonical }).StorageArrayType
          try{$esxcli.storage.nmp.satp.rule.add($null,$null,$null,$canonical,$null,$null,$null,"enable_local",$null,$null,$satp,$null,$null,$null) | Out-Null}catch{}
          $satpreturn = ($esxcli.storage.nmp.satp.rule.list() | ?{$_.Device -eq $canonical -and $_.options -eq "enable_local"})
          [array]$return += New-Object PSObject -Property @{
            Device = $canonical
            SATPRuleName = $satpreturn.Name
            SATPOptions = $satpreturn.Options    
            }
          try{$esxcli.storage.core.claiming.reclaim($canonical) | Out-Null}catch{}
        }
      }
      $esxcli.system.settings.advanced.set($false,110000,"/LSOM/diskIoTimeout")
      $esxcli.system.settings.advanced.set($false,1,"/LSOM/diskIoRetryFactor")
      $esxcli.system.settings.advanced.list($false,"/LSOM/diskIoTimeout")
      $esxcli.system.settings.advanced.list($false,"/LSOM/diskIoRetryFactor")
    }
    Write-Progress -Activity "Claiming Remote disks as Local" -Completed -Id 91
    Write-Progress -Activity "Claiming Remote disks on $($esxi.Name)" -Completed -Id 92
    return $return
  }catch{
    throw $_
  }
}
Function Claim-VSANDisks{
  Param(
    $vmhosts
  )
  Begin{
    $progress = 0
  }
  Process{
    try{
        #Claim VSAN Disks
        
        $vmhosts | %{ $esxi = $_; $progress++
        	Write-Progress -Activity "Finding eligible disks for VSAN on VMHost $($esxi.Name)" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 91
        	$disks = $esxi.EsxiObj | Get-VMHostDisk
        	
        	# Find the blank SSDs for the current host
        	$SSDs = $disks | ?{ $_.scsilun.extensiondata.ssd }
        	[array]$BlankSSDs = ($SSDs | ?{ -not $_.Extensiondata.Layout.Partition[0].partition }).scsilun.CanonicalName
        	
        	# Find the blank Magnetic disks for the current host
        	$HDDs = $disks | ?{ -not $_.scsilun.extensiondata.ssd }
        	[array]$BlankHDDs = ($HDDs | ?{ -not $_.Extensiondata.Layout.Partition[0].partition }).scsilun.CanonicalName
        	
        	If(-not [string]::IsNullOrEmpty($BlankSSDs)){
        		#If there are multiple SSD drives and this isn't an all flash vsan then we will need to create 1 group per SSD
        		# We need to determine how many SSDs and groups needed then we need to divide the number of magnetic disks 
        		# by that number of groups to disperse the HDDs into the groups
        		
        		[int]$numGrp = $BlankSSDs.Count
        		[int]$numHDDs = $BlankHDDs.Count
        		
        		#Assigning [int] will give us whole numbers and the last group will get the remainder disks
        		# Ex. 3xSSDs 16xHDDs
        		#  16/3=5.333 with [int] we will get 5
        		# group1 = 1xSSD, 5xHDD
        		# group2 = 1xSSD, 5xHDD
        		# group3 = 1xSDD, 6xHDD
        		[int]$HDDperGrp = [System.Math]::Floor($numHDDs/$numGrp)
        		
        		(1..$numGrp) | %{ $grp = $_
        			[String[]]$eligHDDs = @()
        			[string]$grpSSD = $BlankSSDs[$grp-1]
        			If($grp -ne $numGrp){
        				#we will pull the end of the index and count backwards to fill the HDD array
        				# ex. HDDs per group is 2, 2 groups
        				# grp1 : $endIndex = 2*1 = 2 then count backward by $HDDperGrp
        				# grp2 : $endIndex = 2*2 = 4
        				[int]$endIndex = $HDDperGrp*$grp
        				For($x=$endIndex;$x -gt ($endIndex-$HDDperGrp);$x--){
        					$eligHDDs += $BlankHDDs[$x-1] #array index starts at 0 not 1
        				}
        				New-VsanDiskGroup -VMHost $esxi.EsxiObj -SSDCanonicalName $grpSSD -DataDiskCanonicalName $eligHDDs | Out-Null
        			}ElseIf($grp -eq $numGrp){
        				#we will pull the end of the index and count backwards to fill the HDD array
        				# ex. HDDs per group is 2, 2 groups
        				# grp1 : $endIndex = 2*1 = 2 then count backward by $HDDperGrp
        				# grp2 : $endIndex = 2*2 = 4
        				[int]$endIndex = $HDDperGrp*$grp
        				For($x=$endIndex;$x -gt ($endIndex-$HDDperGrp);$x--){
        					$eligHDDs += $BlankHDDs[$x-1] #array index starts at 0 not 1
        				}
        				$eligHDDs += $BlankHDDs[$BlankHDDs.Count-1] #add the last remainder disk
        				New-VsanDiskGroup -VMHost $esxi.EsxiObj -SSDCanonicalName $grpSSD -DataDiskCanonicalName $eligHDDs | Out-Null
        			}
        		}
        	}
        	
        	$esxcli = $null
        	$esxcli = Get-EsxCli -VMHost $esxi.EsxiObj
        	$esxcli.system.settings.advanced.set($false,110000,"/LSOM/diskIoTimeout")
        	$esxcli.system.settings.advanced.set($false,1,"/LSOM/diskIoRetryFactor")
        	$esxcli.system.settings.advanced.list($false,"/LSOM/diskIoTimeout")
        	$esxcli.system.settings.advanced.list($false,"/LSOM/diskIoRetryFactor")
        }
    }catch{
      throw $_
    }
  }
  End{
    return $null
  }
}
LoadSnapins
LoadModules
Import-Module UcgModule -ErrorAction Stop -WarningAction SilentlyContinue
cd G:\store_scripts
cls

try{
  $RootCredentials=Get-Credential -Message "Please enter the root credentials for these ESXi hosts" -UserName root

  cls
  Write-Host "`n`n`n`n`n`n`n`n`n`n`n`n`n" #spacing to show text/errors below the progress bars
  Get-Date

  Write-Progress -Activity "Connecting to vCenter $($vCenter)" -PercentComplete 1 -Id 90
  $vi = Connect-ViServer -Server $vCenter -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  If(-not [string]::IsNullOrEmpty($vi)){ Write-Progress -Activity "Connecting to vCenter $($vCenter)" -PercentComplete 100 -Id 90 }
  Else{ Write-Host "Error:1`tUnable to connect to vCenter $($vCenter).`nExiting..." -BackgroundColor Black -ForegroundColor Red; Exit 1 }

  $dc = Validate-Datacenter $Datacenter
  $cl = Validate-Cluster $Cluster
  
  [array]$vmhosts = Configure-VMHost $VMHost $RootCredentials
  [array]$esxiLicenses = Get-ESXiLicense $vmhosts
  [array]$vsanLicenses = Get-VSANLicense $vmhosts

  If($esxiLicenses.Count -gt 1){
    $lk = Prompt-ESXiLicense $esxiLicenses
  }Else{ $lk = $esxiLicenses[0] }

  Assign-ClusterLicense $cl $lk

  If($vsanLicenses.Count -gt 1){
    $lk = Prompt-VSANLicense $vsanLicenses
  }Else{ $lk = $vsanLicenses[0] }

  Assign-ClusterLicense $cl $lk
  $hp = Prompt-HostProfile
  Apply-HostProfile $hp $vmhosts
  Set-RemoteDiskLocal $vmhosts
  #$hp = Prompt-HostProfile ##################### REMOVE THIS LINE ###########################
  $vumTasks = Apply-VUMBaselines $vmhosts
  Track-VUMProcess $vumTasks
  
  #Move ESXi Hosts to the cluster
  $progress = 0
  $vmhosts | %{ $esxi = $_; $progress++
  	Write-Progress -Activity "Moving ESXi Host $($esxi.Name) to Cluster $($cl.Name)" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 91
  	Move-VMHost -VMHost $esxi.EsxiObj -Destination (Get-VIObjectByVIView -MORef $cl.MoRef) -Confirm:$false | Out-Null
  }

  #Disconnect and Reconnect to assign the esxi License
  $progress = 0
  $vmhosts | %{ $esxi = $_; $progress++
  	Write-Progress -Activity "Disconnecting/Reconnecting Host $($esxi.Name) to Cluster $($cl.Name) to assign vSphere License" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 91
  	$esxi.EsxiObj | Set-VMHost -State:Disconnected -Confirm:$false | Out-Null
  	Sleep -Seconds 3
  	$esxi.EsxiObj | Set-VMHost -State:Maintenance -Confirm:$false | Out-Null
  }

  #Setup HA Admission Control Policy
  Write-Progress -Activity "Setting up HA Admission Control on Cluster $($cl.Name)" -PercentComplete 90 -Id 91
  $vmhosts = $vmhosts | Sort Name
  $esxi = $vmhosts[$vmhosts.Count-1]
  $clConfig = New-Object VMware.Vim.ClusterConfigSpecEx
  	$clConfig.dasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
  		$clConfig.dasConfig.admissionControlPolicy = New-Object VMware.Vim.ClusterFailoverHostAdmissionControlPolicy
  			$clConfig.dasConfig.admissionControlPolicy.FailoverHosts = $esxi.EsxiObj.ExtensionData.MoRef
  $cl.ReconfigureComputeResource_Task($clConfig,$true)

  #Claim-VSANDisks $vmhosts #commented out as we are using automatic VSAN mode
  
  #Setup ESXi Firewall ACL policies  
  $outNull = .\Set-EsxiFirewallACL.ps1 -vCenter $vCenter -Cluster $cl.Name

  $vi = Connect-VIServer -Session $vi -Server $vCenter
  #Take ESXi hosts out of Maintenance Mode
  $progress = 0
  $vmhosts | %{ $esxi = $_; $progress++
  	Write-Progress -Activity "Exit Maitenance Mode on ESXi Host $($esxi.Name)" -PercentComplete (100*($progress/$vmhosts.Count)) -Id 91
  	$esxi.EsxiObj | Set-VMHost -State:Connected -Confirm:$false | Out-Null
  }
  Write-Host "Script Complete. Please verify the configuration of the esxi hosts" -ForegroundColor Cyan -BackgroundColor Black
}catch{
  throw $_
}Finally{
  Disconnect-VIServer -Server $vi.Name -Confirm:$false -Force:$true
  Write-Progress -Activity "Exit Maitenance Mode on ESXi Host $($esxi.Name)" -Completed -Id 91
  Write-Progress -Activity "CONFIRMED: ESXi Host $($thisObj) is online and pinging." -Completed -Id 92
  Write-Progress -Activity "Adding ESXi Host $($thisObj) to vCenter Datacenter root $($dc.Name)." -Completed -Id 93
  Get-Date
}
