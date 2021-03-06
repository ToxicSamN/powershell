# created by Sammy Shuck
# date : feb 2012
Param($vCenter=$null,$ESXiHost=$null,[string]$NOWvlan=$null,[string]$NPOSvlan=$null)
cls
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule
$Global:ScriptFileName = $MyInvocation.MyCommand.Name

Function Set-VMHostADDomain{
	param(
	[parameter(ValueFromPipeline = $true,Position=1,Mandatory = $true)]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost,
	[string]$Domain,
	[string]$User,
	[string]$Password,
	[System.Management.Automation.PSCredential]$Credential,
	[switch]$ADJoin,
	[switch]$RemovePermission = $false
	)

	process{
		if(!$VMHost){$VMHost = $_}
		foreach($esx in $VMHost){
			$filter = New-Object VMware.Vim.PropertyFilterSpec -Property @{
				ObjectSet = New-Object VMware.Vim.ObjectSpec -Property @{
					Obj = $esx.ExtensionData.ConfigManager.AuthenticationManager
				}
				PropSet = New-Object VMware.Vim.PropertySpec -Property @{
					Type = "HostAuthenticationManager"
					All = $true
				}
			}
			$collector = Get-View $esx.ExtensionData.Client.ServiceContent.PropertyCollector
			$content = $collector.RetrieveProperties($filter)
			$stores = $content | Select -First 1 | %{$_.PropSet} | where {$_.Name -eq "supportedStore"}
			$result = $stores.Val | where {$_.Type -eq "HostActiveDirectoryAuthentication"}
			$hostADAuth = [VMware.Vim.VIConvert]::ToVim50($result)
			Write-Host $ADJoin
			if($ADJoin){
				if($Credential){
					$User = $Credential.GetNetworkCredential().UserName
					$Password = $Credential.GetNetworkCredential().Password
				}
				$taskMoRef = $esx.ExtensionData.Client.VimService.JoinDomain_Task($hostADAuth,$Domain,$User,$Password)
			}
			else{
				$taskMoRef = $esx.ExtensionData.Client.VimService.LeaveCurrentDomain_Task($hostADAuth,$RemovePermission)
			}
			$esx.ExtensionData.WaitForTask([VMware.Vim.VIConvert]::ToVim($taskMoRef))
		}
	}
}
Function Get-VMHostAuthentication{
	param(
	[parameter(ValueFromPipeline = $true,Position=1,Mandatory = $true)]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl[]]$VMHost)

	process{
		if(!$VMHost){$VMHost = $_}
		foreach($esx in $VMHost){
			$filter = New-Object VMware.Vim.PropertyFilterSpec -Property @{
				ObjectSet = New-Object VMware.Vim.ObjectSpec -Property @{
					Obj = $esx.ExtensionData.ConfigManager.AuthenticationManager
				}
				PropSet = New-Object VMware.Vim.PropertySpec -Property @{
					Type = "HostAuthenticationManager"
					All = $true
				}
			}
			$collector = Get-View $esx.ExtensionData.Client.ServiceContent.PropertyCollector
			$content = $collector.RetrieveProperties($filter)
			$stores = $content | Select -First 1 | %{$_.PropSet} | where {$_.Name -eq "info"}
			foreach($authConfig in $stores.Val.AuthConfig){
				$row = New-Object PSObject
				$row | Add-Member -MemberType NoteProperty -Name Name -Value $null
				$row | Add-Member -MemberType NoteProperty -Name Type -Value $null
				$row | Add-Member -MemberType NoteProperty -Name Enabled -Value $null
				$row | Add-Member -MemberType NoteProperty -Name Domain -Value $null
				$row | Add-Member -MemberType NoteProperty -Name Membership -Value $null
				$row | Add-Member -MemberType NoteProperty -Name Trust -Value $null
				$row.Name = $esx.Name
				$row.Enabled = $authConfig.Enabled
				switch($authConfig.GetType().Name){
					'HostLocalAuthenticationInfo'{
						$row.Type = 'Local authentication'
					}
					'HostActiveDirectoryInfo'{
						$row.Type = 'Active Directory'
						$row.Domain = $authConfig.JoinedDomain
						$row.Membership = $authConfig.DomainMembershipStatus
						$row.Trust = $authConfig.TrustedDomain
					}
				}
				$row
			}
		}
	}
}
Function SyntaxUsage($HelpOption){
Write-Host "$Global:ScriptFileName replaces the use of Host Profiles for Store In A Box ESXi Hosts.`n
$Global:ScriptFileName `n
  REQUIRED PARAMETERS
  --------------------
  [-vCenter:{vCenter Server Name}]
  [-ESXiHost:{ESXi Host Name}]
  [-NOWvlan:{NOW VLAN Number}]
  [-NPOSvlan:{NPOS VLAN Number}]`n

Example1: $Global:ScriptFileName -vCenter:a0319p133 -ESXiHost:a0005vm02 -NOWvlan:100 -NPOSvlan:300`n
Example2: $Global:ScriptFileName -vCenter:a0319p133 -ESXiHost:a0021vm02 -NOWvlan:100 -NPOSvlan:1`n

Parameters:                         Description:
 -vCenter:{vCenter Server Name}     REQUIRED - Connects to the vCenter Server 
                                    to configure the ESXi Hosts.`n
 -ESXiHost:{ESXi Host Name}         REQUIRED - Used to specify the ESXi Host 
                                    that needs to be configured.`n
 -NOWvlan:{NOW VLAN Number}         REQUIRED - Specify the VLAN Number for the
                                    NOW Network.`n
 -NPOSvlan:{NPOS VLAN Number}       REQUIRED - Specify the VLAN Number for the
                                    NPOS Network.`n
`n"

Exit 99
}

$targs = $args
$carg = 0
$args | %{ 
			$carg++
			[string]$tempstr = $_
			If ($tempstr.StartsWith("-"))
			{[string]$tempvar = $_
				Switch -wildcard ($tempvar.ToLower()){
				"-vcenter*" {$vCenter = $targs[$carg]}
				"-esxihost*" {$ESXiHost = $targs[$carg]}
				"-nowvlan*" {[string]$NOWvlan = $targs[$carg]}
				"-nposvlan*" {[string]$NPOSvlan = $targs[$carg]}
				}
			}
			Else{
				Switch ($tempstr.ToLower()){
					"?" { SyntaxUsage -HelpOption $true }
					"help" { SyntaxUsage -HelpOption $true }
					"/?" { SyntaxUsage -HelpOption $true }
				}
			}
		 }

If ($help) { SyntaxUsage -HelpOption $true }
If ($vCenter -eq $null -or $ESXiHost -eq $null -or $NOWvlan -eq $null -or $NPOSvlan -eq $null) { SyntaxUsage }

Write-Host "Connecting to $vCenter ..."
$hVIClient = Connect-VIServer -Server:$vCenter -WarningAction SilentlyContinue

If ($hVIClient -eq $null)
{ $hVIClient = Connect-VIServer -Server:$vCenter -WarningAction SilentlyContinue }
If ($hVIClient -eq $null)
{ Exit 1 }
Write-Host "`nConnected to vCenter $vCenter."

If (!$ESXiHost.EndsWith(".nordstrom.net"))
{ $ESXiHost += ".nordstrom.net" }


####################################
#vSwitches Configuration
$gHost = Get-VMHost -Name $ESXiHost
$PingHost = $gHost.Name
$HostPingObj = Get-WmiObject Win32_PingStatus -filter "Address='$PingHost'" | select ProtocolAddress
$HostIPAddress = $HostPingObj.ProtocolAddress
If ($HostIPAddress.StartsWith("10.1.84") -or $HostIPAddress.StartsWith("10.16.78.")) { $nBuild = $true } Else { $nBuild = $false }
If ($PingHost.EndsWith("01.nordstrom.net")) { $vMotionIP = "192.168.14.20" } ElseIf ($PingHost.EndsWith("02.nordstrom.net")) { $vMotionIP = "192.168.14.21" }

$nposName = "v" + $NPOSvlan + "_NPOS"
$nowName = "v" + $NOWvlan + "_NOW"
If ($NPOSvlan -eq 1)
{	$NPOSvlan = 0 }
If ($NOWvlan -eq 1)
{	$NOWvlan = 0 }

$cvSwitch1 = Get-VirtualSwitch -VMHost $gHost -Name vSwitch1 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
If ($cvSwitch1 -eq $null) 
{
	Write-Host "`nCreating a new Virtual Switch Named vSwitch1 and attaching vmnic2, and vmnic3 to vSwitch1."
	$nvSwitch1 = New-VirtualSwitch -VMHost $gHost -Name vSwitch1 -NumPorts 120 -Nic vmnic2, vmnic3 -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	$gvSwitch1 = Get-VirtualSwitch -VMHost $gHost -Name vSwitch1 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	Write-Host "`nCreating a new Port Group for the NOW network on VLAN $NOWvlan on vSwitch1."
	$nvSwitch1PG1 = New-VirtualPortGroup -VirtualSwitch $gvSwitch1 -Name $nowName -VLanId $NOWvlan -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
}
ElseIf ($cvSwitch1 -ne $null)
{
	$gvSwitch1 = Get-VirtualSwitch -VMHost $gHost -Name vSwitch1 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	$gvSwitch1PGnow = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch1 -Name $nowName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	
	If ($gvSwitch1PGnow -eq $null)
	{Write-Host "`nCreating a new Port Group for the NOW network on VLAN $NOWvlan on vSwitch1." ;$nvSwitch1PGnow = New-VirtualPortGroup -VirtualSwitch $gvSwitch1 -Name $nowName -VLanId $NOWvlan -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }
	ElseIf ($gvSwitch1PGnow -ne $null)
	{Write-Host "`nConfirming Port Group for the NOW network is on VLAN $NOWvlan on vSwitch1." ;$svSwitch1PGnow = Set-VirtualPortGroup -VirtualPortGroup $gvSwitch1PGnow -Name $nowName -VLanId $NOWvlan -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }
}

$gvSwitch0 = Get-VirtualSwitch -VMHost $gHost -Name vSwitch0 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
$gvSwitch0PGnpos = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name $nposName -WarningAction SilentlyContinue  -ErrorAction SilentlyContinue
$gvSwitch0PGmgmt = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "Management" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
$gvSwitch0PGvmot = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "vMotion" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

If ($gvSwitch0PGnpos -eq $null)
{Write-Host "`nCreating a new Port Group for the NPOS network on VLAN $NPOSvlan on vSwitch0." ;$nvSwitch0PGnpos = New-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name $nposName -VLanId $NPOSvlan -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }
ElseIf ($gvSwitch0PGnpos -ne $null)
{Write-Host "`nConfirming Port Group for the NPOS network is on VLAN $NPOSvlan on vSwitch0." ;$svSwitch0PGnpos = Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGnpos -Name $nposName -VLanId $NPOSvlan -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }

If ($nBuild)
{
	$gvSwitch0PGvmnet = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "VM Network" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 
	$gvSwitch0PGdcs = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "DCSBuildNet" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	If ($gvSwitch0PGvmnet -ne $null -and $gvSwitch0PGdcs -eq $null)
	{Write-Host "`nCreating a new Port Group for the DCS network on VLAN 984 on vSwitch0." ;Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGvmnet -Name "DCSBuildNet" -VLanId 984 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
	ElseIf ($gvSwitch0PGvmnet -eq $null -and $gvSwitch0PGdcs -ne $null)
	{Write-Host "`nCreating a new Port Group for the DCS network on VLAN 984 on vSwitch0." ;Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGdcs -Name "DCSBuildNet" -VLanId 984 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
	ElseIf ($gvSwitch0PGvmnet -eq $null -and $gvSwitch0PGdcs -eq $null)
	{Write-Host "`nCreating a new Port Group for the DCS network on VLAN 984 on vSwitch0." ;$nvSwitch0PGdcs = New-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "DCSBuildNet" -VLanId 984 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
	ElseIf ($gvSwitch0PGvmnet -ne $null -and $gvSwitch0PGdcs -ne $null)
	{Write-Host "`nRemoving the Port Group labeled VM Network on vSwitch0." ;Remove-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGvmnet -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
}
ElseIf (!$nBuild)
{
	$gvSwitch0PGvmnet = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "VM Network" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 
	$gvSwitch0PGdcs = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "DCSBuildNet" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	If ($gvSwitch0PGvmnet -ne $null) 
	{Write-Host "`nRemoving the Port Group labeled VM Network on vSwitch0." ;Remove-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGvmnet -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
	If ($gvSwitch0PGdcs -ne $null) 
	{Write-Host "`nRemoving the Port Group labeled DCSBuildNet on vSwitch0." ;Remove-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGdcs -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
}

If ($gvSwitch0PGmgmt -eq $null)
{ 
	$gvSwitch0PGmgmt1 = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "Management Network" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	If ($gvSwitch0PGmgmt1 -eq $null)
	{	
		#HAVE TO FIND THE MGMT PG
		$findMgmtPG = Get-VMHostNetworkAdapter -VMHost $gHost -VMKernel:$true | Select vmk0,PortgroupName
		$gvSwitch0PGmgmt1 = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name $findMgmtPG[0].PortGroupName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
		If ($nBuild)
		{ 
			Write-Host "`nModifying the Management Kernel for DCS Build Out on VLAN 984"
			$svSwitch0PGmgmt = Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGmgmt1 -Name "Management" -VLanId 984 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
			Write-Host "`nSetting up the NIC Teaming Policy for the Management Network."
			$gvManageNicTP = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch0 -Name "Management" -WarningAction SilentlyContinue | Get-NicTeamingPolicy
			$gvManageNicTP | Set-NicTeamingPolicy -FailbackEnabled:$true -LoadBalancingPolicy LoadBalanceSrcId -NetworkFailoverDetectionPolicy LinkStatus -NotifySwitches $true -MakeNicActive vmnic0, vmnic1 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
		}
		ElseIf (!$nBuild)
		{ 
			Write-Host "`nModifying the Management Kernel for Final Store Virtualization on VLAN 13"
			$svSwitch0PGmgmt = Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGmgmt1 -Name "Management" -VLanId 13 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
			Write-Host "`nSetting up the NIC Teaming Policy for the Management Network."
			$gvManageNicTP = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch0 -Name "Management" -WarningAction SilentlyContinue | Get-NicTeamingPolicy
			$gvManageNicTP | Set-NicTeamingPolicy -FailbackEnabled:$true -LoadBalancingPolicy LoadBalanceSrcId -NetworkFailoverDetectionPolicy LinkStatus -NotifySwitches $true -MakeNicActive vmnic0, vmnic1 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
		}
		
	}

	ElseIf ($gvSwitch0PGmgmt1 -ne $null)
	{ 
		If ($nBuild)
		{ 
			Write-Host "`nModifying the Management Kernel for DCS Build Out on VLAN 984"
			$svSwitch0PGmgmt = Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGmgmt1 -Name "Management" -VLanId 984 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
			Write-Host "`nSetting up the NIC Teaming Policy for the Management Network."
			$gvManageNicTP = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch0 -Name "Management" -WarningAction SilentlyContinue | Get-NicTeamingPolicy
			$gvManageNicTP | Set-NicTeamingPolicy -FailbackEnabled:$true -LoadBalancingPolicy LoadBalanceSrcId -NetworkFailoverDetectionPolicy LinkStatus -NotifySwitches $true -MakeNicActive vmnic0, vmnic1 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
		}
		ElseIf (!$nBuild)
		{ 
			Write-Host "`nModifying the Management Kernel for Final Store Virtualization on VLAN 13"
			$svSwitch0PGmgmt = Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGmgmt1 -Name "Management" -VLanId 13 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
			Write-Host "`nSetting up the NIC Teaming Policy for the Management Network."
			$gvManageNicTP = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch0 -Name "Management" -WarningAction SilentlyContinue | Get-NicTeamingPolicy
			$gvManageNicTP | Set-NicTeamingPolicy -FailbackEnabled:$true -LoadBalancingPolicy LoadBalanceSrcId -NetworkFailoverDetectionPolicy LinkStatus -NotifySwitches $true -MakeNicActive vmnic0, vmnic1 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
		}
	}
}	
ElseIf ($gvSwitch0PGmgmt -ne $null)
{ 
	If ($nBuild)
	{
		Write-Host "`nModifying the Management Kernel for DCS Build Out on VLAN 984"
		$svSwitch0PGmgmt = Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGmgmt -Name "Management" -VLanId 984 -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 
		Write-Host "`nSetting up the NIC Teaming Policy for the Management Network."
		$gvManageNicTP = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch0 -Name "Management" -WarningAction SilentlyContinue | Get-NicTeamingPolicy
		$gvManageNicTP | Set-NicTeamingPolicy -FailbackEnabled:$true -LoadBalancingPolicy LoadBalanceSrcId -NetworkFailoverDetectionPolicy LinkStatus -NotifySwitches $true -MakeNicActive vmnic0, vmnic1 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
	}
	ElseIf (!$nBuild)
	{ 
		#Write-Host "`nModifying the Management Kernel for Final Store Virtualization on VLAN 13"
		#$svSwitch0PGmgmt = Set-VirtualPortGroup -VirtualPortGroup $gvSwitch0PGmgmt -Name "Management" -VLanId 13 -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
		Write-Host "`nSetting up the NIC Teaming Policy for the Management Network."
		$gvManageNicTP = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch0 -Name "Management" -WarningAction SilentlyContinue | Get-NicTeamingPolicy
		$gvManageNicTP | Set-NicTeamingPolicy -FailbackEnabled:$true -LoadBalancingPolicy LoadBalanceSrcId -NetworkFailoverDetectionPolicy LinkStatus -NotifySwitches $true -MakeNicActive vmnic0, vmnic1 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
	}
}

If ($gvSwitch0PGvmot -eq $null)
{ 
	Write-Host "`nCreating a new vMotion network on VLAN 14 on vSwitch0."
	New-VMHostNetworkAdapter -VMHost $gHost -PortGroup "vMotion" -VirtualSwitch $gvSwitch0 -IP $vMotionIP -SubnetMask 255.255.254.0 -VMotionEnabled $true -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
	$gnvSwitch0PGvmot = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "vMotion" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	Set-VirtualPortGroup -VirtualPortGroup $gnvSwitch0PGvmot -VLanId 14 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
	$gvMotionNicTP = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch0 -Name "vMotion" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Get-NicTeamingPolicy
	$gvMotionNicTP | Set-NicTeamingPolicy -FailbackEnabled:$true -LoadBalancingPolicy LoadBalanceSrcId -NetworkFailoverDetectionPolicy LinkStatus -NotifySwitches $true -MakeNicActive vmnic0, vmnic1 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
}
ElseIf ($gvSwitch0PGvmot -ne $null)
{
	Write-Host "`nConfirming the vMotion network on VLAN 14 on vSwitch0."
	$vNic = Get-VMHostNetworkAdapter -VMHost $gHost -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | where {$_.PortgroupName -eq "vMotion"}
	Remove-VMHostNetworkAdapter -Nic $vNic -WarningAction SilentlyContinue -Confirm:$false
	Remove-VirtualPortgroup -VirtualPortGroup $gvSwitch0PGvmot -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
	New-VMHostNetworkAdapter -VMHost $gHost -PortGroup vMotion -VirtualSwitch $gvSwitch0 -IP $vMotionIP -SubnetMask 255.255.254.0 -VMotionEnabled $true -Confirm:$false -ErrorAction SilentlyContinue
	$gnvSwitch0PGvmot = Get-VirtualPortGroup -VirtualSwitch $gvSwitch0 -Name "vMotion" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	Set-VirtualPortGroup -VirtualPortGroup $gnvSwitch0PGvmot -VlanId 14 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
	$gvMotionNicTP = Get-VirtualPortGroup -VMHost $gHost -VirtualSwitch $gvSwitch0 -Name "vMotion" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Get-NicTeamingPolicy
	$gvMotionNicTP | Set-NicTeamingPolicy -FailbackEnabled:$true -LoadBalancingPolicy LoadBalanceSrcId -NetworkFailoverDetectionPolicy LinkStatus -NotifySwitches $true -MakeNicActive vmnic0, vmnic1 -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue
}

$vmHostAdapters = Get-VMHostNetworkAdapter -VMHost $gHost -Physical:$true
$vmHostAdapters | %{ Set-VMHostNetworkAdapter -AutoNegotiate:$true -PhysicalNic $_ -Confirm:$false }

#################################################################

#################################################################
# Modify vSwitches Adapters to be Active-Active

Write-Host "`n Modifying vSwitch0 and vSwitch1 to have Active-Active Adapters"
$gvSwitch0 = Get-VirtualSwitch -VMHost $gHost -Name vSwitch0 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
$gvSwitch1 = Get-VirtualSwitch -VMHost $gHost -Name vSwitch1 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
$gvSwitch0TP = Get-NicTeamingPolicy -VirtualSwitch $gvSwitch0 -ErrorAction SilentlyContinue
$gvSwitch1TP = Get-NicTeamingPolicy -VirtualSwitch $gvSwitch1 -ErrorAction SilentlyContinue
$gvSwitch0TP | Set-NicTeamingPolicy -MakeNicActive vmnic0,vmnic1 -ErrorAction SilentlyContinue
$gvSwitch1TP | Set-NicTeamingPolicy -MakeNicActive vmnic2,vmnic3 -ErrorAction SilentlyContinue

##################################################################

##################################
#Set Services startup policy
Write-Host "`nAttempting to start services ..."
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "DCUI"} | Start-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "TSM"} | Stop-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "lbtd"} | Start-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "lsassd"} | Start-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "lwiod"} | Start-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "netlogond"} | Start-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "ntpd"} | Start-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "vmware-vpxa"} | Start-VMHostService -Confirm:$false -ErrorAction SilentlyContinue
##################################

