# by sammy shuck
# date Dec 2016
#TODO: Synopsis/comment
Param(
	[Parameter(Mandatory=$true, Position=0)]
	[string]$vCenter,
	[Parameter(Mandatory=$true, Position=1)]
	[string]$Cluster,
	$RulesetCSV = "G:\store_scripts\StoreEsxiFirewall_RuleSet.csv"
)
cls
Function Get-VSANMultiCastAddresses{
  #There are two VSAN Multicast addresses on each VSAN Esxi host
	
	return @{
		"VSAN" = @("224.1.2.3", "224.2.3.4")
	}
}
Function Get-RemoteUCGNodeIpAddresses{
	
	$RemoteUCG = @{"RemoteUCG" = @()}
	@("a0319p217","a0319p218","a0319p268","a0319p184") | %{ $rucg = $_
		[int]$index = 0
		#Have to use the nslookup method as Test-Connection will sometimes return remoteUCG 2nd NIC IP instead
		$nslookup = nslookup $_
		$nslookup | %{ $obj = $_; $index++
			$obj = $obj.Trim()
			
			If($obj -like "*$($rucg)*"){
				$obj = $nslookup[$index]
				$obj = $obj.Replace("Address:","")
				$obj = $obj.Trim()
			}
			
			If($obj.StartsWith("10.")){
				#$RemoteUCG["RemoteUCG"] = $RemoteUCG["RemoteUCG"] + $obj + ","
        $RemoteUCG["RemoteUCG"] += $obj
			}
		}
		
		#$tmp = (Test-Connection -ComputerName $_ -Count 1).IPV4Address.IPAddressToString
		#$RemoteUCG["RemoteUCG"] = $RemoteUCG["RemoteUCG"] + $tmp + ","
	}
  #Adding the 319/864 test template distribution esxi hosts to the ACLs
  @("a0319vmt01","a0319vmt02","a0864tvm04","a0864tvm05","a0864tvm06") | %{ $rucg = $_
		[int]$index = 0
		#Have to use the nslookup method as Test-Connection will sometimes return remoteUCG 2nd NIC IP instead
		$nslookup = nslookup $_
		$nslookup | %{ $obj = $_; $index++
			$obj = $obj.Trim()
			
			If($obj -like "*$($rucg)*"){
				$obj = $nslookup[$index]
				$obj = $obj.Replace("Address:","")
				$obj = $obj.Trim()
			}
			
			If($obj.StartsWith("10.")){
				#$RemoteUCG["RemoteUCG"] = $RemoteUCG["RemoteUCG"] + $obj + ","
        $RemoteUCG["RemoteUCG"] += $obj
			}
		}
		
		#$tmp = (Test-Connection -ComputerName $_ -Count 1).IPV4Address.IPAddressToString
		#$RemoteUCG["RemoteUCG"] = $RemoteUCG["RemoteUCG"] + $tmp + ","
	}
	$RemoteUCG["RemoteUCG"] = $RemoteUCG.Values.TrimEnd(",")
	
	#return a n array
	return $RemoteUCG
}
Function Get-NordstromDomainControllersIpAddress{
	$NordstromDCs = @{"DomainControllers" = @()}
	[string]$IPAddresses = ""
	$nslookup = nslookup nordstrom.net
	
	$nslookup | %{ $obj = $_
		$obj = $obj.Trim()
		
		If($obj -like "*Addresses*"){
			$obj = $obj.Replace("Addresses:","")
			$obj = $obj.Trim()
		}
		
		If($obj.StartsWith("10.")){
			#[string]$IPAddresses = "$($IPAddresses)$($obj),"
      $NordstromDCs["DomainControllers"] += $obj
		}
	}
	#$IPAddresses = $IPAddresses.TrimEnd(',')
	
	#$NordstromDCs.Add("DomainControllers",$IPAddresses)
	return $NordstromDCs
}
Function Get-NordstromDnsServersIpAddress{
	return @{
		"DNSServers" = @("10.16.172.129", "10.16.172.131", "10.12.137.20", "10.12.137.21")
	}
}
Function Get-NordstromSNMPServersIpAddress{
	return @{
		"SNMPServers" = @("10.1.81.138", "10.16.101.101", "10.12.140.10")
	}
}
Function Get-vCommanderServersIpAddress{
	$vCommander = @{"vCommander" = @()}
	@("vcommanderprod","vcommandertest") | %{
    $tmp = (Test-Connection -ComputerName $_ -Count 1).IPV4Address.IPAddressToString
		$vCommander["vCommander"] += $tmp
	}
	#$vCommander["vCommander"] = $vCommander.Values.TrimEnd(",")
	
	#return a hash table
	return $vCommander
}
Function Get-vCenterSubnetCIDR{
	Param(
		[Parameter(Mandatory=$true, Position=0)]
		$vCenter
	)
	#08/04/2016 Firewall rules are preventig RPC connections from RemoteUCG. Once this is fixed then this function will change
	#  For now though we will staticaly assign that the vCenters subnet Mask is 255.255.254.0 untile we can dynamically determine this
	
	$cidr = Get-SubnetCIDR -IPAddress (Test-Connection -ComputerName $vCenter -Count 1).IPV4Address -SubnetMask "255.255.254.0"
	
	return @{
    "vCenter" = @($cidr)
	}
}
	
