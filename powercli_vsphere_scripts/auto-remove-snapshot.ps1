
Param([Parameter(Mandatory=$false)][array]$vcenter=$null)
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
CLS

$prodVcenters = @("a0319p362","a0319p364","a0864p71","a0870p01","319ProdVcenter","319VdiVcenter","864ProdVcenter","870ProdVcenter")
$nonprodVcenters = @("a0319p691","a0319p10133","a0319t355","a0864p72","319NonProdVcenter","319TestLabVcenter","864NonProdVcenter")
$storeVcenters = @("a0319p366","StoreVcenter", "a0319p1201", "stvc01", "a0319p1202", "stvc02", "a0319p1203", "stvc03", "a0319p1205")


#$vcenter = @("a0319p8k","a0319p133","a0319p362","a0319p363","a0319p366","a0864p71","a0864p72","a0870p01")
[DateTime]$todayDate = Get-Date -Format s
$ImpPath = '\\a0319p184\UCG-Logs\Snapshots-AutoRemove\snapshot_delete.csv'

### TESTING PURPOSES ONLY ###
#$vcenter = @("a0319t355")
#$ImpPath = '\\a0319p184\UCG-Logs\Snapshots-AutoRemove\snapshot_delete_test.csv'
#############################

$snapLog = Import-Csv $ImpPath
[bool] $SkipServer = $false
[array]$removeReport = @()
$rename = $ImpPath+"."+(Get-Date -Format "MMddyyyy")
Copy-Item $ImpPath $rename -Confirm:$false

Do{
	[array]$files = Get-Item -Path "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\snapshot_delete.csv.*"
	$tmpFile = $null
	If($files.Count -gt 60){
		$files | %{
			If($_.CreationTime -lt $tmpFile.CreationTime -or $tmpFile -eq $null){ $tmpFile = $_ }
		}
		Remove-Item $tmpFile
	}
}While($files.Count -gt 60)

