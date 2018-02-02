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
	[Parameter(Mandatory=$False,ValueFromPipeline=$False,Position=1)]
		[string]$Name=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=2)]
		[string]$MacAddress=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=3)]
		[string]$DHCPServer=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=4)]
		[string]$ScopeName=$null
)

Function Remove-DHCPReservation(){
	Param(
		[Parameter(Mandatory=$False,ValueFromPipeline=$False,Position=1)]
			[string]$Name=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=2)]
			[string]$MacAddress=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=3)]
			[string]$DHCPServer=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=4)]
			[string]$ScopeName=$null
	)
	
	Begin{
		#Initialize parameters
		#Write-Host "BEGIN"
		[array]$rtrn = @()
		$tmp = $null
	}
	Process{
		#Write-Host "PROCESS"
		try{	
		#	Write-Host "In TRY statement"
			$MacAddress = $MacAddress.Replace(":","")
			$MacAddress = $MacAddress.Replace("-","")
			$scope = Get-DhcpServerv4Scope -ComputerName $DHCPServer | ?{$_.Name -like "*$($ScopeName)*"}
			If(-not [string]::IsNullOrEmpty($scope)){
				$exRes = Get-DhcpServerv4Reservation -ClientId $MacAddress -ComputerName $DHCPServer -ScopeId $scope[0].ScopeId -ErrorAction SilentlyContinue
				If(-not [string]::IsNullOrEmpty($exRes)){
					$tmp = Remove-DhcpServerv4Reservation -ScopeId $exRes.ScopeId -ComputerName $DHCPServer -ClientId $exRes.ClientId
				}
			}
		}
		catch{
		#Write-Host "In Catch Statement"
			Write-Error $_.Exception.Message
		}
		finally{
			If(-not [string]::IsNullOrEmpty($tmp)){
				[array]$rtrn += $tmp
			}
			$tmp = $null
		}
	}
	End{
		#Write-Host "PROCESS"
		return $exRes
	}
}

Remove-DHCPReservation -Name $Name -MacAddress $MacAddress -DHCPServer $DHCPServer -ScopeName $ScopeName