Function Get-EsxiSubnetCIDR{
	Param(
	[VMware.Vim.HostSystem]$VMHost
	)
	
	try{
		$tmp = @()
		$VMHost.Config.Network.Vnic | %{$obj = $_
			$cidr = Get-SubnetCIDR -IPAddress $obj.Spec.Ip.IpAddress -SubnetMask $obj.Spec.Ip.SubnetMask
			$tmp += $cidr
		}
		#$str = $str.TrimEnd(",")
		
		return @{
      "Esxi" = $tmp
    }
		
	}catch{
		throw $_
	}
}
Function Get-FilePrintIpAddress{
	Param(
		[Vmware.Vim.ClusterComputeResource]$Cluster
	)
	try{
		$FilePrint = @{"FilePrint" = @()}
    $dc = Get-VIObjectByVIView -MORef $Cluster.MoRef | Get-Datacenter
		Get-VM -Location (Get-VIObjectByVIView -MORef $Cluster.MoRef) | ?{$_.Name -like "F$($dc.name.Substring(0,4))*"} | %{
			If([string]::IsNullOrEmpty($_.ExtensionData.Summary.Guest.IpAddress)){
        $tmp = (Test-Connection -ComputerName $_.Name -Count 1).IPV4Address.IPAddressToString
        If(-not [string]::IsNullOrEmpty($tmp)){
          $FilePrint["FilePrint"] += $tmp
        }
      }Else{
        $FilePrint["FilePrint"] += $_.ExtensionData.Summary.Guest.IpAddress
      }
		}
		
		return $FilePrint
		
	}catch{
		throw $_
	}
	
}
Function Get-NFSServersIpAddress{
	
	#There is a Corporate NFS server F0319P09 that is used
	#However, there isn't a dynamic way getting this information so this is a static configuration
	
	return @{
		"NFSServer" = @("10.16.172.202")
	}
}
Function Get-NutanixCVMIpAddress{
  #There is a Controller VM for all Nutanix deployments that requires communication to and from ESXi hosts
	#The IP addresses are alway 192.168.5.1 and 192.168.5.2 so adding a CIDR of 192.168.5.0/30
  
  return @{
    "CVM" = @("192.168.5.0/30", "192.168.5.254")
  }
}
Function Validate-IPAddress{
	Param(
		[string]$IPAddress
	)
	
    [regex]$IPregex = '^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$'
    return ($IPAddress -match $IPregex)
}
Function Validate-CIDRAddress{
	Param(
		[string]$IPAddress
	)
	
	[regex]$CIDRregex = '^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\/\d{1,2}$'
    return ($IPAddress -match $CIDRregex)
}
Function New-HostFirewallSpec{
	Param(
		$policy,
		$AllowedList
	)
	
	[String[]]$iplist = $null
	[array]$ipnetwork = $null
	
	#Write-Host $policy
	
	$HostFWSpec = New-Object Vmware.Vim.HostFirewallRulesetRulesetSpec
	$HostFWSpec.allowedHosts = New-Object VMware.Vim.HostFirewallRulesetIpList
	$HostFWSpec.AllowedHosts.AllIp = $false
  
	$AllowedList | %{
		If(-not [string]::IsNullOrEmpty($_)){
	    $IPAddress = $_.Trim()
			If( Validate-IPAddress $IPAddress ){
			  $HostFWSpec.AllowedHosts.IpAddress += $IPAddress
			}ElseIf( Validate-CIDRAddress $IPAddress ){
			  $IP,$prefixLength = $IPAddress.Split('/',2)
				$HostFWSpec.AllowedHosts.IpNetwork += New-Object VMware.Vim.HostFirewallRulesetIpNetwork -Property @{Network=$IP;PrefixLength=($prefixLength -as [int])}
			}
			Else{ 
        Write-Host $IPAddress; 
        throw "{$($IPAddress)} NOT A VALID IP ADDRESS" 
      }
		}Else{
			$HostFWSpec.AllowedHosts.IpAddress = $null
			$HostFWSpec.AllowedHosts.IpNetwork = $null
		}
	}
	
	return $HostFWSpec
}

