<# 
.SYNOPSIS  
	Used to output Storage jobs or your physical disks during maintenance operations.
.DESCRIPTION  
	Simple loops that will watch either the storage jobs or the physical disks/count during maintenance operations.
.NOTES  
	Name  			: Watch-StorageInformation
	Author     		: Sammy Shuck 
	Github			: https://github.com/ToxicSamN/powershell/blob/master/hyperv/Watch-StorageInformation.ps1
	Requires   		: Minimum WS2016 and Powershell v5
.EXAMPLE  
	Watch-StorageInformation -StoragePoolName s2d_storage_pool_01 -WhatToWatch Jobs
.EXAMPLE  
	Watch-StorageInformation -StoragePoolName s2d_storage_pool_01 -WhatToWatch Disks -RefreshSecs 15
#> 
Param(
	[Parameter(Mandatory=$true)]
	$StoragePoolName = $null,
	[ValidateSet("Jobs","Disks")]
	[Parameter(Mandatory=$true)]
	$WhatToWatch = $null,
	$RefreshSecs = 5
)
if ($WhatToWatch -eq "Jobs"){
	do{
		cls
		$jobs = Get-StorageJob
		$health_action = Get-StorageHealthAction
		$health_report = Get-StorageSubsystem $StoragePoolName -ErrorAction Stop | Get-StorageHealthReport
		Write-Output ($jobs | ft -AutoSize) | Out-String -Stream
		Write-Output ($health_action | ft -AutoSize) | Out-String -Stream
		Write-Output ($health_report[0] | ft -AutoSize) | Out-String -Stream
		Sleep -Seconds $RefreshSecs
	}while($true)
}elseif ($WhatToWatch -eq "Disks"){
	do{
		cls
		$disk_count = Get-PhysicalDisk | measure-object | Select @{n="NumberOfPhysicalDisks";e={"$($_.Count)"} }
		$disks = Get-PhysicalDisk | ft -AutoSize
		Write-Output ($disk_count | ft -AutoSize) | Out-String -Stream
		Write-Output ($disks | ft -AutoSize) | Out-String -Stream
		sleep -Seconds $RefreshSecs
	}while($true)
}