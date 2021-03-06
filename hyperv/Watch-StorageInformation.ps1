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
$first_run = 1
if ($WhatToWatch -eq "Jobs"){
	do{
        if ($first_run -ne 1){
            Sleep -Seconds $RefreshSecs
        }
		
		$jobs = Get-StorageJob
		$health_action = Get-StorageHealthAction
		$health_report = Get-StorageSubsystem $StoragePoolName -ErrorAction Stop | Get-StorageHealthReport
		cls
        Write-Output ($jobs | ft -AutoSize) | Out-String -Stream
		Write-Output ($health_action | ft -AutoSize) | Out-String -Stream
		Write-Output ($health_report[0] | ft -AutoSize) | Out-String -Stream
        $first_run = 0
		
	}while($true)
}elseif ($WhatToWatch -eq "Disks"){
	do{
        if ($first_run -ne 1){
            Sleep -Seconds $RefreshSecs
        }
		
		$disk_count = Get-PhysicalDisk | measure-object | Select @{n="NumberOfPhysicalDisks";e={"$($_.Count)"} }
		$disks = Get-PhysicalDisk | ft -AutoSize
		cls
		Write-Output ($disks | ft -AutoSize) | Out-String -Stream
        Write-Output ($disk_count | ft -AutoSize) | Out-String -Stream		
        $first_run = 0
	}while($true)
}