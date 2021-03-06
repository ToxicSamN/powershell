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
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=1)]
		[string]$Name=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=2)]
		[string]$MacAddress=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=3)]
		[string]$DHCPServer=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=4)]
		[string]$ScopeName=$null,
	[ValidateScript({
		if(-not (Test-Path $_)){ "" | Out-File -FilePath $_ -ErrorAction Stop; Test-Path $_ }
		else{$true}
	})]
	[alias("l")]
		[string]$Log = "\\a0319p184\UCG-Logs\New-DHCPReservation.log"
)
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
Function New-DHCPReservation(){
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=1)]
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
				If([string]::IsNullOrEmpty($exRes)){
					Write-Log -Path $Log -Message "[$(Get-Date)]`tNo Existing DHCP Reservation based on MAC Address"
					#No reservation based on provided MAC, so let's look for an existing DNS record and then lokup reservations based on IP address
					$exRes = try{Get-DhcpServerv4Reservation -IPAddress (Test-Connection -ComputerName $Name -Count 1 -ErrorAction SilentlyContinue | Select @{Name='IPAddressToString';Expression={$_.IPV4Address.IPAddressToString}}).IPAddressToString -ComputerName $DHCPServer -ErrorAction SilentlyContinue}catch{$null}
					If([string]::IsNullOrEmpty($exRes)){					
						Write-Log -Path $Log -Message "[$(Get-Date)]`tNo Existing DHCP Reservation based on IP Address"
						Write-Log -Path $Log -Message "[$(Get-Date)]`tCreating a New DHCP reservation"
						$freeIp = Get-DhcpServerv4FreeIPAddress -ScopeId $scope[0].ScopeId -ComputerName $DHCPServer
						Write-Log -Path $Log -Message "[$(Get-Date)]`tFree DHCP IP Address"
						$tmp = Add-DhcpServerv4Reservation -Name $Name -IPAddress $freeIp -ScopeId $scope[0].ScopeId -Type DHCP -ComputerName $DHCPServer -ClientId $MacAddress -Description "DHCP Reservation for ESXi Host $($Name) : $($MacAddress)" -Confirm:$false
						$tmp = Get-DhcpServerv4Reservation -ScopeId $scope[0].ScopeId -ComputerName $DHCPServer -ClientId $MacAddress
						$optPol012 = Set-DhcpServerv4OptionValue -ReservedIP $tmp.IPAddress -OptionId 12 -Value $Name -ComputerName $DHCPServer -Confirm:$false
						$tmp = Get-DhcpServerv4Reservation -ScopeId $scope[0].ScopeId -ComputerName $DHCPServer -ClientId $MacAddress
						Write-Log -Path $Log -Message "[$(Get-Date)]`tCreated a new DHCP Reservation"
						Write-Log -Path $Log -Message $tmp
					}Else{
						Write-Log -Path $Log -Message "[$(Get-Date)]`tExisting DHCP Reservation based on IP Address found"
						Write-Log -Path $Log -Message $exRes
						Write-Log -Path $Log -Message "[$(Get-Date)]`tModifying Existing DHCP Reservation to have the new MAC Address $($MacAddress)"
						$tmp = $exRes | Set-DhcpServerv4Reservation -Name $Name -ClientId $MacAddress -ComputerName $DHCPServer -Type DHCP -Description "DHCP Reservation for ESXi Host $($Name) : $($MacAddress)" -Confirm:$false
						$tmp = Get-DhcpServerv4Reservation -ScopeId $scope[0].ScopeId -ComputerName $DHCPServer -ClientId $MacAddress
						$optPol012 = Set-DhcpServerv4OptionValue -ReservedIP $tmp.IPAddress -OptionId 12 -Value $Name -ComputerName $DHCPServer -Confirm:$false
						Write-Log -Path $Log -Message $tmp
					}
				}Else{
					Write-Log -Path $Log -Message "[$(Get-Date)]`tExisting DHCP Reservation based on MAC Address found"
					Write-Log -Path $Log -Message $exRes
					Write-Log -Path $Log -Message "[$(Get-Date)]`tEnsuring the Existing DHCP Reservation is configured properly"
					$tmp = $exRes | Set-DhcpServerv4Reservation -Name $Name -ComputerName $DHCPServer -Type DHCP -Description "DHCP Reservation for ESXi Host $($Name) : $($MacAddress)" -Confirm:$false
					$tmp = Get-DhcpServerv4Reservation -ScopeId $scope[0].ScopeId -ComputerName $DHCPServer -ClientId $MacAddress
					$optPol012 = Set-DhcpServerv4OptionValue -ReservedIP $tmp.IPAddress -OptionId 12 -Value $Name -ComputerName $DHCPServer -Confirm:$false
					Write-Log -Path $Log -Message $tmp
				}
			}
		}
		catch{
		#Write-Host "In Catch Statement"
			Write-Log -Path $Log -Message "[$(Get-Date)]`tError:`t$($_.Exception.Message)"
			Write-Error $_.Exception.Message
			throw $_.Exception.Message
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
		If($rtrn.Count -eq 0){ return $null }
		Else{ return $rtrn }
	}
}

try{ New-DHCPReservation -Name $Name -MacAddress $MacAddress -DHCPServer $DHCPServer -ScopeName $ScopeName }catch{ return throw }