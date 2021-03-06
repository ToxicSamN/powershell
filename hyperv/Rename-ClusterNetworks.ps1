function Rename-ClusterNetworks{
[cmdletbinding()]
Param(
	[parameter(Mandatory=$true)]
	$ClusterName,
	$Name="*"
)
	Write-Verbose "Parameter Set:`n`tClusterName : $($ClusterName)`n`tName : $($Name)"
	Get-Cluster -Name $ClusterName | Get-ClusterNetwork -Name $Name | %{ $cl_net = $_
		Write-Verbose "Cluster Network Information:"
		Write-Output ($cl_net | Select @{Name='Cluster';Expression={$_.Cluster.Name}},Name,Address,Id,Metric) | ft -AutoSize| Out-String -Stream | Write-Verbose

		if($cl_net.Address -eq "192.168.10.0"){
			# S2D network
			try{
				Write-Verbose "Renaming $($cl_net.Name) to vEthernet (S2D)"
				$cl_net.Name = "vEthernet (S2D)"
			}catch{
				Write-Verbose "Unable to Rename the Network"
				Write-Warning "Cluster Network $($cl_net.Name) already exists as $($cl_net.Name). No changes made."
			}
		}elseif($cl_net.Address -eq "192.168.20.0"){
			#LiveMigration Network
			try{
				Write-Verbose "Renaming $($cl_net.Name) to vEthernet (LiveMigration)"
				$cl_net.Name = "vEthernet (LiveMigration)"
			}catch{
				Write-Warning "Cluster Network $($cl_net.Name) already exists as $($cl_net.Name). No changes made."
			}
		}else{
			#OSMgmt Network
			try{
				Write-Verbose "Renaming $($cl_net.Name) to vEthernet (OSMgmt)"
				$cl_net.Name = "vEthernet (OSMgmt)"
			}catch{
				Write-Warning "Cluster Network $($cl_net.Name) already exists as $($cl_net.Name). No changes made."
			}
		}
	}
}
