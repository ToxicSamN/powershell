<#
.SYNOPSIS
    Creates an emailed report showing vSphere cluster capacity levels.
.DESCRIPTION
    This script sends an email report of current vSphere cluster capacity levels for Ram, CPU, and Disk space
	for all clusters in a0319p8k and a0319p363. It is intended as a guide for use in planning the provisioning
	of disk space, purchasing of new blades, and build outs of new hosts and clusters.
	There is currently no option to specify the email address to send it to. This is hard coded in the script.
.EXAMPLE
    C:\PS> Get-UCGClusterCapacityReport.ps1
		Gathers cluster capacity information and sends it through email.
.NOTES
    Author: Sammy Shuck
    Co-Author: Mark Leno
    Create Date:	March 20, 2014
    Last Modified:	July 16th, 2014
#>
#region ######################################### PARAMETERS ###########################################
Param(
	[array]$VIServers,
  [array]$OtherDeployClusters,
  [switch]$testing
)
#endregion
Start-Transcript D:\temp\UcgClusterCapacityReport.log
#region ######################################### FUNCTIONS ############################################
	Function FindArrayInArray($firstArray,$secondArray){
		If (($firstArray | ?{ $secondArray -contains $_ }) -ne $null){ return $true }
		If (($secondArray | ?{ $firstArray -contains $_ }) -ne $null){ return $true }
		return $false
	}
	Function Get-InstallPath {
	#Function provided by VMware used by PowerCLI to initialize Snapins
	# Initialize-PowerCLIEnvironment.ps1
	   $regKeys = Get-ItemProperty "hklm:\software\VMware, Inc.\VMware vSphere PowerCLI" -ErrorAction SilentlyContinue

	   #64bit os fix
	   if($regKeys -eq $null){
	      $regKeys = Get-ItemProperty "hklm:\software\wow6432node\VMware, Inc.\VMware vSphere PowerCLI"  -ErrorAction SilentlyContinue
	   }

	   return $regKeys.InstallPath
	}
	Function LoadSnapins(){
	#Function provided by VMware used by PowerCLI to initialize Snapins
	# Initialize-PowerCLIEnvironment.ps1
	   $snapinList = @( "VMware.VimAutomation.Core", "VMware.VimAutomation.License", "VMware.DeployAutomation", "VMware.ImageBuilder", "VMware.VimAutomation.Cloud")

	   $loaded = Get-PSSnapin -ErrorAction SilentlyContinue | ?{$_.Name -like "*VMware*"} | % {$_.Name}
	   $registered = Get-PSSnapin -Registered -ErrorAction SilentlyContinue  | ?{$_.Name -like "*VMware*" } | % {$_.Name}
	   $notLoaded = $registered | ? {$loaded -notcontains $_}

	   foreach ($snapin in $registered) {
	      if ($loaded -notcontains $snapin) {
	         Add-PSSnapin $snapin -ErrorAction SilentlyContinue
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
	Function LoadModules(){
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
	Function Get-TableHeader($Ncount,$ClusterType){
		$thishtml = "<tr><td style='font-size: 14pt;' colspan='9' rowspan='1' text-align='left' nowrap='nowrap' valign='middle'>$ClusterType Clusters with $NCount Configuration</td></tr>
			<tr><td style='font-size: 8pt;' text-align='left' nowrap='nowrap' valign='middle'>Cluster Name</td>"
		if ($ClusterType -ne "NonDeploy"){
			$thishtml += "<td style='font-size: 8pt;' text-align='left' nowrap='nowrap' valign='middle'>Deploy Cluster<br/>Tag</td>"
		}
		$thishtml += "<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>7 Day<br/>Change</td>
      <td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>VMHosts</td>
      <td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>VMHost<br/>Change</td>
			<td style='font-size: 8pt;width: 40px;' text-align='center' nowrap='nowrap' valign='middle'>vCPU Used with $NCount HA</td>
			<td style='font-size: 8pt;width: 40px;' text-align='center' nowrap='nowrap' valign='middle'>Memory Used with $NCount HA</td>
			<td style='font-size: 8pt;width: 40px;' text-align='center' nowrap='nowrap' valign='middle'>Storage</td>
			<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>$NCount HA Status</td>
		</tr>"
		return $thishtml
	}
	Function Get-TableRow1 ($ClusterType,$ClusterName,$DeployCluster,$PercentChange,$NumberOfVmhost,$NumberOfVmhostIncrease,$boldIt){
		If ($boldIt -eq $true) { $boldStart="<b>"; $boldEnd="</b>"; } else { $boldStart=$null; $boldEnd=$null; }
		$thishtml = "<tr>`n<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>$boldStart $ClusterName $boldEnd</td>`n"
		if ($ClusterType -ne "NonDeploy"){
			$thishtml += "<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>$boldStart $DeployCluster $boldEnd</td>`n"
		}
		$thishtml += "<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>$boldStart $PercentChange $boldEnd</td>`n"
		$thishtml += "<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>$boldStart $NumberOfVmhost $boldEnd</td>`n"
		$thishtml += "<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>$boldStart $NumberOfVmhostIncrease $boldEnd</td>`n"
		return $thishtml
	}
	Function Get-TableRow2 ($thisPercent,$thisValue) {
		$boldStart = $null; $boldEnd = $null;
		$thishtml = "<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>`n
					<table style='width: 100%;' border='0' cellpadding='0' cellspacing='0'>`n
						<tr>`n
							<td style='width: 60%;'>`n
								<table style='width: 100%;border-top: 1px solid black;border-bottom: 1px solid black;border-left: 1px solid black;border-right: 1px solid black;' cellspacing='0' cellpadding='0'>`n
									<tr>`n"
		$thisPercentInt = ($thisPercent.Replace("%","")/10 -as [int])
		$thisValueFormated = [string]$($thisValue / 1024).tostring(" 00 ")
		if ([string]::IsNullOrEmpty($thisValue)){ $thisValueInt = $null } else { $thisValueInt = "(" + $thisValueFormated + "TB free)" }
		If ($thisPercentInt -lt 1){ $thisPercentInt = $thisPercentInt + 1 }
		1..10 | %{
			If ($_ -lt 5){ $bgcolor = "green" } elseif ($_ -ge 5 -and $_ -le 6) { $bgcolor = "yellow" } elseif ($_ -eq 7) { $bgcolor = "orange" } elseif ($_ -gt 7) { $bgcolor = "red" }
			If ($_ -gt $thisPercentInt){ $bgcolor = $null }
			If ($_ -lt 11) { $thishtml += "<td width='5' height='10' style='font-size: 8pt; background-color: $bgcolor;'></td>`n" }
		}
		$spaces = "&nbsp&nbsp&nbsp&nbsp&nbsp"
		If(($thisPercent.Replace("%","") -as [int]) -lt 10 -and ($mem.Replace("%","") -as [int]) -ge 10){ $spaces = "&nbsp&nbsp&nbsp"; $thisPercent = "<font color='#FFFFFF'>0</font>$($thisPercent)" }
		$thishtml += "					</tr>`n
								</table>`n
							</td>
							<td colspan='10' rowspan='1' text-align='center' valign='middle' nowrap='nowrap' style='width: 20%;font-size: 8pt;'>$($spaces)$boldStart $($thisPercent) $boldEnd</td>
							<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle' >$($spaces)$boldStart $thisValueInt $boldEnd</td>`n
						</tr>`n
					</table></td>`n"
		return $thishtml
	}
  Function Get-TableStopLights ($htmlTemp,$env='deploy') {
    If ($env -like 'deploy'){
        $greenLimit = 60
        $yellowLimit = 70
        $orangelimit = 80
    } elseif ($env -like 'nondeploy') {
        $greenLimit = 85
        $yellowLimit = 87
        $orangelimit = 90   
    }
    $column = 0
    $greencirclehtml = "<span style='width:1%; padding:0px 0px; margin:0 auto; border:1px solid #a1a1a1; border-radius:5px; background-color:green;'>&nbsp;</span>"
    $yellowcirclehtml = "<span style='width:1%; padding:0px 0px; margin:0 auto; border:1px solid #a1a1a1; border-radius:5px; background-color:yellow;'>&nbsp;</span>"
    $orangecirclehtml = "<span style='width:1%; padding:0px 0px; margin:0 auto; border:1px solid #a1a1a1; border-radius:5px; background-color:orange;'>&nbsp;</span>"
    $redcirclehtml = "<span style='width:1%; padding:0px 0px; margin:0 auto; border:1px solid #a1a1a1; border-radius:5px; background-color:red;'>&nbsp;</span>"
    #write-host "Column's 5, 6, 8, 10 and 11"
    $htmlnew = ""
    #write-host $htmlTemp
    $htmlTemp = $htmlTemp.replace("`r`n","")
    $htmlTemp -split("<td>") | %{
      $newColVal = $null;
      #write-host "Current Column is $column" -foregroundcolor green
      #write-host "Current column value is: $_"
      If ($_ -like "*</td>*") {
        If ($column -eq 0) { # Cluster Column
          $newColVal = "<td width='9%'> $_"
          $column++
        } elseif ($column -eq 1) { # vCommander Deployment Destination
          $newColVal = "<td align='center' width='20%'> $_"
          $column++
        } elseif ($column -ge 2 -and $column -le 10) { # 
          $newColVal = "<td align='center' width='6%'> $_"
          $column++
        } elseif (($column -ge 11 -and $column -le 13)) {
          try {
            $columnValue = [int]$_.SubString(0,$_.IndexOf("%"))
            #write-host "columnValue is: $columnValue"
            If ($columnValue -lt $greenLimit) { $newColVal = "<td>$greencirclehtml $_" }
            If ($columnValue -ge $greenLimit -and $columnValue -lt $yellowLimit) { $newColVal = "<td>$yellowcirclehtml $_" }
            If ($columnValue -ge $yellowLimit -and $columnValue -lt $orangelimit) { $newColVal = "<td>$orangecirclehtml $_" }
            If ($columnValue -ge $orangelimit) { $newColVal = "<td>$redcirclehtml $_" }
          } catch { $newColVal = "$_" }
          $column++
        } else {
          $newColVal = "<td width='5%' align='center'>$_"
          $column++
          If ($column -eq 19) { $column = 0 } #this is either going to be 13, 14 or 15 depending on wether or not the datadate column is passed.
        }
      } else {
        $newColVal = "$_"
      }
      #write-host "New column value is: $newColVal" -foregroundcolor yellow
      $htmlnew += $newColVal
    }
    #write-host $htmlnew
    return $htmlnew | out-string
  }
	Function Get-AllHTML ($Cluster,$ClusterType){
    $thishtml = "<table style='font-family: Arial; font-size: 8pt; width: 100%; text-align: center; margin-left: auto; margin-right: auto;' border='1' cellpadding='1' cellspacing='1'>"
    2..1 | %{
      $NCount = "N+$($_)"
      $thishtml += Get-TableHeader $NCount $ClusterType
      $Cluster | Sort ClusterName | %{
        $thisObj = $_
        if ($NCount -eq "N+1"){
          $cpu=$thisObj."UsedCpu_N+1"; $mem=($thisObj."UsedMemory_N+1"); $stat=$thisObj."Status_N+1";
        } else {
          $cpu=$thisObj."UsedCpu_N+2"; $mem=($thisObj."UsedMemory_N+2"); $stat=$thisObj."Status_N+2";
        }
        $disk=$thisObj.UsedStorage
        if ($stat -eq "Cluster OK" -or $stat -like "WARNING:*"){
          $boldStart=$null; $boldEnd=$null; $boldIt = $false;
        } else {
          $boldStart="<b>"; $boldEnd="</b>"; $boldIt = $true;
        }
        $spaces = "&nbsp&nbsp&nbsp"
        $thishtml += Get-TableRow1 $ClusterType $($thisObj.ClusterName) $($thisObj.DeployCluster) $($thisObj.PercentChange) $($thisObj.NumberOfVmhost) $($thisObj.NumberOfVmhostIncrease) $boldIt
        $thishtml += Get-TableRow2 $cpu
        $thishtml += Get-TableRow2 $mem
        $thishtml += Get-TableRow2 $([string]$(($disk.Replace('%','') -as [int]) + 20) + "%") $thisObj.FreeStorage
        $thishtml += "<td style='font-size: 8pt;' text-align='center' nowrap='nowrap' valign='middle'>$boldStart $($stat) $boldEnd</td></tr>"
      }
      $thishtml += "<tr><td colspan='7' 'style=border:0px;'>&nbsp</td></tr>"
    }
    $thishtml += "</table><br>"
    return $thishtml
  }
#endregion
#region ######################################### Variables and Constants ##############################
	[HashTable]$rawData = @{}
	[HashTable]$Clusters = @{}
	[array]$SortDates = @()
	$path = "\\nord\dr\Software\VMware\Reports\ClusterCapacity"
	$children = dir $path | ?{$_.Name.StartsWith("ClusterCapacity")} | Sort CreationTime
#endregion
#region ######################################### Logging ##############################################
	$ScriptName = ($MyInvocation.MyCommand).Name
	$ScriptName = $ScriptName.SubString(0,$scriptname.indexof("."))
	$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
	$Date = Get-Date -format 'yyyyMMddHHmmss'
  $rundate = get-date -format M_d_yyyy
	$userID = get-content env:username
	#Start-Transcript -path "$ScriptPath\$Date-$ScriptName.log" -append
#endregion
#region ######################################### Other Prep ###########################################
  #CLS
	Import-Module UcgModule -WarningAction SilentlyContinue -Arg vmware,cisco | out-null
	[Reflection.Assembly]::LoadWithPartialName("System.Security") | out-null
  Get-Date
#endregion
#region ######################################### MAIN #################################################
  #region Get Current Deploy Cluster Information
  $deployClusters = get-content "\\nord\dr\software\vmware\software\vCommander\vCommanderDeployClusterReport.csv" | ConvertFrom-CSV
  $deployClustersNames = get-content "\\nord\dr\software\vmware\software\vCommander\vCommanderDeployClusterReport.csv" | ConvertFrom-CSV | ?{ $_.ClusterName -ne $null } | select -expand ClusterName
  $deployClustersNamesNoDeploy = get-content "\\nord\dr\software\vmware\software\vCommander\vCommanderDeployClusterReport.csv" | ConvertFrom-CSV | ?{ $_.ClusterName -ne $null } | select -expand ClusterName | %{ $_.replace("_deploy","") }
	#endregion

  #region Get Current Cluster Data
    $clusterReportHistory = Get-Content "$path\ClusterCapacity.csv" | ConvertFrom-CSV
    If ([string]::IsNullOrEmpty($VIServers)) { $VIServers = import-csv \\nord\dr\Software\VMware\Reports\vcenterlist.txt | ?{ $_.Type -ne "Store" -and $_.Type -ne "Lab" } | Select -expand Name }
    [array]$todayClusters = @()
		$VIServers | %{ $vc = $_; $vc
			$vi = $null
			$vi=Connect-VIServer -Server $vc -cred (login-vcenter) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
			If(-not [string]::IsNullOrEmpty($vi)){
				$allClusters = Get-View -ViewType ClusterComputeResource | Sort Name
				$allClusters | %{ $cl = $_; $cl.Name
					[int]$memTotal = 0
					[int]$memUsage = 0
          [int]$memCommit = 0
					[int]$cpuCores = 0
					[int]$vcpuUsage = 0
					[int]$hostCount = 0
          [int]$hostCountMM = 0
          [int]$vmCount = 0
					[float]$vmStorageTotal = 0
					[float]$clusterTotalStorage = 0
					$cl.Datastore | %{ Get-View -Id $_ | ?{ $_.summary.MaintenanceMode -eq 'normal' } | %{ [float]$clusterTotalStorage += ($_.Summary.Capacity -as [float])/1073741824 } }
					$vms = @()
          Get-View -ViewType HostSystem -SearchRoot $cl.MoRef | %{ $esxi = $_
            If ( -not $_.summary.runtime.InMaintenanceMode ){
              $hostCount = $hostCount + 1
              [int]$memTotal += (($esxi.Hardware.MemorySize/1024)/1024)
              [int]$memUsage += $esxi.Summary.QuickStats.overallMemoryUsage
              [int]$cpuCores += $esxi.Hardware.CpuInfo.NumCpuCores
              Get-View -ViewType VirtualMachine -SearchRoot $esxi.MoRef -filter @{'summary.runtime.powerstate'="PoweredOn"} | %{
                $vmCount = $vmCount + 1
                $vms += $_
                [int]$vcpuUsage += $_.Config.Hardware.NumCPU
                [int]$vcpuUsage += $_.Config.Hardware.NumCoresPerSocket
                [int]$memCommit += $_.Config.Hardware.MemoryMB              
                $_.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualDisk]} | ?{$($_.Backing.GetType()).Name -notlike "VirtualDiskRawDiskMapping*"} | %{ 
                  [float]$vmStorageTotal += ($_.CapacityInKB -as [float])/1048576 
                }
              }
            } elseif ( $_.summary.runtime.InMaintenanceMode -eq "True" ) {
              $hostCountMM += 1
            }
					}
          #region ### OverCommit math
            #HA Percent/Factors
              $totalHostCount = $cl.Host.Count
            #Usable Resources
              $cpuOverCommit_factor = 10
            #VM Usage
              $vmUsedCPU = [Math]::Ceiling(($vms.Config.Hardware.numCpu | Measure-Object -Sum).Sum)
              $vmUsedMemGB = [Math]::Ceiling(($vms.Config.Hardware.MemoryMB | Measure-Object -Sum).Sum/1024)
            If ($totalHostCount -le 4){
              #HA Percent/Factors N+1
                $n1_percent = [Math]::Ceiling((1/$totalHostCount)*100)
                $n1_factor = $n1_percent/100
              #Usable Resources
                $n1_real_Cpu = [Math]::Floor($cl.Summary.NumCpuCores - ($cl.Summary.NumCpuCores*$n1_factor))
                $n1_usableCPU = ([Math]::Floor($cl.Summary.NumCpuCores - ($cl.Summary.NumCpuCores*$n1_factor))*$cpuOverCommit_factor)
                $n1_usableMemGB = [Math]::Floor(($cl.Summary.TotalMemory - ($cl.Summary.TotalMemory*$n1_factor))/1073741824)
              #Calculate Actual Overcommitment
                $n1_actual_CPU_oc = $vmUsedCPU/$n1_real_Cpu
                $n1_actual_Mem_oc = $vmUsedMemGB/$n1_usableMemGB
                $cpuUsed_percent = [Math]::Ceiling(($vmUsedCPU/$n1_usableCPU)*100)
                $memUsed_percent = [Math]::Ceiling(($vmUsedMemGB/$n1_usableMemGB)*100)
              #conclusions
                $usableCPU = $n1_usableCPU
                $usableMemGB = $n1_usableMemGB
                $actual_CPU_oc = $n1_actual_CPU_oc
                $actual_Mem_oc = $n1_actual_Mem_oc
            } else {
              #HA Percent/Factors N+2
                $n2_percent = [Math]::Ceiling((2/$totalHostCount)*100)
                $n2_factor = $n2_percent/100
              #Usable Resources
                $n2_real_Cpu = [Math]::Floor($cl.Summary.NumCpuCores - ($cl.Summary.NumCpuCores*$n2_factor))
                $n2_usableCPU = ([Math]::Floor($cl.Summary.NumCpuCores - ($cl.Summary.NumCpuCores*$n2_factor))*$cpuOverCommit_factor)
                $n2_usableMemGB = [Math]::Floor(($cl.Summary.TotalMemory - ($cl.Summary.TotalMemory*$n2_factor))/1073741824)
                $cpuUsed_percent = [Math]::Ceiling(($vmUsedCPU/$n2_usableCPU)*100)
                $memUsed_percent = [Math]::Ceiling(($vmUsedMemGB/$n2_usableMemGB)*100)
              #Calculate Actual Overcommitment
                $n2_actual_CPU_oc = $vmUsedCPU/$n2_real_Cpu
                $n2_actual_Mem_oc = $vmUsedMemGB/$n2_usableMemGB
              #conclusions
                $usableCPU = $n2_usableCPU
                $usableMemGB = $n2_usableMemGB
                $actual_CPU_oc = $n2_actual_CPU_oc
                $actual_Mem_oc = $n2_actual_Mem_oc
            }
          #endregion
          If ($vmUsedCPU -gt 0) { $cpuOvercommit = $actual_CPU_oc } else { $cpuOverCommit = 0 }
          If ($vmUsedMemGB -gt 0) { $memOvercommit = $actual_Mem_oc } else { $memOvercommit = 0 }
					#$pso = New-Object -TypeName PSObject -Property @{ClusterName=$cl.Name;MemTotal=$memTotal;MemUsed=$memUsage;CPUTotal=($cpuCores*10);CPUUsed=$vcpuUsage;TotalStorageCapacity=$clusterTotalStorage;UsedStorage=$vmStorageTotal;NumHosts=$hostCount;DeployCluster=(Get-Cluster -Id $cl.MoRef | Get-Annotation -CustomAttribute "DeployCluster" -erroraction silentlycontinue).Value }
          $pso = New-Object -TypeName PSObject -Property @{ClusterName=$cl.Name;MemTotal=$memTotal;MemUsed=$memUsage;CPUTotal=($cpuCores*10);CPUUsed=$vcpuUsage;`
                                                            TotalStorageCapacity=$clusterTotalStorage;UsedStorage=$vmStorageTotal;NumHosts=$hostCount;`
                                                            NumHostsInMM=$hostCountMM;DeployCluster=$null;NumVMs=$vmCount;cpuOC=$cpuOvercommit;memOC=$memOvercommit}
					If ($deployClustersNames -contains $($cl.Name) -or $deployClustersNamesNoDeploy -contains $($cl.Name)) {
            $deployDestinations = $deployClusters | ?{ $_.ClusterName -like "$(($cl.Name).replace('_deploy',''))*" } | select -expand name
            #$pso.DeployCluster = "$($pso.DeployCluster) `n$($deployDestinations -join ', ')"
            $pso.DeployCluster = "$($deployDestinations -join ', ')"
          }
          [array]$todayClusters += $pso
				}
				Disconnect-VIServer -Server $vc -Confirm:$false -Force:$true -ErrorAction SilentlyContinue
			}
		}
	#endregion

	#region Analyze Current Cluster status
		[array]$clusterReport = @()
		$todayClusters | ?{($_.NumHosts -as [int]) -gt 0} | %{
			$cl = $_
			#lets do math :)
			[int]$percentHA_N1 = ((100/($cl.NumHosts -as [int]))*1)
			[int]$percentHA_N2 = ((100/($cl.NumHosts -as [int]))*2)
			[int]$usedStoragePercent = (($cl.UsedStorage/$cl.TotalStorageCapacity)*100)
			If($percentHA_N1 -eq 100){
				[int]$percentCpu_N1 = (($cl.CPUUsed -as [int])/($cl.CPUTotal -as [int])*100)+100
				[int]$percentMem_N1 = ((($cl.MemUsed -as [double])/1024)/(($cl.MemTotal -as [double])/1024)*100)+100
			}Else{
				[int]$percentCpu_N1 = (($cl.CPUUsed -as [int])/(($cl.CPUTotal -as [int]) * ((100-$percentHA_N1)/100))*100)
				[int]$percentMem_N1 = ((($cl.MemUsed -as [double])/1024)/((($cl.MemTotal -as [double])/1024) * ((100-$percentHA_N1)/100))*100)
			}
			If($percentHA_N2 -eq 100){
				[int]$percentCpu_N2 = (($cl.CPUUsed -as [int])/($cl.CPUTotal -as [int])*100)+100
				[int]$percentMem_N2 = ((($cl.MemUsed -as [double])/1024)/(($cl.MemTotal -as [double])/1024)*100)+100
			}Else{
				[int]$percentCpu_N2 = (($cl.CPUUsed -as [int])/(($cl.CPUTotal -as [int]) * ((100-$percentHA_N2)/100))*100)
				[int]$percentMem_N2 = ((($cl.MemUsed -as [double])/1024)/((($cl.MemTotal -as [double])/1024) * ((100-$percentHA_N2)/100))*100)
			}
			$pso="" | Select ClusterName,DeployCluster,PercentChange28d,PercentChange7d,NumberOfVmhost,NumberOfVmhostInMM,NumberOfVmhostIncrease28d,`
                        NumberOfVmhostIncrease7d,UsedCpu,UsedMem,Status,"UsedCpu_N+1","UsedCpu_N+2",N2_CPU_7d_Chg,"UsedMemory_N+1",`
                        "UsedMemory_N+2",N2_MEM_7d_Chg,UsedStorage,FreeStorage,"Status_N+1","Status_N+2",vmDensity,cpuOC,memOC,nPlus
      $pso.vmDensity = "{0:n2}" -f (($cl.NumVMs) / ($cl.NumHosts))
      $pso.cpuOC = "{0:n2}" -f $cl.cpuOC
      $pso.memOC = "{0:n2}" -f $cl.memOC
			$pso.ClusterName = $cl.ClusterName
			if ($OtherDeployClusters -contains $($cl.ClusterName)) { $pso.DeployCluster = "-" } else { $pso.DeployCluster = $cl.DeployCluster }
      #<#region ################################### A 7 day history ###################################
        $sevenDaysAgo = ((Get-Date).AddDays(-7)).ToShortDateString()
        $tempClusterName = $cl.ClusterName.replace("_deploy","")
        $clusterHistory_7d = $clusterReportHistory | ?{ $_.ClusterName -like "$tempClusterName*" -and $_.DataDate -like "$sevenDaysAgo*"} | select -first 1
        $cluster_PercentIncrease_7d = $null
        $numberOfVmhostChange_7d = $null
        If (-not [string]::IsNullOrEmpty($clusterHistory_7d)) {
          if ($percentCpu_N2 -ne 0) {
            $usedCpu_PercentIncrease_7d = ($percentCpu_N2) - [int]($clusterHistory_7d."UsedCpu_N+2".replace("%",""))
            If ($usedCpu_PercentIncrease_7d -ne $null) {
              If ($usedCpu_PercentIncrease_7d -eq 0){
                $pso.N2_CPU_7d_Chg = $null
              } else {
                $pso.N2_CPU_7d_Chg = (($usedCpu_PercentIncrease_7d -as [string])+"%")
              }
            }
          } else { $usedCpu_PercentIncrease_7d = 0 }
          if ($percentMem_N2 -ne 0) {
            $usedMemory_PercentIncrease_7d = ($percentMem_N2) - [int]($clusterHistory_7d."UsedMemory_N+2".replace("%",""))
            If ($usedMemory_PercentIncrease_7d -ne $null) {
              If ($usedMemory_PercentIncrease_7d -eq 0){
                $pso.N2_MEM_7d_Chg = $null
              } else {
                $pso.N2_MEM_7d_Chg = (($usedMemory_PercentIncrease_7d -as [string])+"%")
              }
            }
          } else { $usedMemory_PercentIncrease_7d = 0 }
          if ($usedStoragePercent -ne 0) {
            $usedStorage_PercentIncrease_7d = $usedStoragePercent - [int]($clusterHistory_7d.UsedStorage.replace("%",""))
          } else { $usedStorage_PercentIncrease_7d = 0 }
          $cluster_PercentIncrease_7d = ($usedCpu_PercentIncrease_7d + $usedMemory_PercentIncrease_7d + $usedStorage_PercentIncrease_7d)
          #write-host "$($cl.ClusterName) vs $($clusterHistory_7d.ClusterName) - 7 days ago"
          #write-host "`tclusterHistory CPU: `t$($clusterHistory_7d.'UsedCpu_N+2')"
          #write-host "`tClusterCurrent CPU: `t$percentCpu_N2"
          #write-host "`tClusterHistory MEM: `t$($clusterHistory_7d.'UsedMemory_N+2')"
          #write-host "`tClusterCurrent MEM: `t$percentMem_N2"
          #write-host "`tClusterHistory DSK: `t$($clusterHistory_7d.UsedStorage)"
          #write-host "`tClusterCurrent DSK: `t$usedStoragePercent"
          #write-host "`t$cluster_PercentIncrease_7d = ($usedCpu_PercentIncrease_7d + $usedMemory_PercentIncrease_7d + $usedStorage_PercentIncrease_7d)"
          $numberOfVmhostChange_7d = $cl.NumHosts - [int]($clusterHistory_7d.NumberOfVmhost.replace("%",""))
        }
        If ($cluster_PercentIncrease_7d -ne $null) {
          If ($cluster_PercentIncrease_7d -eq 0){
            $pso.PercentChange7d = $null
          } else {
            $pso.PercentChange7d = "$([string]$cluster_PercentIncrease_7d)%"
          }
        }
        If ($numberOfVmhostChange_7d -ne $null) {
          If ($numberOfVmhostChange_7d -eq 0){
            $numberOfVmhostIncreased_7d = $null
          } else {
            $numberOfVmhostIncreased_7d = "$numberOfVmhostChange_7d"
          }
        }
      #endregion #>
      #<#region ################################### A 28 day history ###################################
        $twentyEightDaysAgo = ((Get-Date).AddDays(-28)).ToShortDateString()
        $tempClusterName = $cl.ClusterName.replace("_deploy","")
        $clusterHistory_28d = $clusterReportHistory | ?{ $_.ClusterName -like "$tempClusterName*" -and $_.DataDate -like "$twentyEightDaysAgo*"} | select -first 1
        $cluster_PercentIncrease_28d = $null
        $numberOfVmhostChange_28d = $null
        If (-not [string]::IsNullOrEmpty($clusterHistory_28d)) {
          if ($percentCpu_N2 -ne 0) {
            $usedCpu_PercentIncrease_28d = ($percentCpu_N2) - [int]($clusterHistory_28d."UsedCpu_N+2".replace("%",""))
          } else { $usedCpu_PercentIncrease_28d = 0 }
          if ($percentMem_N2 -ne 0) {
            $usedMemory_PercentIncrease_28d = ($percentMem_N2) - [int]($clusterHistory_28d."UsedMemory_N+2".replace("%",""))
          } else { $usedMemory_PercentIncrease_28d = 0 }
          if ($usedStoragePercent -ne 0) {
            $usedStorage_PercentIncrease_28d = $usedStoragePercent - [int]($clusterHistory_28d.UsedStorage.replace("%",""))
          } else { $usedStorage_PercentIncrease_28d = 0 }
          $cluster_PercentIncrease_28d = ($usedCpu_PercentIncrease_28d + $usedMemory_PercentIncrease_28d + $usedStorage_PercentIncrease_28d)
          #write-host "$($cl.ClusterName) vs $($clusterHistory_28d.ClusterName)"
          #write-host "`tclusterHistory CPU: `t$($clusterHistory_28d.'UsedCpu_N+2')"
          #write-host "`tClusterCurrent CPU: `t$percentCpu_N2"
          #write-host "`tClusterHistory MEM: `t$($clusterHistory_28d.'UsedMemory_N+2')"
          #write-host "`tClusterCurrent MEM: `t$percentMem_N2"
          #write-host "`tClusterHistory DSK: `t$($clusterHistory_28d.UsedStorage)"
          #write-host "`tClusterCurrent DSK: `t$usedStoragePercent"
          #write-host "`t$cluster_PercentIncrease_28d = ($usedCpu_PercentIncrease_28d + $usedMemory_PercentIncrease_28d + $usedStorage_PercentIncrease_28d)"
          $numberOfVmhostChange_28d = $cl.NumHosts - [int]($clusterHistory_28d.NumberOfVmhost.replace("%",""))
        }
        If ($cluster_PercentIncrease_28d -ne $null) {
          If ($cluster_PercentIncrease_28d -eq 0){
            $pso.PercentChange28d = $null
          } else {
            $pso.PercentChange28d = "$([string]$cluster_PercentIncrease_28d)%"
          }
        }
        If ($numberOfVmhostChange_28d -ne $null) {
          If ($numberOfVmhostChange_28d -eq 0){
            $numberOfVmhostIncreased_28d = $null
          } else {
            $numberOfVmhostIncreased_28d = "$numberOfVmhostChange_28d"
          }
        }
      #endregion #>
      $pso.NumberOfVmhost = "$($cl.NumHosts)"
      If ($cl.NumHostsInMM -eq 0){ $pso.NumberOfVmhostInMM = $null } else { $pso.NumberOfVmhostInMM = "$($cl.NumHostsInMM)" }
      $pso.NumberOfVmhostIncrease7d = $numberOfVmhostIncreased_7d
      $pso.NumberOfVmhostIncrease28d = $numberOfVmhostIncreased_28d
			$pso."UsedCpu_N+1" = (($percentCpu_N1 -as [string])+"%")
			$pso."UsedCpu_N+2" = (($percentCpu_N2 -as [string])+"%")
			$pso."UsedMemory_N+1" = (($percentMem_N1 -as [string])+"%")
			$pso."UsedMemory_N+2" = (($percentMem_N2 -as [string])+"%")
			$pso.UsedStorage = (($usedStoragePercent -as [string])+"%")
			$pso.FreeStorage = ($cl.TotalStorageCapacity * ((100 - ($usedStoragePercent + 20))/100))
      #Storage Message
      If($usedStoragePercent -ge 70 -and $($cl.ClusterName) -notlike "*NTNX*" -and $($cl.ClusterName) -notlike "*emg*"){
        $storageMessage = ", Increase Storage" 
      } else { 
        $storageMessage = $null
      }
      If (-not [string]::IsNullOrEmpty($cl.DeployCluster)){
        #N+1
          If($percentCpu_N1 -lt 50 -and $percentMem_N1 -lt 50){ $statusLevel = "Cluster OK" }
          If($percentCpu_N1 -ge 50 -or $percentMem_N1 -ge 50){ $statusLevel = "Warning" }
          If($percentCpu_N1 -ge 60 -or $percentMem_N1 -ge 60){ $statusLevel = "Minor" }
          If($percentCpu_N1 -ge 70 -or $percentMem_N1 -ge 70){ $statusLevel = "Major" }
          If($percentCpu_N1 -ge 79 -or $percentMem_N1 -ge 79){ $statusLevel = "CRITICAL" }
          If ($statusLevel -like "CRITICAL*"){ $criticalMessage = ", Use Standby" } else { $criticalMessage = $null }
          $pso."Status_N+1" = "$statusLevel$criticalMessage$storageMessage"
        #N+2
          If($percentCpu_N2 -lt 50 -and $percentMem_N2 -lt 50){ $statusLevel = "Cluster OK" }
          If($percentCpu_N2 -ge 50 -or $percentMem_N2 -ge 50){ $statusLevel = "Warning" }
          If($percentCpu_N2 -ge 60 -or $percentMem_N2 -ge 60){ $statusLevel = "Minor" }
          If($percentCpu_N2 -ge 70 -or $percentMem_N2 -ge 70){ $statusLevel = "Major" }
          If($percentCpu_N2 -ge 79 -or $percentMem_N2 -ge 79){ $statusLevel = "CRITICAL" }
          If ($statusLevel -like "CRITICAL*"){ $criticalMessage = ", Use Standby" } else { $criticalMessage = $null }
          $pso."Status_N+2" = "$statusLevel$criticalMessage$storageMessage"
      } else {
        #N+1
          If($percentCpu_N1 -lt 80 -and $percentMem_N1 -lt 80){ $statusLevel = "Cluster OK" }
          If($percentCpu_N1 -ge 82 -or $percentMem_N1 -ge 82){ $statusLevel = "Warning" }
          If($percentCpu_N1 -ge 85 -or $percentMem_N1 -ge 85){ $statusLevel = "Minor" }
          If($percentCpu_N1 -ge 87 -or $percentMem_N1 -ge 87){ $statusLevel = "Major" }
          If($percentCpu_N1 -ge 90 -or $percentMem_N1 -ge 90){ $statusLevel = "CRITICAL" }
          $pso."Status_N+1" = "$statusLevel$storageMessage"
        #N+2
          If($percentCpu_N2 -lt 75 -and $percentMem_N2 -lt 80){ $statusLevel = "Cluster OK" }
          If($percentCpu_N2 -ge 80 -or $percentMem_N2 -ge 82){ $statusLevel = "Warning" }
          If($percentCpu_N2 -ge 85 -or $percentMem_N2 -ge 85){ $statusLevel = "Minor" }
          If($percentCpu_N2 -ge 90 -or $percentMem_N2 -ge 87){ $statusLevel = "Major" }
          If($percentCpu_N2 -ge 95 -or $percentMem_N2 -ge 90){ $statusLevel = "CRITICAL" }
          $pso."Status_N+2" = "$statusLevel$storageMessage"      
      }
      #Use the right states for the cluster HA size (n+1 vs n+2)
        If (([int]($pso.NumberOfVmhost)) -gt 4 -and $pso.ClusterName -notlike "*sql*" -and $pso.ClusterName -notlike "*ora*"){
          $pso.UsedCpu = $pso."UsedCpu_N+2"
          $pso.UsedMem = $pso."UsedMemory_N+2"
          $pso.Status = $pso."Status_N+2"
          $pso.nPlus = "2"
        } else {
          $pso.UsedCpu = $pso."UsedCpu_N+1"
          $pso.UsedMem = $pso."UsedMemory_N+1"
          $pso.Status = $pso."Status_N+1"
          $pso.nPlus = "1"        
        }
			[array]$clusterReport += $pso
		}
	#endregion

	$clusterReport | Sort DeployCluster,ClusterName -Descending | Export-Csv "D:\SplunkData\ClusterComputeReport\ClusterComputeReport.csv" -NoTypeInformation
  $clusterReportHistoryNew = $clusterReport
  $clusterReportHistoryNew | ft * -a
  $clusterReportHistoryNew | Add-Member DataDate $(Get-Date)
  $clusterReportHistoryNew | Add-Member -MemberType NoteProperty -Name DayOfWeek -value $(get-date -Uformat %u)
  $clusterReportHistoryNew | Sort DeployCluster,ClusterName -Descending | Export-Csv "$path\ClusterCapacity.csv" -Append -NoTypeInformation

	#region Create HTML Tables
    write-host "Emailing Report" -foregroundcolor green
    $clusterReport = $clusterReport | select @{n='Cluster';e={$_.ClusterName}},@{n='vCommander Deployment Destination';e={$_.DeployCluster}},@{n='Overall Chg 28d';e={$_.PercentChange28d}},`
                                          @{n='Overall Chg 7d';e={$_.PercentChange7d}},@{n='Vmhosts';e={$_.NumberOfVmhost}},@{n='Vmhosts In MM';e={$_.NumberOfVmhostInMM}},`
                                          @{n='Host Chg 28d';e={$_.NumberOfVmhostIncrease28d}},@{n='Host Chg 7d';e={$_.NumberOfVmhostIncrease7d}},@{n='CPU Chg';e={$_.'N2_CPU_7d_Chg'}},`
                                          @{n='MEM Chg';e={$_.'N2_MEM_7d_Chg'}},nPlus,@{n='CPU';e={$_.UsedCpu}},@{n='MEM';e={$_.UsedMem}},@{n='DSK Used';e={$_.UsedStorage}},`
                                          @{n='DSK Free';e={"$([int]($_.FreeStorage/1024)) TB"}},@{n='Status';e={$_.Status}},vmDensity,cpuOC,memOC | Sort Cluster
    $tempReport = $clusterReport | Select Cluster,vmDensity,cpuOC,memOC
    $tempReport | ft -a
    # windows summary
    $vmDensityWin = "{0:n2}" -f (($tempReport | ?{ ($_.Cluster -like "*win*" -or $_.Cluster -like "*ntnxt001*") -and $_.vmDensity -ne 0 } | select -expand vmDensity | measure -average).average)
    $cpuOCWin = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*win*" -or $_.Cluster -like "*ntnxt001*" } | select -expand cpuOC | measure -average).average)
    $memOCWin = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*win*" -or $_.Cluster -like "*ntnxt001*" } | select -expand memOC | measure -average).average)
    # linux summary
    $vmDensityLin = "{0:n2}" -f (($tempReport | ?{ ($_.Cluster -like "*lin*" -or $_.Cluster -like "*ntnxt002*") -and $_.vmDensity -ne 0 } | select -expand vmDensity | measure -average).average)
    $cpuOCLin = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*lin*" -or $_.Cluster -like "*ntnxt002*" } | select -expand cpuOC | measure -average).average)
    $memOCLin = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*lin*" -or $_.Cluster -like "*ntnxt002*"} | select -expand memOC | measure -average).average)
    # sql summary
    $vmDensitySql = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*sql*" -and $_.vmDensity -ne 0 } | select -expand vmDensity | measure -average).average)
    $cpuOCSql = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*sql*" } | select -expand cpuOC | measure -average).average)
    $memOCSql = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*sql*" } | select -expand memOC | measure -average).average)
    # ora summary
    $vmDensityOra = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*ora*" -and $_.vmDensity -ne 0 } | select -expand vmDensity | measure -average).average)
    $cpuOCOra = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*ora*" } | select -expand cpuOC | measure -average).average)
    $memOCOra = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*ora*" } | select -expand memOC | measure -average).average)   
    # www summary
    $vmDensitywww = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*www*" -and $_.vmDensity -ne 0 } | select -expand vmDensity | measure -average).average)
    $cpuOCwww = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*www*" } | select -expand cpuOC | measure -average).average)
    $memOCwww = "{0:n2}" -f (($tempReport | ?{ $_.Cluster -like "*www*" } | select -expand memOC | measure -average).average)       
    # special purpose tables
    # get-content "\\nord\dr\software\vmware\Reports\ClusterCapacity\ClusterCapacity.csv" | convertfrom-csv | select -last 1 | fl
    # $clusterReport = get-content "\\nord\dr\software\vmware\Reports\ClusterCapacity\ClusterCapacity.csv" | convertfrom-csv | ?{ $_.DataDate -eq "8/8/2017 5:30"}
    $top10Movers = $clusterReport | ?{[string]::IsNullOrEmpty($_.'Overall Chg 7d') -ne $true} | sort @{e={[math]::ABS([int]$_.'Overall Chg 7d'.replace("%",""))};Descending=$true} | select -first 10
    $top10Movers = $top10Movers | select * -exclude 'UsedCpu_N+1','UsedCpu_N+2','UsedMemory_N+1','UsedMemory_N+2','Status_N+1','Status_N+2' | Sort Cluster
    $storageOver80 = $clusterReport | ?{ [int]($_.'DSK Used'.split("%")[0]) -gt 80 -and $_.Cluster -notlike "*ntnx*" -and $_.Cluster -notlike "*emg*"} | sort @{e={[int]($_.'DSK Used'.split("%")[0])}}
    $storageOver80 = $storageOver80 | select * -exclude 'UsedCpu_N+1','UsedCpu_N+2','UsedMemory_N+1','UsedMemory_N+2','Status_N+1','Status_N+2' | Sort Cluster
    $standbyClusters = $clusterReport | ?{ $_.Cluster -like "*_standby" } | select * -exclude 'UsedCpu_N+1','UsedCpu_N+2','UsedMemory_N+1','UsedMemory_N+2','Status_N+1','Status_N+1','percentChanged' | Sort Cluster
    $lowUtilization = $clusterReport | Sort @{e={([int]($_.CPU.split("%")[0])+([int]($_.MEM.split("%")[0])))/2}} | ?{ (([int]($_.CPU.split("%")[0])+([int]($_.MEM.split("%")[0])))/2) -gt 1 } | select -first 10
    $lowUtilization = $lowUtilization | select * -exclude 'UsedCpu_N+1','UsedCpu_N+2','UsedMemory_N+1','UsedMemory_N+2','Status_N+1','Status_N+1'
    # meat and potatoes
    $DeployClusters = $clusterReport | ?{ -not [string]::IsNullOrEmpty($_.'vCommander Deployment Destination') }
    $DeployClusters = $DeployClusters | select * -exclude 'UsedCpu_N+1','UsedCpu_N+2','UsedMemory_N+1','UsedMemory_N+2','Status_N+1','Status_N+1' | Sort Cluster    
    $NonDeployClusters = $clusterReport | ?{ [string]::IsNullOrEmpty($_.'vCommander Deployment Destination') }
    $NonDeployClusters = $NonDeployClusters | select * -exclude 'UsedCpu_N+1','UsedCpu_N+2','UsedMemory_N+1','UsedMemory_N+2','Status_N+1','Status_N+1' | Sort Cluster    
    $html = Get-HtmlHeader -Message "" -Title "Cluster Compute Status Report" -Image "Nordstrom.png" -ResultCount ($clusterReport.Count)
    $html += "<h5>Cluster Class Metrics</h5>"
    $html += "<table width='100%'>
                <tr><th>Windows</th><th>Linux</th><th>Sql</th><th>Oracle</th><th>WWW</th></tr>
                <tr><td align='center'>vmDensity: $vmDensityWin</br>
                        cpuOvercommit: $cpuOCWin</br>
                        memOvercommit: $memOCWin</td>
                    <td align='center'>vmDensity: $vmDensityLin</br>
                        cpuOvercommit: $cpuOCLin</br>
                        memOvercommit: $memOCLin</td>
                    <td align='center'>vmDensity: $vmDensitySql</br>
                        cpuOvercommit: $cpuOCSql</br>
                        memOvercommit: $memOCSql</td>
                    <td align='center'>vmDensity: $vmDensityOra</br>
                        cpuOvercommit: $cpuOCOra</br>
                        memOvercommit: $memOCOra</td>
                    <td align='center'>vmDensity: $vmDensitywww</br>
                        cpuOvercommit: $cpuOCOra</br>
                        memOvercommit: $memOCOra</td>
                </tr>
              </table><br/>"
    $html += "<h5>Top 10 Movers and Shakers</h5>"
    $html += Get-TableStopLights $($top10Movers | ConvertTo-Html -Fragment | Set-HtmlTableFormat) "nondeploy"
    $html += "<br/><h5>Clusters Needing Storage</h5>"
    $html += Get-TableStopLights $($storageOver80 | ConvertTo-Html -Fragment | Set-HtmlTableFormat) "nondeploy"
    $html += "<br/><h5>Clusters on Standby</h5>"
    $html += Get-TableStopLights $($standbyClusters | ConvertTo-Html -Fragment | Set-HtmlTableFormat) "nondeploy"
    $html += "<br/><h5>Top 10 Underutilized Clusters</h5>"
    $html += Get-TableStopLights $($lowUtilization | ConvertTo-Html -Fragment | Set-HtmlTableFormat) "nondeploy"
    $html += "<br/><h5>$($DeployClusters.count) Deploy Clusters</h5>"
    $html += Get-TableStopLights $($DeployClusters | ConvertTo-Html -Fragment | Set-HtmlTableFormat) "deploy"
    $html += "<br/><h5>$($NonDeployClusters.count) Non-Deploy Clusters</h5>"
    $html += Get-TableStopLights $($NonDeployClusters | ConvertTo-Html -Fragment | Set-HtmlTableFormat) "nondeploy"
    $html += "<br/><br/><table><tr><td>Deploy Clusters</td><td></td><td></td>
                      <td width='50%' rowspan='99' style='border-left: 1px solid black;'>
                        <li>A <b>deploy cluster</b> is a cluster that is currently receiving new server builds from
                        vCommander.</li>
                        <li>A <b>runway cluster</b> is an unused cluster of 4 hosts that was built out when the last runway
                        cluster was converted to the current deploy cluster. It will become the next deploy cluster
                        when the current deploy cluster has filled. This change occurs when we notify the platform
                        teams to change the vCommander configuration.</li>
                        <li><b>Storage Used/Free</b> is an estimate only. It is meant as an indication of which clusters
                        to check for storage shortages so you don't have to check each and every one. TB free
                        is shown along with percentage because some clusters, like oracle clusters, have a large
                        amount of storage provisioned and 10% free on those clusters could still mean 20 TB free.
                        At the same time it is important to keep in mind that several TB should be free for storage
                        migrations.</li>
                        <li><b>N+1/N+2 usage</b> If the number of hosts in a cluster are greater than 4 and the cluster
                        name does not contain sql or ora then N+2 is used. N+1 is used in clusters where the host count is 
                        less than 5 or sql/ora is in the cluster name.</td></tr>
                      <tr><td>WARNING</td><td>Greater than 50</td><td>Cluster OK</td></tr>
                      <tr><td>MINOR</td><td>Greater than 60</td><td>Capacity Low</td></tr>
                      <tr><td>MAJOR</td><td>Greater than 70</td><td>Capacity Very Low</td></tr>
                      <tr><td>CRITICAL</td><td>Greater than 80</td><td>Cluster Full</td></tr>
                      <tr><td>NonDeploy Clusters</td><td></td><td></td></tr>
                      <tr><td>WARNING</td><td>Greater than 82</td><td>Cluster OK</td></tr>
                      <tr><td>MINOR</td><td>Greater than 85</td><td>Capacity Low</td></tr>
                      <tr><td>MAJOR</td><td>Greater than 87</td><td>Capacity Very Low</td></tr>
                      <tr><td>CRITICAL</td><td>Greater than 90</td><td>Cluster Full</td></tr>
                      <tr><td></td><td></td><td></td></tr>
              </table>"
    $html += "<br/><br/>Deploy cluster information can be found on the confluence pages named
                <a href='https://confluence.nordstrom.net/pages/viewpage.action?pageId=40229165' target='clusters'>
                Clusters, LUNs/Storage groups to use for VM deployment.</a> and
                <a href='https://confluence.nordstrom.net/pages/viewpage.action?pageId=132487960' target='capacity'>
                VMware capacity management reviews & Runway clusters</a><br>"
    $html += Get-HtmlFooter -Message "This report was generated from A0319P184 by script Get-UCGClusterCapacity.ps1"
    If ($testing) {
      [array]$emailAddr = "$userID@nordstrom.com"
    } else {
      #[array]$emailAddr = "$userID@nordstrom.com"
      [array]$emailAddr = "itucg@nordstrom.com","techdcs@nordstrom.com"
    }
    If (test-path "$ScriptPath\Nordstrom.png") {
      [string[]]$attachments += "$ScriptPath\Nordstrom.png"
      Send-MailMessage -SmtpServer "exchange.nordstrom.net" -To $emailAddr -From "itucg@nordstrom.com" -Subject "Cluster Compute Status Report" -BodyAsHtml $html -Attachments $attachments
    } else {
      Send-MailMessage -SmtpServer "exchange.nordstrom.net" -To $emailAddr -From "itucg@nordstrom.com" -Subject "Cluster Compute Status Report" -BodyAsHtml $html
    }
    $tempFolder = (get-childitem env:\TEMP).Value
    $outputFile = "$tempFolder\$ScriptName-$Date.csv"
    $clusterReport | Export-csv $outputFile -NoTypeInformation
    Copy-Item $outputFile "\\nord\dr\software\vmware\Reports\ClusterCapacity\"
    $today = get-date -f s
    #$clusterReport = get-content (get-childitem "\\nord\dr\software\vmware\Reports\ClusterCapacity\" | sort name -Descending | select -first 1 -expand fullname) | convertfrom-csv
    $clusterReport | Add-Member -MemberType NoteProperty -Name "Date" -value $today
    $outputFile = "\\nord\dr\software\vmware\Reports\ClusterCapacity\" + $ScriptName + "_Trending.csv"
    $clusterReport | Export-csv $outputFile -Append
	#endregion
#endregion
#region ######################################### Cleanup ##############################################
	Stop-Transcript
#endregion
