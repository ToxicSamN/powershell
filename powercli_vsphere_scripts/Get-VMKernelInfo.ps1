
Param([Parameter(Mandatory=$true,Position=0)][array]$vcenter = $null,[Parameter(Mandatory=$false,Position=2)][string]$output="TRUE", [switch]$Force)
cls
If($output -eq "true" -and (-not $Force)){
$eprompt = Read-Host "Would you like to send an email with the results? (y/n) "
If($eprompt -eq "yes" -or $eprompt -eq "y"){
	[bool]$email=$true
	$userAddress = Read-Host "Please provide a single email address or multiple email addresses separated by a comma (,) "
	$emailAddress = $userAddress.Split(",")
}Else{[bool]$email=$false}
}
cls
Write-Host "Loading the script ... "
Import-Module UcgModule -WarningAction SilentlyContinue
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Write-Host "Script Loaded ... `n`n"
cls
Write-Host "Script Started at:"
Get-Date
[array]$report = @()
$vmks = $null; $vswif = $null
$vcenter |%{
	$vc = $_
	Write-Host "Connecting to $($_) ..."
	$vi = Connect-VIServer -Server $vc -Credential (Login-vCenter) -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	If($vi -ne "" -and $vi -ne $null){
	Get-View -ViewType HostSystem | %{
		$esxi = $_
		$vmks = $_.Config.Network.Vnic
		$vswif = $_.Config.Network.ConsoleVnic
		
		#Have to search for vswif interfaces since we have ESX 3.5 hosts
		If($vswif -ne $null -and $vswif -ne ""){
		$vswif | %{
			$row = "" | Select vCenter,Host,VMKernel,PortGroup,IP,SubnetMask,Management,vMotion,FTLogging
			$row.Management = "TRUE" #Set this to TRUE Because vswif interfaces are always management
			$row.vMotion = "FALSE" #Set this to FALSE and check below if it is true
			$row.FTLogging = "FALSE" #Set this to FALSE and check below if it is true
			
			If($_.Portgroup -eq $null -or $_.Portgroup -eq "" ){
				$dvPortgroup = Get-View -ViewType DistributedVirtualPortgroup -Property Name -Filter @{"Key" = $_.Spec.DistributedVirtualPort.PortgroupKey }
				$row.PortGroup = $dvPortgroup.Name
			}ElseIf($_.Portgroup -ne $null -and $_.Portgroup -ne ""){
				$row.PortGroup = $_.Portgroup
			}
			$vmkKey = $_.Key
			
			$row.vCenter = $vc
			$row.Host = $esxi.Name
			$row.VMKernel = $_.Device			
			$row.IP = $_.Spec.Ip.IpAddress
			$row.SubnetMask = $_.Spec.Ip.SubnetMask
			
			$esxi.Config.VirtualNicManagerInfo.NetConfig | %{
				If($_.NicType -eq "management" -and $_.SelectedVnic -ne $null){
					$_.SelectedVnic | %{
						If($_ -like "*$vmkKey") { $row.Management = "TRUE" }
					}
				}
				ElseIf($_.NicType -eq "faultToleranceLogging" -and $_.SelectedVnic -ne $null){
					$_.SelectedVnic | %{
						If($_ -like "*$vmkKey") { $row.FTLogging = "TRUE" }
					}
				}
				ElseIf($_.NicType -eq "vmotion" -and $_.SelectedVnic -ne $null){
					$_.SelectedVnic | %{
						If($_ -like "*$vmkKey") { $row.vMotion = "TRUE" }
					}
				}
			}
			[array]$report += $row
		}
		}
		If($vmks -ne $null -and $vmks -ne ""){
		$vmks | %{
			$row = "" | Select vCenter,Host,VMKernel,PortGroup,IP,SubnetMask,Management,vMotion,FTLogging
			$row.Management = "FALSE" #Set this to FALSE and check below if it is true
			$row.vMotion = "FALSE" #Set this to FALSE and check below if it is true
			$row.FTLogging = "FALSE" #Set this to FALSE and check below if it is true
			
			If($_.Portgroup -eq $null -or $_.Portgroup -eq "" ){
				$dvPortgroup = Get-View -ViewType DistributedVirtualPortgroup -Property Name -Filter @{"Key" = $_.Spec.DistributedVirtualPort.PortgroupKey }
				$row.PortGroup = $dvPortgroup.Name
			}ElseIf($_.Portgroup -ne $null -and $_.Portgroup -ne ""){
				$row.PortGroup = $_.Portgroup
			}
			$vmkKey = $_.Key
			
			$row.vCenter = $vc
			$row.Host = $esxi.Name
			$row.VMKernel = $_.Device
			$row.IP = $_.Spec.Ip.IpAddress
			$row.SubnetMask = $_.Spec.Ip.SubnetMask
			
			$esxi.Config.VirtualNicManagerInfo.NetConfig | %{
				If($_.NicType -eq "management" -and $_.SelectedVnic -ne $null){
					$_.SelectedVnic | %{
						If($_ -like "*$vmkKey") { $row.Management = "TRUE" }
					}
				}
				ElseIf($_.NicType -eq "faultToleranceLogging" -and $_.SelectedVnic -ne $null){
					$_.SelectedVnic | %{
						If($_ -like "*$vmkKey") { $row.FTLogging = "TRUE" }
					}
				}
				ElseIf($_.NicType -eq "vmotion" -and $_.SelectedVnic -ne $null){
					$_.SelectedVnic | %{
						If($_ -like "*$vmkKey") { $row.vMotion = "TRUE" }
					}
				}
			}
			[array]$report += $row
		}
		}
	}
	Disconnect-VIServer -Confirm:$false -Force:$true
}
}
$report | Export-Csv "\\nord\dr\Software\VMware\Reports\VMKernelReport.csv"
If($output -eq "true"){ $report | Export-Csv D:\VMKernelReport.csv -NoTypeInformation }
If($email){
Write-Host "Emailing VMKernelReport.csv to $($emailaddress) ..."
	Send-MailMessage -From 'sammy.shuck@nordstrom.com' -To $emailAddress -Subject "ESXi Host Vmkernel Report" -Attachments 'D:\VMKernelReport.csv' -Body "`nReport of all ESXi Hosts VMKernel adapters in $($vcenter)" -SmtpServer "exchange.nordstrom.net" | Out-Null
}
Write-Host "Script Completed at:"
Get-Date