$vcenter | %{
	$vc = $_
	$vi = Connect-VIServer -Server $_ -Credential (Login-vCenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	If($vi -eq $null -or $vi -eq ""){ Write-Host "Cannot Connect to $($vc) ." }
	Else{

	Get-Datacenter -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | %{
		$datacenter = $_
		If($datacenter -notlike "*Lab*"){
		$allVms = $null
		Get-VM -Location $datacenter -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | %{
			$thisVM = $_
			If($thisVM -ne $null -and $thisVM -ne "" -and $thisVM.Name -ne "snapshotverify-NeverDelete" -and $thisVM.Name -notlike "U0864*"){				
				[array]$findVm = $snapLog | ?{ $_.Server -eq $thisVM.Name -or $_.Uuid -eq $thisVM.Id }
				If($findVm -ne $null -and $findVm -ne ""){ #found the Vm in the snapshot-delete list
				  $findVm | %{ $thisObj = $_					
					[DateTime]$removeDate = $thisObj.CanBeDeletedOn
					If($todayDate -gt $removeDate){				
						$allSnaps = $null
						Get-Snapshot -VM $thisVM -Id $thisObj.SnapshotId -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | %{
							$thisSnap = $_
							"$($thisVM.Name) : $($thisSnap.Name)"
							$suffix = Get-Random -Minimum 1000 -Maximum 10000
							$path = "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log" + $suffix
							$outNull = Remove-Snapshot -Snapshot $thisSnap -Confirm:$false -RunAsync -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
							Add-Content "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log" -Value "`n$($todayDate)  :  $($thisVM.Name)  :  $($thisSnap.Name)`n" -Confirm:$false -Force:$true
							
						}						
						[System.Collections.ArrayList]$err = $null; $openwrite = $false
						$tmpEAP = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
						Do{ #need to loop in case I can't open or edit the file because it is being used by something else
							$snapLog = Import-Csv $ImpPath -ErrorAction SilentlyContinue -ErrorVariable err
							If([string]::IsNullOrEmpty($err)){
								$tsnapLog = $snapLog | ?{ $_.SnapshotId -ne $thisObj.SnapshotId -and $_.Uuid -ne $thisObj.Uuid }
								If(-not [string]::IsNullOrEmpty($tsnapLog)){
									$tsnapLog | Export-Csv -Path $ImpPath -NoTypeInformation -Confirm:$false -Force:$true -ErrorAction SilentlyContinue -ErrorVariable err
								}
								If([string]::IsNullOrEmpty($err)){ $openwrite = $true }
							}
						}While(-not $openwrite)
						$ErrorActionPreference = $tmpEAP
						$snapLog = Import-Csv $ImpPath						
					}
				  }
				}
				Else{ #Did not find the VM in the snapshot delete list
					$allSnaps = $null
					$allSnaps = Get-Snapshot -VM $thisVM -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
					If($allSnaps -ne $null -and $allSnaps -ne ""){
						#TODO: Need to parse out prod/nonprod/store
						If($nonprodVcenters -contains $vc) { [bool]$nonprod = $true }
						ElseIf($prodVcenters -contains $vc){ [bool]$prod = $true }
						ElseIf($vc -eq "864ProdVcenter"){
							If($datacenter.Name -eq "0319" -or $datacenter.Name -eq "0870" -or $datacenter.Name -eq "DMZ"){ [bool]$prod = $true }
							ElseIf($datacenter -eq "0864"){ 
								$resPool = $thisVM | Get-ResourcePool
								If($resPool.Name -eq "non-prod"){ [bool]$nonprod = $true }
								ElseIf($resPool.Name -eq "prod" -or $resPool.Name -eq "exchange") { [bool]$prod = $true }
								Else{ [bool]$nonprod = $true }
							}
						}
						ElseIf($storeVcenters -contains $vc){ [bool]$storeprod = $true }
						
						$allSnaps | %{
							$thisSnap = $_
							[DateTime]$snapCreated = $thisSnap.Created
							
							If(($storeprod) -and ($todayDate -gt $snapCreated.AddDays(7))){
								"$($thisVM.Name) : $($thisSnap.Name)"
								$outNull = Remove-Snapshot -Snapshot $thisSnap -Confirm:$false -RunAsync -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
								Add-Content "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log" -Value "`n$($todayDate)  :  $($thisVM.Name)  :  $($thisSnap.Name)`n" -Confirm:$false -Force:$true
							}
							ElseIf(($prod) -and ($todayDate -gt $snapCreated.AddDays(2))){
								"$($thisVM.Name) : $($thisSnap.Name)"
								$outNull = Remove-Snapshot -Snapshot $thisSnap -Confirm:$false -RunAsync -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
								Add-Content "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log" -Value "`n$($todayDate)  :  $($thisVM.Name)  :  $($thisSnap.Name)`n" -Confirm:$false -Force:$true
							}
							ElseIf(($nonprod) -and ($todayDate -gt $snapCreated.AddDays(7))){
								"$($thisVM.Name) : $($thisSnap.Name)"
								$outNull = Remove-Snapshot -Snapshot $thisSnap -Confirm:$false -RunAsync -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
								Add-Content "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log" -Value "`n$($todayDate)  :  $($thisVM.Name)  :  $($thisSnap.Name)`n" -Confirm:$false -Force:$true
							}
							Else{
								If($todayDate -gt $snapCreated.AddDays(7)){
									"$($thisVM.Name) : $($thisSnap.Name)"
									$outNull = Remove-Snapshot -Snapshot $thisSnap -Confirm:$false -RunAsync -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
									Add-Content "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log" -Value "`n$($todayDate)  :  $($thisVM.Name)  :  $($thisSnap.Name)`n" -Confirm:$false -Force:$true
								}
							}
						}
					}
				}
			}
		}
		}
	}
	}
}

If((Get-Item "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log").length -gt 500kb){
	$rename = "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log."+(Get-Date -Format "MMddyyyy")
	Rename-Item "\\a0319p184\UCG-Logs\Snapshots-AutoRemove\autoRemoveLog.log" $rename
}
Disconnect-VIServer -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force:$true
