PARAM(
	#[Parameter(Mandatory=$true)]
	[array]$vCenter = @("a0319p1201","a0319p1202","a0319p1203","a0319p366"),
	[string]$Cluster
)
Function Get-ClusterDatacenter{
	Param(
		$cl
	)
	
	try{
		Get-VIObjectByVIView -MORef $cl.MoRef | Get-Datacenter -ErrorAction Stop
	}catch{
		Write-Error $_
		throw $Error[0]
	}
	
}
Function Get-VMHostEsxiVersion{
	Param(
		$VMHost,
		$store
	)
	
	try{
		$hsh = @{}
		$pso = New-Object PSObject -Property @{Store=$store;VMHost=$VMHost.Name;EsxiVersion=$VMHost.Summary.Config.Product.Version;BuildVersion=$VMHost.Summary.Config.Product.Build}
		return $pso
	}catch{
		Write-Error $_
		throw $Error[0]
	}
}

Add-PSSnapin VM*
Import-Module UcgModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force:$true
cls
try{
	[array]$report = @()
	$vCenter | %{ $vc = $_
	
		$vi = Connect-VIServer -Server $vc -Credential (Login-vCenter)
		
		if($Cluster){ $searchRoot = Get-View -ViewType ClusterComputeResource -Filter @{"Name"=$Cluster} }
		else{ $searchRoot = Get-View -ViewType ClusterComputeResource }
		
		$searchRoot | %{ $cl = $_; $dc = Get-ClusterDatacenter $cl
			$cl.Host | %{ $esxi = Get-View $_
				  [array]$report += Get-VMHostEsxiVersion $esxi $dc.Name
			}
		}
		
		Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue
	}
	
	$report | Select Store,VMHost,ESXiVersion,BuildVersion | Export-Csv C:\temp\esxiversions.csv -NoTypeInformation
	
}catch{
	Write-Error $_
	throw $Error[0]
}