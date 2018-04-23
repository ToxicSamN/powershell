# Watch-StorageJobs
Param(
	[Parameter(Mandatory=$true)]
	$StoragePoolName = $null,
	[ValidateSet("Jobs","Disks")]
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



