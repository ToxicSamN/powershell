
Function IsAutoNegotiated{
  Param(
    [Parameter(mandatory=$true)]
    [VMware.Vim.PhysicalNic]$PhysicalNic
  )
  If($PhysicalNic.Spec.LinkSpeed){ return $false }
  Else{ return $true }
  
}

Function Get-VlanIdInfo{
  Param(
    [Parameter(mandatory=$true)]
    [VMware.Vim.PhysicalNic]$PhysicalNic,
    [Parameter(Mandatory=$true)]
    [VMware.Vim.HostNetworkInfo]$NetworkInfo
  )
  
  $vSw = $NetworkInfo.Vswitch | ?{$_.Pnic -contains $PhysicalNic.Key}
  $ary = ($NetworkInfo.Portgroup | ?{$_.Vswitch -eq $vSw.Key} | %{ $_.Spec.VlanId }) | Select -Unique
  return $ary -join ", "
}

[array]$report = @()

Add-PSSnapin VM* -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Import-Module UcgModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
cls

@("a0319p366","a0319p1201","a0319p1202","a0319p1203") | %{ $vc = $_

  Connect-VIServer -Server $vc -ErrorAction Stop

  Get-View -ViewType Datacenter | %{ $dc = $_
    Get-View -ViewType HostSystem -SearchRoot $dc.MoRef | %{ $esxi = $_
      If($esxi.Runtime.ConnectionState -eq "Connected"){
        If($esxi.Name -eq "a0399vm01.nordstrom.net"){
          $str = "pause"
        }
        $netSys = $null
        $netSys = Get-View -Id $esxi.ConfigManager.NetworkSystem
        
        $pso = New-Object PSObject -Property @{
          Store = $dc.Name
          VMhost = $esxi.Name
          vmnic0_link = $null
          vmnic0_AutoNegotiated = $null
          vmnic0_sw = $null
          vmnic0_swport = $null
          vmnic0_vlan = $null
          vmnic1_link = $null
          vmnic1_AutoNegotiated = $null
          vmnic1_sw = $null
          vmnic1_swport = $null
          vmnic1_vlan = $null
          vmnic2_link = $null
          vmnic2_AutoNegotiated = $null
          vmnic2_sw = $null
          vmnic2_swport = $null
          vmnic2_vlan = $null
          vmnic3_link = $null
          vmnic3_AutoNegotiated = $null
          vmnic3_sw = $null
          vmnic3_swport = $null
          vmnic3_vlan = $null
        }
        
        $netSys.NetworkInfo.Pnic | %{ $pnic = $_
          $cdpInfo = $netSys.QueryNetworkHint($pnic.Device)
          
          $pso."$($pnic.Device)_sw" = If([string]::IsNullOrEmpty($cdpInfo[0].ConnectedSwitchPort.DevId)){"CDP is not enabled on Cisco Switch Port"}Else{$cdpInfo[0].ConnectedSwitchPort.DevId}
          $pso."$($pnic.Device)_swport" = If([string]::IsNullOrEmpty($cdpInfo[0].ConnectedSwitchPort.PortId)){"CDP is not enabled on Cisco Switch Port"}Else{$cdpInfo[0].ConnectedSwitchPort.PortId}
          $pso."$($pnic.Device)_link" = If($pnic.LinkSpeed -eq $null){"Not Connected"}Else{"Connected"}
          $pso."$($pnic.Device)_AutoNegotiated" = IsAutoNegotiated $pnic
          $pso."$($pnic.Device)_vlan" = Get-VlanIdInfo -NetworkInfo $netSys.NetworkInfo -PhysicalNic $pnic
        }
        [array]$report += $pso | Select Store,VMhost,vmnic0_link,vmnic0_AutoNegotiated,vmnic0_sw,vmnic0_swport,vmnic0_vlan,vmnic1_link,vmnic1_AutoNegotiated,vmnic1_sw,vmnic1_swport,vmnic1_vlan,vmnic2_link,vmnic2_AutoNegotiated,vmnic2_sw,vmnic2_swport,vmnic2_vlan,vmnic3_link,vmnic3_AutoNegotiated,vmnic3_sw,vmnic3_swport,vmnic3_vlan
      }
    }
  }
  
  Disconnect-VIServer * -Confirm:$false -Force:$true -ErrorAction SilentlyContinue
}

$report | Export-Csv "E:\Sammy\Store_vmnic_info.csv" -NoTypeInformation