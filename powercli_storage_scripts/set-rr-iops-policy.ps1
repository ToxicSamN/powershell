
Param(
[Parameter(Mandatory=$true,Position=1)][string]$vmhost=$null,
[Parameter(Mandatory=$true,Position=2)][long]$iops=0
)
Function SyntaxUsage($message){
Write-Host "Set-RR-IOPS-Policy.ps1 sets storage devices Round Robin path policy and iops policy.`n
Set-RR-IOPS-Policy.ps1 `n
  REQUIRED PARAMETERS
  --------------------
  [-vmhost:{ESXi host name}]  Specify ESXi Host Name
  [-array:{'VMW_SATP_SYMM'|'VMW_SATP_ALUA_CX'|'VMW_SATP_DEFAULT_AA'}] Choose one array type
  [-iops:{Number Value}] Used in setting the IOPS Policy`n
  
   OPTIONAL PARAMETERS
  --------------------
  [-credential(optional)]
  [-norr (optional)] Opt out of setting Round Robin Policy
  [-noiops (optional)] Opt out of setting IOPS policy
 `n
Example: Set-RR-IOPS-Policy.ps1 -vmhost a0319vm9a,a0319vm9b -iops 1 -array VMW_SATP_SYMM -credential
[ For the two hosts a0319vm9a and a0319vm9b and the VMW_SATP_SYMM luns attached to these hosts, this sets the path policy to Round Robin and sets the IOPS Policy to 1 ]`n

Parameters:                                 Description:

 -vmhost:{ESXi host name}                   REQUIRED parameter
                                             Connects to the specified ESXi Host(s).`n
 -array:{VMW SATP Array}                    REQUIRED - Specifies the array to configure/ 
                                             There are specific Entries allowed:
                                                VMW_SATP_SYMM
                                                VMW_SATP_ALUA_CX
                                                VMW_SATP_DEFAULT_AA`n
 -iops:{Number Value}                       OPTIONAL - Used to set IOPS per host per lun. Must be greater than 0`n
 -noiops                                    OPTIONAL - Skips applying the IOPS policy.`n
 -norr                                      OPTIONAL - Skips applying the Round Robin policy.`n
 -credential                                OPTIONAL - Prompt to enter credentials to login
                                             to ESXi Host.`n
`n"

Write-Host $message
Exit 99
}

#  PARSE USER CLI ARGUMENTS
#$args = @("-vcenter","a0319t172","-array","VMW_SATP_SYMM","-norr","-iops","1","-cluster",@("testcluster","cl0319ucg04t001"))
#[array]$vcenter = $null
#[array]$vmhost = $null
#[string]$array = $null
[bool]$prompforcred = $false
[array]$datacenter = $null
[array]$cluster = $null
#[long]$iops = $null
[bool]$norr = $false
[bool]$noiops = $false
[bool]$clusterIsNull = $true
[System.Management.Automation.PSCredential] $psCred = $null

$targs = $args
$carg = 0
$args | %{ 
			$carg++
			[string]$tempstr = $_
			If ($tempstr.StartsWith("-"))
			{[string]$tempvar = $_
				Switch -wildcard ($tempvar.ToLower()){
				#"-vcenter*" {[array]$vcenter = $targs[$carg]}
				#"-vmhost*" {[array]$vmhost = $targs[$carg]}
				"-datacenter*" {[array]$datacenter = $targs[$carg]}
				"-cluster*" {[array]$cluster = $targs[$carg];[bool]$clusterIsNull = $false }
				"-credential*" {[bool]$prompforcred = $true}
				"-noiops*" {[bool]$noiops = $true}
				"-norr*" {[bool]$norr = $true}
				}
			}
			Else{
				Switch ($tempstr.ToLower()){
					"?" { SyntaxUsage }
					"help" { SyntaxUsage }
					"/?" { SyntaxUsage }
				}
			}
		 }
#If(($vcenter -and $vmhost) -or ($vcenter -eq $null -and $vmhost -eq $null)) { SyntaxUsage ("Must supply at least a -vcenter or a -vmhost parameter. You may not use both.`n")  }
If($noiops -eq $false -and $iops -eq $null){ SyntaxUsage ("Please supply an -iops number value or use the -noiops parameter to opt out of the iops policy.`n") }
If($iops -lt 1 -and $noiops -eq $false) { SyntaxUsage ("Please supply an -iops value greater than 0")}
If($vcenter) { [array]$Server = $vcenter }
If($vmhost ) { [array]$Server = $vmhost  }
##############################################################

cls
Write-Host "Loading the Script ..."
Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Import-Module UcgModule -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
cls

Function _Get-Datacenter($Name){ If($Name -eq $null){ return (Get-Datacenter) } Else { return (Get-Datacenter -Name $Name) }}
Function _Get-Cluster($Name,$Location){ If($Name -eq $null){ return (Get-VmCluster -Location $Location) } Else { return (Get-VmCluster -Name $Name -Location $Location) }}
Function Set-PathPolicy([string]$SATPArray, [string]$VMHost, [string]$ESXiVersion){

  If($ESXiVersion.StartsWith("4."))
  {
  	$EsxCLI = Get-EsxCli
	
	$hsh = @{}
	$devices = $EsxCLI.nmp.device.list() | ?{$_.StorageArrayType -like "VMW_SATP_*" -and $_.PathSelectionPolicy -notlike "*_RR*"}
	$devices | %{
		$tmpEAP = $ErrorActionPreference
		$ErrorActionPreference = "SilentlyContinue"
		$hsh.Add($_.StorageArrayType,$_.StorageArrayType) 
		$ErrorActionPreference = $tmpEAP
	}
	$hsh.Keys | %{ $SATPArray = $_
  		$EsxCLI.nmp.satp.setdefaultpsp($null,"VMW_PSP_RR ",$SATPArray)
	
		#$devices = $EsxCLI.nmp.device.list() | ?{ $_.StorageArrayType -eq $SATPArray -and ($_.PathSelectionPolicy -eq "VMW_PSP_FIXED_AP" -or $_.PathSelectionPolicy -eq "VMW_PSP_FIXED")};
		Write-Host "`nSetting PathSelectionPolicy to VMW_PSP_RR for host $($VMHost)"

		$devices | %{ $device = $_
			If($_){ $ret = $EsxCLI.nmp.device.setpolicy($null, $_.Device, "VMW_PSP_RR")}
		}
		$VMHostStorage = Get-VmHostStorage -VMHost $VMHost -Refresh #A refresh of the host storage is needed otherwise we output "..Changed from FIXED to FIXED.."
		$RefreshDevices = $EsxCLI.nmp.device.list() | ?{ $_.StorageArrayType -eq $SATPArray -and $_.PathSelectionPolicy -eq "VMW_PSP_RR"}
		$devices | %{
			$device = $_
			If($_){
				$deviceTable = ForEach-Object{$RefreshDevices} | ?{ $_.Device -eq $device.Device} | Select PathSelectionPolicy
				Write-Host "PathSelectionPolicy for '$($_.device)' has been set from ' $($_.PathSelectionPolicy)' to '$($deviceTable.PathSelectionPolicy)'"
			}
		}
	}
  }
  ElseIf($ESXiVersion.StartsWith("5."))
  {
  	$EsxCLI = Get-EsxCli -VMHost $VMHost
	
    $hsh = @{}
    $devices = $EsxCLI.storage.nmp.device.list() | ?{$_.StorageArrayType -like "VMW_SATP_*" -and $_.PathSelectionPolicy -notlike "*_RR*"}
    $devices | %{
      $tmpEAP = $ErrorActionPreference
      $ErrorActionPreference = "SilentlyContinue"
      $hsh.Add($_.StorageArrayType,$_.StorageArrayType) 
      $ErrorActionPreference = $tmpEAP
    }
    $hsh.Keys | %{ $SATPArray = $_
  		$EsxCLI.storage.nmp.satp.set($null,"VMW_PSP_RR",$SATPArray)
	
      #$devices = $EsxCLI.storage.nmp.device.list() | ?{ $_.StorageArrayType -eq $SATPArray -and ($_.PathSelectionPolicy -eq "VMW_PSP_FIXED_AP" -or $_.PathSelectionPolicy -eq "VMW_PSP_FIXED")};
      Write-Host "Setting PathSelectionPolicy to VMW_PSP_RR for host $($VMHost)"
    
      $devices | %{ $device = $_
        If($_){ $ret = $EsxCLI.storage.nmp.device.set($null, $_.Device, "VMW_PSP_RR") }
      }
      $VMHostStorage = Get-VmHostStorage -VMHost $VMHost -Refresh #A refresh of the host storage is needed otherwise we output "..Changed from FIXED to FIXED.."
      $RefreshDevices = $EsxCLI.storage.nmp.device.list() | ?{ $_.StorageArrayType -eq $SATPArray -and $_.PathSelectionPolicy -eq "VMW_PSP_RR"}
      $devices | %{ $device = $_
        If($_){
          $deviceTable = ForEach-Object{$RefreshDevices} | ?{ $_.Device -eq $device.Device} | Select PathSelectionPolicy
          Write-Host "PathSelectionPolicy for '$($_.device)' has been set from ' $($_.PathSelectionPolicy)' to '$($deviceTable.PathSelectionPolicy)'"
        }
      }
  	}
  }
  ElseIf($ESXiVersion.StartsWith("6."))
  {
  	$EsxCLI = Get-EsxCli -VMHost $VMHost
	
    $hsh = @{}
    $devices = $EsxCLI.storage.nmp.device.list() | ?{$_.StorageArrayType -like "VMW_SATP_*" -and $_.PathSelectionPolicy -notlike "*_RR*"}
    $devices | %{
      $tmpEAP = $ErrorActionPreference
      $ErrorActionPreference = "SilentlyContinue"
      $hsh.Add($_.StorageArrayType,$_.StorageArrayType) 
      $ErrorActionPreference = $tmpEAP
    }
    $hsh.Keys | %{ $SATPArray = $_
  		$EsxCLI.storage.nmp.satp.set($null,"VMW_PSP_RR",$SATPArray)
	
      #$devices = $EsxCLI.storage.nmp.device.list() | ?{ $_.StorageArrayType -eq $SATPArray -and ($_.PathSelectionPolicy -eq "VMW_PSP_FIXED_AP" -or $_.PathSelectionPolicy -eq "VMW_PSP_FIXED")};
      Write-Host "Setting PathSelectionPolicy to VMW_PSP_RR for host $($VMHost)"
    
      $devices | %{ $device = $_
        If($_){ $ret = $EsxCLI.storage.nmp.device.set($null, $_.Device, "VMW_PSP_RR") }
      }
      $VMHostStorage = Get-VmHostStorage -VMHost $VMHost -Refresh #A refresh of the host storage is needed otherwise we output "..Changed from FIXED to FIXED.."
      $RefreshDevices = $EsxCLI.storage.nmp.device.list() | ?{ $_.StorageArrayType -eq $SATPArray -and $_.PathSelectionPolicy -eq "VMW_PSP_RR"}
      $devices | %{ $device = $_
        If($_){
          $deviceTable = ForEach-Object{$RefreshDevices} | ?{ $_.Device -eq $device.Device} | Select PathSelectionPolicy
          Write-Host "PathSelectionPolicy for '$($_.device)' has been set from ' $($_.PathSelectionPolicy)' to '$($deviceTable.PathSelectionPolicy)'"
        }
      }
  	}
  }
}
Function Set-IOPolicy([string]$SATPArray, [string]$VMHost, [string]$ESXiVersion, [long]$iops){
  
	$EsxCLI = Get-EsxCli -VMHost $VMHost
  
  	Write-Host "`nSetting IOPS-Policy to '$($iops)' for $($VMHost)"
  
  	If($ESXiVersion.StartsWith("4.")){
		$hsh = @{}
		$devices = $EsxCLI.nmp.device.list() | ?{$_.StorageArrayType -like "VMW_SATP_*"}
		$devices | %{
			$tmpEAP = $ErrorActionPreference
			$ErrorActionPreference = "SilentlyContinue"
			$hsh.Add($_.StorageArrayType,$_.StorageArrayType) 
			$ErrorActionPreference = $tmpEAP
		}
		$hsh.Keys | %{ $SATPArray = $_
  			#$devices = $EsxCLI.nmp.device.list() | ?{ $_.StorageArrayType -eq $array -and $_.PathSelectionPolicy -eq "VMW_PSP_RR"}
			$devices | %{
				If($_){
					$config = $EsxCLI.nmp.roundrobin.getconfig($_.device)
					$preIO = $config.IOOperationLimit
					$ret = $EsxCLI.nmp.roundrobin.setconfig(0,$_.device,[long]$iops,"iops",$false)
					$config = $EsxCLI.nmp.roundrobin.getconfig($_.device)
					Write-Host "IOPS for $($_.device) on $($VMHost) has been set from '$($preIO)' to '$($config.IOOperationLimit)'"
				}
			}
		}
  	}
  	ElseIf($ESXiVersion.StartsWith("5.0")){
  		$hsh = @{}
		$devices = $EsxCLI.storage.nmp.device.list() | ?{$_.StorageArrayType -like "VMW_SATP_*"}
		$devices | %{
			$tmpEAP = $ErrorActionPreference
			$ErrorActionPreference = "SilentlyContinue"
			$hsh.Add($_.StorageArrayType,$_.StorageArrayType) 
			$ErrorActionPreference = $tmpEAP
		}
		$hsh.Keys | %{ $SATPArray = $_
			#$devices = $EsxCLI.storage.nmp.device.list() | ?{ $_.StorageArrayType -eq $array -and $_.PathSelectionPolicy -eq "VMW_PSP_RR"}
			$devices | %{
				If($_){
					$config = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.get($_.device)
					$preIO = $config.IOOperationLimit
					$ret = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.set(0,$_.device,[long]$iops,"iops",$false)
					$config = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.get($_.device)
					Write-Host "IOPS for $($_.device) on $($VMHost) has been set from '$($preIO)' to '$($config.IOOperationLimit)'"
				}
			}
		}
  	}
  	ElseIf($ESXiVersion.StartsWith("5.1")){
  		$hsh = @{}
		$devices = $EsxCLI.storage.nmp.device.list() | ?{$_.StorageArrayType -like "VMW_SATP_*"}
		$devices | %{
			$tmpEAP = $ErrorActionPreference
			$ErrorActionPreference = "SilentlyContinue"
			$hsh.Add($_.StorageArrayType,$_.StorageArrayType) 
			$ErrorActionPreference = $tmpEAP
		}
		$hsh.Keys | %{ $SATPArray = $_
			#$devices = $EsxCLI.storage.nmp.device.list() | ?{ $_.StorageArrayType -eq $array -and $_.PathSelectionPolicy -eq "VMW_PSP_RR"}
			$devices | %{
				If($_){
					$config = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.get($_.device)
					$preIO = $config.IOOperationLimit
					$ret = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.set(0,$null,$_.device,[long]$iops,"iops",0)
					$config = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.get($_.device)
					Write-Host "IOPS for $($_.device) on $($VMHost) has been set from '$($preIO)' to '$($config.IOOperationLimit)'"
				}
			}
		}
  	}
  	ElseIf($ESXiVersion.StartsWith("5.5")){
  		$hsh = @{}
      $devices = $EsxCLI.storage.nmp.device.list() | ?{$_.StorageArrayType -like "VMW_SATP_*"}
      $devices | %{
        $tmpEAP = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        $hsh.Add($_.StorageArrayType,$_.StorageArrayType) 
        $ErrorActionPreference = $tmpEAP
      }
      $hsh.Keys | %{ $SATPArray = $_
        #$devices = $EsxCLI.storage.nmp.device.list() | ?{ $_.StorageArrayType -eq $array -and $_.PathSelectionPolicy -eq "VMW_PSP_RR"}
        $devices | %{
          If($_){
            $config = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.get($_.device)
            $preIO = $config.IOOperationLimit
            $ret = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.set(0,$null,$_.device,[long]$iops,"iops",0)
            $config = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.get($_.device)
            Write-Host "IOPS for $($_.device) on $($VMHost) has been set from '$($preIO)' to '$($config.IOOperationLimit)'"
          }
        }
      }
  	} ElseIf($ESXiVersion.StartsWith("6")) {
  		$hsh = @{}
      $devices = $EsxCLI.storage.nmp.device.list() | ?{$_.StorageArrayType -like "VMW_SATP_*"}
      $devices | %{
        $tmpEAP = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        $hsh.Add($_.StorageArrayType,$_.StorageArrayType) 
        $ErrorActionPreference = $tmpEAP
      }
      $hsh.Keys | %{ $SATPArray = $_
        #$devices = $EsxCLI.storage.nmp.device.list() | ?{ $_.StorageArrayType -eq $array -and $_.PathSelectionPolicy -eq "VMW_PSP_RR"}
        $devices | %{
          If($_){
            $config = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.get($_.device)
            $preIO = $config.IOOperationLimit
            $ret = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.set(0,$null,$_.device,[long]$iops,"iops",0)
            $config = $EsxCLI.storage.nmp.psp.roundrobin.deviceconfig.get($_.device)
            Write-Host "IOPS for $($_.device) on $($VMHost) has been set from '$($preIO)' to '$($config.IOOperationLimit)'"
          }
        }
      }
    }
}

$hVIClient = $null
$loopCount = 0
If($prompforcred){ $psCred = (Get-Credential) }
$Server | %{
	Write-Host "Connecting to $($_)"
	If($prompforcred){
		Do{
			$hVIClient = Connect-VIServer -Server $_ -Credential $psCred -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
			If($hVIClient -eq $null) { Write-Host "Unable to Connect to server $($_). Please Try Again ... ($($loopCount+1)/3)"; $loopCount++; $psCred = (Get-Credential); }Else{$loopCount = 3}
		}While($loopCount -le 2)
		If($hVIClient -eq $null -and $loopCount -ge 3){ Exit 1 }
	}
	Else{
		Do{
			$hVIClient = Connect-VIServer -Server $_ -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 
			If($hVIClient -eq $null) { Write-Host "Unable to Connect to server $($_). Trying again ...($($loopCount+1)/3)"; $loopCount++; }Else{$loopCount = 3}
		}While($loopCount -le 2)
		If($hVIClient -eq $null -and $loopCount -ge 3){ Exit 1 }
	}
	If ($vmhost -eq $null){
		If($datacenter -eq $null){ 
			$tdc = Get-Datacenter | Select Name
			$tdc | %{ $tdcname = $_.Name
				$datacenter += $tdcname
			}
		}
		$datacenter | %{
			$DC = Get-Datacenter -Name $_ -ErrorAction SilentlyContinue
			If ($clusterIsNull){ $cluster = $null }
			If($cluster -eq $null){ 
				$tcl = Get-VmCluster -Location $DC -ErrorAction SilentlyContinue | Select Name 
				$tcl | %{ $tclname = $_.Name
					$cluster += $tclname
				}
			}
			$cluster | %{
				$CL = Get-VmCluster -Name $_ -Location $DC -ErrorAction SilentlyContinue
				If($CL -ne $null){
					$ESXiHost = Get-VMHost -Location $CL -Server $hVIClient -ErrorAction SilentlyContinue | Select Name,@{N="Version";E={$_.Extensiondata.Config.Product.Version}}
					$ESXiHost | %{
						If($norr -eq $false){
							Write-Host "`nApplying the Round Robin Policy for $($DC.Name) > $($CL.Name) > $($_.Name)`n"
							Set-PathPolicy -SATPArray $array -VMHost $_.Name -ESXiVersion $_.Version
						}
						If($noiops -eq $false -and $iops -ne $null){
							Write-Host "`nApplying the IOPS Policy for $($DC.Name) > $($CL.Name) > $($_.Name)"
							Set-IOPolicy -SATPArray $array -VMHost $_.Name -ESXiVersion $_.Version -iops $iops
						}
					}
				}
			}
		}
	}
	ElseIf ($vmhost -ne $null){
		$ESXiHost = Get-VMHost -Server $hVIClient | Select Name,@{N="Version";E={$_.Extensiondata.Config.Product.Version}}
		If($norr -eq $false){
			Write-Host "`nApplying the Round Robin Policy for $($ESXiHost.Name)`n"
			Set-PathPolicy -SATPArray $array -VMHost $ESXiHost.Name -ESXiVersion $ESXiHost.Version
		}
		If($noiops -eq $false -and $iops -ne $null){
			Write-Host "`nApplying the IOPS Policy for $($ESXiHost.Name)"
			Set-IOPolicy -SATPArray $array -VMHost $ESXiHost.Name -ESXiVersion $ESXiHost.Version -iops $iops
		}
	}				
	Disconnect-VIServer -Server $hVIClient.Name -Confirm:$false -ErrorAction SilentlyContinue
}
