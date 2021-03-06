
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue

CLS

[array]$VMs = @()

$targs = $args
$carg = 0
$args | %{ 
			$carg++
			[string]$tempstr = $_
			If ($tempstr.StartsWith("-"))
			{[string]$tempvar = $_
				Switch -wildcard ($tempvar.ToLower()){
				"-vm*" {[array]$VMs = $targs[$carg]}
				#"-datacenter*" {[array]$VMs = $targs[$carg]}
				#"-cluster*" {[array]$VMs = $targs[$carg]}
				#"-filename*" {[string]$filename = $targs[$carg]}
				#"-email*" {[string]$SendToEmail = $targs[$carg]}
				}
			}
		 }

$StorageInfo = @()
If($VMs.Count -eq 0){ 
Write-Host "
You must supply at least one VM to get the storage information from.
Usage: .\Get-VMStorageInfo.ps1 -vm:{vm1,vm2,vm3...n}"
Exit 1
}
echo "Connecting to a0319p8k..."
$esxi = Connect-VIServer -Server a0319p8k -WarningAction SilentlyContinue

$VMs | %{
			Write-Host "`nGathering Storage Information for $($_) ..."
			$vm = Get-VM -Name $_
			$esxiHost = Get-VMHost -Name $vm.Host

			
			$vm | %{ 
						$vmachine = $_
						$_.DatastoreIdList | %{
							$dsID = $_
							$gdatastores = Get-Datastore -VMHost $esxiHost | where {$_.Type -eq "vmfs" -and $_.Id -eq $dsID}
							$gdatastores | %{
								$dsName = $_						
								$_.Extensiondata.Info.Vmfs.Extent | %{											
									$newHashTbl = @{}
									$newHashTbl = @{VMName=$vmachine.Name;ESXiHost=$esxiHost.Name;Cluster=$esxiHost.Parent;Datastore=$dsName.Name;DeviceID=$_.DiskName}
									$tempPSObj = New-Object -TypeName PSObject -Property $newHashTbl
									$row = "" | Select VMName,Datastore,DeviceID,ESXiHost,Cluster
									$row.VMName = $tempPSObj.VMName
									$row.ESXiHost = $tempPSObj.ESXiHost
									$row.Cluster = $tempPSObj.Cluster
									$row.Datastore = $tempPSObj.Datastore
									$row.DeviceID = $tempPSObj.DeviceID
									$StorageInfo += $row
								}
							}
						}	
			}
}
$StorageInfo | %{ $_ }
#$StorageInfo | Export-Csv D:\VMStorageReport.csv -NoTypeInformation

#Send-MailMessage -From 'itucg@nordstrom.com' -To 'itucg@nordstrom.com' -Subject "All VM's Storage Information" -Attachments 'D:\VMStorageReport.csv' -Body "`nReport of all VMs in a0319p8k and the storage that is connected to those VMs." -SmtpServer "exchange.nordstrom.net"

Disconnect-VIServer -Server $esxi.Name -Confirm:$false