Import-Module UcgModule -ArgumentList vmware -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

try{
	$ruleset = Import-Csv $RulesetCSV -ErrorAction Stop

	$vi = Connect-VIServer -Server $vCenter -ErrorAction Stop
  Write-Log -Message "[$(Get-Date)]`tConnected to vCenter $($vi.Name)" -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue

	$AllowedList = @{}
	$AllowedList += (Get-RemoteUCGNodeIpAddresses)
	$AllowedList += (Get-NordstromDomainControllersIpAddress)
	$AllowedList += (Get-NordstromDnsServersIpAddress)
	$AllowedList += (Get-NordstromSNMPServersIpAddress)
	$AllowedList += (Get-vCommanderServersIpAddress)
	$AllowedList += (Get-vCenterSubnetCIDR -vCenter $vCenter)
	$AllowedList += (Get-NFSServersIpAddress)
  $AllowedList += (Get-NutanixCVMIpAddress)
  $AllowedList += (Get-VSANMultiCastAddresses)

	$cl = Get-View -ViewType ClusterComputeResource -Filter @{"Name"=$Cluster}
	$AllowedList += (Get-FilePrintIpAddress -Cluster $cl)
  [int]$progress = 0
  
  Write-Log -Message "[$(Get-Date)]`tCluster Hosts" -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
  Write-Log -Message $cl.Host -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
	$cl.Host | %{ $progress++; [int]$subProgress = 0
		$esxi = Get-View $_
    Write-Log -Message "[$(Get-Date)]`tConfiguring ESXi ACL for VMHost $($esxi.Name)" -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
    Write-Progress -Activity "Configuring ESXi ACL for VMHost $($esxi.Name)" -PercentComplete (100*($progress/$cl.Host.Count)) -Id 10
		$tmp = (Get-EsxiSubnetCIDR -VMHost $esxi)
    $AllowedList["Esxi"] = $tmp["Esxi"]
		#If($AllowedList["Esxi"] -ne $tmp["Esxi"]){ 
		#	$AllowedList["Esxi"] += $tmp["Esxi"]
		#}
		Write-Log -Message "[$(get-Date)] Allowed List:" -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
    Write-Log -Message $AllowedList -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
		#$esxcli = Get-EsxCli -VMHost (Get-VIObjectByVIView $esxi.MoRef)
		$ruleset | %{ $policy = $_; $subProgress++
      Write-Progress -Activity "Setting Firewall Policy $($policy.RuleSet) Allowed List to $($policy.AllowedList)" -PercentComplete (100*($subprogress/$ruleset.Count)) -Id 11 -ParentId 10
			#If($policy.ruleset -eq "nfsClient"){ ($policy.AllowedList.Split(',') | %{ $AllowedList["$($_.Trim())"]}) }
      #($policy.AllowedList.Split(',') | %{ $AllowedList["$($_.Trim())"]}); "`nAllowedList:";$policy.AllowedList
      $fwPolSpec = New-HostFirewallSpec -Policy $policy -AllowedList ($policy.AllowedList.Split(',') | %{ $AllowedList["$($_.Trim())"]})
      #$fwPolSpec.AllowedHosts.IpAddress
      #$fwPolSpec.AllowedHosts.IpNetwork
			$fwSystem = Get-View -Id $esxi.ConfigManager.FirewallSystem
			$tmp = $null
			$tmp = $fwSystem.FirewallInfo.RuleSet | ?{$_.Key -eq $policy.RuleSet }
      try{
        Write-Log -Message "[$(get-Date)] Setting Firewall Policy $($policy.RuleSet) Allowed List to $($policy.AllowedList)" -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
        Write-Log -Message $fwPolSpec.AllowedHosts.IpAddress -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
        Write-Log -Message $fwPolSpec.AllowedHosts.IpNetwork -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
      }catch{}
			If($tmp){
				$fwSystem.UpdateRuleset($tmp.Key,$fwPolSpec)
			}
		}
    Write-Progress -Activity "Complete" -Completed -Id 11
	}
  Write-Progress -Activity "Complete" -Completed -Id 10
  Disconnect-VIServer -Server $vCenter -Confirm:$false -Force:$true -ErrorAction SilentlyContinue
}catch{
	Write-Error $_
  Write-Log -Message "[$(Get-Date)]" -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
  Write-Log -Message $_ -Path "D:\Temp\EsxiACL.log" -ErrorAction SilentlyContinue
  throw $_
}
