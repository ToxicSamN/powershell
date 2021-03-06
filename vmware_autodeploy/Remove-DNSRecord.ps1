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
		[string]$IPAddress=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=3)]
		[string]$DNSServer=$null,
	[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=4)]
		[string]$Domain=$null
)

Function Remove-DNSRecord(){
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=1)]
			[string]$Name=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=2)]
			[string]$IPAddress=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=3)]
			[string]$DNSServer=$null,
		[Parameter(Mandatory=$true,ValueFromPipeline=$False,Position=4)]
			[string]$Domain=$null
	)
	
	Begin{
		#Initialize parameters
		#Write-Host "BEGIN"
		
		#ReverseLookup Zones:
			#10.in-addr.arpa
			#172.in-addr.arpa
			#168.192.in-addr.arpa
			#181.161.in-addr.arpa
		$revLookupZones = @{}
			$revLookupZones.Add("10","10.in-addr.arpa")
			$revLookupZones.Add("172","172.in-addr.arpa")
			$revLookupZones.Add("192","168.192.in-addr.arpa")
			$revLookupZones.Add("161","181.161.in-addr.arpa")
		[array]$rtrn = @()
		$tmp = $null
	}
	Process{
		#Write-Host "PROCESS"
		try{	
			#Write-Host "In TRY statement"
      if ($Name -like "*.nordstrom.net") { $Name = $Name.replace(".nordstrom.net", "") }
			$exRes = Get-DnsServerResourceRecord -Name $Name -ComputerName $DNSServer -ZoneName $Domain -ErrorAction SilentlyContinue
			If(-not [string]::IsNullOrEmpty($exRes)){ #DNS Entry
				$chk = $null
				$chk = $exRes | ?{$_.RecordData.IPv4Address.IPAddressToString -eq $IPAddress}
				If(-not [string]::IsNullOrEmpty($chk)){
					#I have the correct DNS A Record, Now lets get the DNS PTR Record
					$tmpAry = $chk.RecordData.IPv4Address.IPAddressToString.Split(".")
					$ZoneName = $revLookupZones[$tmpAry[0]]
					$revIP = ($tmpAry[3]+"."+$tmpAry[2])
					If(-not $ZoneName.StartsWith(($tmpAry[1]+"."+$tmpAry[0]))){ $revIP = ($revIP+"."+$tmpAry[1]) }
          $ptrRecord = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -Node $revIP -RRType Ptr -ErrorAction SilentlyContinue
					If(-not [string]::IsNullOrEmpty($ptrRecord)){
						#Remove PTR record
						Remove-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -InputObject $ptrRecord -Confirm:$false -Force
					}
					#Remove HOST A record
          Remove-DnsServerResourceRecord -ZoneName $Domain -ComputerName $DNSServer -InputObject $exRes -Confirm:$false -Force
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
		If($rtrn.Count -eq 0){ return $null }
		Else{ return $rtrn }
	}
}

Remove-DNSRecord -Name $Name -IPAddress $IPAddress -DNSServer $DNSServer -Domain $Domain