# Watch-StorageJobs
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
	Watch-StorageInformation -StoragePoolName s2d_storage_pool_01 -WhatToWatch Disks
#> 
Param(
	[Parameter(Mandatory=$true)]
	$StoragePoolName = $null,
	[ValidateSet("Jobs","Disks")]
	[Parameter(Mandatory=$true)]
	$WhatToWatch = $null
)
if ($WhatToWatch -eq "Jobs"){
	do{
		cls
		Get-StorageJob | ft -AutoSize
		Get-StorageHealthAction;sleep -Seconds 5
		Get-StorageSubsystem $StoragePoolName -ErrorAction Stop | Get-StorageHealthReport
	}while($true)
}elseif ($WhatToWatch -eq "Disks"){
	do{
		cls
		Get-PhysicalDisk | measure-object | Select @{n="NumberOfPhysicalDisks";e=$_.Count  | ft -AutoSize
		Get-PhysicalDisk | ft -AutoSize;
		sleep -Seconds 15
	}while($true)
}