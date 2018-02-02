# sammy shuck
# used to get current license key usage information accross all vcenters
Function Get-LicenseKey{
  Process{
    $sInstance = Get-View ServiceInstance
    $licenseManager = Get-View $sInstance.Content.LicenseManager
    return $licenseManager.Licenses
  }
}

cls
Import-Module UcgModule -ArgumentList vmware -WarningAction SilentlyContinue
$vcenters = Import-Csv "\\nord\dr\Software\VMware\Reports\vcenterlist.txt"
$report = @(); $licenses = @{}

$vcenters | %{ $vcObj = $_
  try{
   $vi = Connect-VIServer -Server $vcObj.Name -ErrorAction Stop
   Get-LicenseKey | %{ $lkObj = $_
   If($licenses.Keys -contains ($lkObj.LicenseKey)){
     $licenses[$lkObj.LicenseKey].Used += ($lkObj.Used -as [int])
   }
   Else{ 
     $licenses[$lkObj.LicenseKey] = New-Object PSObject -Property @{
         Name = $lkObj.Name
         Total = $lkObj.Total -as [int]
         Used = $lkObj.Used -as [int]
         LicenseUnit = $lkObj.CostUnit
         LicenseKey = $lkObj.LicenseKey
       }
     }
   }
  }catch{
    Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue
    continue
  }
}