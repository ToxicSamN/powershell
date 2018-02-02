<#
.SYNOPSIS
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
#>
Param(
	[Parameter(Mandatory=$true,ValueFromPipeline=$True,Position=1)]
		[string]$Name=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=2)]
		[string]$MacAddress=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=3)]
		[string]$DHCPServer=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=4)]
		[string]$ScopeName=$null
)
Function New-DHCPReservation(){
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$True,Position=1)]
			[string]$Name=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=2)]
			[string]$MacAddress=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=3)]
			[string]$DHCPServer=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=4)]
			[string]$ScopeName=$null
	)
	
	Begn{
		#Initialize parameters
		[array]$rtrn = @()
	}
	Process{
		try{
			$tmp = $null
			$MacAddress = $MacAddress.Replace(":","")
			$MacAddress = $MacAddress.Replace("-","")
			$scope = Get-DhcpServerv4Scope -ComputerName $DHCPServer | ?{$_.Name -like "*$($ScopeName)*"}
			If(-not [string]::IsNullOrEmpty($scope)){
				$exRes = Get-DhcpServerv4Reservation -ClientId $MacAddress -ComputerName $DHCPServer -ScopeId $scope
				If(-not [string]::IsNullOrEmpty($exRes)){
					$freeIp = Get-DhcpServerv4FreeIPAddress -ScopeId $scope[0] -NumAddress 1 -ComputerName $DHCPServer
					$tmp = Add-DhcpServerv4Reservation -Name $Name -IPAddress $freeIp -ScopeId $scope[0] -ComputerName $DHCPServer -ClientId $MacAddress -Description "DHCP Reservation for ESXi Host $($Name) : $($MacAddress)" -Confirm:$false
					$rtrn += $tmp
				}
			}
		}
		catch{
			$_.Exception.Message
		}
	}
	End{
		If($rtrn.Count -eq 0){ return $null }
		Else{ return $rtrn }
	}
}

New-DHCPReservation -Name $Name -MacAddress $MacAddress -DHCPServer $DHCPServer -ScopeName $ScopeName