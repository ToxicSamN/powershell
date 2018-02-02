# by sammy
# date mar 2016
# purpose : addresses vsan issues with gen 1 hardware in which specific advanced setting are required per VMware support ticket
Param(
	[string]$vCenter=$null,
	[string]$Cluster="All"
)
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
cls

[array]$report = @()

$vi = Connect-VIServer -Server $vCenter -ErrorAction Stop -WarningAction SilentlyContinue

If($Cluster -eq "All"){
	$clObjs = Get-VmCluster | ?{$_.VsanEnabled}
}ElseIf((-not [string]::IsNullOrEmpty($Cluster))){
	$clObjs = Get-VmCluster -Name $Cluster
}

If(-not [string]::IsNullOrEmpty($clObjs)){
	$clObjs | %{ $cl = $_
		$cl | Get-VMHost | %{ $esxi = $_
			$tmp=$null
			$esxcli = Get-EsxCli -VMHost $esxi
			
			#get the current value for /LSOM/diskIoTimeout
			$tmp = $esxcli.system.settings.advanced.list($false,"/LSOM/diskIoTimeout")
			$orig1 = $tmp[0].IntValue
			#change the vlaue to 110000
			$esxcli.system.settings.advanced.set($false,110000,"/LSOM/diskIoTimeout")
			
			#get the current value for /LSOM/diskIoRetryFactor
			$tmp = $esxcli.system.settings.advanced.list($false,"/LSOM/diskIoRetryFactor")
			$orig2 = $tmp[0].IntValue
			#change the value to 1
			$esxcli.system.settings.advanced.set($false,1,"/LSOM/diskIoRetryFactor")
			
			#get the value again
			$tmp = $esxcli.system.settings.advanced.list($false,"/LSOM/diskIoTimeout")
			#populate the the CSV data for export
			$report += New-Object PSObject -Property @{Cluster=$cl.Name;VMHost=$esxi.Name;Path=$tmp[0].Path;Description=$tmp[0].Description;Value=$tmp[0].IntValue;OrigValue=$orig1}
			#get the value again
			$tmp = $esxcli.system.settings.advanced.list($false,"/LSOM/diskIoRetryFactor")
			#populate the the CSV data for export
			$report += New-Object PSObject -Property @{Cluster=$cl.Name;VMHost=$esxi.Name;Path=$tmp[0].Path;Description=$tmp[0].Description;Value=$tmp[0].IntValue;OrigValue=$orig2}
		}
	}
	#export the CSV data
	$report | Export-Csv "C:\Temp\vsanRemediation.csv" -NoTypeInformation -Append
}