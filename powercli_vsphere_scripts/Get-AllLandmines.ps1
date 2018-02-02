<#
.SYNOPSIS
	Create a report of all landmines.

.DESCRIPTION
	Get-AllLandmines.ps1 will generate a report of all landmines and email
	the report to the current user as well as any email address specified
  in the email switch.
	Currently, the list of potential problems it checks for include: RDMs, 
	VirtualDisks with the multi-writer flag set, cluster DRS mode, 
	SCSI bus sharing (virtual or physical) and VM DRS
	where specific VMs are not set to default DRS mode.

.EXAMPLE
  .\Get-AllLandmines.ps1 -email itucg@nordstrom.net

.Parameter Email
	A string parameter used to specify an additional email address to 
  send the report too.
#>

#region ######################################### PARAMETERS ###########################################
Param(
	[string]$email
)
#endregion

#region ######################################### Variables and Constants ##############################
	cls
	### $ErrorActionPreference
		$WarningPreference = "SilentlyContinue"
	### Import Modules
		If((get-pssnapin) -notcontains "VMware.VimAutomation.Core"){ Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue }
		Import-Module Encryption -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
		If([string]::IsNullOrEmpty($global:defaultviserver) -eq $false){
			$global:defaultviservers | %{ disconnect-viserver $_ -confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }
		}
	### Get all vcenters that are in prod, nonprod, dr, p1 and m1
		[array]$vCenter = get-content \\nord\dr\software\vmware\reports\vcenterlist.txt | ConvertFrom-Csv | ?{ $_.Type -in "Prod","NonProd","DR","P1","M1" } | Select -expand Name 
#endregion

#region ######################################### FUNCTIONS ############################################
	Function Get-Msg (){
		$fromemail = "mark.leno@exchange.nordstrom.com"
		$users = "mark.leno@nordstrom.com" # List of users to email your report to (separate by comma) such as "techeowindows@exchange.nordstrom.com,mark.leno@nordstrom.com" 
		$ScriptName = $script:MyInvocation.MyCommand.Path
		$a = get-content env:username
		$HTMLmessage = @"
					<!DOCTYPE HTML PUBLIC '-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd'>
					<html><head><title>ScriptRan</title>
					</head>
					<body>
					<p>$a has run $ScriptName on $([System.Net.Dns]::GetHostName()) resulting in $turnoverspreadsheetpath.</p>
					</body>
"@
		send-mailmessage -from $fromemail -to $users -subject "ScriptRan" -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer exchange.nordstrom.net -ErrorAction SilentlyContinue
	}
	Function Send-eMail($emailaddress,$additionalMessage,$emailTable,$sendfile){
		$emailbody = "$additionalMessage<br/>
						<table>
							<tr>
								<td valign='top'>$emailTable</td>
							</tr>
						</table>"
		$emailsubject = "Minesweeper Detail Report"
		$ListOfAttachments = @("$sendfile") # An array with full unc paths like so @("$ThisPath\chart-ram-$_.png")
		$HTMLmessage = @"
					<!DOCTYPE HTML PUBLIC '-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd'>
					<html><head><title>TurnOver Spreadsheet</title>
					</head>
					<body>
					<p>$emailbody</p>
					</body>
"@
		$fromemail = "mark.leno@nordstrom.com"
		[string[]]$toAddress = $emailaddress
		if ([string]::IsNullOrEmpty($sendfile)){
			send-mailmessage -from $fromemail -to $toAddress -subject $emailsubject -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer exchange.nordstrom.net
		} else {
			send-mailmessage -from $fromemail -to $toAddress -subject $emailsubject -Attachments $ListOfAttachments -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer exchange.nordstrom.net
		}		
	}
	Function cleanup(){
		#remove-item $outputFile
		#Stop-Transcript
		$global:defaultviservers | %{ Disconnect-viServer $_ -confirm:$false }
		#Get-Msg
	}
#endregion

#region ######################################### Logging ##############################################
	$ScriptName = ($MyInvocation.MyCommand).Name
	$ScriptName = $ScriptName.SubString(0,$scriptname.indexof("."))
	$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
	$Date = (Get-Date -format 'yyyyMMddhhmmtt')
  $userID = get-content env:username
	$userIDEmail = "$userID@nordstrom.com"
	#IF ((test-path "$ScriptPath\Logs") -eq $false){ New-Item -type directory "$ScriptPath\Logs" }
	#Start-Transcript -path "$ScriptPath\Logs\$ScriptName-$Date.log" -append
	#IF ((test-path "$ScriptPath\output") -eq $false){ New-Item -type directory "$ScriptPath\output" }
