Param (
	[Parameter(Mandatory=$True,ValueFromPipeline=$False,Position=1)]
		$VMHost=$null,
	[Parameter(Mandatory=$True,ValueFromPipeline=$False,Position=2)]
		[array]$RDMDeviceIds = @()
)

function Get-InstallPath {
#Function provided by VMware used by PowerCLI to initialize Snapins
# Initialize-PowerCLIEnvironment.ps1
   $regKeys = Get-ItemProperty "hklm:\software\VMware, Inc.\VMware vSphere PowerCLI" -ErrorAction SilentlyContinue
   
   #64bit os fix
   if($regKeys -eq $null){
      $regKeys = Get-ItemProperty "hklm:\software\wow6432node\VMware, Inc.\VMware vSphere PowerCLI"  -ErrorAction SilentlyContinue
   }

   return $regKeys.InstallPath
}
function LoadSnapins(){
   [xml]$xml = Get-Content ("{0}\vim.psc1" -f (Get-InstallPath))
   $snapinList = Select-Xml  "//PSSnapIn" $xml |%{$_.Node.Name }

   $loaded = Get-PSSnapin -Name $snapinList -ErrorAction SilentlyContinue | % {$_.Name}
   $registered = Get-PSSnapin -Name $snapinList -Registered -ErrorAction SilentlyContinue  | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   foreach ($snapin in $registered) {
      if ($loaded -notcontains $snapin) {
         Add-PSSnapin $snapin -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      }

      # Load the Intitialize-<snapin_name_with_underscores>.ps1 file
      # File lookup is based on install path instead of script folder because the PowerCLI
      # shortuts load this script through dot-sourcing and script path is not available.
      $filePath = "{0}Scripts\Initialize-{1}.ps1" -f (Get-InstallPath), $snapin.ToString().Replace(".", "_")
      if (Test-Path $filePath) {
         & $filePath
      }
   }
}
function LoadModules(){
   [xml]$xml = Get-Content ("{0}\vim.psc1" -f (Get-InstallPath))
   $moduleList = Select-Xml  "//PSModule" $xml |%{$_.Node.Name }

   $loaded = Get-Module -Name $moduleList -ErrorAction SilentlyContinue | % {$_.Name}
   $registered = Get-Module -Name $moduleList -ListAvailable -ErrorAction SilentlyContinue  | % {$_.Name}
   $notLoaded = $registered | ? {$loaded -notcontains $_}
   
   foreach ($module in $registered) {
      if ($loaded -notcontains $module) {
         Import-Module $module -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      }
   }
}
Function Unmount-RDMDevice(){
	Param(
		[Parameter(Mandatory=$True,ValueFromPipeline=$True,Position=1)]
			[string]$DeviceId = $null, #Mandatory Parameter
		[Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=2)]
			[Boolean]$NoPersist = $false, #Optional Paramaeter
		[Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=3)]
			[switch]$ESXi50 = $false, #Optional Paramaeter
		[Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=4)]
			[switch]$ESXi55 = $false #Optional Paramaeter
	)
	
	Begin{
		[array]$rtrn = @()
		$esxcli = Get-EsxCli
	}
	Process{
		Try{
			$chk = $null
			Write-Host "`nPROCESS: Unmount Device $($DeviceId)"
			If($ESXi55){
				$esxcli.Storage.Core.Device.Set($null,$DeviceId,$null,$null,$NoPersist,$null,$null,$null,"off")
			}ElseIf($ESXi50){
				$esxcli.Storage.Core.Device.Set($DeviceId,$null,$NoPersist,"off")
			}
			$chk = $esxcli.Storage.Core.Device.list($DeviceId)
			If([string]::IsNullOrEmpty($chk.DevfsPath) -and $chk.Status -eq "off"){
				Write-Host "COMPLETE: Unmount Device $($DeviceId)"
				$tmp = $chk
			}
		}
		Catch{
			$tmp = $null
			Write-Error $_.Exception.Message
		}
		Finally{
			If(-not [string]::IsNullOrEmpty($tmp)){
				[array]$rtrn += $tmp
			}
			$tmp = $null
		}
	}
	End{
		return $rtrn
	}	
}
cls
LoadSnapins
LoadModules
Import-Module UcgModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue
cls

If(-not [string]::IsNullOrEmpty($VMHost)){
	Switch(($VMHost.GetType().FullName)){
		{"VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl"}	{$viName = $VMHost.Name}
		{"VMware.Vim.HostSystem"}	{$viName = $VMHost.Name}
		{"VMware.VimAutomation.ViCore.Impl.V1.VIServerImpl"}	{$vi = $VMHost}
		{"System.String"}	{$viName = $VMHost}
		Default {$viName = $null}
	}
	Disconnect-VIServer * -Confirm:$false -ErrorAction SilentlyContinue
	$vi = Connect-VIServer -Server $viName -ErrorAction Stop
	
	$esxi = Get-View -ViewType HostSystem -Server $vi
	
	If($RDMDeviceIds.Count -gt 0){
		If($RDMDeviceIds.Count -eq 1){
			#use wildcard method on index 0
			#Check for naa.
			If(-not $RDMDeviceIds[0].StartsWith("naa.")){ $RDMDeviceIds[0] = "naa.$($RDMDeviceIds[0])" }
			
			[array]$unmountLuns = $esxi.Config.StorageDevice.ScsiLun | ?{$_.CanonicalName -like "$($RDMDeviceIds[0])*" -and $_.DevicePath -like "/vmfs/devices/disks/$($RDMDeviceIds[0])*"}
			
		}ElseIf($RDMDeviceIds.Count -gt 1){
			[array]$unmountLuns = @()
			$RDMDeviceIds | %{ $dev = $_
				If(-not $dev.StartsWith("naa.")){ $dev = "naa.$($dev)" }
				$unmountLuns += $esxi.Config.StorageDevice.ScsiLun | ?{$_.CanonicalName -like "$($dev)*" -and $_.DevicePath -like "/vmfs/devices/disks/$($dev)*"}
			}
		}
		If($esxi.Config.Product.Version -like "5.0*"){
			$unmountLuns.CanonicalName | Unmount-RDMDevice -ESXi50
		}
		ElseIf($esxi.Config.Product.Version -like "5.5*"){
			$unmountLuns.CanonicalName | Unmount-RDMDevice -ESXi55
		}
	}
	
	Disconnect-VIServer -Server $vi.Name -Confirm:$false -ErrorAction SilentlyContinue
}