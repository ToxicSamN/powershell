
#where is my VM
Param([parameter(Mandatory = $true)][array]$VM=@(),[datetime]$date = (Get-Date))
cls
[string]$date = $date.ToString("M'_'d'_'yyyy")
Write-Host "Collecting VM Information. Please wait..."
$imp=Import-Csv "\\nord\dr\Software\VMware\Reports\VMInventory\VMInventory$($date).csv" | Select vCenter,ClusterName,VMName,ESXiHost | ?{$VM -contains $_.VMName}
$imp | ft -AutoSize
Write-Host "Complete"
