[CmdletBinding()]
Param(
  	[Parameter(Mandatory=$true, Position=1)]
  	[ValidateNotNullOrEmpty()]
	$ClusterName,
	[Parameter(Mandatory=$true, Position=2)]
  	[ValidateNotNullOrEmpty()]
	[array]$Nodes,
	[Parameter(Mandatory=$true, Position=3)]
  	[ValidateNotNullOrEmpty()]
	[ValidateSet("Test","Create","Add","Remove")]
	$Operation,
	$ClusterIPAddress,
	$VMMServer,
	[switch]$NoStorage=$false,
	[string[]]$IgnoreNetwork,
	[ValidateSet("FileShareWitness","NodeMajority","NodeAndDiskMajority","NodeAndFileShareMajority","CloudWitness")]
	[string]$ClusterQuorumType="NodeMajority",
	[string]$ClusterQourumValue,
	[switch]$EnableS2D=$false,
	[String[]]$Include,
	[switch]$IgnoreStorageConnectivityLoss=$false,
	[switch]$CleanupDisks,
	[switch]$Wait=$false,
	[switch]$Confirm=$true,
	[switch]$Force=$false,
  	[string]$LogFile
  
)
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

if (-not $LogFile) {
	New-Variable -Name log_file -Value "C:\temp\Invoke-ClusterOperation.log" -Option AllScope -Scope Script -ErrorAction SilentlyContinue
}else{
	New-Variable -Name log_file -Value $LogFile -Option AllScope -Scope Script -ErrorAction SilentlyContinue
}

