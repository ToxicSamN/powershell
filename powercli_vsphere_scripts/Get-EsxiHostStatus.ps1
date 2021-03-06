# created by sammy shuck
# specifically used for a splunk process that scans a specific folder for a EsxiHostStatusReport.csv file
Param([array]$vCenters=@())
cls
#region Load Snapins/Modules
function Get-InstallPath {
#Function provided by VMware used by PowerCLI to initialize Snapins
# Initialize-PowerCLIEnvironment.ps1
   $regKeys = Get-ItemProperty "hklm:\software\VMware, Inc.\VMware vSphere PowerCLI" -ErrorAction SilentlyContinue
   
   #64bit os fix
   if($regKeys -eq $null){
      $regKeys = Get-ItemProperty "hklm:\software\wow6432node\VMware, Inc.\VMware vSphere PowerCLI"  -ErrorAction SilentlyContinue
   }

   return $regKeys.InstallPath
}
function LoadSnapins(){
   [xml]$xml = Get-Content ("{0}\vim.psc1" -f (Get-InstallPath))
   $snapinList = Select-Xml  "//PSSnapIn" $xml |%{$_.Node.Name }

   $loaded = Get-PSSnapin -Name $snapinList -ErrorAction SilentlyContinue | % {$_.Name}
   $registered = Get-PSSnapin -Name $snapinList -Registered -ErrorAction SilentlyContinue  | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   foreach ($snapin in $registered) {
      if ($loaded -notcontains $snapin) {
         Add-PSSnapin $snapin -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
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
function LoadModules(){
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
LoadSnapins
LoadModules
#endregion
cls
[array]$hostReport = @()
[int]$vcCount = 0
#region Loop Through vCenters and Connect
$vCenters | %{ $vcCount++
	Write-Progress -Status "Progress..." -Activity "Connecting to vCenter $($_)" -PercentComplete (100*($vcCount/$vCenters.Count)) -Id 90 -ErrorAction SilentlyContinue
	$vi = Connect-VIServer -Server $_ -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Write-Progress -Status "Progress..." -Activity "Connected to vCenter $($_)" -PercentComplete (100*($vcCount/$vCenters.Count)) -Id 90 -ErrorAction SilentlyContinue
#endregion

	#region Get Clusters
	[array]$allClusters = Get-View -ViewType ClusterComputeResource -Server $vi
	#endregion

	#region Payload
	#loop through the clusters getting ESXi Hosts and their status
	[int]$clCount = 0
	$allClusters | %{ $cl = $_; $clCount++
		Write-Progress -Status "Progress..." -Activity "Cluster $($cl.Name)" -PercentComplete (100*($clCount/$allClusters.Count)) -Id 91 -ErrorAction SilentlyContinue
		[int]$hvCount = 0
		$cl.Host | %{ $esxi = Get-View $_; $hvCount++
			Write-Progress -Status "Progress..." -Activity "ESXi Host $($esxi.Name)" -PercentComplete (100*($hvCount/$cl.Host.Count)) -Id 92 -ParentId 91 -ErrorAction SilentlyContinue
			$pso = New-Object PSObject -Property @{vCenter=$vi.Name;Cluster=$cl.Name;Host=$esxi.Name;Status=$esxi.Runtime.ConnectionState;OutOfService=$esxi.Runtime.InMaintenanceMode}
			[array]$hostReport += $pso
		}
	}
	#endregion
	Disconnect-VIServer -Server $vi.Name -Confirm:$false
}#end of vCenter Loop
Write-Progress -Status "Progress..." -Activity "complete" -Completed -Id 92 -ErrorAction SilentlyContinue
Write-Progress -Status "Progress..." -Activity "complete" -Completed -Id 91 -ErrorAction SilentlyContinue
Write-Progress -Status "Progress..." -Activity "complete" -Completed -Id 90 -ErrorAction SilentlyContinue
$hostReport | Select vCenter,Cluster,Host,Status,OutOfService | Sort vCenter,Cluster,Host | Export-Csv "D:\SplunkData\EsxiHostStatusReport\EsxiHostStatusReport.csv" -NoTypeInformation
$string = "<html><table cellpadding='5'>
<tr><td>vCenter</td><td>Cluster</td><td>Host</td><td>Status</td><td>OutOfService</td>"
$hostReport | Select vCenter,Cluster,Host,Status,OutOfService | Sort vCenter,Cluster,Host | %{
	$string += "<tr><td>$($_.vCenter)</td><td>$($_.Cluster)</td><td>$($_.Host)</td><td>$($_.Status)</td><td>$($_.OutOfService)</td>"
}
$string += "</table></html>"
#$string | Out-File "D:\SplunkData\EsxiHostStatusReport\EsxiHostStatusReport.html"
