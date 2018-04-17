<# 
.Synopsis 
   Script to automatically keep SCVMM Baselines in sync with WSUS  
.DESCRIPTION 
   Script that synchronizes WSUS Updates with SCVMM, both adding new updates and removes old inactive updates.  
.EXAMPLE 
   Update-BaseLineUpdates $Baselinename 
 
# Author 
Current Author, Markus Lassfolk @Truesec  
Original Author, Mikael Nyström @Truesec  
 
# Version 1.5 
  Markus Lassfolk 
 - Minor tewaks and changes 
 
# Version 1.2 
  Markus Lassfolk  
 - Added section to remove inactive updates  
 
# Version 1.0  
  Markus Lassfolk  
 - Initial Release  
 
# Version 0.5  
  Mikael Nyström  
  
#> 
 
 
Function Update-BaseLineUpdates{ 
  Param ( 
  [Parameter(Mandatory=$false, 
  ValueFromPipeline=$true, 
  ValueFromPipelineByPropertyName=$true, 
  ValueFromRemainingArguments=$false, 
  Position=0)] 
  [String] 
  $BaseLineName
  ) 

  $baseline = Get-SCBaseline -Name $BaseLineName 
 
  # Set-SCBaseline -Baseline $baseline -Name $BaseLineName -Description $BaseLineName -RemoveUpdates $baseline.Updates 
  write-host $baseline.UpdateCount : Current number of Updates in Baseline $BaseLineName 
 
  $addedUpdateList = "$null" 
  $addedUpdateList = @() 
 
  if ($baseline.UpdateCount -eq 0) {  
    if ($baseline -notlike "Drivers") { 
        write-host "No previous updates in" $BaselineName", adding all existing updates for" $BaseLineName "from WSUS"   
        $addedUpdateList += Get-SCUpdate | Where-Object -Property UpdateClassification -EQ -Value $BaseLineName | Where-Object -Property IsApproved -Like -Value "True" | Where-Object -Property IsDeclined -Like -Value "False"| Where-Object -Property IsExpired -Like -Value "False" | Where-Object -Property IsSuperseded -Like -Value "False" 
        write-host $addedUpdateList.Count ": New updates to add in" $Baseline  
        Set-SCBaseline -Baseline $baseline -Name $BaseLineName -Description $BaseLineName -AddUpdates $addedUpdateList 
    }
  if ($Baseline -like "Drivers") { 
        write-host "No previous updates in" $BaselineName", adding all existing updates for" $BaseLineName "from WSUS"   
        $addedUpdateList += Get-SCUpdate | Where-Object -Property UpdateClassification -EQ -Value Drivers | Where-Object -Property IsApproved -Like -Value "True" | Where-Object -Property IsDeclined -Like -Value "False"| Where-Object -Property IsExpired -Like -Value "False" | Where-Object -Property IsSuperseded -Like -Value "False" | Where-Object Products -Like "*Windows Server*"         
        write-host $addedUpdateList.Count ": New updates to add in" $Baseline  
        Set-SCBaseline -Baseline $baseline -Name $BaseLineName -Description $BaseLineName -AddUpdates $addedUpdateList 
    }
  } 
 
  if ($baseline.UpdateCount -gt 0 ) {  
    if ($baseline -notlike "Drivers") {         
        write-host "Scanning WSUS Updates for matching updates for $BaselineName"  
        $LatestUpdates = Get-SCUpdate | Where-Object -Property UpdateClassification -EQ -Value $BaseLineName | Where-Object -Property IsApproved -Like -Value "True" | Where-Object -Property IsDeclined -Like -Value "False"| Where-Object -Property IsExpired -Like -Value "False" | Where-Object -Property IsSuperseded -Like -Value "False" 
        write-host $LatestUpdates.Count ": Updates found, verifying if update(s) already exist in" $BaseLineName  
        Compare-Object -ReferenceObject $baseline.Updates -DifferenceObject $LatestUpdates -IncludeEqual | % { 
          if($_.SideIndicator -eq '=>') { $addedUpdateList += Get-SCUpdate -ID $_.inputobject.id }  
         } 
    }
   if ($Baseline -like "Drivers") { 
    write-host "Scanning WSUS Updates for matching updates for $BaselineName"  
        $LatestUpdates = Get-SCUpdate | Where-Object -Property UpdateClassification -EQ -Value $BaseLineName | Where-Object -Property IsApproved -Like -Value "True" | Where-Object -Property IsDeclined -Like -Value "False"| Where-Object -Property IsExpired -Like -Value "False" | Where-Object -Property IsSuperseded -Like -Value "False" | Where-Object Products -Like "*Windows Server*"
        write-host $LatestUpdates.Count ": Updates found, verifying if update(s) already exist in" $BaseLineName  
        Compare-Object -ReferenceObject $baseline.Updates -DifferenceObject $LatestUpdates -IncludeEqual | % { 
        if($_.SideIndicator -eq '=>') { $addedUpdateList += Get-SCUpdate -ID $_.inputobject.id }  
        } 
    }
  }
 
  write-host $addedUpdateList.Count : New updates to be added to SCVMM for $BaseLineName  


#    write-host $addedUpdateList | ft 
  Set-SCBaseline -Baseline $baseline -Name $BaseLineName -Description $BaseLineName -AddUpdate $addedUpdateList 
     
  write-host "Scan WSUS for Updates that should not be Checked anymore"  
  $remove = "" 
  $remove = @() 
  $removeUpdateList = "" 
  $removeUpdateList = @() 
 
  $remove += Get-SCUpdate | Where-Object -Property UpdateClassification -EQ -Value $BaseLineName | Where-Object -Property IsApproved -Like -Value "False" 
  $remove += Get-SCUpdate | Where-Object -Property UpdateClassification -EQ -Value $BaseLineName | Where-Object -Property IsDeclined -Like -Value "True" 
  $remove += Get-SCUpdate | Where-Object -Property UpdateClassification -EQ -Value $BaseLineName | Where-Object -Property IsExpired -Like -Value "True" 
  $remove += Get-SCUpdate | Where-Object -Property UpdateClassification -EQ -Value $BaseLineName | Where-Object -Property IsSuperseded -Like -Value "True" 
 
  write-host $remove.count "Remove Unapproved/Superseded/Expired/Declined updates"  
 
  Compare-Object -ReferenceObject $baseline.Updates -DifferenceObject $remove -IncludeEqual | % { 
    if($_.SideIndicator -eq '==') { $removeUpdateList += Get-SCUpdate -ID $_.inputobject.id }  
  } 
 
  Set-SCBaseline -Baseline $baseline -Name $BaseLineName -Description $BaseLineName -RemoveUpdates $RemoveupdateList  
} 

 
 
