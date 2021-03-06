
#Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -ArgumentList vmware -WarningAction SilentlyContinue
CLS
try{
Get-Date
[array]$StorageInfo = @()
$vcenters = Import-Csv "\\nord\dr\software\vmware\reports\vcenterlist.txt" | ?{$_.Type -notlike "*Store*" -and $_.Type -notlike "*Lab*" -and $_.Type -ne "DR"}
$vcenters | %{ $vc = $_
	$vi = Connect-VIServer -Server $_.Name -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	try{
		Get-View -ViewType Datacenter | Sort-Object Name | %{
			$dc = $_
			try{
				Get-View -ViewType ClusterComputeResource -SearchRoot $dc.MoRef | Sort-Object Name | %{
					$cl = $_
					try{
						Get-View -ViewType HostSystem -SearchRoot $cl.MoRef | Sort-Object Name | %{
							$esxi = $_
							Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`t$($vc.Name) > $($dc.Name) > $($cl.Name) > $($esxi.Name)"
							try{
								$luns = @{}
								Get-ScsiLun -VmHost (Get-VMHost $esxi.Name) -LunType disk | %{ $luns.Add($_.ExtensionData.Uuid,$_.CanonicalName) }
							}catch{
								Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`tERROR`t$_.Message"
								Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message $_
							}
							try{
								Get-View -ViewType VirtualMachine -SearchRoot $esxi.MoRef | Sort-Object Name | %{
								#-Filter @{"Name"="y0319p259"} | %{ #
									$vm = $_
									$vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk]} | %{
										$row = "" | Select VMName,Datastore,DeviceID,ESXiHost,Cluster
										$row.VMName = $vm.Name
										$row.ESXiHost = $esxi.Name
										$row.Cluster = $cl.Name
										$rdm = $null; $vmfs = $null
										Switch($_.Backing){
											{$_ -is [VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo]}{ $rdm = $_ }
											{$_ -is [VMware.Vim.VirtualDiskFlatVer1BackingInfo]}{ $vmfs = $_ }
											{$_ -is [VMware.Vim.VirtualDiskFlatVer2BackingInfo]}{ $vmfs = $_ }
											default { [array]$Needtype += $_.GetType() }
										}
										If($rdm){
											#$naa = Get-ScsiLun -VmHost (Get-VMHost $esxi.Name) | ?{ $_.ExtensionData.Uuid -eq $rdm.LunUuid } | Select CanonicalName
											$row.Datastore = "Raw Device Mapping"
											If($rdm.LunUuid -eq $null){ $row.DeviceID = $rdm.DeviceName }
											Else{ $row.DeviceID = $luns[$rdm.LunUuid] }
										}
										If($vmfs){
											$ds = Get-View -Id $vmfs.Datastore 
											$row.Datastore = $ds.Name
											$row.DeviceID = $ds.Info.Vmfs.Extent[0].DiskName
										}
									
										[array]$StorageInfo += $row
									}
								}
							}catch{
								Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`tERROR`t$_.Message"
								Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message $_
							}
						}
					}catch{
						Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`tERROR`t$_.Message"
						Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message $_
					}
				}
			}catch{
				Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`tERROR`t$_.Message"
				Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message $_
			}	
		}
	}catch{
		Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`tERROR`t$_.Message"
		Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message $_
	}
	try{
		Disconnect-VIServer -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	}catch{
		Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`tERROR`t$_.Message"
		Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message $_
	}
}
Get-Date
$StorageInfo | Export-Csv D:\VMStorageReport.csv -NoTypeInformation
}catch{
	Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`tERROR`t$_.Message"
	Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message $_
}
try{
	Copy-Item -Path D:\VMStorageReport.csv -Destination "\\nord\dr\Software\VMware\Reports\VMStorageReport.csv" -Force -Confirm:$false
	Copy-Item -Path D:\VMStorageReport.csv -Destination "\\cns0319p02\uis_san1\DR2\VMStorageReport.csv" -Force -Confirm:$false
	Send-MailMessage -From 'itucg@nordstrom.com' -To 'itucg@nordstrom.com' -Subject "All VM's Storage Information" -Attachments 'D:\VMStorageReport.csv' -Body "`nReport of all VMs and the storage that is connected to those VMs." -SmtpServer "exchange.nordstrom.net"
}catch{
	Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message "$(Get-Date)`tERROR`t$_.Message"
	Write-Log -Path "$($UcgLogPath)\Get-StorageInfo.log" -Message $_
}