#endregion

#region ######################################### MAIN #################################################
	$previousRun = get-content -path ((Get-ChildItem -Path \\nord\dr\software\vmware\reports\Landmines | sort LastWriteTime -desc | select -first 1).Versioninfo.FileName) | convertfrom-csv
  $allClusterInfo = @()
  $NumOfClustersTotal = 0
  $NumOfHostsTotal = 0
  $NumOfVMs = 0
  $vCenter | ?{$_ -ne $null} | %{ 
    Write-Host "Connecting to VIServer $_"
    $vi = Connect-VIServer -Server $_ -Credential (login-vcenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    $NumOfHostsTotal += (get-vmhost).count
    Get-Cluster | Select Name | %{ $_.Name } | %{
      $NumOfClustersTotal++
      Get-View -ViewType ClusterComputeResource -Filter @{"Name"=$_} | ?{ $_.Name -notlike "cl0319emgp001"} | %{ 
        $cl = $_
        
        Write-Host "Analyzing $($cl.Name)"
        $clConfigurationEx = $cl.ConfigurationEx
        
        #viserver
        $viServerName = (get-cluster $_.Name).Uid.split("@")[1].split(":")[0]
        
        #Cluster DRS Config
        $DrsConfig = $clConfigurationEx.DrsConfig.DefaultVmBehavior
        
        #DRS VMConfig
        $clConfigurationEx.DrsVmConfig | ?{$_.Behavior -ne "fullyAutomated" -or $_.Enabled -eq $false} | %{
          IF (-not ([string]::IsNullOrEmpty($_))) {
            $vm = Get-VM -Id $_.Key -ErrorAction SilentlyContinue
            If ($vm.Name -notlike "Z-VRA*" -and $vm.Name -notlike "*-CVM"){
              IF ([string]::IsNullOrEmpty(($allClusterInfo | ?{ $_.vmName -eq $vm.Name }))) {
                $clusterInfo = $null;
                $clusterInfo = "" | select VIServer,ClusterName,ClusterDRS,VmotionRate,Hosts,vmName,vmPower,VMDRSs,SharedScsiBuss,SharedVMDKs,RDMs,Moved,MovedOn,MovedBy,PreviousHost
                $clusterInfo.VIServer = $viServerName
                $clusterInfo.ClusterDRS = [string]($clConfigurationEx.DrsConfig.DefaultVmBehavior)
                $clusterInfo.VmotionRate = $clConfigurationEx.DrsConfig.VmotionRate
                $clusterInfo.ClusterName = $cl.Name
                $clusterInfo.vmName = $vm.Name
                $clusterInfo.vmPower = $vm.PowerState
                $clusterInfo.VMDRSs = $_.Behavior
                $clusterInfo.Hosts = $vm.vmHost.tostring().replace(".nordstrom.net", "")
                $allClusterInfo += $clusterInfo
              } ELSE {
                ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).VMDRSs = $_.Behavior
              }
            }
          }
        }
        #endregion
        
        #<#region MultiWriter Flag, Raw Device Mappings and SCSI Bus Sharing
        Get-View -ViewType VirtualMachine -SearchRoot $cl.MoRef | %{
          $NumOfVMs++
          $vm = $_
          #<#region Multi-Write Flag
          $tmp = $vm.Config.ExtraConfig | ?{$_.Value -eq "multi-writer"}
          IF (-not ([string]::IsNullOrEmpty($tmp))) {
            IF ([string]::IsNullOrEmpty(($allClusterInfo | ?{ $_.vmName -eq $vm.Name }))) {
              $clusterInfo = $null;
              $clusterInfo = "" | select VIServer,ClusterName,ClusterDRS,VmotionRate,Hosts,vmName,vmPower,VMDRSs,SharedScsiBuss,SharedVMDKs,RDMs,Moved,MovedOn,MovedBy,PreviousHost
              $clusterInfo.VIServer = $viServerName
              $clusterInfo.ClusterDRS = $clConfigurationEx.DrsConfig.DefaultVmBehavior
              $clusterInfo.VmotionRate = $clConfigurationEx.DrsConfig.VmotionRate
              $clusterInfo.ClusterName = $cl.Name
              $clusterInfo.vmName = $vm.Name
              $clusterInfo.vmPower = $vm.Summary.Runtime.PowerState
              $clusterInfo.SharedVMDKs = "x"
              $clusterInfo.Hosts = (get-vmhost -id $vm.runtime.host).name.replace(".nordstrom.net", "")
              $allClusterInfo += $clusterInfo
            } ELSE {
              ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).SharedVMDKs = "x"
            }
          }
          #endregion #>
          #<#region SCSI Bus Sharing
          $scsiController = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualLsiLogicController] -or $_ -is [VMware.Vim.VirtualLsiLogicSASController] -or $_ -is [VMware.Vim.VirtualBusLogicController] -or $_ -is [VMware.Vim.ParaVirtualSCSIController]}
          $scsiBus = $scsiController | ?{ $_.SharedBus -ne "noSharing" -and $_.SharedBus -ne "" -and $_.SharedBus -ne $null}
          IF (-not ([string]::IsNullOrEmpty($scsiBus))) {
            IF ([string]::IsNullOrEmpty(($allClusterInfo | ?{ $_.vmName -eq $vm.Name }))) {
              $clusterInfo = $null;
              $clusterInfo = "" | select VIServer,ClusterName,ClusterDRS,VmotionRate,Hosts,vmName,vmPower,VMDRSs,SharedScsiBuss,SharedVMDKs,RDMs,Moved,MovedOn,MovedBy,PreviousHost
              $clusterInfo.VIServer = $viServerName
              $clusterInfo.ClusterDRS = $clConfigurationEx.DrsConfig.DefaultVmBehavior
              $clusterInfo.VmotionRate = $clConfigurationEx.DrsConfig.VmotionRate
              $clusterInfo.ClusterName = $cl.Name
              $clusterInfo.vmName = $vm.Name
              $clusterInfo.vmPower = $vm.Summary.Runtime.PowerState
              $clusterInfo.SharedScsiBuss = "x"
              $clusterInfo.Hosts = (get-vmhost -id $vm.runtime.host).name.replace(".nordstrom.net", "")
              $allClusterInfo += $clusterInfo
            } ELSE {
              ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).SharedScsiBuss = "x"
            }
          }
          #endregion #>
          #<#region Raw Device Mappings
          $vmDisk = $vm.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk]}
          $rdm = $vmDisk | ?{$_.Backing -is [VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo]}
          IF (-not ([string]::IsNullOrEmpty($rdm))) {
            IF ([string]::IsNullOrEmpty(($allClusterInfo | ?{ $_.vmName -eq $vm.Name }))) {
              $clusterInfo = $null;
              $clusterInfo = "" | select VIServer,ClusterName,ClusterDRS,VmotionRate,Hosts,vmName,vmPower,VMDRSs,SharedScsiBuss,SharedVMDKs,RDMs,Moved,MovedOn,MovedBy,PreviousHost
              $clusterInfo.VIServer = $viServerName
              $clusterInfo.ClusterDRS = $clConfigurationEx.DrsConfig.DefaultVmBehavior
              $clusterInfo.VmotionRate = $clConfigurationEx.DrsConfig.VmotionRate
              $clusterInfo.ClusterName = $cl.Name
              $clusterInfo.vmName = $vm.Name
              $clusterInfo.vmPower = $vm.Summary.Runtime.PowerState
              $clusterInfo.RDMs = "x"
              $clusterInfo.Hosts = (get-vmhost -id $vm.runtime.host).name.replace(".nordstrom.net", "")
              $allClusterInfo += $clusterInfo
            } ELSE {
              ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).RDMs = "x"
            }          
          }
          #endregion #>
          #<#region Check if the host is different than last time
            IF (-not [string]::IsNullOrEmpty(($allClusterInfo | ?{ $_.vmName -eq $vm.Name }))) {
              $previousHost = $previousRun | ?{ $_.vmName -eq $vm.Name } | select -expand Hosts
              IF (($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).Hosts -ne $previousHost) {
                ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).Moved = "x"
                ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).PreviousHost = ($previousRun | ?{ $_.vmName -eq $vm.Name }).Hosts
                $events = Get-VIEvent -MaxSamples 1000 -Entity (get-vm $vm.Name) | sort CreatedTime -desc 
                $HAevent = $events | ?{ $_.FullFormattedMessage -like "*vSphere HA restarted*"} | select -first 1
                $ReloEvent = $events | ?{ $_.FullFormattedMessage -like "*Relocate virtual machine*"} | select -first 1
                IF ($HAevent.CreatedTime -gt $ReloEvent.CreatedTime) {
                  ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).MovedOn = $HAevent.CreatedTime
                  ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).MovedBy = "HA"
                } ELSE {
                  ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).MovedOn = $ReloEvent.CreatedTime
                  ($allClusterInfo | ?{ $_.vmName -eq $vm.Name }).MovedBy = $ReloEvent.UserName                
                }
              }              
            }        
          
          #endregion #>
        }
        #endregion #>
      }
    }
    disconnect-viserver $_ -confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
  }

	### output
    write-host "`n`n############################################## 1st RESULTS ##############################################`n" -foregroundcolor Green
    $allClusterInfo | ft -a -property *
    $allClusterInfo = $allClusterInfo | sort VIServer,ClusterName,vmName
    write-host "`n`n############################################## RESULTS ##############################################`n" -foregroundcolor Green
    $allClusterInfo | ft -a -property *
  ### copy file to report location
    $tempFolder = (get-childitem env:\TEMP).Value
    $outputFile = "$tempFolder\$ScriptName-$Date.csv"
    $allClusterInfo | Export-csv $outputFile -NoTypeInformation
    Copy-Item $outputFile "\\nord\dr\software\vmware\Reports\Landmines"
  ### historical
    $currentVMs = $allClusterInfo | select vmName,clusterName
    #$currentVMs = get-content (get-childitem "\\nord\dr\software\vmware\Reports\Landmines" | ?{ $_.Name -like "Get-AllLandmines-*.csv" -and $_.CreationTime -gt ((get-date).AddDays(-1)) } | sort CreationTime | select -first 1 -expand fullname) | convertfrom-csv
    $old7 = get-content (get-childitem "\\nord\dr\software\vmware\Reports\Landmines" | ?{ $_.Name -like "Get-AllLandmines-*.csv" -and $_.CreationTime -gt ((get-date).AddDays(-8)) } | sort CreationTime | select -first 1 -expand fullname) | convertfrom-csv
    $old7VMs = $old7 | select vmName,clusterName
    $new7 = compare-object $old7VMs $currentVMs | ?{ $_.SideIndicator -eq "=>" }
    $new7VMnames = $new7 | %{"<tr><td>$($_.InputObject.vmName)</td><td>$($_.InputObject.clusterName)</td></tr>"}
    $old7 = compare-object $old7VMs $currentVMs | ?{ $_.SideIndicator -eq "<=" }
    $old7VMnames = $old7 | %{"<tr><td>$($_.InputObject.vmName)</td><td>$($_.InputObject.clusterName)</td></tr>"}
    $old28 = get-content (get-childitem "\\nord\dr\software\vmware\Reports\Landmines" | ?{ $_.Name -like "Get-AllLandmines-*.csv" -and $_.CreationTime -gt ((get-date).AddDays(-29)) } | sort CreationTime | select -first 1 -expand fullname) | convertfrom-csv
    $old28VMs = $old28 | select vmName,clusterName
    $new28 = compare-object $old28VMs $currentVMs | ?{ $_.SideIndicator -eq "=>" }
    $new28VMnames = $new28 | %{"<tr><td>$($_.InputObject.vmName)</td><td>$($_.InputObject.clusterName)</td></tr>"}
    $old28 = compare-object $old28VMs $currentVMs | ?{ $_.SideIndicator -eq "<=" }
    $old28VMnames = $old28 | %{"<tr><td>$($_.InputObject.vmName)</td><td>$($_.InputObject.clusterName)</td></tr>"}
  ### send email
    $html = Get-HtmlHeader -Message "" -Title "Landmine Report" -Image "Nordstrom.png" -ResultCount ($allClusterInfo.Count) 
    
    $allClusterInfo = $allClusterInfo | Sort vmName
    $allClusterInfoByVcenter = $allClusterInfo | Sort VIServer | group VIServer | Select Count, Name | Sort Count -desc | ConvertTo-Html -Fragment
    $allClusterInfoByCluster = $allClusterInfo | Sort ClusterName | group ClusterName | Select Count, Name | Sort Count -desc | Select -first 10 | ConvertTo-Html -Fragment
    $allClusterInfoByHosts = $allClusterInfo | Sort Hosts | group Hosts | Select Count, Name | Sort Count -desc | Select -first 10 | ConvertTo-Html -Fragment
    $allClusterInfoVMDRSsManualCount = ($allClusterInfo | ?{ $_.VMDRSs -eq "manual" }).count
    $allClusterInfoVMDRSsPartiallyAutomatedCount = ($allClusterInfo | ?{ $_.VMDRSs -eq "partiallyAutomated" }).count
    $allClusterInfoSharedScsiBussCount = ($allClusterInfo | ?{ $_.SharedScsiBuss -eq "x" }).count
    $allClusterInfoSharedVMDKsCount = ($allClusterInfo | ?{ $_.SharedVMDKs -eq "x" }).count
    $allClusterInfoRDMsCount = ($allClusterInfo | ?{ $_.RDMs -eq "x" }).count
    
    $NumOfClustersLandmine = ($allClusterInfo | Select -expand ClusterName | Sort | get-unique).count
    $NumOfHostsLandmine = ($allClusterInfo | Select -expand Hosts | Sort | get-unique).count
    $PercentOfLandminesClusters = [int](($NumOfClustersLandmine / $NumOfClustersTotal) * 100)
    $PercentOfLandminesHosts = [int](($NumOfHostsLandmine / $NumOfHostsTotal) * 100)
    $PercentOfLandminesVM = [int]((($allClusterInfo.count) / $NumOfVMs) * 100)
    
    $html += "<table style='border:1px solid black' width='100%'><tr><td valign='top'><table width='100%'><tr>"
    $html += "<td valign='top' style='border-right: 1px solid black; border-bottom: 1px solid black' width='15%'>"
    $html += "<h3>New Landmines</h3><br/><h5>From 7 days - $($new7.count)</h5><table>$new7VMnames</table><br/><h5>From 28 days - $($new28.count)</h5><table>$new28VMnames</table></td>"
    $html += "<td valign='top' style='border-right: 1px solid black; border-bottom: 1px solid black' width='15%'>"
    $html += "<h3>Landmines by vCenter</h3><br/>$allClusterInfoByVcenter</td>"
    $html += "<td valign='top' style='border-right: 1px solid black; border-bottom: 1px solid black' width='15%'>"
    $html += "<h3>Landmines by Cluster (Top 10)</h3><br/>$allClusterInfoByCluster</td>"
    $html += "<td valign='top' style='border-right: 1px solid black; border-bottom: 1px solid black' width='15%''>"
    $html += "<h3>Landmines by Hosts (Top 10)</h3><br/>$allClusterInfoByHosts</td>"
    $html += "<td valign='top' style='border-right: 1px solid black; border-bottom: 1px solid black' width='15%'>"
    $html += "<h3>Landmines by Type</h3>&nbsp;<br/><table><tr><td>DRS manual</td><td>$allClusterInfoVMDRSsManualCount</td></tr>"
    $html += "<tr><td>DRS partially-Automated</td><td>$allClusterInfoVMDRSsPartiallyAutomatedCount</td></tr>"
    $html += "<tr><td>SharedScsiBus</td><td>$allClusterInfoSharedScsiBussCount</td></tr>"
    $html += "<tr><td>SharedVMDKs</td><td>$allClusterInfoSharedVMDKsCount</td></tr>"
    $html += "<tr><td>RDMs</td><td>$allClusterInfoRDMsCount</td></tr></table></td>"
    $html += "<td valign='top' style='border-right: 1px solid black; border-bottom: 1px solid black' width='15%'>"
    $html += "<h3>No Longer Landmines</h3><br/><h5>From 7 days - $($old7.count)</h5><table>$old7VMnames</table><br/><h5>From 28 days - $($old28.count)</h5><table>$old28VMnames</table></td>"
    $html += "</tr></table></tr></table><br/>" 
    $html += "Percent of Clusters with Landmines: $PercentOfLandminesClusters %</br>"
    $html += "Percent of Hosts with Landmines: $PercentOfLandminesHosts %</br>"
    $html += "Percent of VMs with Landmines: $PercentOfLandminesVM %</br>"
    $html += "<br/>"
    
    $html += $allClusterInfo | ConvertTo-Html -Fragment | Set-HtmlTableFormat
    $html += Get-HtmlFooter -Message "This report was generated from A0319P184 by script Get-AllLandmines.ps1"
    IF ([string]::IsNullOrEmpty($email)) { $email = @("$userIDEmail") }
    IF (test-path "$ScriptPath\Nordstrom.png") {
      [string[]]$attachments += "$ScriptPath\Nordstrom.png"
      Send-MailMessage -SmtpServer "exchange.nordstrom.net" -To $email -From "itucg@nordstrom.com" -Subject "Landmine Report" -BodyAsHtml $html -Attachments $attachments
    } ELSE {
      Send-MailMessage -SmtpServer "exchange.nordstrom.net" -To $email -From "itucg@nordstrom.com" -Subject "Landmine Report" -BodyAsHtml $html
    }
#endregion #>
	
#<#region ######################################### Cleanup #################################################
	cleanup
#endregion #>