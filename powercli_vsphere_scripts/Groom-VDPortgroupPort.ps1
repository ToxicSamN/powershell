#Distributed Portgroup port count grooming
#This script will connect the specified vCenter and scan all portgroups o all VD Switches and set
#  the port count to portsUsed + 30. This allows for 30 ports of additional growth.
#  This script should run every night and make the adjustments. With VDS 5.5+ there is an option
#  to enable auto growth of portgroups. But until Nordstrom environment is setup to do this 
#  then an automated script will need to run to keep the portgroup port counts in check so we
#  don't hit vcenter maximums any longer.
Param(
	[string]$vCenter=$null
)
Import-Module UcgModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
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
   $snapinList += "VMware.VumAutomation"

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
LoadSnapins
LoadModules
cls
[array]$report = @()
$vi = Connect-VIServer -Server $vCenter -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

$vmKernels = Get-VMHostNetworkAdapter -VMKernel #Only needed for PowerCLI 5.5, PowerCLI 6.0 this line can be removed
Get-VDPortgroup | ?{-not $_.IsUplink} | %{ $pg = $_
	[array]$vmks,[array]$nadps = @(),@()
	[array]$nadps = Get-NetworkAdapter -RelatedObject $pg
	#PowerCLI 6 this line below works, but PCLI 5.5 I have to go about it a different way
	#[array]$vmks = Get-VMHostNetworkAdapter -PortGroup $pg
	#powerCLI 5.5 work around until all RemoteUCG and Scripty server gets updated to PowerCLI 6.0
	$vmks = $vmKernels | ?{$_.PortGroupName -eq $pg.Name}
	$outNull = $pg | Set-VDPortgroup -NumPorts ($nadps.Count+$vmks.Count+30)
}
Disconnect-VIServer -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
#$report | Export-Csv C:\temp\groomPgWhatIf.csv -NoTypeInformation