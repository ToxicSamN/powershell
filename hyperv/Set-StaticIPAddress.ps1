Param(
	$ComputerName=$null,
	$NetworkAdapterName="Ethernet",
	$cred=(Get-Credential)
)


if ($ComputerName -eq $null){ $ComputerName = $env:ComputerName }

Invoke-Command $ComputerName -Credential $cred -ScriptBlock {
	Param( $NetworkAdapterName )
	$netadapt = Get-NetAdapter -Name $NetworkAdapterName
	$ipaddr = $netadapt | Get-NetIPAddress -AddressFamily IPV4 | ?{$_.prefixOrigin -eq "Dhcp"}
	$defGateway = Get-NetRoute -AddressFamily IPV4 -DestinationPrefix "0.0.0.0/0"
	$dnsServer = $netadapt | Get-DnsClientServerAddress -AddressFamily IPV4
	if (-not [string]::IsNullOrEmpty($ipaddr)){
		$netadapt | Remove-NetIPAddress -Confirm:$false
		Remove-NetRoute -AddressFamily IPV4 -DestinationPrefix "0.0.0.0/0" -Confirm:$false
		$staticIP = $netadapt | New-NetIPAddress -AddressFamily IPv4 -IPAddress $ipaddr.IPv4Address -DefaultGateway $defGateway.NextHop -PrefixLength $ipaddr.PrefixLength -Confirm:$false
		$netadapt | Set-DnsClientServerAddress -ServerAddresses $dnsServer.ServerAddresses -Confirm:$false
	}
	$netadapt | Get-NetIPConfiguration
} -ArgumentList $NetworkAdapterName