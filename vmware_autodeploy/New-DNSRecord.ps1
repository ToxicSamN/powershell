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
		[string]$Domain=$null,
	[ValidateScript({
		if(-not (Test-Path $_)){ "" | Out-File -FilePath $_ -ErrorAction Stop; Test-Path $_ }
		else{$true}
	})]
	[alias("l")]
		[string]$Log = "\\a0319p184\UCG-Logs\New-DNSRecord.log"
)

Function New-DNSRecord(){
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
		[array]$rtrn = @()
		$tmp = $null
	}
	Process{
		#Write-Host "PROCESS"
		try{	
			#Write-Host "In TRY statement"
			$exRes = Get-DnsServerResourceRecord -Name $Name -ComputerName $DNSServer -ZoneName $Domain -ErrorAction SilentlyContinue
			If([string]::IsNullOrEmpty($exRes)){ #No DNS Entry
				Write-Log -Path $Log -Message "[$(Get-Date)]`tNo Existing DNS A Record found for $($Name)"
				Write-Log -Path $Log -Message "[$(Get-Date)]`tCreating a New DNS A and PTR Record for $($Name)"
				try {
					$tmp = Add-DnsServerResourceRecordA -Name $Name -IPv4Address $IPAddress -ZoneName $Domain -ComputerName $DNSServer -CreatePtr:$true
					#$ipad = $tmp.RecordData.IPv4Address.IPAddressToString
					#$zoneName = "$($ipad.split(".")[0]).in-addr.arpa"
					#$rvipName = "$($ipad.split(".")[1]).$($ipad.split(".")[2]).$($ipad.split(".")[3])"
					#Add-DnsServerResourceRecordPtr -Name $rvipName -ZoneName $zoneName -AllowUpdateAny -PtrDomainName "$($tmp.hostname).nordstrom.net" -ComputerName "10.16.172.129"
				} catch {
					sleep 3
					$tmp = Add-DnsServerResourceRecordA -Name $Name -IPv4Address $IPAddress -ZoneName $Domain -ComputerName $DNSServer -CreatePtr:$true
				}
				$tmp = Get-DnsServerResourceRecord -Name $Name -ZoneName $Domain -ComputerName $DNSServer
				Write-Log -Path $Log -Message $tmp
			}ElseIf($exRes.RecordData.IPv4Address.IPAddressToString -eq $IPAddress){ #DNS Entry exists with the same IP
				Write-Log -Path $Log -Message "[$(Get-Date)]`tExisting DNS A Record found for $($Name) and $($IPAddress)"
				Write-Log -Path $Log -Message $exRes
				Write-Warning "DNS Record Already Exists"
				#$exRes | ft -AutoSize
				$tmp = $exRes
			}Else{ #DNS Entry Exists but has a different IP Address
				Write-Log -Path $Log -Message "[$(Get-Date)]`tExisting DNS Record for $($Name) but with a Different IP Address"
				Write-Log -Path $Log -Message $exRes
				Write-Log -Path $Log -Message "[$(Get-Date)]`tModifying Existing DNS Record for $($Name) with new IP address $($IPAddress)"
				Write-Warning "Existing DNS Record with a Different IP Address. Creating the new DNS record any way, please verify if the below DNS Record is needed."
				#$exRes | ft -AutoSize
				try {
					$tmp = Add-DnsServerResourceRecordA -Name $Name -IPv4Address $IPAddress -ZoneName $Domain -ComputerName $DNSServer -CreatePtr:$true
					#$ipad = $tmp.RecordData.IPv4Address.IPAddressToString
					#$zoneName = "$($ipad.split(".")[0]).in-addr.arpa"
					#$rvipName = "$($ipad.split(".")[1]).$($ipad.split(".")[2]).$($ipad.split(".")[3])"
					#Add-DnsServerResourceRecordPtr -Name $rvipName -ZoneName $zoneName -AllowUpdateAny -PtrDomainName "$($tmp.hostname).nordstrom.net" -ComputerName "10.16.172.129"
				} catch {
					sleep 3
					$tmp = Add-DnsServerResourceRecordA -Name $Name -IPv4Address $IPAddress -ZoneName $Domain -ComputerName $DNSServer -CreatePtr:$true
				}
				$tmp = Get-DnsServerResourceRecord -Name $Name -ZoneName $Domain -ComputerName $DNSServer
				Write-Log -Path $Log -Message $tmp
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

New-DNSRecord -Name $Name -IPAddress $IPAddress -DNSServer $DNSServer -Domain $Domain