# by sammy shuck
# date may 207
# this is used by the firewall team to deploy virtual paloalto firewalls to the virtualization infrastructure
# this script is a wrapper to the Deploy-StoreFirewall.ps1 script so that multiple firewalls can be deployed at once based on a csv file
Param(
  [Parameter(Mandatory=$true)]
  $CSVFilePath,
  [int]$Throttle = 2
)
cls
Function Validate-CSVStructure{
  Param(
    [Parameter(Mandatory=$true)]
    $Object
  )
  try{
    $dict = @{
      "vCenter"=$false
      "Store"=$false
      "Name"=$false
      "ISOFileName"=$false
    }
    $headers = $Object | Get-Member -MemberType:NoteProperty | Select Name
    $headers | %{ $lbl = $_
      Switch($lbl.Name){
        "vCenter"{$dict[$lbl.Name] = $true}
        "Store"{$dict[$lbl.Name] = $true}
        "Name"{$dict[$lbl.Name] = $true}
        "ISOFileName"{$dict[$lbl.Name] = $true}
        default {$dict[$lbl.Name] = $false}
      }
    }
    $chk = $null
    $chk = $dict.Values | ?{$_ -eq $false}
    If(-not [string]::IsNullOrEmpty($chk) -or $chk -eq $false){
      Write-Error "Imported CSV file does not contain the proper Headings.`nExpected CSV Headings : vCenter, Store, Name, ISOFileName" -Category:InvalidData -ErrorAction Stop
    }
  }catch{
    throw $_
  } 
}
Function Deploy-FirewallVMs{
  Param(
    [Parameter(Mandatory=$true)]
    $CSVObject
  )
  $dict = @{}
  try{
    $CSVObject | %{ $obj = $_
      $dict[$obj.Name] = Start-Job -Name $obj.Name -FilePath ".\Deploy-StoreFirewall.ps1" -ArgumentList @($obj.vCenter,$obj.Store,$obj.Name,$obj.ISOFileName) -ErrorAction Stop
    }
    return $dict
  }catch{
    Write-Error $_
    throw $_
  }
  
}
Function Track-Jobs{
  Param(
    $jobs
  )
  try{
    If(-not [string]::IsNullOrEmpty($jobs)){
    	[bool]$tskRun = $true
    	Write-Progress -Activity "Waiting for VM Deployment Jobs to complete." -PercentComplete 50 -Id 91 -ErrorAction SilentlyContinue
    	Do{
    		$jobs = Get-Job -Id $jobs.Id -ErrorAction SilentlyContinue
    		$chk=$null
    		$chk = $jobs | ?{$_.State -ne "Success" -and $_.State -ne "Running"}
    		If(-not [string]::IsNullOrEmpty($chk)){[bool]$tskError=$true}Else{$tskError=$false}
    		$chk=$null
    		$chk = $jobs | ?{ $_.State -eq "Running"}
    		If([string]::IsNullOrEmpty($chk)){$tskRun=$false}
    	}While($tskRun)
    	If($tskError){
    		#Job failed
        Get-Job | ?{$_.State -eq "failed"}
    		Write-Error "At least 1 VM Deployment Job failed." -Category:InvalidResult -ErrorAction Stop
    	}
      Write-Progress -Activity "Waiting for Applying VUM Baselines on Esxi Hosts" -Completed -Id 91
    }
  }catch{
    throw $_
  }
}
try{
  $data = Import-Csv $CSVFilePath -ErrorAction Stop
  Validate-CSVStructure $data
  
  [int]$skip = 0
  For($x = 1; $x -le [Math]::Ceiling($data.Count/$Throttle); $x++){
    $data | Select -First $Throttle -Skip $skip
    $jobs = Deploy-FirewallVMs $data
    Track-Jobs $jobs.values
    $skip = $skip + $Throttle
  }
  
}catch{
  Write-Error $_
}