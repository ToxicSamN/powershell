# created by sammy
# when you have multiple vsan clusters on the same subnet and switches then multicast settings should be different
Param(
  [Parameter(Mandatory=$true)]
  $vCenter = "vcsa0319vdip002",
  $Cluster = "cl0319vdivsanp002",
  $VMHost,
  [ValidateSet("vmk0","vmk1","vmk2","vmk3","vmk4","vmk5","vmk6")]
  [Parameter(Mandatory=$true)]
  $Vmkernel,
  $AgentMCAddr = "224.2.3.5",
  $MasterMCAddr = "224.1.2.4"
)

Import-Module UcgModule -ArgumentList vmware -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
cls
try{
  $TargetVMHost = @()
  $vi = Connect-VIServer -Server $vCenter -Credential (Login-vCenter) -WarningAction SilentlyContinue -ErrorAction Stop
  If($PSBoundParameters.ContainsKey("Cluster") -and $PSBoundParameters.ContainsKey("VMhost")){
    $TargetVMHost += Get-VMHost | ?{$_.Name -like "*$($VMHost)*"}
  
  }
  Elseif($PSBoundParameters.ContainsKey("Cluster")){
    $TargetVMHost += Get-VmCluster -Name $Cluster | Get-VMHost
  
  }
  ElseIf($PSBoundParameters.ContainsKey("VMhost")){
    $TargetVMHost += Get-VMHost | ?{$_.Name -like "*$($VMHost)*"}
  
  }
  $TargetVMHost | %{ $esxi = $_
    $esxcli = Get-EsxCli -VMHost $esxi
    $esxcli.vsan.network.ipv4.set($AgentMCAddr,$null,$null,$null,$Vmkernel,$MasterMCAddr,$null,$null,$null,$null)
    
  }
  
  Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue
}catch{
  Write-Error $_ -ErrorAction Stop
}
  
  
  
