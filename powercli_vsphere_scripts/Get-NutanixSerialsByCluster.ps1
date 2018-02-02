

Import-Module UcgModule -ArgumentList vmware
cls
$report = @()
Import-Csv "\\nord\dr\software\vmware\reports\vcenterlist.txt" | %{ $vc = $_.name

$vi = Connect-ViServer -server $vc -Credential (Login-vCenter) -WarningAction SilentlyContinue

$vmhosts = Get-View -ViewType HostSystem
$vmhosts | ?{$_.Name -like "ntnx*"} | %{ $esxi = $_
  
  $serviceTags = $esxi.Hardware.SystemInfo.OtherIdentifyingInfo | ?{$_.IdentifierType.key -eq "ServiceTag"} | Sort
  
  $report += New-Object PSObject -Property @{
    Cluster = (Get-View $esxi.Parent).Name
    BlockSerial = $serviceTags[0].IdentifierValue
    NodeSerial = $serviceTags[1].IdentifierValue
    ModelNumber = "NX"
  }
  
}

Disconnect-VIServer * -Confirm:$false


}
$report | Export-Csv "E:\Sammy\nutanixinfo\nutanix_serials.csv" -NoTypeInformation