Function Test-FailoverCluster(){
[CmdletBinding()]
	Param(
	[Parameter(Mandatory=$true, Position=1)]
  	[ValidateNotNullOrEmpty()]
	[array]$Nodes,
	[Parameter(Mandatory=$true, Position=2)]
  	[ValidateNotNullOrEmpty()]
	[string[]]$Include
	)
	
	Test-Cluster -Node $Nodes -Include $Include
}
Function Create-FailoverCluster(){
[CmdletBinding()]
	Param(
	[Parameter(Mandatory=$true, Position=1)]
  	[ValidateNotNullOrEmpty()]
	$ClusterName,
	[Parameter(Mandatory=$true, Position=2)]
  	[ValidateNotNullOrEmpty()]
	[array]$Nodes,
	[Parameter(Mandatory=$true, Position=3)]
  	[ValidateNotNullOrEmpty()]
	$ClusterIPAddress,
	[Parameter(Mandatory=$true, Position=4)]
  	[ValidateNotNullOrEmpty()]
	$VMMServer,
	[switch]$NoStorage,
	[string[]]$IgnoreNetwork,
	[ValidateSet("FileShareWitness","NodeMajority","NodeAndDiskMajority","NodeAndFileShareMajority","CloudWitness")]
	[string]$ClusterQuorumType="NodeMajority",
	[string]$ClusterQuorumValue,
	[switch]$EnableS2D,
	[switch]$Force
	)
	
	Write-Output (New-Cluster -Name $ClusterName -Node $Nodes -StaticAddress $ClusterIPAddress -NoStorage:$NoStorage -IgnoreNetwork $IgnoreNetwork -Force:$Force)`
		| Out-String -Stream | Format-Message | Write-Log -Path $log_file
	
	Switch ($ClusterQuorumType){
		 "FileShareWitness"			{
		 	# Set Cluster Quorum to FileShareWitness
			Write-Output (Set-ClusterQuorum -FileShareWitness $ClusterQuorumValue | ft -AutoSize)| Out-String -Stream | Format-Message | Write-Log -Path $log_file
		 }
		 "NodeMajority"				{
		 	# Set Cluster Quorum to Node Majority
			Write-Output (Set-ClusterQuorum -NodeMajority | ft -AutoSize)| Out-String -Stream | Format-Message | Write-Log -Path $log_file
		 }
		 "NodeAndDiskMajority"		{
		 	# Set Cluster Quorum to Node and Disk Majority
			Write-Output (Set-ClusterQuorum -NodeAndDiskMajority $ClusterQuorumValue | ft -AutoSize)| Out-String -Stream | Format-Message | Write-Log -Path $log_file
		 }
		 "NodeAndFileShareMajority" {
		 	# Set Cluster Quorum to Node and File Share Majority
			Write-Output (Set-ClusterQuorum -NodeAndFileShareMajority $ClusterQuorumValue | ft -AutoSize)| Out-String -Stream | Format-Message | Write-Log -Path $log_file
		 }
		 "CloudWitness"				{
		 	# Set Cluster Quorum to Cloud witness
			#Set-ClusterQuorum -CloudWitness -AccountName <AzureStorageAccountName> -AccessKey <AzureStorageAccountAccessKey>
			Format-Message "Cloud Witness is not a valid option at this time" | Write-Log -Path $log_file
			exit -1
		 }
		 
	}
	
	If ($EnableS2D) {
		Enable-ClusterS2D -PoolFriendlyName "$($ClusterName)_s2d_pool"
	}
	
	Write-Output (Rename-ClusterNetworks -ClusterName $ClusterName -Verbose)| Out-String -Stream | Format-Message | Write-Log -Path $log_file
	
	$no_migr_net = Get-ClusterNetwork | ?{$_.Name -ne "vEthernet (LiveMigration)"}
	Write-Output (Get-ClusterResourceType -Name "Virtual Machine" | Set-ClusterParameter -Name "MigrationExcludeNetworks" -Value ([string]::join(";",$no_migr_net.id)))| Out-String -Stream | Format-Message | Write-Log -Path $log_file
	
	if ($VMMServer -isnot [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]){
		Write-Verbose "$($VMMServer) is not of type [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]. Getting SCVMM Server"
    	$vmm = Get-SCVMMServer -ComputerName $VMMServer
	}else { $vmm = $VMMServer } 
    
	$cl = Get-SCVMHostCluster -Name $ClusterName -VMMServer $vmm
	Get-SCVMHost -VMHostCluster $cl | %{ $vmhost = $_
 		$lm_subnet = $vmhost.MigrationSubnet | ?{$_ -like "192.168.20.*"}
 		Write-Output (Set-SCVMHost -VMHost $vmhost -RunAsynchronously -LiveStorageMigrationMaximum "4" -EnableLiveMigration $true -LiveMigrationMaximum "8" -MigrationPerformanceOption "UseSmbTransport" -MigrationAuthProtocol "Kerberos" -UseAnyMigrationSubnet $false -MigrationSubnet $lm_subnet | ft -AutoSize)| Out-String -Stream | Format-Message | Write-Log -Path $log_file
	}
}
Function AddTo-FailoverCluster(){
[CmdletBinding()]
	Param(
	[Parameter(Mandatory=$true, Position=1)]
  	[ValidateNotNullOrEmpty()]
	$ClusterName,
	[Parameter(Mandatory=$true, Position=2)]
  	[ValidateNotNullOrEmpty()]
	[array]$Nodes,
	[Parameter(Mandatory=$true, Position=3)]
  	[ValidateNotNullOrEmpty()]
	$VMMServer,
	[switch]$NoStorage
	)
	
	$cl = Get-Cluster -Name $ClusterName
	$Nodes | %{ $node = $_
		Write-Output ($cl | Add-ClusterNode -Name $node -NoStorage:$NoStorage | ft -AutoSize) | Out-String -Stream | Format-Message | Write-Log -Path $log_file
	}
	
	$no_migr_net = Get-ClusterNetwork | ?{$_.Name -ne "vEthernet (LiveMigration)"}
	Write-Output (Get-ClusterResourceType -Name "Virtual Machine" | Set-ClusterParameter -Name "MigrationExcludeNetworks" -Value ([string]::join(";",$no_migr_net.id)))| Out-String -Stream | Format-Message | Write-Log -Path $log_file
	
	if ($VMMServer -isnot [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]){
		Write-Verbose "$($VMMServer) is not of type [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]. Getting SCVMM Server"
    	$vmm = Get-SCVMMServer -ComputerName $VMMServer
	}else { $vmm = $VMMServer } 
    
	$cl = Get-SCVMHostCluster -Name $ClusterName -VMMServer $vmm
	Get-SCVMHost -VMHostCluster $cl | ?{$Nodes -contains $_.Name} | %{ $vmhost = $_
 		$lm_subnet = $vmhost.MigrationSubnet | ?{$_ -like "192.168.20.*"}
 		Write-Output (Set-SCVMHost -VMHost $vmhost -RunAsynchronously -LiveStorageMigrationMaximum "4" -EnableLiveMigration $true -LiveMigrationMaximum "8" -MigrationPerformanceOption "UseSmbTransport" -MigrationAuthProtocol "Kerberos" -UseAnyMigrationSubnet $false -MigrationSubnet $lm_subnet | ft -AutoSize)| Out-String -Stream | Format-Message | Write-Log -Path $log_file
	}
}
Function RemoveFrom-FailoverCluster(){
[CmdletBinding()]
	Param(
	[Parameter(Mandatory=$true, Position=1)]
  	[ValidateNotNullOrEmpty()]
	$ClusterName,
	[Parameter(Mandatory=$true, Position=2)]
  	[ValidateNotNullOrEmpty()]
	[array]$Nodes,
	[switch]$IgnoreStorageConnectivityLoss,
	[switch]$CleanupDisks,
	[switch]$Wait,
	[switch]$Confirm,
	[switch]$Force
	)
	$cl = Get-Cluster -Name $ClusterName
	$Nodes | %{ $node = $_
		$cl | Remove-ClusterNode -Name $node `
			-IgnoreStorageConnectivityLoss:$IgnoreStorageConnectivityLoss `
			-Force:$Force `
			-Wait$Wait `
			-CleanupDisks:$CleanupDisks `
			-Confirm:$Confirm
	}
}

# Main #
switch ($Operation){
	"Test"	{ Test-FailoverCluster -Nodes $Nodes -Include $Include }
	"Create"{ Create-FailoverCluster -ClusterName $ClusterName `
				-Nodes $Nodes `
				-ClusterIPAddress $ClusterIPAddress `
				-VMMServer $VMMServer `
				-NoStorage:$NoStorage `
				-IgnoreNetwork $IgnoreNetwork `
				-ClusterQuorumType $ClusterQuorumType `
				-ClusterQourumValue $ClusterQourumValue `
				-EnableS2D:$EnableS2D 
			}
	"Add"	{ AddTo-FailoverCluster -ClusterName $ClusterName -Nodes $Nodes -VMMServer $VMMServer -NoStorage:$NoStorage }
	"Remove"{ RemoveFrom-FailoverCluster -ClusterName $ClusterName -Nodes $Nodes -IgnoreStorageConnectivityLoss:$IgnoreStorageConnectivityLoss -CleanupDisks:$CleanupDisks -Wait:$Wait -Confirm:$Confirm -Force:$Force}
}