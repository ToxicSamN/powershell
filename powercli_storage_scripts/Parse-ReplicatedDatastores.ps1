
cls
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
cls

$today = Get-Date
$path = "\\cns0319p02\uis_san1\DR2\log\SRDF_audit\"
#$path = "D:\temp\SRDF_audit\"
$child = dir $path | ?{$_.Name.EndsWith(".out")} | Sort CreationTime
$chk = $null
$child | %{ If($_.CreationTime -gt $chk.CreationTime){ $chk = $_ }}; $child = $chk
If($child.Count -gt 1){ $child = $child[$child.Count-1] }
$contents = Get-Content $child.PSPath

[array]$report = @("__Updated as of : "+(Get-Date)+"__"," ")
$contents | %{
	$tmpStr = $_.Replace(" ","")
	$tmp = $tmpStr.Split("		") | ?{$_ -ne "" -and ($_ -like "60000*") -and $_.Length -gt 4}
	If($tmp -ne $null -and $tmp -ne ""){
		[array]$report += $tmp
	}
}
$report = $report | Sort; $report
#$report | Out-File "\\nord\dr\Software\VMware\Reports\replicatedDatastores.csv" -Confirm:$false -Force:$true

If($report.Count -gt 1){
	cls
	Get-Date
	@("a0319p8k","a0319p362") | %{
		$vcenter = $_
		$vi = Connect-VIServer -Server $vcenter -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
		$dc = Get-Datacenter | ?{$_.Name -eq "0319" -or $_.Name -like "*dmz*" -or $_.Name -eq "*landmine*"} | %{ $dc = $_
			Get-Datastore -Location $dc | %{
				$ds = $_
				$naa = $ds.ExtensionData.Info.Vmfs.Extent[0].DiskName
				$naa = $naa.Replace("naa.","")
				$chk = $report | ?{$_ -eq $naa}
		
				If(-not [string]::IsNullOrEmpty($chk)){
					If((-not($ds.Name.EndsWith("_rpl")))){
						$chName = $ds.Name + "_rpl"
						#the datastore is on the replication list and not named _rpl
						Write-Host "$($chName) is on the list but is named $($ds.Name), renaming to $($chName)"
						$ds | Set-Datastore -Name $chName
					}
				}ElseIf([string]::IsNullOrEmpty($chk)){
					If(($ds.Name.EndsWith("_rpl"))){
						$chName = $ds.Name.Replace("_rpl","")
						#datastore in not on the replication list but is labeled with _rpl
						Write-Host "$($ds.Name) is not in the list but labeled with _rpl, renaming to $($chName)"
						$ds | Set-Datastore -Name $chName
					}
				}
			}
		}
		Disconnect-VIServer -Server $vcenter -Confirm:$false -Force:$true
	}
}
Get-Date
