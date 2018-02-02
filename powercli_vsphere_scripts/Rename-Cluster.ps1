# sammy shuck
# this is designed to renmae a cluster and the associated auto deploy rule as well
Param(
  [Parameter(Mandatory=$true,Position=0)]
  $vCenter,
  [Parameter(Mandatory=$true,Position=1)]
  $ClusterName,
  [Parameter(Mandatory=$true,Position=2)]
  $NewName
)

Add-PSSnapin VM* -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Import-Module UcgModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
cls

try{
  $vi = Connect-VIServer -Server $vCenter -ErrorAction Stop
  Write-Host "Current Cluster Name : $($ClusterName)"
  $clObj = Get-VmCluster -Name $ClusterName -ErrorAction SilentlyContinue
  If(-not [string]::IsNullOrEmpty($clObj)){
    $clObj = $clObj | Set-VmCluster -Name $NewName
    Write-Host "New Cluster Name : $($clObj.Name)"
  }
  
  $dr = Get-DeployRule -Name $ClusterName
  If(-not [string]::IsNullOrEmpty($dr)){
    Write-Host "Auto Deploy Rule Found : $($dr.Name)`nRenaming Deploy Rule to $($NewName)"
    $outNull = Copy-DeployRule -DeployRule $dr -Name $NewName
    $drNew = Get-DeployRule -Name $NewName
    $outNull = Add-DeployRule -DeployRule $drNew -ErrorAction SilentlyContinue
    If(-not [string]::IsNullOrEmpty($drNew)){
      $outNull = Remove-DeployRule -DeployRule $dr -Delete
    }
    $drNew
    Disconnect-VIServer * -Confirm:$false -Force:$true
  }
}catch{
  Write-Error $_
  throw $_
}