[cmdletbinding()]
Param(
	[string[]]$InterfaceName = @(),
	[array]$Nodes = @()
)

$script_block = {
Param(
	[string[]]$InterfaceName = @()
)
	Get-NetAdapter | ?{[string[]]$InterfaceName -contains $_.Name} | Select Name,InterfaceDescription,ifIndex,Status,MacAddress,LinkSpeed,@{n="ServerName";e={$env:ComputerName}}
}

do{

    $report = Invoke-Command $Nodes -ScriptBlock $script_block -ArgumentList @($InterfaceName)
	
    cls
    $report | ft -a
    $report| measure
    Sleep -Seconds 5
}While($true)