####################################
#Join Host to nordstrom.net Domain
$gAuth = Get-VMHost -Name $ESXiHost | Get-VMHostAuthentication
$isOnDomain = ForEach-Object {$gAuth} | Where-Object {$_.Type -eq "Active Directory"} | Select-Object Enabled
If (!$isOnDomain.Enabled)
{
	Write-Host "`nAdding host $ESXiHost to the nordstrom.net domain. Please enter your Credentials when Prompted ..."
	$bDomain = Set-VMHostADDomain -VMHost (Get-VMHost -Name $ESXiHost) -ADJoin:$true -Domain 'nordstrom.net' -Credential ($host.ui.PromptForCredential("Adding to Domain Nordstrom.net", "Adding host $($ESXiHost) to the nordstrom.net domain. Please enter your Domain Admin credentials.", "", "NetBiosUserName"))
}
####################################

##################################
#Setup NTP Settings
$gNTPServer = Get-VMHostNtpServer -VMHost $gHost -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
If ($gNTPServer -eq $null)
{Write-Host "`nAdding an NTP entry for ldap0319.nordstrom.net"; $gNTPServer = Add-VmHostNtpServer -VMHost $gHost -NtpServer ldap0319.nordstrom.net -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
ElseIf ($gNTPServer -ne $null -and $gNTPServer -ne "ldap0319.nordstrom.net")
{Write-Host "`nNTP Settings inccorect. Current NTP Server listed is $gNTPServer. Adding NTP Server ldap0319.nordstrom.net" ;Add-VmHostNtpServer -VMHost $gHost -NtpServer ldap0319.nordstrom.net -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
Get-VMHostService -VMHost $gHost | Where {$_.key –eq "ntpd"} | Start-VMHostService -Confirm:$false -ErrorAction SilentlyContinue

##################################

Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue

##################################
#Change Administrator Password
Write-Host "`nModifying the ESXi root Password..."
$hESXiHost = Connect-VIServer -Server $gHost.Name -User root -Password 'kevin is cool!' -WarningAction SilentlyContinue
If ($hESXiHost -ne $null)
{ Set-VMHostAccount -Server $hESXiHost -UserAccount root -Password (Decrypt-String "gu5U246vLO4Xp8azcrJaug==" "NordStrongPasscode") -WarningAction SilentlyContinue -Confirm:$false -ErrorAction SilentlyContinue }
Disconnect-VIServer -Server $gHost.Name -Confirm:$false  -ErrorAction SilentlyContinue
##################################