Function Add-BaseLine{ 
  Param ( 
  [Parameter(Mandatory=$false, 
  ValueFromPipeline=$true, 
  ValueFromPipelineByPropertyName=$true, 
  ValueFromRemainingArguments=$false, 
  Position=0)] 
  [String] 
  $BaseLineName 
  ) 

  $baseline = New-SCBaseline -Name $BaseLineName -Description $BaseLineName 
  $scope = Get-SCVMHostGroup -Name "All Hosts" 
  Set-SCBaseline -Baseline $baseline -AddAssignmentScope $scope 
  $scope2 = Get-SCVMMManagedComputer 

  ForEach($Server in $scope2){ 
  Set-SCBaseline -Baseline $baseline -Name $baseLine -AddAssignmentScope $Server 
  } 
} 



 
Write-Host "Synchronizing with WSUS Server"  
Get-SCUpdateServer | Start-SCUpdateServerSynchronization  
 
. Update-BaseLineUpdates "Security Updates" 
. Update-BaseLineUpdates "Critical Updates" 
. Update-BaseLineUpdates "Updates" 
. Update-BaseLineUpdates "Update Rollups" 
. Update-BaseLineUpdates "Hotfix" 
. Update-BaseLineUpdates "Drivers" 
 
#. Update-BaseLineUpdates "Definition Updates" 
. Update-BaseLineUpdates "Service Packs" 
. Update-BaseLineUpdates "Feature Packs" 
 
write-host "Start Compliance Scan for all Servers"  
Get-SCVMMManagedComputer | Start-SCComplianceScan -RunAsynchronously 







