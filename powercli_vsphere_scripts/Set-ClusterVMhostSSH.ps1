<#
.SYNOPSIS
    Turns SSH on or off for an entire cluter.
.DESCRIPTION
    This script will connect to the specified vCenter Server and turn SSH on or off for the specified
	cluster.
.PARAMETER vCenter
    MANDATORY
	Used to specify the vCenter Server that contains the target cluster.
.PARAMETER Cluster
    MANDATORY
	Used to sepcify the target cluster within which to turn on or off SSH on all hosts.
.PARAMETER Enable
    Switch paramter used to specify wether SSH should be turned on.
.PARAMETER Disable
    Switch paramter used to specify wether SSH should be turned off.
.EXAMPLE
    C:\PS> Set-ClusterVMhostSSH.ps1 -vCenter 319NonProdVcenter -Cluster cl0319win07t001 -Enable
		Turns on SSH for all hosts in the cl0319win07t001 cluster in the 319NonProdVcenter vcenter.
    C:\PS> Set-ClusterVMhostSSH.ps1 -vCenter 319NonProdVcenter -Cluster cl0319win07t001 -Disable
		Turns off SSH for all hosts in the cl0319win07t001 cluster in the 319NonProdVcenter vcenter.
.NOTES
    Author: Sammy Shuck
    Date:   June 06, 2016
#>

Param(
	[Parameter(Mandatory=$true)]
	[string]$vCenter,
	[Parameter(Mandatory=$true)]
	[string]$Cluster,
	[Parameter(Mandatory=$false)]
	[switch]$Enable,
	[Parameter(Mandatory=$false)]
	[switch]$Disable
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
LoadSnapins
LoadModules
Import-Module UcgModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
cls 

$clObj = $null
[string[]]$errorHost = $null

try{	
	#Validate action
	If(($Enable -and $Disable) -or (-not $Enable -and -not $Disable)){ throw "Unable to determine the action based on Enable=$($Enable), Disable=$($Disable)" }	
	
	#Connect to vCenter
	$vi = Connect-VIServer -Server $vCenter -WarningAction SilentlyContinue
	
	$cl = Get-View -ViewType ClusterComputeResource -Filter @{"Name"="$($Cluster)"}
	If([string]::IsNullOrEmpty($cl)){ throw "Unable to locate cluster $($Cluster) in vCenter $($vCenter)" }
	
	$cl.Host | Get-VIObjectByVIView | %{ $esxi = $_
		If($Enable){
			try{ Start-VMHostService -HostService ($esxi | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"}) }
			catch{ [string[]]$errorHost += "$($esxi.Name) : Starting SSH : $($_.exception.message)" }
		}
		ElseIf($Disable){
			try{ Stop-VMHostService -HostService ($esxi | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"}) -Confirm:$false }
			catch{ [string[]]$errorHost += "$($esxi.Name) : Stopping SSH : $($_.exception.message)" }
		}
	}
	If(-not [string]::IsNullOrEmpty($errorHost)){
		 $errorHost | Write-Host $_ -ForegroundColor Yellow -BackgroundColor Black
	}
}catch{
	Write-Error $_.Exception.Message
}